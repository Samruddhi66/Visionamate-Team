import 'dart:ui';
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
import 'package:visionmate/features/scene_analysis/screens/scene_analysis_screen.dart';
import 'package:visionmate/features/scene_analysis/services/scene_understanding_service.dart';

class MockSceneUnderstandingService implements SceneUnderstandingService {
  final SceneDescriptionResult result;

  MockSceneUnderstandingService({
    this.result = const SceneDescriptionResult(
      descriptionText: 'Open indoor pathway directly ahead. Desk surface with workspace equipment on your right, clear floor corridor on your left.',
      confidence: 0.95,
      isLocalInference: true,
      detectedElements: [],
      realWorldObjects: [],
    ),
  });

  @override
  Future<SceneDescriptionResult> analyzeScene({
    required XFile imageFile,
    String languageCode = 'en',
    DescriptionVerbosity verbosity = DescriptionVerbosity.concise,
  }) async =>
      result;
}

void main() {
  group('Scene Analysis Screen & Explore by Touch Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late MockCameraService mockCamera;
    late MockSceneUnderstandingService mockSceneService;
    late HistoryRepository historyRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      mockCamera = MockCameraService();
      mockSceneService = MockSceneUnderstandingService();
      historyRepo = HistoryRepository(prefs);
    });

    Widget createSceneWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          cameraServiceProvider.overrideWithValue(mockCamera),
          sceneUnderstandingServiceProvider.overrideWithValue(mockSceneService),
          historyRepositoryProvider.overrideWithValue(historyRepo),
        ],
        child: const MaterialApp(
          home: SceneAnalysisScreen(),
        ),
      );
    }

    testWidgets('renders AI Vision screen without dummy boxes and displays Explore by Touch guide', (tester) async {
      await tester.pumpWidget(createSceneWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header and Live Analysis
      expect(find.text('AI Vision'), findsOneWidget);
      expect(find.text('Live Analysis'), findsOneWidget);

      // Explore by Touch Guide
      expect(find.textContaining('Explore by Touch'), findsOneWidget);

      // Verify that old dummy bounding box tags are NOT present
      expect(find.text('Chair • 0.9 m'), findsNothing);
      expect(find.text('Pathway • Ahead (Clear)'), findsNothing);
      expect(find.text('Desk • 1.2 m'), findsNothing);

      // Controls exist
      expect(find.byIcon(Icons.camera_alt_rounded), findsWidgets);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('touching or dragging across viewfinder triggers haptic feedback and spatial voice feedback', (tester) async {
      await tester.pumpWidget(createSceneWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      mockHaptics.reset();
      mockTts.spokenHistory.clear();

      // Tap on center of the screen
      final centerPoint = tester.getCenter(find.byType(SceneAnalysisScreen));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(centerPoint);
      await tester.pump(const Duration(milliseconds: 50));

      // Verify haptic feedback was triggered
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.lightTap));

      // Verify speech feedback was delivered
      expect(mockTts.spokenHistory.isNotEmpty, isTrue);
      expect(
        mockTts.spokenHistory.any((phrase) =>
            phrase.toLowerCase().contains('path') ||
            phrase.toLowerCase().contains('ground') ||
            phrase.toLowerCase().contains('front') ||
            phrase.toLowerCase().contains('walking')),
        isTrue,
      );

      // Drag towards upper left side
      await gesture.moveTo(const Offset(80, 100));
      await tester.pump(const Duration(milliseconds: 50));

      // Verify new sector haptic and speech
      expect(mockHaptics.triggeredPatterns.length, greaterThanOrEqualTo(2));
      expect(
        mockTts.spokenHistory.any((phrase) =>
            phrase.toLowerCase().contains('left') ||
            phrase.toLowerCase().contains('upper')),
        isTrue,
      );

      // Up gesture
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
