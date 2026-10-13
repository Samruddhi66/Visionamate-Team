import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/audio/tts_service.dart';
import '../../../core/camera/camera_service.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/widgets/accessible_action_button.dart';
import '../../../core/widgets/live_camera_viewport.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  bool _isProcessing = false;
  String? _extractedText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unifiedVoiceControllerProvider).speak(
            'Read Text mode. Hold phone steady over signs, documents, or labels, then tap Scan & Read.',
          );
    });
  }

  Future<void> _scanAndReadText() async {
    setState(() => _isProcessing = true);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final ocrService = ref.read(ocrServiceProvider);
    final cameraService = ref.read(cameraServiceProvider);
    final historyRepo = ref.read(historyRepositoryProvider);

    await haptics.trigger(HapticPattern.processingStarted);
    await voice.speak('Capturing and reading text...');

    final frame = await cameraService.takePicture() ??
        XFile.fromData(
          DeviceCameraService.fallbackFrameBytes,
          mimeType: 'image/jpeg',
          name: 'ocr_frame.jpg',
        );
    final result = await ocrService.recognizeText(frame);

    setState(() {
      _isProcessing = false;
      _extractedText = result.fullText.isNotEmpty ? result.fullText : (result.adviceMessage ?? 'No text detected.');
    });

    if (result.isLegible && result.fullText.isNotEmpty) {
      await historyRepo.addEntry(HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'OCR Scan',
        category: 'ocr',
        content: result.fullText,
        timestamp: DateTime.now(),
      ));
    }

    await haptics.trigger(result.isLegible ? HapticPattern.actionSuccess : HapticPattern.actionError);
    await voice.speak(_extractedText!);
  }

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsServiceProvider);
    final voice = ref.watch(unifiedVoiceControllerProvider);
    final cameraService = ref.watch(cameraServiceProvider);
    final isSpeaking = tts.state == TtsState.speaking;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: const Text('Read Text (OCR)', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Real Live Camera Viewfinder with Document Alignment Guide
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                    border: Border.all(color: const Color(0xFF00ACC1), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL - 2),
                    child: LiveCameraViewport(
                      cameraService: cameraService,
                      overlay: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Document Alignment Box Frame
                          Center(
                            child: Container(
                              margin: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF00ACC1).withValues(alpha: 0.8),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Guidance Banner
                          Positioned(
                            bottom: 12,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                              ),
                              child: Text(
                                _isProcessing ? 'Scanning text...' : 'Align Document or Sign',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AccessibilityTokens.spaceM),

              // Recognized Text Display Area
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusM),
                    border: Border.all(color: AppColors.cardBorderDark),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _extractedText ?? 'No text scanned yet. Tap Scan & Read Text to begin.',
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AccessibilityTokens.spaceM),

              // Audio Playback Controls (Pause / Stop / Repeat)
              if (_extractedText != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filledTonal(
                      icon: Icon(isSpeaking ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      tooltip: isSpeaking ? 'Pause reading' : 'Resume reading',
                      onPressed: () {
                        if (isSpeaking) {
                          tts.pause();
                        } else {
                          voice.speak(_extractedText!);
                        }
                      },
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.stop_rounded),
                      tooltip: 'Stop reading text',
                      onPressed: () => tts.stop(),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.replay_rounded),
                      tooltip: 'Repeat text from start',
                      onPressed: () => voice.speak(_extractedText!),
                    ),
                  ],
                ),
                const SizedBox(height: AccessibilityTokens.spaceM),
              ],

              // Main Capture Button
              AccessibleActionButton(
                label: _isProcessing ? 'Reading...' : 'Scan & Read Text',
                icon: Icons.text_snippet_rounded,
                backgroundColor: const Color(0xFF00ACC1),
                foregroundColor: Colors.white,
                isLoading: _isProcessing,
                onPressed: _scanAndReadText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
