import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/core/haptics/haptic_patterns.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';

void main() {
  group('HapticService and Patterns Tests', () {
    test('MockHapticService records triggered patterns when enabled', () async {
      final mock = MockHapticService();

      await mock.trigger(HapticPattern.lightTap);
      await mock.trigger(HapticPattern.hazardDetected);
      await mock.trigger(HapticPattern.emergencyStatus);

      expect(mock.triggeredPatterns, hasLength(3));
      expect(mock.triggeredPatterns, contains(HapticPattern.lightTap));
      expect(mock.triggeredPatterns, contains(HapticPattern.hazardDetected));
      expect(mock.triggeredPatterns, contains(HapticPattern.emergencyStatus));
    });

    test('MockHapticService suppresses triggers when disabled by settings', () async {
      final mock = MockHapticService();
      mock.isEnabled = false;

      await mock.trigger(HapticPattern.lightTap);
      await mock.trigger(HapticPattern.navigationTurnLeft);

      expect(mock.triggeredPatterns, isEmpty);
    });

    test('All HapticPatterns have spoken alternatives for accessible fallback', () {
      for (final pattern in HapticPattern.values) {
        expect(pattern.spokenAlternative, isNotEmpty);
      }
    });

    test('All HapticPatterns have non-empty vibration timing profiles', () {
      for (final pattern in HapticPattern.values) {
        expect(pattern.vibrationDurationsMs, isNotEmpty);
        expect(pattern.vibrationDurationsMs.first, equals(0)); // starts with 0 wait
      }
    });
  });
}
