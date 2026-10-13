import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../app/theme/accessibility_tokens.dart';
import '../../app/theme/app_colors.dart';

enum AnnouncementSeverity {
  info,
  success,
  warning,
  error,
}

class AccessibleStatusAnnouncement extends StatefulWidget {
  final String message;
  final AnnouncementSeverity severity;
  final bool announceImmediately;

  const AccessibleStatusAnnouncement({
    super.key,
    required this.message,
    this.severity = AnnouncementSeverity.info,
    this.announceImmediately = true,
  });

  @override
  State<AccessibleStatusAnnouncement> createState() => _AccessibleStatusAnnouncementState();
}

class _AccessibleStatusAnnouncementState extends State<AccessibleStatusAnnouncement> {
  @override
  void initState() {
    super.initState();
    if (widget.announceImmediately && widget.message.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SemanticsService.sendAnnouncement(View.of(context), widget.message, TextDirection.ltr);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AccessibleStatusAnnouncement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message && widget.message.isNotEmpty) {
      SemanticsService.sendAnnouncement(View.of(context), widget.message, TextDirection.ltr);
    }
  }

  Color _getBadgeColor() {
    switch (widget.severity) {
      case AnnouncementSeverity.info:
        return AppColors.infoBlue;
      case AnnouncementSeverity.success:
        return AppColors.successGreen;
      case AnnouncementSeverity.warning:
        return AppColors.warningAmber;
      case AnnouncementSeverity.error:
        return AppColors.emergencyRed;
    }
  }

  IconData _getIcon() {
    switch (widget.severity) {
      case AnnouncementSeverity.info:
        return Icons.info_outline_rounded;
      case AnnouncementSeverity.success:
        return Icons.check_circle_outline_rounded;
      case AnnouncementSeverity.warning:
        return Icons.warning_amber_rounded;
      case AnnouncementSeverity.error:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBadgeColor();

    return Semantics(
      liveRegion: true,
      label: 'Status announcement: ${widget.message}',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AccessibilityTokens.spaceS),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusS),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(_getIcon(), color: color, size: 22),
            const SizedBox(width: AccessibilityTokens.spaceM),
            Expanded(
              child: Text(
                widget.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
