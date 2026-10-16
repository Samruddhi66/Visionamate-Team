import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/coordinator/unified_voice_controller.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/speech/voice_command_router.dart';

class VoiceAssistantModal extends ConsumerStatefulWidget {
  const VoiceAssistantModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const VoiceAssistantModal(),
    );
  }

  @override
  ConsumerState<VoiceAssistantModal> createState() => _VoiceAssistantModalState();
}

class _VoiceAssistantModalState extends ConsumerState<VoiceAssistantModal> {
  final TextEditingController _textController = TextEditingController();

  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(unifiedVoiceControllerProvider);
      controller.onCommandDispatched = _handleCommand;
      controller.startListening();
    });
  }

  void _handleCommand(ParsedVoiceCommand command) {
    if (!mounted) return;

    final haptics = ref.read(hapticServiceProvider);

    switch (command.actionType) {
      case VoiceActionType.describeSurroundings:
        haptics.trigger(HapticPattern.actionSuccess);
        Navigator.of(context).pop();
        context.push('/scene');
        break;
      case VoiceActionType.readText:
        haptics.trigger(HapticPattern.actionSuccess);
        Navigator.of(context).pop();
        context.push('/ocr');
        break;
      case VoiceActionType.identifyCurrency:
        haptics.trigger(HapticPattern.actionSuccess);
        Navigator.of(context).pop();
        context.push('/currency');
        break;
      case VoiceActionType.identifyObject:
        haptics.trigger(HapticPattern.actionSuccess);
        Navigator.of(context).pop();
        context.push('/object');
        break;
      case VoiceActionType.imageQa:
        haptics.trigger(HapticPattern.actionSuccess);
        Navigator.of(context).pop();
        context.push('/image-qa');
        break;
      case VoiceActionType.navigateToPlace:
        haptics.trigger(HapticPattern.actionSuccess);
        Navigator.of(context).pop();
        context.push('/navigation', extra: command.argument);
        break;
      case VoiceActionType.emergencySos:
        haptics.trigger(HapticPattern.hazardDetected);
        Navigator.of(context).pop();
        context.push('/emergency');
        break;
      case VoiceActionType.openSettings:
        haptics.trigger(HapticPattern.lightTap);
        Navigator.of(context).pop();
        context.push('/settings');
        break;
      case VoiceActionType.stopSpeaking:
        ref.read(unifiedVoiceControllerProvider).stopSpeaking();
        break;
      case VoiceActionType.repeatLast:
        ref.read(unifiedVoiceControllerProvider).repeatLast();
        break;
      case VoiceActionType.help:
        ref.read(unifiedVoiceControllerProvider).speak(
              'You can say: Describe surroundings, Read text, Identify currency, Navigate to a place, or Emergency.',
            );
        break;
      case VoiceActionType.wake:
        ref.read(unifiedVoiceControllerProvider).speak(
              'VisionMate is active and ready. What would you like to do?',
            );
        break;
      case VoiceActionType.cancelOperation:
        break;
      case VoiceActionType.unknown:
        final query = command.rawSpokenText.trim();
        if (query.isNotEmpty) {
          _handleGeneralQuery(query);
        }
        break;
    }
  }

  Future<void> _handleGeneralQuery(String query) async {
    final voice = ref.read(unifiedVoiceControllerProvider);
    final gemini = ref.read(geminiVisionServiceProvider);
    final haptics = ref.read(hapticServiceProvider);
    final lang = ref.read(preferencesServiceProvider).language;

    setState(() {
      _conversationHistory.add({'role': 'user', 'text': query});
    });

    await haptics.trigger(HapticPattern.processingStarted);
    final analyzingSpeech = lang.startsWith('mr')
        ? 'विचार करत आहे...'
        : (lang.startsWith('hi') ? 'सोच रहा हूँ...' : 'Analyzing...');
    await voice.speak(analyzingSpeech);

    final langInstruction = lang.startsWith('mr')
        ? 'The user speaks Marathi (मराठी). You MUST respond in fluent, grammatically correct, natural Marathi for Text-to-Speech in 1 to 2 spoken sentences.'
        : (lang.startsWith('hi')
            ? 'The user speaks Hindi (हिन्दी). You MUST respond in fluent, grammatically correct, natural Hindi for Text-to-Speech in 1 to 2 spoken sentences.'
            : 'Answer clearly and concisely in 1 to 2 spoken English sentences.');

    try {
      final answer = await gemini.askGemini(
        prompt: 'You are VisionMate, an intelligent assistive voice companion for visually impaired people. '
            'Answer this spoken user question or request directly, clearly, and concisely: "$query"\n$langInstruction',
      );

      if (!mounted) return;

      setState(() {
        _conversationHistory.add({'role': 'assistant', 'text': answer});
      });

      await haptics.trigger(HapticPattern.actionSuccess);
      await voice.speak(answer);
    } catch (e) {
      if (mounted) {
        final fallback = lang.startsWith('mr')
            ? 'मी ऐकले. आपण मला परिसर, नोटा, मजकूर किंवा मार्गदर्शनाबद्दल विचारू शकता.'
            : (lang.startsWith('hi')
                ? 'मैंने सुना। आप मुझसे आसपास की स्थिति, नोट, टेक्स्ट या दिशा के बारे में पूछ सकते हैं।'
                : 'I heard you. You can ask me about surroundings, currency, text, or directions.');
        setState(() {
          _conversationHistory.add({
            'role': 'assistant',
            'text': fallback,
          });
        });
        await voice.speak(fallback);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final strings = AppStrings.of(context);
    final voiceController = ref.watch(unifiedVoiceControllerProvider);
    final haptics = ref.watch(hapticServiceProvider);
    final snapshot = voiceController.snapshot;
    final isListening = snapshot.state == VoiceSessionState.listening;

    return Semantics(
      label: 'Voice Assistant interaction dialog',
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.primaryCyan, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.cardBorderDark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Bar (Soundwave Icon + Voice Assistant + Settings Gear) - Matching Reference Screen 5
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E293B),
                      ),
                      child: const Center(
                        child: Icon(Icons.graphic_eq_rounded, color: AppColors.primaryCyan, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      strings.voiceAssistantTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                      tooltip: 'Settings',
                      onPressed: () {
                        haptics.trigger(HapticPattern.lightTap);
                        Navigator.pop(context);
                        context.push('/settings');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      tooltip: 'Close',
                      onPressed: () {
                        voiceController.cancelListening();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Conversational Chat Bubbles History (Matching Reference Screen 5)
            Expanded(
              child: _conversationHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryCyan.withValues(alpha: 0.12),
                              border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.graphic_eq_rounded, color: AppColors.primaryCyan, size: 36),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Listening in real time...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Speak commands like "Describe surroundings", "Read text", or "Identify currency".',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildQuickChip('👁️ Describe Scene', () {
                                Navigator.pop(context);
                                context.push('/scene-analysis');
                              }),
                              _buildQuickChip('💵 Identify Cash', () {
                                Navigator.pop(context);
                                context.push('/currency');
                              }),
                              _buildQuickChip('📄 Read Text', () {
                                Navigator.pop(context);
                                context.push('/ocr');
                              }),
                              _buildQuickChip('🧭 Start Navigation', () {
                                Navigator.pop(context);
                                context.push('/navigation');
                              }),
                            ],
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversationHistory.length,
                      itemBuilder: (context, index) {
                  final msg = _conversationHistory[index];
                  final isUser = msg['role'] == 'user';

                  if (isUser) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12, left: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          msg['text']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  } else {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14, right: 30),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                          border: Border.all(color: AppColors.cardBorderDark, width: 1.2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1E293B),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryCyan, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                msg['text']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),

            // Quick Prompt Suggestion Chips (Matching Reference Screen 5)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickActionChip(
                    icon: Icons.article_rounded,
                    label: strings.quickPromptReadText,
                    onTap: () {
                      haptics.trigger(HapticPattern.lightTap);
                      Navigator.pop(context);
                      context.push('/ocr');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionChip(
                    icon: Icons.currency_rupee_rounded,
                    label: strings.quickPromptDetectCurrency,
                    onTap: () {
                      haptics.trigger(HapticPattern.lightTap);
                      Navigator.pop(context);
                      context.push('/currency');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionChip(
                    icon: Icons.explore_rounded,
                    label: strings.quickPromptWhatsAround,
                    onTap: () {
                      haptics.trigger(HapticPattern.lightTap);
                      Navigator.pop(context);
                      context.push('/scene');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionChip(
                    icon: Icons.camera_alt_rounded,
                    label: strings.quickPromptOpenCamera,
                    onTap: () {
                      haptics.trigger(HapticPattern.lightTap);
                      Navigator.pop(context);
                      context.push('/scene');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Giant Elevated Glowing Mic Button with "Tap to speak" (Matching Reference Screen 5)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: isListening ? strings.stopSpeaking : strings.tapToSpeak,
                    child: InkWell(
                      onTap: () {
                        if (isListening) {
                          haptics.trigger(HapticPattern.lightTap);
                          voiceController.cancelListening();
                        } else {
                          haptics.trigger(HapticPattern.actionSuccess);
                          voiceController.startListening();
                        }
                      },
                      borderRadius: BorderRadius.circular(42),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isListening
                                ? [AppColors.warningAmber, const Color(0xFFEA580C)]
                                : [AppColors.primaryCyan, AppColors.primaryBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isListening ? AppColors.warningAmber : AppColors.primaryCyan)
                                  .withValues(alpha: 0.5),
                              blurRadius: 22,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isListening ? strings.listening : strings.tapToSpeak,
                    style: TextStyle(
                      color: isListening ? AppColors.primaryCyan : AppColors.textSecondaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
        border: Border.all(color: AppColors.cardBorderDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.primaryCyan, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: const Color(0xFF1E293B),
      side: const BorderSide(color: Color(0xFF334155)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: onTap,
    );
  }
}
