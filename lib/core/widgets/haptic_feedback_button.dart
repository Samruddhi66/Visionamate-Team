import 'package:flutter/material.dart';
import '../haptics/haptic_patterns.dart';
import '../haptics/haptic_service.dart';
import '../../app/theme/accessibility_tokens.dart';

class HapticFeedbackButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final HapticPattern pattern;
  final HapticService? hapticService;
  final String? semanticLabel;

  const HapticFeedbackButton({
    super.key,
    required this.child,
    required this.onTap,
    this.pattern = HapticPattern.lightTap,
    this.hapticService,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AccessibilityTokens.minTouchTarget,
          minHeight: AccessibilityTokens.minTouchTarget,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusS),
          onTap: () {
            hapticService?.trigger(pattern);
            onTap();
          },
          child: Center(child: child),
        ),
      ),
    );
  }
}
