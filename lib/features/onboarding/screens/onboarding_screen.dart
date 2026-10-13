import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/widgets/accessible_action_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  final List<Map<String, String>> _onboardingSteps = [
    {
      'title': 'Welcome to VisionMate 2.0',
      'body':
          'See Beyond. Live Independently. VisionMate is an accessibility-first companion designed to describe your surroundings, read text aloud, identify rupee notes, and navigate with voice and touch feedback.',
    },
    {
      'title': 'Voice-First Interaction',
      'body':
          'Tap the large Start Voice Assistant button anytime, or say commands like "Describe surroundings", "Read text", or "Identify currency".',
    },
    {
      'title': 'Tactile Haptic Feedback',
      'body':
          'Distinct vibration patterns communicate turns, obstacles, and confirmations without requiring you to look at the screen.',
    },
    {
      'title': 'Safety & Real Intelligence',
      'body':
          'VisionMate provides real-time assistive guidance. It supplements but never replaces your white cane, mobility training, or personal safety judgment.',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentStep();
    });
  }

  void _speakCurrentStep() {
    final stepData = _onboardingSteps[_step];
    ref.read(unifiedVoiceControllerProvider).speak(
          '${stepData['title']}. ${stepData['body']}',
          interrupt: true,
        );
  }

  void _nextStep() {
    ref.read(hapticServiceProvider).trigger(HapticPattern.lightTap);
    if (_step < _onboardingSteps.length - 1) {
      setState(() => _step++);
      _speakCurrentStep();
    } else {
      ref.read(preferencesServiceProvider).setOnboardingCompleted(true);
      ref.read(hapticServiceProvider).trigger(HapticPattern.actionSuccess);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepData = _onboardingSteps[_step];
    final isLast = _step == _onboardingSteps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Brand Tag
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16233B),
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
                    border: Border.all(color: AppColors.primaryCyan, width: 2),
                  ),
                  child: const Icon(Icons.remove_red_eye_rounded, color: AppColors.primaryCyan, size: 32),
                ),
              ),
              const SizedBox(height: AccessibilityTokens.spaceL),

              // Step indicator
              Text(
                'Step ${_step + 1} of ${_onboardingSteps.length}',
                style: const TextStyle(color: AppColors.primaryCyan, fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AccessibilityTokens.spaceM),

              // Title & Body
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stepData['title']!,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AccessibilityTokens.spaceL),
                        Text(
                          stepData['body']!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondaryDark,
                                fontSize: 17,
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Repeat voice instructions button
              TextButton.icon(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryCyan),
                label: const Text('Repeat Spoken Instructions', style: TextStyle(color: AppColors.primaryCyan, fontSize: 16)),
                onPressed: _speakCurrentStep,
              ),
              const SizedBox(height: AccessibilityTokens.spaceM),

              // Next / Get Started button
              AccessibleActionButton(
                label: isLast ? 'Start Using VisionMate' : 'Next Step',
                icon: isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                onPressed: _nextStep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
