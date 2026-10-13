import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/coordinator/unified_voice_controller.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/widgets/accessible_feature_card.dart';
import '../../../core/widgets/voice_command_button.dart';
import '../../voice_assistant/widgets/voice_assistant_modal.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strings = AppStrings.of(context);
      final voice = ref.read(unifiedVoiceControllerProvider);
      voice.speak(
        '${strings.appTitle}. ${strings.helpPrompt}',
        interrupt: false,
      );
    });
  }

  void _showMoreMenu(BuildContext context, AppStrings strings) {
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticPattern.lightTap);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.apps_rounded, color: AppColors.primaryCyan, size: 28),
                const SizedBox(width: 12),
                Text(
                  strings.moreFeatures,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.document_scanner_rounded, color: Color(0xFF00ACC1)),
              title: Text(strings.readText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(strings.readTextSubtitle, style: const TextStyle(color: AppColors.textSecondaryDark)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/ocr');
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_answer_rounded, color: AppColors.primaryBlue),
              title: Text(strings.aiImageQaTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Ask natural questions about photos', style: TextStyle(color: AppColors.textSecondaryDark)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/image-qa');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Saved Places', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Frequent walking destinations', style: TextStyle(color: AppColors.textSecondaryDark)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/saved');
              },
            ),
            ListTile(
              leading: const Icon(Icons.spatial_audio_off_rounded, color: AppColors.accentViolet),
              title: const Text('Voice-Guided Intro Tour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Replay audio tour & splash welcome', style: TextStyle(color: AppColors.textSecondaryDark)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/splash');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale so dashboard updates smoothly whenever user changes language
    ref.watch(localeProvider);
    final strings = AppStrings.of(context);
    final voiceController = ref.watch(unifiedVoiceControllerProvider);
    final hapticService = ref.watch(hapticServiceProvider);
    final isListening = voiceController.snapshot.state == VoiceSessionState.listening;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: CustomScrollView(
              slivers: [
                // Status bar & App Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Menu Hamburger Icon
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                          tooltip: 'More features menu',
                          onPressed: () => _showMoreMenu(context, strings),
                        ),

                        // App Title Tag
                        Text(
                          strings.appTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                              ),
                        ),

                        // Quick Accessibility Settings Icon
                        IconButton(
                          icon: const Icon(Icons.accessibility_new_rounded, color: AppColors.primaryCyan, size: 26),
                          tooltip: 'Open settings and accessibility preferences',
                          onPressed: () {
                            hapticService.trigger(HapticPattern.lightTap);
                            context.push('/settings');
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Greeting Section (Personalized Hello Yogeshh 👋)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.greetingPrefix,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 25,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.helpPrompt,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondaryDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Giant Hero Voice Assistant Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: VoiceHeroCard(
                      isListening: isListening,
                      hapticService: hapticService,
                      onTap: () {
                        hapticService.trigger(HapticPattern.actionSuccess);
                        VoiceAssistantModal.show(context);
                      },
                    ),
                  ),
                ),

                // 6 Core Features in 2x3 Grid (Matching Reference Design)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.12,
                    children: [
                  // 1. Navigation (Red Location Pin)
                  AccessibleFeatureCard(
                    title: strings.navigation,
                    subtitle: strings.navigationSubtitle,
                    icon: Icons.navigation_rounded,
                    iconBackgroundColor: const Color(0xFFEF4444),
                    semanticHint: 'Double tap to open navigation and walking guidance.',
                    hapticService: hapticService,
                    onTap: () => context.push('/navigation'),
                  ),

                  // 2. AI Vision (Cyan Camera Lens)
                  AccessibleFeatureCard(
                    title: strings.aiVision,
                    subtitle: strings.aiVisionSubtitle,
                    icon: Icons.camera_alt_rounded,
                    iconBackgroundColor: AppColors.primaryCyan,
                    semanticHint: 'Double tap to open real-time scene and obstacle analysis.',
                    hapticService: hapticService,
                    onTap: () => context.push('/scene'),
                  ),

                  // 3. Cash Detector (Emerald Green Note)
                  AccessibleFeatureCard(
                    title: strings.cashDetector,
                    subtitle: strings.cashSubtitle,
                    icon: Icons.currency_rupee_rounded,
                    iconBackgroundColor: const Color(0xFF10B981),
                    semanticHint: 'Double tap to identify Indian rupee banknote denomination.',
                    hapticService: hapticService,
                    onTap: () => context.push('/currency'),
                  ),

                  // 4. Object Recognition (Purple 3D Cube)
                  AccessibleFeatureCard(
                    title: strings.objectRecognition,
                    subtitle: strings.objectSubtitle,
                    icon: Icons.view_in_ar_rounded,
                    iconBackgroundColor: const Color(0xFF8B5CF6),
                    semanticHint: 'Double tap to identify obstacles, people, and objects.',
                    hapticService: hapticService,
                    onTap: () => context.push('/object'),
                  ),

                  // 5. Settings (Blue Gear)
                  AccessibleFeatureCard(
                    title: strings.settings,
                    subtitle: strings.settingsSubtitle,
                    icon: Icons.settings_rounded,
                    iconBackgroundColor: const Color(0xFF3B82F6),
                    semanticHint: 'Double tap to adjust language, voice rate, and accessibility.',
                    hapticService: hapticService,
                    onTap: () => context.push('/settings'),
                  ),

                  // 6. More (Vibrant Indigo Grid)
                  AccessibleFeatureCard(
                    title: strings.moreFeatures,
                    subtitle: strings.moreSubtitle,
                    icon: Icons.grid_view_rounded,
                    iconBackgroundColor: const Color(0xFF6366F1),
                    semanticHint: 'Double tap to open OCR, image Q&A, and saved places.',
                    hapticService: hapticService,
                    onTap: () => _showMoreMenu(context, strings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        selectedItemColor: AppColors.primaryCyan,
        unselectedItemColor: AppColors.textMutedDark,
        backgroundColor: AppColors.surfaceDark,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          hapticService.trigger(HapticPattern.selectionClick);
          setState(() => _currentNavIndex = index);
          switch (index) {
            case 0:
              // Home
              break;
            case 1:
              context.push('/history');
              break;
            case 2:
              // SOS Emergency One-Touch Beacon
              context.push('/emergency');
              break;
            case 3:
              // Profile / Settings
              context.push('/settings');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_filled),
            label: strings.navHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_rounded),
            label: strings.navHistory,
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emergencyRed.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.sos_rounded, color: AppColors.emergencyRed),
            ),
            label: strings.navSos,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: strings.navProfile,
          ),
        ],
      ),
    );
  }
}
