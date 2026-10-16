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
import 'package:visionmate/features/image_qa/screens/image_qa_screen.dart';
import 'package:visionmate/features/image_qa/services/image_qa_service.dart';

class MockImageQaService implements ImageQaService {
  final ImageQaResult result;

  MockImageQaService({
    this.result = const ImageQaResult(
      answer: 'This is a blue ceramic coffee mug located in front of you.',
      confidence: 0.95,
      isLocal: false,
    ),
  });

  @override
  Future<ImageQaResult> answerQuestion({
    required XFile imageFile,
    required String question,
    String languageCode = 'en',
  }) async =>
      result;
}

void main() {
  group('Image Q&A Screen Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late MockCameraService mockCamera;
    late MockImageQaService mockQaService;
    late HistoryRepository historyRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      mockCamera = MockCameraService();
      mockQaService = MockImageQaService();
      historyRepo = HistoryRepository(prefs);
    });

    Widget createQaWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          cameraServiceProvider.overrideWithValue(mockCamera),
          imageQaServiceProvider.overrideWithValue(mockQaService),
          historyRepositoryProvider.overrideWithValue(historyRepo),
        ],
        child: const MaterialApp(
          home: ImageQaScreen(),
        ),
      );
    }

    testWidgets('renders Image Q&A title, live camera viewfinder, question pill, and mic button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createQaWidget());
      await tester.pumpAndSettle();

      expect(find.text('AI Image Q&A'), findsOneWidget);
      expect(find.text('What is this object?'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Tap to speak'), findsOneWidget);
    });

    testWidgets('tapping mic triggers visual question answering and speaks result',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createQaWidget());
      await tester.pumpAndSettle();

      final micButton = find.byIcon(Icons.mic_rounded);
      expect(micButton, findsOneWidget);

      await tester.tap(micButton);
      await tester.pumpAndSettle();

      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.actionSuccess));
      expect(
        find.text('This is a blue ceramic coffee mug located in front of you.'),
        findsOneWidget,
      );
      expect(
        mockTts.spokenHistory,
        contains('This is a blue ceramic coffee mug located in front of you.'),
      );
    });

    testWidgets('renders preset question chips and tapping preset triggers question answering',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createQaWidget());
      await tester.pumpAndSettle();

      expect(find.text('Identify Object'), findsOneWidget);
      expect(find.text('Check Colors'), findsOneWidget);
      expect(find.text('Read Text'), findsOneWidget);
      expect(find.text('Check Safety'), findsOneWidget);

      await tester.tap(find.text('Check Colors'));
      await tester.pumpAndSettle();

      expect(find.text('What colors are present in this image?'), findsOneWidget);
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.actionSuccess));
      expect(
        mockTts.spokenHistory,
        contains('This is a blue ceramic coffee mug located in front of you.'),
      );
    });

    testWidgets('tapping listen again repeats the spoken answer',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createQaWidget());
      await tester.pumpAndSettle();

      // First run Q&A
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();

      final initialSpokenCount = mockTts.spokenHistory.length;

      // Tap Listen Again speaker button
      final listenButton = find.byIcon(Icons.volume_up_rounded).last;
      await tester.tap(listenButton);
      await tester.pumpAndSettle();

      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.selectionClick));
      expect(mockTts.spokenHistory.length, greaterThan(initialSpokenCount));
      expect(mockTts.lastSpokenText, equals('This is a blue ceramic coffee mug located in front of you.'));
    });
  });
}

