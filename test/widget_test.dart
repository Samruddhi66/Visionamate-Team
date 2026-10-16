import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visionmate/app/app.dart';
import 'package:visionmate/app/providers.dart';
import 'package:visionmate/core/audio/tts_service.dart';
import 'package:visionmate/core/haptics/haptic_patterns.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';
import 'package:visionmate/core/speech/speech_service.dart';

void main() {
  testWidgets('VisionMate 2.0 App starts at Splash Screen and navigates to Dashboard',
      (WidgetTester tester) async {
    // Set dummy SharedPreferences values
    SharedPreferences.setMockInitialValues({
      'vm_theme_mode': 'dark',
      'vm_language': 'en',
      'vm_haptics_enabled': true,
      'vm_speech_rate': 0.5,
    });
    final prefs = await SharedPreferences.getInstance();

    final mockTts = MockTtsService();
    final mockSpeech = MockSpeechService();
    final mockHaptics = MockHapticService();

    // Set screen size
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsServiceProvider.overrideWithValue(mockTts),
          speechServiceProvider.overrideWithValue(mockSpeech),
          hapticServiceProvider.overrideWithValue(mockHaptics),
        ],
        child: const VisionMateApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Splash Screen elements
    expect(find.text('VisionMate 2.0'), findsOneWidget);
    expect(find.text('See Beyond • Live Independently'), findsOneWidget);
    expect(find.text('Tap to Start'), findsOneWidget);
    expect(find.text('Double tap to continue (Voice will guide you)'), findsOneWidget);

    // Tap "Tap to Start" button to go to Dashboard
    final tapToStartButton = find.text('Tap to Start');
    await tester.tap(tapToStartButton);
    await tester.pumpAndSettle();

    // Verify Dashboard Screen
    expect(find.text('Hello Yogeshh 👋'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);

    // Verify Hero Voice Assistant Button
    expect(find.text('Start Voice Assistant'), findsOneWidget);
    expect(find.text("Tap or say 'Hey VisionMate'"), findsOneWidget);

    // Verify All 6 Feature Cards from Design Sheet
    expect(find.text('Navigation'), findsOneWidget);
    expect(find.text('AI Vision'), findsOneWidget);
    expect(find.text('Cash Detector'), findsOneWidget);
    expect(find.text('Object Recognition'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    // Verify Bottom Navigation Items
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Test Screen-Wide Touch Explorer: Touch anywhere triggers haptic + spoken guidance
    mockHaptics.triggeredPatterns.clear();
    await tester.tapAt(const Offset(100, 260)); // Hero Assistant / Greeting area
    await tester.pump();

    expect(mockHaptics.triggeredPatterns, contains(HapticPattern.lightTap));
    expect(
      mockTts.spokenHistory.any((msg) => msg.contains('Voice Assistant') || msg.contains('Hello Yogeshh')),
      isTrue,
    );
  });
}
