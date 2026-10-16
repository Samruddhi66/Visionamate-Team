import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'haptic_patterns.dart';
import 'web_haptic_bridge.dart';

/// Abstract service contract for tactile feedback
abstract class HapticService {
  /// Whether haptic feedback is globally enabled by user settings
  bool get isEnabled;
  set isEnabled(bool value);

  /// Dispatches the given named tactile feedback pattern.
  Future<void> trigger(HapticPattern pattern);

  /// Cancels any active vibration pulses.
  Future<void> cancel();
}

/// Production implementation utilizing flutter HapticFeedback with custom Vibration fallback
class DeviceHapticService implements HapticService {
  @override
  bool isEnabled = true;

  bool _hasVibratorChecked = false;
  bool _hasCustomVibrationSupport = false;

  DeviceHapticService({this.isEnabled = true});

  Future<void> _checkHardwareCapabilities() async {
    if (_hasVibratorChecked) return;
    if (kIsWeb) {
      _hasCustomVibrationSupport = false;
      _hasVibratorChecked = true;
      return;
    }
    try {
      final hasVibrator = await Vibration.hasVibrator();
      final hasCustom = await Vibration.hasCustomVibrationsSupport();
      _hasCustomVibrationSupport = (hasVibrator == true) && (hasCustom == true);
    } catch (e) {
      debugPrint('[HapticService] Hardware check fallback: $e');
      _hasCustomVibrationSupport = false;
    } finally {
      _hasVibratorChecked = true;
    }
  }

  @override
  Future<void> trigger(HapticPattern pattern) async {
    if (!isEnabled) return;

    try {
      await _checkHardwareCapabilities();

      if (_hasCustomVibrationSupport) {
        final patternList = pattern.vibrationDurationsMs;
        await Vibration.vibrate(pattern: patternList);
      } else {
        // Graceful fallback to Flutter's standard HapticFeedback system channels
        switch (pattern) {
          case HapticPattern.lightTap:
          case HapticPattern.buttonTap:
          case HapticPattern.selectionClick:
            await HapticFeedback.selectionClick();
            break;
          case HapticPattern.actionSuccess:
            await HapticFeedback.mediumImpact();
            break;
          case HapticPattern.actionError:
          case HapticPattern.hazardDetected:
          case HapticPattern.emergencyStatus:
          case HapticPattern.warningImpending:
            await HapticFeedback.heavyImpact();
            break;
          case HapticPattern.listeningStarted:
          case HapticPattern.processingStarted:
            await HapticFeedback.lightImpact();
            break;
          case HapticPattern.navigationTurnLeft:
          case HapticPattern.navigationTurnRight:
          case HapticPattern.destinationArrival:
            await HapticFeedback.vibrate();
            break;
        }
      }
      if (kIsWeb) {
        final duration = pattern.vibrationDurationsMs.isNotEmpty
            ? pattern.vibrationDurationsMs.first
            : 30;
        triggerWebHaptic(duration);
      }
    } catch (e) {
      // Graceful degradation on unsupported platforms (e.g. desktop/web without vibration)
      debugPrint('[HapticService] Trigger degraded gracefully: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      if (kIsWeb) {
        cancelWebHaptic();
      } else {
        await Vibration.cancel();
      }
    } catch (_) {
      // Ignore cancellation failures
    }
  }
}

/// Test spy/mock implementation to verify haptic dispatches in automated unit tests
class MockHapticService implements HapticService {
  @override
  bool isEnabled = true;

  final List<HapticPattern> triggeredPatterns = [];
  bool wasCancelled = false;

  @override
  Future<void> trigger(HapticPattern pattern) async {
    if (isEnabled) {
      triggeredPatterns.add(pattern);
    }
  }

  @override
  Future<void> cancel() async {
    wasCancelled = true;
  }

  void reset() {
    triggeredPatterns.clear();
    wasCancelled = false;
  }
}
