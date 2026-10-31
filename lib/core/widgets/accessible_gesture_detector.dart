import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../haptics/haptic_patterns.dart';
import '../haptics/haptic_service.dart';
import '../audio/tts_service.dart';

/// Wraps application screens with global blind-accessible gestures:
/// - **2-Finger Tap:** Instantly silences/stops active speech (Mute).
/// - **3-Finger Tap:** Announces current time and device battery percentage.
class AccessibleGestureDetector extends StatefulWidget {
  final Widget child;
  final TtsService ttsService;
  final HapticService hapticService;
  final String languageCode;

  const AccessibleGestureDetector({
    super.key,
    required this.child,
    required this.ttsService,
    required this.hapticService,
    this.languageCode = 'mr',
  });

  @override
  State<AccessibleGestureDetector> createState() => _AccessibleGestureDetectorState();
}

class _AccessibleGestureDetectorState extends State<AccessibleGestureDetector> {
  final Set<int> _activePointers = {};
  int _maxPointersDuringGesture = 0;
  DateTime _lastGestureTrigger = DateTime.now();
  final Battery _battery = Battery();

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length > _maxPointersDuringGesture) {
      _maxPointersDuringGesture = _activePointers.length;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _evaluateGesture();
      _maxPointersDuringGesture = 0;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _maxPointersDuringGesture = 0;
    }
  }

  void _evaluateGesture() {
    final now = DateTime.now();
    if (now.difference(_lastGestureTrigger) < const Duration(milliseconds: 600)) {
      return;
    }

    if (_maxPointersDuringGesture == 2) {
      _lastGestureTrigger = now;
      _handleTwoFingerTap();
    } else if (_maxPointersDuringGesture >= 3) {
      _lastGestureTrigger = now;
      _handleThreeFingerTap();
    }
  }

  Future<void> _handleTwoFingerTap() async {
    // 2-finger tap: Instantly Mute / Silence TTS
    await widget.ttsService.stop();
    await widget.hapticService.trigger(HapticPattern.lightTap);
  }

  Future<void> _handleThreeFingerTap() async {
    await widget.hapticService.trigger(HapticPattern.selectionClick);

    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now);
    int batteryLevel = 80;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {}

    final isMr = widget.languageCode.startsWith('mr');
    final isHi = widget.languageCode.startsWith('hi');

    String announcement;
    if (isMr) {
      announcement = 'सध्याची वेळ $timeStr. बॅटरी $batteryLevel टक्के शिल्लक आहे.';
    } else if (isHi) {
      announcement = 'वर्तमान समय $timeStr. बैटरी $batteryLevel प्रतिशत शेष है।';
    } else {
      announcement = 'Current time $timeStr. Battery is at $batteryLevel percent.';
    }

    await widget.ttsService.speak(announcement, interrupt: true);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
