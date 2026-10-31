import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
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
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              title: Text(strings.obstacleTrafficScanner, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(strings.obstacleTrafficSubtitle, style: const TextStyle(color: AppColors.textSecondaryDark)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/obstacle-traffic');
              },
            ),
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
              leading: const Icon(Icons.settings_rounded, color: Color(0xFF3B82F6)),
              title: Text(strings.settings, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(strings.settingsSubtitle, style: const TextStyle(color: AppColors.textSecondaryDark)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/settings');
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

  String? _lastDashboardTouchZone;
  DateTime _lastDashboardTouchTime = DateTime.now();

  void _handleDashboardTouch(Offset localPos, Size size, AppStrings strings) {
    final normX = (localPos.dx / size.width).clamp(0.0, 1.0);
    final normY = (localPos.dy / size.height).clamp(0.0, 1.0);
    final lang = strings.locale.languageCode;
    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    String zone;
    String feedback;

    if (normY < 0.09) {
      if (normX < 0.28) {
        zone = 'header_menu';
        feedback = isMr
            ? 'अधिक पर्याय मेनू बटण.'
            : (isHi ? 'अन्य विकल्प मेन्यू बटन।' : 'More features menu button.');
      } else if (normX > 0.72) {
        zone = 'header_settings';
        feedback = isMr
            ? 'सुगमता आणि सेटिंग्ज बटण.'
            : (isHi ? 'सुगमता और सेटिंग्स बटन।' : 'Settings and accessibility button.');
      } else {
        zone = 'header_title';
        feedback = isMr
            ? 'VisionMate 2.0. स्वावलंबी जगा.'
            : (isHi ? 'VisionMate 2.0. स्वतंत्र जीवन जिएं।' : 'VisionMate 2.0. See beyond boundaries.');
      }
    } else if (normY < 0.16) {
      zone = 'greeting';
      feedback = isMr ? 'नमस्ते. आज तुम्हाला कशात मदत करू?' : (isHi ? 'नमस्ते। आज आपको किसमें सहायता करूं?' : 'Hello. How can I help you today?');
    } else if (normY < 0.32) {
      zone = 'hero_assistant';
      feedback = isMr
          ? 'व्हॉइस असिस्टंट: बोलण्यासाठी किंवा जेमिनीला विचारण्यासाठी टॅप करा.'
          : (isHi
              ? 'वॉइस सहायक: बोलने या जेमिनी से सहायता के लिए टैप करें।'
              : 'Voice Assistant hero card: Tap to speak voice commands or ask questions.');
    } else if (normY < 0.54) {
      if (normX < 0.5) {
        zone = 'card_nav';
        feedback = isMr ? 'नेव्हिगेशन: पायी चालण्याचे मार्गदर्शन मिळवण्यासाठी टॅप करा.' : (isHi ? 'नेविगेशन: पैदल मार्ग दर्शन के लिए टैप करें।' : 'Navigation: Tap for pedestrian walking guidance.');
      } else {
        zone = 'card_vision';
        feedback = isMr ? 'एआय व्हिजन: परिसर विश्लेषण आणि अडथळे तपासण्यासाठी टॅप करा.' : (isHi ? 'एआई विजन: परिसर और बाधा विश्लेषण के लिए टैप करें।' : 'AI Vision: Tap for real-time surroundings and scene analysis.');
      }
    } else if (normY < 0.74) {
      if (normX < 0.5) {
        zone = 'card_cash';
        feedback = isMr ? 'चलन ओळख: भारतीय नोटा ओळखण्यासाठी टॅप करा.' : (isHi ? 'कैश डिटेक्टर: भारतीय नोट पहचानने के लिए टैप करें।' : 'Cash Detector: Tap to identify Indian rupee banknotes.');
      } else {
        zone = 'card_objects';
        feedback = isMr ? 'वस्तू शोधणे: आसपासच्या वस्तू ओळखण्यासाठी टॅप करा.' : (isHi ? 'वस्तु पहचान: आसपास की वस्तुएं खोजने के लिए टैप करें।' : 'Object Recognition: Tap to identify objects around you.');
      }
    } else {
      if (normX < 0.5) {
        zone = 'card_obstacles';
        feedback = isMr ? 'अडथळे आणि ट्रॅफिक स्कॅनर: रस्ता सुरक्षिततेसाठी टॅप करा.' : (isHi ? 'बाधा और ट्रैफिक स्कैनर: सुरक्षित चलने के लिए टैप करें।' : 'Obstacle & Traffic Scanner: Tap for walking hazard safety.');
      } else {
        zone = 'card_emergency';
        feedback = isMr ? 'इमर्जन्सी एसओएस: तात्काळ मदतीसाठी टॅप करा.' : (isHi ? 'इमरजेंसी एसओएस: आपातकालीन सहायता के लिए टैप करें।' : 'Emergency SOS: Tap to call and send location to contacts.');
      }
    }

    final now = DateTime.now();
    if (zone != _lastDashboardTouchZone || now.difference(_lastDashboardTouchTime).inMilliseconds > 750) {
      _lastDashboardTouchZone = zone;
      _lastDashboardTouchTime = now;
      ref.read(hapticServiceProvider).trigger(HapticPattern.lightTap);
      ref.read(unifiedVoiceControllerProvider).speak(feedback, interrupt: true);
    }
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _handleDashboardTouch(e.localPosition, screenSize, strings),
              onPointerMove: (e) => _handleDashboardTouch(e.localPosition, screenSize, strings),
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

                        // App Title Tag with Logo
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.appTitle,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                  ),
                            ),
                          ],
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

                // Quick Status & Language Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Gemini Vision Status
                          InkWell(
                            onTap: () => context.push('/scene-analysis'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, color: AppColors.successGreen, size: 16),
                                  SizedBox(width: 5),
                                  Text(
                                    'Gemini AI Live',
                                    style: TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Quick Language Cycle Chip
                          Builder(builder: (context) {
                            final currentLocale = ref.watch(localeProvider);
                            final code = currentLocale.languageCode;
                            final label = code == 'mr' ? '🌐 मराठी' : (code == 'hi' ? '🌐 हिन्दी' : '🌐 English');
                            return InkWell(
                              onTap: () {
                                final nextCode = code == 'en' ? 'hi' : (code == 'hi' ? 'mr' : 'en');
                                ref.read(localeProvider.notifier).setLocale(nextCode);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),

                          // Quick High Contrast Toggle Chip
                          Builder(builder: (context) {
                            final currentTheme = ref.watch(themeModeProvider);
                            final isHc = currentTheme == AppThemeMode.highContrast;
                            return InkWell(
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setTheme(
                                      isHc ? AppThemeMode.dark : AppThemeMode.highContrast,
                                    );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isHc ? AppColors.hcYellow : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isHc ? AppColors.hcYellow : const Color(0xFF334155)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.contrast_rounded,
                                      color: isHc ? Colors.black : Colors.white70,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isHc ? 'High Contrast: ON' : 'High Contrast',
                                      style: TextStyle(
                                        color: isHc ? Colors.black : Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
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

                      // 5. Obstacle & Traffic Scanner (Vibrant Amber / Orange Alert)
                      AccessibleFeatureCard(
                        title: strings.obstacleTrafficScanner,
                        subtitle: strings.obstacleTrafficSubtitle,
                        icon: Icons.traffic_rounded,
                        iconBackgroundColor: const Color(0xFFF59E0B),
                        semanticHint: 'Double tap to scan vehicles, pedestrian traffic signals, stairs, and road obstacles.',
                        hapticService: hapticService,
                        onTap: () => context.push('/obstacle-traffic'),
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
  );
},
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
