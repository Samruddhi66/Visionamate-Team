import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/core/accessibility/semantic_wrapper.dart';
import 'package:visionmate/core/haptics/haptic_patterns.dart';
import 'package:visionmate/core/haptics/haptic_service.dart';
import 'package:visionmate/core/widgets/accessible_action_button.dart';
import 'package:visionmate/core/widgets/accessible_feature_card.dart';
import 'package:visionmate/core/widgets/accessible_status_announcement.dart';
import 'package:visionmate/core/widgets/voice_command_button.dart';

void main() {
  group('Accessibility & Semantics Widget Tests', () {
    testWidgets('AccessibleActionButton satisfies minimum touch target and semantic button role',
        (WidgetTester tester) async {
      bool pressed = false;
      final mockHaptics = MockHapticService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleActionButton(
              label: 'Scan Document',
              hint: 'Double tap to capture',
              hapticService: mockHaptics,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(AccessibleActionButton);
      expect(buttonFinder, findsOneWidget);

      // Verify touch target height >= 64 logical pixels
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(64.0));

      // Verify Semantics
      expect(find.bySemanticsLabel('Scan Document'), findsOneWidget);
      expect(
        tester.getSemantics(buttonFinder),
        matchesSemantics(
          label: 'Scan Document',
          hint: 'Double tap to capture',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
        ),
      );

      // Tap and verify haptic feedback
      await tester.tap(buttonFinder);
      await tester.pump();
      expect(pressed, isTrue);
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.lightTap));
    });

    testWidgets('VoiceHeroCard exposes accessible speech instructions and triggers haptic pulse',
        (WidgetTester tester) async {
      bool tapped = false;
      final mockHaptics = MockHapticService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceHeroCard(
              hapticService: mockHaptics,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      final heroFinder = find.byType(VoiceHeroCard);
      expect(heroFinder, findsOneWidget);

      final size = tester.getSize(heroFinder);
      expect(size.height, greaterThanOrEqualTo(76.0));

      await tester.tap(heroFinder);
      await tester.pump();
      expect(tapped, isTrue);
      expect(mockHaptics.triggeredPatterns, contains(HapticPattern.listeningStarted));
    });

    testWidgets('AccessibleFeatureCard renders distinctive labels and handles emergency styling',
        (WidgetTester tester) async {
      final mockHaptics = MockHapticService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleFeatureCard(
              title: 'Identify Currency',
              subtitle: 'Indian Rupee notes',
              icon: Icons.currency_rupee_rounded,
              iconBackgroundColor: Colors.green,
              semanticHint: 'Double tap to scan banknote',
              hapticService: mockHaptics,
              onTap: () {},
            ),
          ),
        ),
      );

      final cardFinder = find.byType(AccessibleFeatureCard);
      expect(cardFinder, findsOneWidget);

      final size = tester.getSize(cardFinder);
      expect(size.height, greaterThanOrEqualTo(110.0));
      expect(find.text('Identify Currency'), findsOneWidget);
    });

    testWidgets('AccessibleStatusAnnouncement produces live region semantics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleStatusAnnouncement(
              message: 'Hazard ahead: Staircase drop-off detected.',
              severity: AnnouncementSeverity.error,
              announceImmediately: false,
            ),
          ),
        ),
      );

      expect(find.text('Hazard ahead: Staircase drop-off detected.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('AccessibleSemanticWrapper excludes decorative children from screen reader noise',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleSemanticWrapper(
              label: 'Battery level 90 percent',
              isHeader: true,
              child: Row(
                children: [
                  Icon(Icons.battery_full),
                  Text('90%'),
                ],
              ),
            ),
          ),
        ),
      );

      final wrapperFinder = find.byType(AccessibleSemanticWrapper);
      expect(
        tester.getSemantics(wrapperFinder),
        matchesSemantics(
          label: 'Battery level 90 percent',
          isHeader: true,
        ),
      );
    });
  });
}
