import 'package:flutter/material.dart';
import '../../app/theme/accessibility_tokens.dart';
import '../../app/theme/app_colors.dart';

class AccessibleLoadingIndicator extends StatelessWidget {
  final String statusMessage;
  final double? progress; // 0.0 to 1.0 or null for indeterminate

  const AccessibleLoadingIndicator({
    super.key,
    required this.statusMessage,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'In progress: $statusMessage',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AccessibilityTokens.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  color: AppColors.primaryCyan,
                  backgroundColor: AppColors.cardBorderDark,
                ),
              ),
              const SizedBox(height: AccessibilityTokens.spaceM),
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
