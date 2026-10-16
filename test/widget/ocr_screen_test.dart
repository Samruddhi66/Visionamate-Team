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
import 'package:visionmate/features/ocr/screens/ocr_screen.dart';
import 'package:visionmate/features/ocr/services/ocr_service.dart';

class MockOcrService implements OcrService {
  final OcrTextResult result;
  MockOcrService({
    this.result = const OcrTextResult(
      fullText: 'CAUTION: WET FLOOR. PLEASE USE ALTERNATE ENTRANCE ON RIGHT',
      textLines: ['CAUTION: WET FLOOR', 'PLEASE USE ALTERNATE ENTRANCE ON RIGHT'],
      confidence: 0.95,
      isLegible: true,
    ),
  });

  @override
  Future<OcrTextResult> recognizeText(XFile imageFile, {String languageCode = 'en'}) async => result;
}

void main() {
  group('OCR Read Text Screen Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late MockCameraService mockCamera;
    late MockOcrService mockOcr;
    late HistoryRepository historyRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      mockCamera = MockCameraService();
      mockOcr = MockOcrService();
      historyRepo = HistoryRepository(prefs);
    });

    Widget createOcrWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          cameraServiceProvider.overrideWithValue(mockCamera),
          ocrServiceProvider.overrideWithValue(mockOcr),
          historyRepositoryProvider.overrideWithValue(historyRepo),
        ],
        child: const MaterialApp(
          home: OcrScreen(),
        ),
      );
    }

    testWidgets('renders initial viewfinder and speaks instructions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createOcrWidget());
      await tester.pumpAndSettle();

      expect(find.text('Read Text (OCR)'), findsOneWidget);
      expect(find.text('Align Document or Sign'), findsOneWidget);
      expect(find.text('Scan & Read Text'), findsOneWidget);

      expect(
        mockTts.spokenHistory,
        contains('Read Text mode. Hold phone steady over signs, documents, or labels, then tap Scan & Read.'),
      );
    });

    testWidgets('captures document, extracts text, announces via TTS, and shows playback controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createOcrWidget());
      await tester.pumpAndSettle();

      final scanButton = find.text('Scan & Read Text');
      expect(scanButton, findsOneWidget);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      // Verify haptic triggers
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.processingStarted));
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.actionSuccess));

      // Verify text rendered and spoken
      expect(
        find.text('CAUTION: WET FLOOR. PLEASE USE ALTERNATE ENTRANCE ON RIGHT'),
        findsOneWidget,
      );
      expect(
        mockTts.spokenHistory,
        contains('CAUTION: WET FLOOR. PLEASE USE ALTERNATE ENTRANCE ON RIGHT'),
      );

      // Verify audio controls appear
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);

      // Verify saved to history
      final entries = historyRepo.getHistory();
      expect(entries.any((e) => e.category == 'ocr'), isTrue);
    });
  });
}
