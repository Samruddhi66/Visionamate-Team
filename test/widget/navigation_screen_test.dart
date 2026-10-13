import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visionmate/app/providers.dart';
import 'package:visionmate/core/audio/tts_service.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';
import 'package:visionmate/core/storage/history_repository.dart';
import 'package:visionmate/features/navigation/screens/navigation_screen.dart';
import 'package:visionmate/features/navigation/services/location_service.dart';

void main() {
  group('Accessible Navigation Screen Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late MockLocationService mockLocation;
    late HistoryRepository historyRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      mockLocation = MockLocationService();
      historyRepo = HistoryRepository(prefs);
    });

    Widget createNavigationWidget({String? initialDestination}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          locationServiceProvider.overrideWithValue(mockLocation),
          historyRepositoryProvider.overrideWithValue(historyRepo),
        ],
        child: MaterialApp(
          home: NavigationScreen(initialDestination: initialDestination),
        ),
      );
    }

    testWidgets('renders navigation header, turn banner, and destination card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createNavigationWidget());
      await tester.pumpAndSettle();

      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('Turn right in 100 meters'), findsOneWidget);
      expect(find.text('College Main Gate'), findsOneWidget);
      expect(find.text('2.4 km • 8 min (walk)'), findsOneWidget);
      expect(find.text('Pause Guidance'), findsOneWidget);

      // Verify TTS announced navigation mode instructions
      expect(
        mockTts.spokenHistory,
        contains('Navigation. Turn right in 100 meters towards College Main Gate.'),
      );
    });

    testWidgets('toggles pause and resume guidance with haptics and voice feedback',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createNavigationWidget());
      await tester.pumpAndSettle();

      final pauseButton = find.text('Pause Guidance');
      expect(pauseButton, findsOneWidget);

      await tester.tap(pauseButton);
      await tester.pumpAndSettle();

      expect(find.text('Resume Guidance'), findsOneWidget);
      expect(
        mockTts.spokenHistory,
        contains('Pause Guidance. Walking directions temporarily paused.'),
      );

      // Tap resume
      await tester.tap(find.text('Resume Guidance'));
      await tester.pumpAndSettle();

      expect(find.text('Pause Guidance'), findsOneWidget);
      expect(
        mockTts.spokenHistory,
        contains('Resume Guidance. Turn right in 100 meters.'),
      );
    });
  });
}
