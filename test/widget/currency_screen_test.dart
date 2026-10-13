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
import 'package:visionmate/features/currency_detection/screens/currency_screen.dart';
import 'package:visionmate/features/currency_detection/services/currency_detection_service.dart';

class MockCurrencyDetectionService implements CurrencyDetectionService {
  final CurrencyDetectionResult result;
  MockCurrencyDetectionService({
    this.result = const CurrencyDetectionResult(
      denomination: RupeeDenomination.fiveHundred,
      confidence: 0.94,
      isConfident: true,
      spokenMessage: 'Identified: 500 Rupees note (Confidence 94%).',
    ),
  });

  @override
  Future<CurrencyDetectionResult> identifyCurrency(XFile imageFile) async => result;
}

void main() {
  group('Indian Currency Detection Screen Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late MockCameraService mockCamera;
    late MockCurrencyDetectionService mockCurrency;
    late HistoryRepository historyRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      mockCamera = MockCameraService();
      mockCurrency = MockCurrencyDetectionService();
      historyRepo = HistoryRepository(prefs);
    });

    Widget createCurrencyWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          cameraServiceProvider.overrideWithValue(mockCamera),
          currencyDetectionServiceProvider.overrideWithValue(mockCurrency),
          historyRepositoryProvider.overrideWithValue(historyRepo),
        ],
        child: const MaterialApp(
          home: CurrencyScreen(),
        ),
      );
    }

    testWidgets('renders Cash Detector title, viewfinder, total value card, and scan button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createCurrencyWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cash Detector'), findsOneWidget);
      expect(find.text('Total Value'), findsOneWidget);
      expect(find.text('₹500'), findsNWidgets(2));
      expect(find.text('1 note found'), findsOneWidget);
      expect(find.text('Tap to scan'), findsOneWidget);
    });

    testWidgets('scans note and announces recognized 500 Rupee denomination with high confidence',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createCurrencyWidget());
      await tester.pumpAndSettle();

      final scanButton = find.text('Tap to scan');
      expect(scanButton, findsOneWidget);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.processingStarted));
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.actionSuccess));
      expect(mockTts.spokenHistory, contains('Identified: 500 Rupees note (Confidence 94%).'));
    });
  });
}
