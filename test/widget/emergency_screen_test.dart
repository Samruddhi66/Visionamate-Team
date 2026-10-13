import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visionmate/app/providers.dart';
import 'package:visionmate/core/audio/tts_service.dart';
import 'package:visionmate/core/haptics/haptic_patterns.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';
import 'package:visionmate/features/emergency/screens/emergency_screen.dart';
import 'package:visionmate/features/navigation/services/location_service.dart';

void main() {
  group('Emergency SOS Screen Widget Tests', () {
    late SharedPreferences prefs;
    late MockTtsService mockTts;
    late MockHapticService mockHaptics;
    late MockLocationService mockLocation;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'vm_emergency_name': 'Guardian',
        'vm_emergency_phone': '+919876543210',
      });
      prefs = await SharedPreferences.getInstance();
      mockTts = MockTtsService();
      mockHaptics = MockHapticService();
      mockLocation = MockLocationService();
    });

    Widget createEmergencyWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          locationServiceProvider.overrideWithValue(mockLocation),
        ],
        child: const MaterialApp(
          home: EmergencyScreen(),
        ),
      );
    }

    testWidgets('renders SOS title, countdown instruction, 3 status cards, and hold button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createEmergencyWidget());
      await tester.pumpAndSettle();

      expect(find.text('Safety Alerts (SOS)'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('Press and hold for 5 seconds to send alert'), findsOneWidget);
      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.text('Emergency Contacts'), findsOneWidget);
      expect(find.text('Live Audio'), findsOneWidget);
      expect(find.text('Hold to Activate'), findsOneWidget);
      expect(find.text('You are safe. I am here to help.'), findsOneWidget);
    });

    testWidgets('Opening and saving emergency contact configuration triggers confirmation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createEmergencyWidget());
      await tester.pumpAndSettle();

      // Tap configure contact icon in AppBar
      final configButton = find.byIcon(Icons.edit_note_rounded);
      expect(configButton, findsOneWidget);

      await tester.tap(configButton);
      await tester.pumpAndSettle();

      expect(find.text('Emergency Contact'), findsOneWidget);
      expect(find.text('Save Contact'), findsOneWidget);

      await tester.tap(find.text('Save Contact'));
      await tester.pumpAndSettle();

      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.actionSuccess));
      expect(mockTts.spokenHistory, contains('Emergency contact saved.'));
    });
  });
}
