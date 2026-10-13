import 'package:flutter/material.dart';
import '../../app/theme/accessibility_tokens.dart';
import '../../app/theme/app_colors.dart';
import '../haptics/haptic_patterns.dart';
import '../haptics/haptic_service.dart';
import 'accessible_action_button.dart';

class AccessibleConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final HapticService? hapticService;

  const AccessibleConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.hapticService,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    HapticService? hapticService,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AccessibleConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        hapticService: hapticService,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
        side: BorderSide(
          color: isDestructive ? AppColors.emergencyRed : AppColors.cardBorderDark,
          width: 2,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isDestructive ? AppColors.emergencyRed : Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimaryDark,
            ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  hapticService?.trigger(HapticPattern.lightTap);
                  if (onCancel != null) {
                    onCancel!();
                  } else {
                    Navigator.of(context).pop(false);
                  }
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(AccessibilityTokens.minTouchTarget, AccessibilityTokens.primaryActionMinSize),
                  foregroundColor: AppColors.textSecondaryDark,
                ),
                child: Text(
                  cancelLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: AccessibilityTokens.spaceM),
            Expanded(
              child: AccessibleActionButton(
                label: confirmLabel,
                backgroundColor: isDestructive ? AppColors.emergencyRed : AppColors.primaryCyan,
                foregroundColor: isDestructive ? Colors.white : AppColors.backgroundDark,
                onPressed: () {
                  hapticService?.trigger(
                    isDestructive ? HapticPattern.actionError : HapticPattern.actionSuccess,
                  );
                  onConfirm();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
