import 'package:flutter/material.dart';
import '../../app/theme/accessibility_tokens.dart';
import '../../app/theme/app_colors.dart';
import '../haptics/haptic_patterns.dart';
import '../haptics/haptic_service.dart';

class AccessibleFeatureCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconBackgroundColor;
  final Color? borderColor;
  final VoidCallback onTap;
  final String semanticHint;
  final HapticService? hapticService;
  final bool isEmergency;

  const AccessibleFeatureCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconBackgroundColor,
    this.borderColor,
    required this.onTap,
    required this.semanticHint,
    this.hapticService,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isEmergency ? 'Emergency SOS: $title' : title,
      hint: semanticHint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            hapticService?.trigger(
              isEmergency ? HapticPattern.emergencyStatus : HapticPattern.lightTap,
            );
            onTap();
          },
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AccessibilityTokens.featureCardMinHeight,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isEmergency
                    ? [
                        const Color(0xFF381419),
                        const Color(0xFF220D12),
                        const Color(0xFF14080B),
                      ]
                    : [
                        iconBackgroundColor.withValues(alpha: 0.24),
                        const Color(0xFF131B2E),
                        const Color(0xFF0F172A),
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
              border: Border.all(
                color: borderColor ??
                    (isEmergency
                        ? AppColors.emergencyRed
                        : iconBackgroundColor.withValues(alpha: 0.45)),
                width: isEmergency ? 2.2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isEmergency
                      ? AppColors.emergencyRed.withValues(alpha: 0.35)
                      : iconBackgroundColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
              child: Stack(
                children: [
                  // Ambient watermark icon filling the background container
                  Positioned(
                    right: -12,
                    bottom: -12,
                    child: Icon(
                      icon,
                      size: 110,
                      color: iconBackgroundColor.withValues(alpha: 0.08),
                    ),
                  ),

                  // Foreground Content: Hero Icon + Accessible Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Large prominent Hero Icon centered in container
                        Expanded(
                          child: Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxHeight < 80;
                                final badgeSize = isCompact ? 58.0 : 72.0;
                                final iconSize = isCompact ? 34.0 : 42.0;

                                return Container(
                                  width: badgeSize,
                                  height: badgeSize,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        iconBackgroundColor,
                                        iconBackgroundColor.withValues(alpha: 0.82),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(badgeSize * 0.32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: iconBackgroundColor.withValues(alpha: 0.45),
                                        blurRadius: 16,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: iconSize,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.2,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Subtitle
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
