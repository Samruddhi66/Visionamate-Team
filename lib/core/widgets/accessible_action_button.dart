import 'package:flutter/material.dart';
import '../../app/theme/accessibility_tokens.dart';
import '../haptics/haptic_patterns.dart';
import '../haptics/haptic_service.dart';

class AccessibleActionButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double minHeight;
  final bool isLoading;
  final HapticService? hapticService;

  const AccessibleActionButton({
    super.key,
    required this.label,
    this.hint,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.minHeight = AccessibilityTokens.primaryActionMinSize,
    this.isLoading = false,
    this.hapticService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary;
    final fg = foregroundColor ?? theme.colorScheme.onPrimary;

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      hint: hint ?? 'Double tap to activate $label',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeight,
          minWidth: AccessibilityTokens.minTouchTarget,
        ),
        child: ElevatedButton(
          onPressed: (onPressed == null || isLoading)
              ? null
              : () {
                  hapticService?.trigger(HapticPattern.lightTap);
                  onPressed!();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.4),
            disabledForegroundColor: fg.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 24, color: fg),
                      const SizedBox(width: AccessibilityTokens.spaceM),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: fg,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
