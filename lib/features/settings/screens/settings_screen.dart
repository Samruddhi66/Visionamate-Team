import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/widgets/accessible_action_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  bool _isObscured = true;
  bool _isTestingApi = false;
  String? _apiTestStatus;
  bool _largeTextEnabled = true;
  bool _audioCuesEnabled = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesServiceProvider);
    _apiKeyController = TextEditingController(text: prefs.geminiApiKey);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'mr':
        return 'मराठी (Marathi)';
      case 'en':
      default:
        return 'English (US)';
    }
  }

  String _getSpeedDisplayName(double rate) {
    if (rate <= 0.35) return 'Slow';
    if (rate <= 0.6) return 'Normal';
    if (rate <= 0.85) return 'Fast';
    return 'Very Fast';
  }

  void _showLanguageSelector(BuildContext context) {
    final currentLocale = ref.read(localeProvider);
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticPattern.lightTap);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10182C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Voice Language',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLanguageOption(
                  ctx,
                  title: 'English (US)',
                  subtitle: 'Natural English speech synthesis',
                  code: 'en',
                  isSelected: currentLocale.languageCode == 'en',
                ),
                _buildLanguageOption(
                  ctx,
                  title: 'हिन्दी (Hindi - India)',
                  subtitle: 'प्राकृतिक हिंदी आवाज़ और इंटरफ़ेस',
                  code: 'hi',
                  isSelected: currentLocale.languageCode == 'hi',
                ),
                _buildLanguageOption(
                  ctx,
                  title: 'मराठी (Marathi - Maharashtra)',
                  subtitle: 'मराठी स्पष्ट उच्चार आणि संपूर्ण इंटरफेस',
                  code: 'mr',
                  isSelected: currentLocale.languageCode == 'mr',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required String code,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E2D4A) : const Color(0xFF162035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primaryCyan : Colors.white12,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryCyan)
              : null,
          onTap: () {
            Navigator.pop(ctx);
            // Set locale smoothly! LocaleNotifier updates language, TTS voice, haptics, and speaks confirmation
            ref.read(localeProvider.notifier).setLocale(code);
          },
        ),
      ),
    );
  }

  void _showSpeedSelector(BuildContext context) {
    final prefs = ref.read(preferencesServiceProvider);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10182C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final speeds = [
              {'label': 'Slow (0.35x)', 'rate': 0.35},
              {'label': 'Normal (0.5x)', 'rate': 0.5},
              {'label': 'Fast (0.75x)', 'rate': 0.75},
              {'label': 'Very Fast (0.9x)', 'rate': 0.9},
            ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Voice Speaking Speed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...speeds.map((s) {
                      final rate = s['rate'] as double;
                      final label = s['label'] as String;
                      final isSelected = (prefs.speechRate - rate).abs() < 0.1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E2D4A) : const Color(0xFF162035),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryCyan : Colors.white12,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            title: Text(label, style: const TextStyle(color: Colors.white)),
                            trailing: isSelected
                                ? const Icon(Icons.check_rounded, color: AppColors.primaryCyan)
                                : null,
                            onTap: () {
                              setModalState(() {});
                              prefs.setSpeechRate(rate);
                              ref.read(ttsServiceProvider).setSpeechRate(rate);
                              haptics.trigger(HapticPattern.buttonTap);
                              voice.speak('Voice speed updated to $label.');
                              Navigator.pop(ctx);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _testGeminiConnection() async {
    setState(() {
      _isTestingApi = true;
      _apiTestStatus = 'Testing connection to Gemini...';
    });

    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final gemini = ref.read(geminiVisionServiceProvider);

    await haptics.trigger(HapticPattern.processingStarted);
    await voice.speak('Testing Gemini API connection...');

    final isSuccess = await gemini.testConnection();

    setState(() {
      _isTestingApi = false;
      _apiTestStatus = isSuccess
          ? 'Connected successfully (${gemini.activeModel} active).'
          : 'Connection failed. Please verify API key and network.';
    });

    if (isSuccess) {
      await haptics.trigger(HapticPattern.actionSuccess);
      await voice.speak('Gemini AI connection successful! Real-time vision is active.');
    } else {
      await haptics.trigger(HapticPattern.actionError);
      await voice.speak('Connection failed. Please check your API key.');
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10182C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF1E88E5)],
                ),
              ),
              child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('VisionMate 2.0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'See Beyond • Live Independently',
              style: TextStyle(color: AppColors.primaryCyan, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Designed specifically for the blind and visually impaired community with voice-first interaction, high contrast, tactile haptic feedback, and real-time Google Gemini AI vision.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Version 2.0.0-rc1 • Multi-language (English, Hindi, Marathi)',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final locale = ref.watch(localeProvider);
    final prefs = ref.watch(preferencesServiceProvider);
    final themeMode = ref.watch(themeModeProvider);
    final haptics = ref.watch(hapticServiceProvider);
    final voice = ref.watch(unifiedVoiceControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF070B16), // Deep navy black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () {
            ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          s.settings,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            // Section 1: Accessibility (Matching Screen 8 from Design)
            _buildSectionHeader(s.accessibilitySection),

            // Voice Language row
            _buildSettingsRow(
              icon: Icons.language_rounded,
              title: s.voiceLanguage,
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getLanguageDisplayName(locale.languageCode),
                    style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                ],
              ),
              onTap: () {
                haptics.trigger(HapticPattern.buttonTap);
                _showLanguageSelector(context);
              },
            ),

            // Voice Speed row
            _buildSettingsRow(
              icon: Icons.speed_rounded,
              title: s.voiceSpeed,
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getSpeedDisplayName(prefs.speechRate),
                    style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                ],
              ),
              onTap: () {
                haptics.trigger(HapticPattern.buttonTap);
                _showSpeedSelector(context);
              },
            ),

            // High Contrast toggle
            _buildSettingsToggleRow(
              icon: Icons.contrast_rounded,
              title: s.highContrastMode,
              value: themeMode == AppThemeMode.highContrast,
              onChanged: (val) {
                haptics.trigger(HapticPattern.buttonTap);
                ref
                    .read(themeModeProvider.notifier)
                    .setTheme(val ? AppThemeMode.highContrast : AppThemeMode.dark);
                voice.speak(
                  val ? 'High contrast mode turned on.' : 'Standard dark theme active.',
                );
              },
            ),

            // Large Text toggle
            _buildSettingsToggleRow(
              icon: Icons.text_fields_rounded,
              title: s.largeText,
              value: _largeTextEnabled,
              onChanged: (val) {
                haptics.trigger(HapticPattern.buttonTap);
                setState(() => _largeTextEnabled = val);
                voice.speak(
                  val ? 'Large text sizing enabled.' : 'Standard text sizing enabled.',
                );
              },
            ),

            // Haptic Feedback toggle
            _buildSettingsToggleRow(
              icon: Icons.vibration_rounded,
              title: s.haptics,
              value: prefs.hapticsEnabled,
              onChanged: (val) {
                prefs.setHapticsEnabled(val);
                haptics.isEnabled = val;
                if (val) {
                  haptics.trigger(HapticPattern.actionSuccess);
                  voice.speak('Haptic feedback vibrations turned on.');
                } else {
                  voice.speak('Haptic vibrations disabled.');
                }
              },
            ),

            // Audio Cues toggle
            _buildSettingsToggleRow(
              icon: Icons.volume_up_rounded,
              title: s.audioCues,
              value: _audioCuesEnabled,
              onChanged: (val) {
                haptics.trigger(HapticPattern.buttonTap);
                setState(() => _audioCuesEnabled = val);
                voice.speak(
                  val ? 'Audio cues turned on.' : 'Audio cues turned off.',
                );
              },
            ),

            const SizedBox(height: 20),

            // Section 2: General
            _buildSectionHeader(s.generalSection),

            // Theme row
            _buildSettingsRow(
              icon: Icons.palette_outlined,
              title: 'Theme',
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    themeMode == AppThemeMode.highContrast ? 'High Contrast' : 'Dark',
                    style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                ],
              ),
              onTap: () {
                haptics.trigger(HapticPattern.buttonTap);
                final newMode = themeMode == AppThemeMode.dark
                    ? AppThemeMode.highContrast
                    : AppThemeMode.dark;
                ref.read(themeModeProvider.notifier).setTheme(newMode);
                voice.speak(
                  newMode == AppThemeMode.highContrast
                      ? 'High Contrast mode active.'
                      : 'Dark mode active.',
                );
              },
            ),

            // About row
            _buildSettingsRow(
              icon: Icons.info_outline_rounded,
              title: 'About',
              trailingWidget: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
              onTap: () {
                haptics.trigger(HapticPattern.buttonTap);
                _showAboutDialog(context);
              },
            ),

            const SizedBox(height: 20),

            // Section 3: Gemini Vision Intelligence
            _buildSectionHeader('AI Vision Intelligence (Google Gemini)'),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10182C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ONLINE',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Google Gemini Vision AI Active',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _isObscured,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                      filled: true,
                      fillColor: const Color(0xFF0C1324),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isObscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: AppColors.primaryCyan,
                            ),
                            onPressed: () => setState(() => _isObscured = !_isObscured),
                          ),
                          IconButton(
                            icon: const Icon(Icons.save_rounded, color: AppColors.primaryCyan),
                            onPressed: () async {
                              final newKey = _apiKeyController.text.trim();
                              await prefs.setGeminiApiKey(newKey);
                              haptics.trigger(HapticPattern.actionSuccess);
                              voice.speak('Gemini API key saved.');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_apiTestStatus != null) ...[
                    Text(
                      _apiTestStatus!,
                      style: TextStyle(
                        color: _apiTestStatus!.contains('successfully')
                            ? const Color(0xFF00E676)
                            : AppColors.warningAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  AccessibleActionButton(
                    label: _isTestingApi ? 'Testing Connection...' : 'Test Gemini Connection',
                    icon: Icons.network_check_rounded,
                    backgroundColor: const Color(0xFF1E2D4A),
                    foregroundColor: AppColors.primaryCyan,
                    onPressed: _isTestingApi ? null : _testGeminiConnection,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required Widget trailingWidget,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10182C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1C2844),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: trailingWidget,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildSettingsToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10182C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1C2844),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          value: value,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF00E676),
          inactiveThumbColor: Colors.white54,
          inactiveTrackColor: Colors.white12,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
