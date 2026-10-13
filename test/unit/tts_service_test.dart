import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/core/audio/tts_service.dart';

void main() {
  group('TtsService Tests', () {
    test('MockTtsService records spoken prompts and repeats last', () async {
      final mock = MockTtsService();

      await mock.speak('VisionMate ready');
      expect(mock.lastSpokenText, equals('VisionMate ready'));
      expect(mock.spokenHistory, contains('VisionMate ready'));

      await mock.speak('Turn right in 50 meters');
      expect(mock.lastSpokenText, equals('Turn right in 50 meters'));
      expect(mock.spokenHistory.length, equals(2));

      await mock.repeatLast();
      expect(mock.spokenHistory.length, equals(3));
      expect(mock.spokenHistory.last, equals('Turn right in 50 meters'));
    });

    test('MockTtsService ignores blank or empty text', () async {
      final mock = MockTtsService();
      await mock.speak('   ');
      expect(mock.spokenHistory, isEmpty);
      expect(mock.lastSpokenText, isNull);
    });
  });
}
