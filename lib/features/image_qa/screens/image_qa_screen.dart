import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/camera/camera_service.dart';
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
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final qaService = ref.read(imageQaServiceProvider);
    final cameraService = ref.read(cameraServiceProvider);
    final historyRepo = ref.read(historyRepositoryProvider);

    await haptics.trigger(HapticPattern.processingStarted);
    await voice.speak('Analyzing scene for: $question...');

    final frame = await cameraService.takePicture() ??
        XFile.fromData(
          DeviceCameraService.fallbackFrameBytes,
          mimeType: 'image/jpeg',
          name: 'frame.jpg',
        );

    final result = await qaService.answerQuestion(
      imageFile: frame,
      question: question,
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
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),

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
                      Text(
                        _questionController.text.isNotEmpty
                            ? _questionController.text
                            : 'What is this object?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

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
              const SizedBox(height: 20),

              // Bottom Elevated Glowing Mic Button (Matching Reference Screen 6)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: strings.tapToSpeak,
                      child: InkWell(
                        onTap: () {
                          haptics.trigger(HapticPattern.actionSuccess);
                          voice.speak('Listening for your question about this image...');
                          _askQuestion('What is this object?');
                        },
                        borderRadius: BorderRadius.circular(38),
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
                    const SizedBox(height: 8),
                    Text(
                      strings.tapToSpeak,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
