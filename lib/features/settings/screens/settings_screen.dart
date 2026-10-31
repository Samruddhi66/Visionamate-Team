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

  String _getPersonaDisplayName(String persona) {
    switch (persona) {
      case 'clear_male':
        return 'Natural Confident (Male)';
      case 'auto_enhanced':
        return 'Auto-Enhanced Neural';
      case 'warm_female':
      default:
        return 'Natural Warm (Female)';
    }
  }

  void _showPersonaSelector(BuildContext context) {
    final prefs = ref.read(preferencesServiceProvider);
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
                      'Natural Voice Persona',
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
                const SizedBox(height: 14),
                _buildPersonaOption(
                  ctx,
                  title: 'Natural Warm (Female)',
                  subtitle: 'Friendly, warm conversational tone (Jenny / Google / Samantha)',
                  persona: 'warm_female',
                  icon: Icons.record_voice_over_rounded,
                  color: const Color(0xFFEC4899),
                  isSelected: prefs.voicePersona == 'warm_female',
                ),
                _buildPersonaOption(
                  ctx,
                  title: 'Natural Confident (Male)',
                  subtitle: 'Grounded, clear assistive tone (Guy / Google / David)',
                  persona: 'clear_male',
                  icon: Icons.mic_external_on_rounded,
                  color: const Color(0xFF3B82F6),
                  isSelected: prefs.voicePersona == 'clear_male',
                ),
                _buildPersonaOption(
                  ctx,
                  title: 'Auto-Enhanced Neural',
                  subtitle: 'Automatically picks the highest fidelity neural system voice',
                  persona: 'auto_enhanced',
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.primaryCyan,
                  isSelected: prefs.voicePersona == 'auto_enhanced',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonaOption(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required String persona,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    final prefs = ref.read(preferencesServiceProvider);
    final tts = ref.read(ttsServiceProvider);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);

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
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
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
          onTap: () async {
            Navigator.pop(ctx);
            await prefs.setVoicePersona(persona);
            await tts.setVoicePersona(persona);
            haptics.trigger(HapticPattern.actionSuccess);
            setState(() {});
            final sample = persona == 'clear_male'
                ? 'Hello Yogeshh! Natural male voice persona activated. I am ready to assist.'
                : (persona == 'auto_enhanced'
                    ? 'Hello Yogeshh! Enhanced neural voice activated.'
                    : 'Hello Yogeshh! Natural warm voice persona activated. VisionMate is ready.');
            await voice.speak(sample);
          },
        ),
      ),
    );
  }

  void _showAiVoiceApiDialog(BuildContext context) {
    final prefs = ref.read(preferencesServiceProvider);
    final aiVoice = ref.read(aiVoiceServiceProvider);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);

    final elevenKeyController = TextEditingController(text: prefs.elevenLabsApiKey);
    final openAiKeyController = TextEditingController(text: prefs.openAiApiKey);
    String selectedProvider = prefs.aiVoiceProvider;
    bool isTesting = false;
    String? testStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10182C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.graphic_eq_rounded, color: AppColors.primaryCyan, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'AI Human Voice API',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Connect high-fidelity AI voice APIs for warm, emotional, lifelike speech that builds deep trust. Local device voice acts as an automatic zero-latency fallback.',
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Provider Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildProviderTab(
                            'Gemini AI',
                            'gemini',
                            selectedProvider,
                            onTap: () => setSheetState(() => selectedProvider = 'gemini'),
                          ),
                          const SizedBox(width: 8),
                          _buildProviderTab(
                            'On-Device',
                            'device',
                            selectedProvider,
                            onTap: () => setSheetState(() => selectedProvider = 'device'),
                          ),
                          const SizedBox(width: 8),
                          _buildProviderTab(
                            'ElevenLabs',
                            'elevenlabs',
                            selectedProvider,
                            onTap: () => setSheetState(() => selectedProvider = 'elevenlabs'),
                          ),
                          const SizedBox(width: 8),
                          _buildProviderTab(
                            'OpenAI TTS',
                            'openai',
                            selectedProvider,
                            onTap: () => setSheetState(() => selectedProvider = 'openai'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (selectedProvider == 'gemini') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162035),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryCyan, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gemini Flash Natural Voice API',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Synthesizes studio-quality natural human speech in Marathi (मराठी), Hindi (हिन्दी), and English using your Gemini API key.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, height: 1.35),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    prefs.hasGeminiApiKey ? '✓ Gemini API key active and ready' : '⚠ Gemini API key required in Settings',
                                    style: TextStyle(
                                      color: prefs.hasGeminiApiKey ? AppColors.successGreen : AppColors.warningAmber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (selectedProvider == 'device') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162035),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.primaryCyan, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Using Google/Apple Neural On-Device Voice. Free, private, and instant 0ms latency with zero setup.',
                                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (selectedProvider == 'elevenlabs') ...[
                      const Text(
                        'ElevenLabs API Key',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: elevenKeyController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter xi-api-key...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF162035),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Uses Rachel (warm, emotional human tone) with multilingual v2 support.',
                        style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                      ),
                    ] else if (selectedProvider == 'openai') ...[
                      const Text(
                        'OpenAI API Key',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: openAiKeyController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter sk-... API key',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF162035),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Uses Nova (natural & empathetic conversational speech) model.',
                        style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                      ),
                    ],

                    if (testStatus != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        testStatus!,
                        style: TextStyle(
                          color: testStatus!.contains('success') || testStatus!.contains('Playing')
                              ? AppColors.primaryCyan
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (selectedProvider != 'device') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: isTesting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCyan),
                                    )
                                  : const Icon(Icons.play_arrow_rounded, color: AppColors.primaryCyan),
                              label: const Text('Test Voice', style: TextStyle(color: AppColors.primaryCyan)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primaryCyan),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isTesting
                                  ? null
                                  : () async {
                                      setSheetState(() {
                                        isTesting = true;
                                        testStatus = 'Connecting to Voice API...';
                                      });
                                      final key = selectedProvider == 'gemini'
                                          ? prefs.geminiApiKey
                                          : (selectedProvider == 'elevenlabs'
                                              ? elevenKeyController.text.trim()
                                              : openAiKeyController.text.trim());
                                      final success = await aiVoice.testConnection(
                                        provider: selectedProvider,
                                        apiKey: key,
                                      );
                                      setSheetState(() {
                                        isTesting = false;
                                        testStatus = success
                                            ? 'Playing natural AI audio sample!'
                                            : 'Connection failed. Please check your key.';
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await prefs.setAiVoiceProvider(selectedProvider);
                              if (selectedProvider == 'elevenlabs') {
                                await prefs.setElevenLabsApiKey(elevenKeyController.text.trim());
                              } else if (selectedProvider == 'openai') {
                                await prefs.setOpenAiApiKey(openAiKeyController.text.trim());
                              }
                              haptics.trigger(HapticPattern.actionSuccess);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                setState(() {});
                              }
                              voice.speak('Voice provider settings updated.');
                            },
                            child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProviderTab(
    String label,
    String value,
    String selectedValue, {
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryCyan.withValues(alpha: 0.18) : const Color(0xFF162035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryCyan : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
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

  void _showGeminiApiKeyDialog(BuildContext context) {
    final prefs = ref.read(preferencesServiceProvider);
    final gemini = ref.read(geminiVisionServiceProvider);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);

    final keyController = TextEditingController(text: prefs.geminiApiKey);
    bool isTesting = false;
    String? testStatus;
    bool? testSuccess;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10182C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: AppColors.primaryCyan, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Gemini AI Vision API Key',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Configure your Google AI Gemini API key for real-time scene understanding, obstacle identification, OCR, and visual Q&A. Leave blank to use Fast Local Vision mode.',
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Gemini API Key',
                        labelStyle: const TextStyle(color: AppColors.primaryCyan),
                        hintText: 'Paste key here',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF162035),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primaryCyan, width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                          onPressed: () {
                            keyController.clear();
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ),
                    if (testStatus != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: (testSuccess == true)
                              ? AppColors.successGreen.withValues(alpha: 0.15)
                              : AppColors.warningAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (testSuccess == true)
                                ? AppColors.successGreen.withValues(alpha: 0.4)
                                : AppColors.warningAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          testStatus!,
                          style: TextStyle(
                            color: (testSuccess == true) ? AppColors.successGreen : AppColors.warningAmber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryCyan,
                              side: const BorderSide(color: AppColors.primaryCyan),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isTesting
                                ? null
                                : () async {
                                    setSheetState(() {
                                      isTesting = true;
                                      testStatus = 'Testing key with Google Gemini...';
                                      testSuccess = null;
                                    });
                                    var candidateKey = keyController.text.trim();
                                    if (candidateKey.startsWith('Q.Ab8RN')) {
                                      candidateKey = 'A$candidateKey';
                                      keyController.text = candidateKey;
                                    }
                                    final ok = await gemini.testConnection(customKey: candidateKey);
                                    setSheetState(() {
                                      isTesting = false;
                                      testSuccess = ok;
                                      testStatus = ok
                                          ? 'Key verified! Connected to \${gemini.activeModel}.'
                                          : 'Test failed. Please check key format or internet.';
                                    });
                                    if (ok) {
                                      voice.speak('Gemini key verified successfully.');
                                    }
                                  },
                            child: isTesting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCyan),
                                  )
                                : const Text('Test Key', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              var savedKey = keyController.text.trim();
                              if (savedKey.startsWith('Q.Ab8RN')) {
                                savedKey = 'A$savedKey';
                              }
                              await prefs.setGeminiApiKey(savedKey);
                              haptics.trigger(HapticPattern.actionSuccess);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                              voice.speak(
                                savedKey.isNotEmpty
                                    ? 'Gemini API key saved. High-speed AI vision enabled.'
                                    : 'Gemini API key cleared. Fast local vision active.',
                              );
                            },
                            child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

            // Natural Voice Persona row
            _buildSettingsRow(
              icon: Icons.record_voice_over_rounded,
              title: 'Natural Voice Persona',
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getPersonaDisplayName(prefs.voicePersona),
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
                _showPersonaSelector(context);
              },
            ),

            // AI Human Voice API row (ElevenLabs / OpenAI / Device)
            _buildSettingsRow(
              icon: Icons.graphic_eq_rounded,
              title: 'AI Human Voice API',
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prefs.aiVoiceProvider == 'gemini'
                        ? 'Gemini Natural'
                        : (prefs.aiVoiceProvider == 'elevenlabs'
                            ? 'ElevenLabs'
                            : (prefs.aiVoiceProvider == 'openai' ? 'OpenAI TTS' : 'On-Device')),
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
                _showAiVoiceApiDialog(context);
              },
            ),

            // Gemini AI Vision API Key row
            _buildSettingsRow(
              icon: Icons.auto_awesome_rounded,
              title: 'Gemini AI Vision API Key',
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prefs.hasGeminiApiKey ? 'Configured' : 'Fast Local Mode',
                    style: TextStyle(
                      color: prefs.hasGeminiApiKey ? AppColors.successGreen : const Color(0xFF4FC3F7),
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
                _showGeminiApiKeyDialog(context);
              },
            ),

            // Test Spoken Voice row
            _buildSettingsRow(
              icon: Icons.play_circle_outline_rounded,
              title: s.testVoice,
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up_rounded, color: AppColors.primaryCyan, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Play',
                      style: TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                haptics.trigger(HapticPattern.buttonTap);
                voice.speak(
                  'Hello Yogeshh! VisionMate is ready with clear, natural voice guidance.',
                );
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

            // Section: Smart Sensors & Hardware Automation
            _buildSectionHeader('Smart Sensors & Automation'),

            // Auto Flashlight toggle
            _buildSettingsToggleRow(
              icon: Icons.flash_auto_rounded,
              title: 'Auto Flashlight (Low-Light Torch)',
              value: prefs.autoTorchEnabled,
              onChanged: (val) {
                haptics.trigger(HapticPattern.buttonTap);
                prefs.setAutoTorchEnabled(val);
                setState(() {});
                voice.speak(
                  val ? 'Auto flashlight enabled in dark environments.' : 'Auto flashlight turned off.',
                );
              },
            ),

            // Shake to SOS toggle
            _buildSettingsToggleRow(
              icon: Icons.vibration_rounded,
              title: 'Shake to SOS (3x Shake Call)',
              value: prefs.shakeSosEnabled,
              onChanged: (val) {
                haptics.trigger(HapticPattern.buttonTap);
                prefs.setShakeSosEnabled(val);
                setState(() {});
                voice.speak(
                  val ? 'Shake to SOS activated.' : 'Shake to SOS turned off.',
                );
              },
            ),

            // Smart Motion Battery Saver toggle
            _buildSettingsToggleRow(
              icon: Icons.battery_charging_full_rounded,
              title: 'Smart Motion Battery Saver',
              value: prefs.smartMotionEnabled,
              onChanged: (val) {
                haptics.trigger(HapticPattern.buttonTap);
                prefs.setSmartMotionEnabled(val);
                setState(() {});
                voice.speak(
                  val ? 'Smart motion battery saving enabled.' : 'Smart motion turned off.',
                );
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
