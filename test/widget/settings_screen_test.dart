import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visionmate/app/providers.dart';
import 'package:visionmate/core/audio/tts_service.dart';
import 'package:visionmate/core/haptics/haptic_patterns.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';
import 'package:visionmate/features/settings/screens/settings_screen.dart';

void main() {
  group('Settings & Accessibility Screen Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'vm_theme_mode': 'dark',
        'vm_language': 'en',
        'vm_haptics_enabled': true,
        'vm_speech_rate': 0.5,
      });
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
    });

    Widget createSettingsWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      );
    }

    testWidgets('renders all accessibility items and toggles high contrast mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSettingsWidget());
      await tester.pumpAndSettle();

      // Header & Accessibility Rows
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('Voice Language'), findsOneWidget);
      expect(find.text('Voice Speed'), findsOneWidget);
      expect(find.text('High Contrast'), findsOneWidget);
      expect(find.text('Large Text'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);
      expect(find.text('Audio Cues'), findsOneWidget);

      // General Rows
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);

      // Toggle High Contrast Mode
      final contrastSwitch = find.widgetWithText(SwitchListTile, 'High Contrast');
      expect(contrastSwitch, findsOneWidget);

      await tester.tap(contrastSwitch);
      await tester.pumpAndSettle();

      expect(mockTts.spokenHistory, contains('High contrast mode turned on.'));
    });

    testWidgets('switches voice language smoothly to Hindi via language selector',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSettingsWidget());
      await tester.pumpAndSettle();

      // Tap Voice Language row to open modal
      final voiceLangRow = find.text('Voice Language');
      expect(voiceLangRow, findsOneWidget);

      await tester.tap(voiceLangRow);
      await tester.pumpAndSettle();

      expect(find.text('Select Voice Language'), findsOneWidget);
      expect(find.text('हिन्दी (Hindi - India)'), findsOneWidget);

      // Select Hindi
      await tester.tap(find.text('हिन्दी (Hindi - India)'));
      await tester.pumpAndSettle();

      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.actionSuccess));
      expect(mockTts.spokenHistory, contains('भाषा बदलकर हिन्दी कर दी गई है। विज़नमेट तैयार है।'));
    });

    testWidgets('Toggles haptic feedback with confirmation speech and haptics',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSettingsWidget());
      await tester.pumpAndSettle();

      final hapticsSwitch = find.widgetWithText(SwitchListTile, 'Haptic Feedback');
      expect(hapticsSwitch, findsOneWidget);

      await tester.tap(hapticsSwitch);
      await tester.pumpAndSettle();

      expect(mockTts.spokenHistory, contains('Haptic vibrations disabled.'));
    });
  });
}
