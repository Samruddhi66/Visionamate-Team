import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visionmate/app/providers.dart';
import 'package:visionmate/core/audio/tts_service.dart';
import 'package:visionmate/core/camera/camera_service.dart';
import 'package:visionmate/core/haptics/haptic_patterns.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';
import 'package:visionmate/core/storage/history_repository.dart';
import 'package:visionmate/features/object_recognition/screens/object_screen.dart';
import 'package:visionmate/features/object_recognition/services/object_detection_service.dart';

class MockObjectDetectionService implements ObjectDetectionService {
  final List<DetectedObject> detections;

  MockObjectDetectionService({
    this.detections = const [
      DetectedObject(
        label: 'Doorway',
        confidence: 0.95,
        position: RelativePosition.centerAhead,
      ),
      DetectedObject(
        label: 'Chair',
        confidence: 0.91,
        position: RelativePosition.left,
      ),
    ],
  });

  @override
  Future<List<DetectedObject>> detectObjects(XFile imageFile) async => detections;
}

void main() {
  group('Object Recognition Screen Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late MockCameraService mockCamera;
    late MockObjectDetectionService mockObjectService;
    late HistoryRepository historyRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      mockCamera = MockCameraService();
      mockObjectService = MockObjectDetectionService();
      historyRepo = HistoryRepository(prefs);
    });

    Widget createObjectWidget({List<DetectedObject>? customDetections}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          cameraServiceProvider.overrideWithValue(mockCamera),
          objectDetectionServiceProvider.overrideWithValue(
            customDetections != null
                ? MockObjectDetectionService(detections: customDetections)
                : mockObjectService,
          ),
          historyRepositoryProvider.overrideWithValue(historyRepo),
        ],
        child: const MaterialApp(
          home: ObjectRecognitionScreen(),
        ),
      );
    }

    testWidgets('renders Object Recognition title, live viewfinder, detections list, and mic button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createObjectWidget());
      await tester.pumpAndSettle();

      expect(find.text('Object Recognition'), findsOneWidget);
      expect(find.text('Doorway'), findsOneWidget);
      expect(find.text('Chair'), findsOneWidget);
      expect(find.text('Tap to hear'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('handles tap on mic to trigger rescan and plays haptic cue',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createObjectWidget());
      await tester.pumpAndSettle();

      final micButton = find.byIcon(Icons.mic_rounded);
      expect(micButton, findsOneWidget);

      await tester.tap(micButton);
      await tester.pumpAndSettle();

      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.actionSuccess));
      expect(mockTts.spokenHistory, contains('Doorway directly ahead. Chair on your left'));
    });

    testWidgets('gracefully displays empty guidance when no objects are detected without crashing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createObjectWidget(customDetections: []));
      await tester.pumpAndSettle();

      expect(find.text('No objects detected. Tap microphone to rescan.'), findsOneWidget);
      expect(mockTts.spokenHistory.any((s) => s.contains('No distinct physical objects')), isTrue);
    });
  });
}
