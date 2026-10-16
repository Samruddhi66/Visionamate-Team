import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/widgets/live_camera_viewport.dart';

class ImageQaScreen extends ConsumerStatefulWidget {
  const ImageQaScreen({super.key});

  @override
  ConsumerState<ImageQaScreen> createState() => _ImageQaScreenState();
}

class _ImageQaScreenState extends ConsumerState<ImageQaScreen> {
  final TextEditingController _questionController = TextEditingController(text: 'What is this object?');

  bool _isProcessing = false;
  String? _answerText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strings = AppStrings.of(context);
      ref.read(unifiedVoiceControllerProvider).speak(
            '${strings.aiImageQaTitle}. ${strings.tapToSpeak}',
          );
    });
  }

  Future<void> _askQuestion([String? customQuestion]) async {
    final question = customQuestion ?? _questionController.text.trim();
    if (question.isEmpty) {
      ref.read(unifiedVoiceControllerProvider).speak('Please speak or enter a question first.');
      return;
    }

    setState(() => _isProcessing = true);
    final strings = AppStrings.of(context);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final qaService = ref.read(imageQaServiceProvider);
    final cameraService = ref.read(cameraServiceProvider);
    final historyRepo = ref.read(historyRepositoryProvider);

    await haptics.trigger(HapticPattern.processingStarted);
    await voice.speak('Analyzing scene for: $question...');

    final frame = await cameraService.takePicture();
    if (frame == null) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      await haptics.trigger(HapticPattern.actionError);
      await voice.speak('Camera is not ready. Please verify camera permissions.');
      return;
    }

    final result = await qaService.answerQuestion(
      imageFile: frame,
      question: question,
      languageCode: strings.locale.languageCode,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _answerText = result.answer;
    });

    await historyRepo.addEntry(HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Q&A: $question',
      category: 'qa',
      content: result.answer,
      timestamp: DateTime.now(),
    ));

    await haptics.trigger(HapticPattern.actionSuccess);
    await voice.speak(_answerText!);
  }

  String? _lastQaTouchZone;
  DateTime _lastQaTouchTime = DateTime.now();

  void _handleQaTouch(Offset localPos, Size size, AppStrings strings) {
    final normY = (localPos.dy / size.height).clamp(0.0, 1.0);
    final isMr = strings.locale.languageCode.startsWith('mr');
    final isHi = strings.locale.languageCode.startsWith('hi');

    String zone;
    String feedback;

    if (normY < 0.50) {
      zone = 'viewfinder';
      feedback = isMr
          ? 'कॅमेरा दृश्य. छायाचित्राबद्दल विचारण्यासाठी टॅप करा.'
          : (isHi
              ? 'कैमरा दृश्य। तस्वीर के बारे में पूछने के लिए टैप करें।'
              : 'Live camera viewfinder. Point at anything to ask questions.');
    } else if (normY < 0.75) {
      zone = 'question_input';
      feedback = isMr
          ? 'प्रश्न बॉक्स: ${_questionController.text}. बदलण्यासाठी टॅप करा.'
          : (isHi
              ? 'प्रश्न बॉक्स: ${_questionController.text}। बदलने के लिए टैप करें।'
              : 'Question box: ${_questionController.text}. Tap to edit question.');
    } else {
      zone = 'ask_button';
      feedback = isMr
          ? 'एआय प्रश्न विचारा बटण. उत्तर मिळवण्यासाठी दोनदा टॅप करा.'
          : (isHi
              ? 'एआई प्रश्न पूछें बटन। उत्तर पाने के लिए दो बार टैप करें।'
              : 'Ask Gemini button. Double tap to capture and answer.');
    }

    final now = DateTime.now();
    if (zone != _lastQaTouchZone || now.difference(_lastQaTouchTime).inMilliseconds > 2200) {
      _lastQaTouchZone = zone;
      _lastQaTouchTime = now;
      ref.read(hapticServiceProvider).trigger(HapticPattern.lightTap);
      ref.read(unifiedVoiceControllerProvider).speak(feedback, interrupt: true);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final strings = AppStrings.of(context);
    final haptics = ref.watch(hapticServiceProvider);
    final voice = ref.watch(unifiedVoiceControllerProvider);
    final cameraService = ref.watch(cameraServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back',
          onPressed: () {
            haptics.trigger(HapticPattern.lightTap);
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          strings.aiImageQaTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _handleQaTouch(e.localPosition, screenSize, strings),
              onPointerMove: (e) => _handleQaTouch(e.localPosition, screenSize, strings),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Camera Viewport for Visual Q&A
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                    border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                  ),
                  child: LiveCameraViewport(
                    cameraService: cameraService,
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                    overlay: Center(
                      child: _isProcessing
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCyan),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Analyzing visual question...',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Question Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildPresetChip(
                      label: 'Identify Object',
                      question: 'What is this object?',
                      icon: Icons.search_rounded,
                      haptics: haptics,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'Check Colors',
                      question: 'What colors are present in this image?',
                      icon: Icons.palette_rounded,
                      haptics: haptics,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'Read Text',
                      question: 'Read any visible text in this scene',
                      icon: Icons.text_fields_rounded,
                      haptics: haptics,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'Check Safety',
                      question: 'Is the path ahead safe and clear of hazards?',
                      icon: Icons.shield_rounded,
                      haptics: haptics,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'Check Path',
                      question: 'Is there any obstacle in my walking path?',
                      icon: Icons.directions_walk_rounded,
                      haptics: haptics,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'Find Exit/Door',
                      question: 'Where is the door or exit?',
                      icon: Icons.door_front_door_rounded,
                      haptics: haptics,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Question Pill: "🔊 What is this object?" (Matching Reference Screen 6)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _questionController.text.isNotEmpty
                              ? _questionController.text
                              : 'What is this object?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // AI Response Card (Matching Reference Screen 6)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                  border: Border.all(color: AppColors.cardBorderDark, width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardDark,
                      ),
                      child: const Center(
                        child: Icon(Icons.camera_alt_rounded, color: AppColors.primaryCyan, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _answerText ??
                            'Point camera towards objects and tap microphone to ask visual questions.',
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
              const SizedBox(height: 16),

              // 3 Floating Action Controls: Camera Recapture, Elevated Cyan Mic, Listen Again
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Shutter / Retake Button (Left)
                  Semantics(
                    button: true,
                    label: strings.capture,
                    child: InkWell(
                      onTap: _isProcessing
                          ? null
                          : () {
                              haptics.trigger(HapticPattern.buttonTap);
                              _askQuestion(_questionController.text);
                            },
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardDark,
                          border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
                      ),
                    ),
                  ),

                  // 2. Elevated Cyan Mic Button (Center Hero)
                  Semantics(
                    button: true,
                    label: strings.tapToSpeak,
                    child: InkWell(
                      onTap: () {
                        haptics.trigger(HapticPattern.actionSuccess);
                        voice.speak('Listening for your question about this image...');
                        _askQuestion(_questionController.text.isNotEmpty ? _questionController.text : 'What is this object?');
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryCyan, AppColors.primaryBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryCyan.withValues(alpha: 0.45),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isProcessing ? Icons.sync_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),

                  // 3. Speaker / Repeat Button (Right)
                  Semantics(
                    button: true,
                    label: strings.listen,
                    child: InkWell(
                      onTap: () {
                        haptics.trigger(HapticPattern.selectionClick);
                        if (_answerText != null) {
                          voice.speak(_answerText!);
                        } else {
                          voice.speak('Point camera and tap the microphone to ask a visual question.');
                        }
                      },
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardDark,
                          border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                        ),
                        child: const Icon(Icons.volume_up_rounded, color: AppColors.primaryCyan, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  strings.tapToSpeak,
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
),
);
}

  Widget _buildPresetChip({
    required String label,
    required String question,
    required IconData icon,
    required dynamic haptics,
  }) {
    final isSelected = _questionController.text == question;
    return InkWell(
      onTap: _isProcessing
          ? null
          : () {
              haptics.trigger(HapticPattern.selectionClick);
              setState(() {
                _questionController.text = question;
              });
              _askQuestion(question);
            },
      borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryCyan.withValues(alpha: 0.22)
              : const Color(0xFF162035),
          borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
          border: Border.all(
            color: isSelected ? AppColors.primaryCyan : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primaryCyan : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
