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

    test('prepareNaturalSpeech sanitizes emojis, expands currency, acronyms, and distances', () {
      // Emojis stripped
      expect(
        FlutterTtsService.prepareNaturalSpeech('Hello Yogeshh 👋! How can I help?'),
        equals('Hello Yogeshh ! How can I help?'),
      );

      // Currency expansion
      expect(
        FlutterTtsService.prepareNaturalSpeech('Detected note: ₹500'),
        equals('Detected note, 500 rupees'),
      );

      // Distance expansion
      expect(
        FlutterTtsService.prepareNaturalSpeech('Turn right in 30m ahead'),
        equals('Turn right in 30 meters ahead'),
      );

      // Acronym expansion
      expect(
        FlutterTtsService.prepareNaturalSpeech('Emergency SOS mode and OCR text scanner'),
        equals('Emergency S.O.S mode and O.C.R text scanner'),
      );

      // Markdown stripping
      expect(
        FlutterTtsService.prepareNaturalSpeech('**Caution**: `Obstacle ahead`'),
        equals('Caution, Obstacle ahead'),
      );
    });

    test('MockTtsService manages natural voice persona and discovery', () async {
      final mock = MockTtsService();
      expect(mock.activePersona, equals('warm_female'));

      await mock.setVoicePersona('clear_male');
      expect(mock.activePersona, equals('clear_male'));

      final voices = await mock.getAvailableVoices();
      expect(voices.length, greaterThanOrEqualTo(2));
      expect(voices.any((v) => v['name']!.contains('Jenny')), isTrue);
    });
  });
}
