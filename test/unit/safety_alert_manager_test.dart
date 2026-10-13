import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/core/audio/tts_service.dart';
import 'package:visionmate/core/haptics/haptic_patterns.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';
import 'package:visionmate/features/safety_alerts/services/safety_alert_manager.dart';

void main() {
  group('SafetyAlertManager Tests', () {
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late SafetyAlertManager alertManager;

    setUp(() {
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      alertManager = SafetyAlertManager(tts: mockTts, haptics: mockHaptics);
    });

    test('Dispatches hazard alert with haptic cue and spoken warning', () async {
      final dispatched = await alertManager.dispatchHazard(
        alertId: 'obstacle_ahead',
        title: 'Obstacle Detected',
        spokenWarning: 'Possible obstacle ahead. Pause and check surroundings.',
      );

      expect(dispatched, isTrue);
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.hazardDetected));
      expect(mockTts.spokenHistory, contains('Possible obstacle ahead. Pause and check surroundings.'));
      expect(alertManager.latestAlert?.id, equals('obstacle_ahead'));
    });

    test('Suppresses duplicate alerts within the 4-second debouncing window', () async {
      final first = await alertManager.dispatchHazard(
        alertId: 'step_dropoff',
        title: 'Step Down',
        spokenWarning: 'Caution: step down detected.',
      );
      expect(first, isTrue);

      final secondImmediate = await alertManager.dispatchHazard(
        alertId: 'step_dropoff',
        title: 'Step Down',
        spokenWarning: 'Caution: step down detected.',
      );
      expect(secondImmediate, isFalse); // Suppressed to avoid overwhelming the user
    });

    test('Allows distinct alerts without duplicate suppression', () async {
      final alert1 = await alertManager.dispatchHazard(
        alertId: 'hazard_left',
        title: 'Obstacle Left',
        spokenWarning: 'Obstacle on your left.',
      );
      final alert2 = await alertManager.dispatchHazard(
        alertId: 'hazard_right',
        title: 'Obstacle Right',
        spokenWarning: 'Obstacle on your right.',
      );

      expect(alert1, isTrue);
      expect(alert2, isTrue);
    });
  });
}
