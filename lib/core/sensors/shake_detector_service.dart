import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects rapid physical device shakes (e.g. 3 sharp shakes within 2.5s)
/// to activate emergency SOS hands-free for blind users.
class ShakeDetectorService {
  static const double shakeThreshold = 14.0; // m/s²
  static const Duration shakeWindow = Duration(milliseconds: 2500);
  static const Duration cooldown = Duration(seconds: 15);

  final List<DateTime> _shakeTimestamps = [];
  DateTime? _lastTriggerTime;
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  bool _isRunning = false;

  final VoidCallback onShakeDetected;

  ShakeDetectorService({required this.onShakeDetected});

  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;
    try {
      _subscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          final double magnitude = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );

          if (magnitude >= shakeThreshold) {
            _handleShakeEvent();
          }
        },
        onError: (e) {
          debugPrint('[ShakeDetectorService] Accelerometer stream error: $e');
        },
        cancelOnError: false,
      );
      _isRunning = true;
    } catch (e) {
      debugPrint('[ShakeDetectorService] Failed to listen to accelerometer: $e');
    }
  }

  void _handleShakeEvent() {
    final now = DateTime.now();

    // Check cooldown
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!) < cooldown) {
      return;
    }

    // Discard shakes outside sliding window
    _shakeTimestamps.removeWhere((t) => now.difference(t) > shakeWindow);
    _shakeTimestamps.add(now);

    // If 3 distinct shakes detected within window
    if (_shakeTimestamps.length >= 3) {
      _lastTriggerTime = now;
      _shakeTimestamps.clear();
      debugPrint('[ShakeDetectorService] Triple-shake detected! Triggering SOS.');
      onShakeDetected();
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _shakeTimestamps.clear();
    _isRunning = false;
  }

  void dispose() {
    stop();
  }
}

