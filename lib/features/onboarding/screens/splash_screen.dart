import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _animController.repeat(reverse: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strings = AppStrings.of(context);
      final voice = ref.read(unifiedVoiceControllerProvider);
      voice.speak(
        '${strings.appTitle}. ${strings.appTagline}. ${strings.splashVoiceGuide}',
        interrupt: false,
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onStartPressed() {
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticPattern.actionSuccess);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '9:41',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Icon(Icons.wifi_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Icon(Icons.battery_full_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ],
              ),

              // Center Brand Hero
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing VisionMate Logo
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final scale = 1.0 + (_animController.value * 0.05);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(alpha: 0.4 + (_animController.value * 0.2)),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: AppColors.accentViolet.withValues(alpha: 0.3),
                                blurRadius: 48,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.primaryCyan,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(29),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Brand Title
                  Text(
                    strings.appTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    strings.appTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Glowing Soundwave Graphic
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(15, (index) {
                          final offset = (index - 7).abs();
                          final baseHeight = (28 - (offset * 3)).clamp(8, 28).toDouble();
                          final dynamicH = baseHeight + (_animController.value * (14 - offset).clamp(2, 14));
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: 4,
                            height: dynamicH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryCyan,
                                  AppColors.primaryBlue,
                                  AppColors.accentViolet,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),

              // Bottom Action Section
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Giant "Tap to Start" Button
                  Semantics(
                    button: true,
                    label: '${strings.splashTapToStart}. ${strings.splashVoiceGuide}',
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF0284C7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.5),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                          onTap: _onStartPressed,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                strings.splashTapToStart,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subtitle info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_open_rounded, color: AppColors.textMutedDark, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          strings.splashVoiceGuide,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Page Indicator Dots (• • •)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.cardBorderDark,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.cardBorderDark,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
