import 'package:flutter/material.dart';
import '../../app/theme/accessibility_tokens.dart';
import '../../app/theme/app_colors.dart';
import '../haptics/haptic_patterns.dart';
import '../haptics/haptic_service.dart';

class VoiceHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isListening;
  final HapticService? hapticService;

  const VoiceHeroCard({
    super.key,
    required this.onTap,
    this.isListening = false,
    this.hapticService,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isListening ? 'Listening. Tap to cancel voice input.' : 'Start Voice Assistant.',
      hint: 'Double tap to open voice assistant or speak commands like "Describe surroundings".',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            hapticService?.trigger(HapticPattern.listeningStarted);
            onTap();
          },
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AccessibilityTokens.heroActionHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E2846),
                  Color(0xFF151C33),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
              border: Border.all(
                color: isListening ? AppColors.primaryCyan : const Color(0xFF2E3E66),
                width: isListening ? 2.5 : 1.5,
              ),
              boxShadow: isListening
                  ? [
                      BoxShadow(
                        color: AppColors.primaryCyan.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Glowing circular mic icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3D5AFE),
                        Color(0xFF7C4DFF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AccessibilityTokens.spaceM),
                // Titles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Start Voice Assistant',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isListening ? 'Listening now... speak clearly' : "Tap or say 'Hey VisionMate'",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryDark,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
                // Arrow navigation indicator
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.primaryCyan,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
