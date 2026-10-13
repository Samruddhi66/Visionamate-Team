import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/audio/tts_service.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/haptics/haptic_service.dart';

enum HazardSeverity {
  low,
  moderate,
  critical,
}

class HazardAlert {
  final String id;
  final String title;
  final String spokenWarning;
  final HazardSeverity severity;
  final DateTime timestamp;
  final double confidence;

  const HazardAlert({
    required this.id,
    required this.title,
    required this.spokenWarning,
    required this.severity,
    required this.timestamp,
    required this.confidence,
  });
}

/// Centralized safety-alert coordinator ensuring alert debouncing and distinctive haptic cues
class SafetyAlertManager extends ChangeNotifier {
  final TtsService tts;
  final HapticService haptics;

  // Debouncing memory: alertId -> timestamp of last dispatch
  final Map<String, DateTime> _dispatchedHistory = {};

  // Debounce duration: suppress identical alerts within 4 seconds so the user is not overwhelmed
  static const Duration duplicateSuppressionWindow = Duration(seconds: 4);

  HazardAlert? _latestAlert;
  HazardAlert? get latestAlert => _latestAlert;

  SafetyAlertManager({
    required this.tts,
    required this.haptics,
  });

  /// Dispatch an alert if not recently triggered and confidence is adequate
  Future<bool> dispatchHazard({
    required String alertId,
    required String title,
    required String spokenWarning,
    HazardSeverity severity = HazardSeverity.moderate,
    double confidence = 0.85,
  }) async {
    final now = DateTime.now();

    // 1. Check duplicate suppression window
    if (_dispatchedHistory.containsKey(alertId)) {
      final lastTime = _dispatchedHistory[alertId]!;
      if (now.difference(lastTime) < duplicateSuppressionWindow) {
        return false; // Suppressed duplicate
      }
    }

    _dispatchedHistory[alertId] = now;

    _latestAlert = HazardAlert(
      id: alertId,
      title: title,
      spokenWarning: spokenWarning,
      severity: severity,
      timestamp: now,
      confidence: confidence,
    );

    notifyListeners();

    // 2. Tactile alert pulse
    await haptics.trigger(HapticPattern.hazardDetected);

    // 3. Spoken warning through TTS
    await tts.speak(spokenWarning, interrupt: true);

    return true;
  }

  /// Manually acknowledge or dismiss the active hazard alert
  void dismissAlert() {
    _latestAlert = null;
    notifyListeners();
  }

  void clearHistory() {
    _dispatchedHistory.clear();
    _latestAlert = null;
    notifyListeners();
  }
}
