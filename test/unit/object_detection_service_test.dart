import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visionmate/core/network/gemini_service.dart';
import 'package:visionmate/core/storage/preferences_service.dart';
import 'package:visionmate/features/object_recognition/services/object_detection_service.dart';

class MockGeminiVisionService extends GeminiVisionService {
  String responseToReturn;

  MockGeminiVisionService({
    required this.responseToReturn,
    required PreferencesService prefs,
  }) : super(preferencesService: prefs);

  @override
  Future<String> askGemini({
    required String prompt,
    List<int>? imageBytes,
    String mimeType = 'image/jpeg',
    String? systemInstruction,
  }) async {
    return responseToReturn;
  }
}

void main() {
  group('ObjectDetectionService Unit Tests', () {
    late PreferencesService fakePrefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      fakePrefs = PreferencesService(sp);
    });

    final dummyFrame = XFile.fromData(
      Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
      mimeType: 'image/jpeg',
      name: 'test.jpg',
    );

    test('returns fallback detections when Gemini service is null', () async {
      final service = DefaultObjectDetectionService();
      final detections = await service.detectObjects(dummyFrame);

      expect(detections.length, equals(3));
      expect(detections[0].label, equals('Doorway'));
      expect(detections[0].position, equals(RelativePosition.centerAhead));
      expect(detections[1].label, equals('Chair'));
      expect(detections[1].position, equals(RelativePosition.left));
      expect(detections[2].label, equals('Desk Surface'));
      expect(detections[2].position, equals(RelativePosition.right));
    });

    test('parses pure JSON array response with left, centerAhead, right positions', () async {
      final mockGemini = MockGeminiVisionService(
        responseToReturn: '''
[
  {"label": "water bottle", "confidence": 0.96, "position": "centerAhead"},
  {"label": "backpack", "confidence": 0.89, "position": "left"},
  {"label": "keyboard", "confidence": 0.92, "position": "right"}
]
''',
        prefs: fakePrefs,
      );

      final service = DefaultObjectDetectionService(geminiService: mockGemini);
      final detections = await service.detectObjects(dummyFrame);

      expect(detections.length, equals(3));
      expect(detections[0].label, equals('Water bottle'));
      expect(detections[0].position, equals(RelativePosition.centerAhead));
      expect(detections[0].confidence, closeTo(0.96, 0.01));

      expect(detections[1].label, equals('Backpack'));
      expect(detections[1].position, equals(RelativePosition.left));

      expect(detections[2].label, equals('Keyboard'));
      expect(detections[2].position, equals(RelativePosition.right));
    });

    test('parses markdown-fenced ```json ``` response properly', () async {
      final mockGemini = MockGeminiVisionService(
        responseToReturn: '''
```json
[
  {"label": "coffee cup", "confidence": 0.94, "position": "ahead"}
]
```
''',
        prefs: fakePrefs,
      );

      final service = DefaultObjectDetectionService(geminiService: mockGemini);
      final detections = await service.detectObjects(dummyFrame);

      expect(detections.length, equals(1));
      expect(detections[0].label, equals('Coffee cup'));
      expect(detections[0].position, equals(RelativePosition.centerAhead));
    });

    test('returns empty list when Gemini reports empty array []', () async {
      final mockGemini = MockGeminiVisionService(
        responseToReturn: '[]',
        prefs: fakePrefs,
      );

      final service = DefaultObjectDetectionService(geminiService: mockGemini);
      final detections = await service.detectObjects(dummyFrame);

      expect(detections, isEmpty);
    });

    test('parses natural language text with object names and positions', () async {
      final mockGemini = MockGeminiVisionService(
        responseToReturn: '''
- Chair on the left side
- Doorway directly ahead
- Desk surface on your right
''',
        prefs: fakePrefs,
      );

      final service = DefaultObjectDetectionService(geminiService: mockGemini);
      final detections = await service.detectObjects(dummyFrame);

      expect(detections.isNotEmpty, isTrue);
      expect(detections[0].label, contains('Chair'));
      expect(detections[0].position, equals(RelativePosition.left));
    });

    test('DetectedObject formatting methods produce accessible spoken phrases and clock orientations', () {
      const obj1 = DetectedObject(
        label: 'Door',
        confidence: 0.95,
        position: RelativePosition.centerAhead,
      );
      expect(obj1.toSpokenPhrase(), equals('Door directly ahead'));
      expect(obj1.toRelativeClockString(), equals("12 o'clock (Ahead)"));

      const obj2 = DetectedObject(
        label: 'Chair',
        confidence: 0.90,
        position: RelativePosition.left,
      );
      expect(obj2.toSpokenPhrase(), equals('Chair on your left'));
      expect(obj2.toRelativeClockString(), equals("9 o'clock (Left)"));

      const obj3 = DetectedObject(
        label: 'Table',
        confidence: 0.85,
        position: RelativePosition.right,
      );
      expect(obj3.toSpokenPhrase(), equals('Table on your right'));
      expect(obj3.toRelativeClockString(), equals("3 o'clock (Right)"));
    });
  });
}
