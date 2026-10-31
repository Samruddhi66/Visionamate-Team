import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/sensors/camera_luminance_service.dart';
import '../../../core/widgets/accessible_gesture_detector.dart';
import '../services/color_matcher_service.dart';

class ColorMatcherScreen extends ConsumerStatefulWidget {
  const ColorMatcherScreen({super.key});

  @override
  ConsumerState<ColorMatcherScreen> createState() => _ColorMatcherScreenState();
}

class _ColorMatcherScreenState extends ConsumerState<ColorMatcherScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isAnalyzing = false;
  ColorMatchResult? _currentResult;

  final CameraLuminanceService _luminanceService = CameraLuminanceService();
  late final ColorMatcherService _colorService;

  @override
  void initState() {
    super.initState();
    _colorService = ColorMatcherService(
      geminiService: ref.read(geminiVisionServiceProvider),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
      });

      final strings = AppStrings.of(context);
      final isMr = strings.locale.languageCode.startsWith('mr');
      ref.read(ttsServiceProvider).speak(
        isMr
            ? 'कलर व कपडे मॅचिंग सुरू झाले आहे. कॅमेरा कपड्यांवर धरा आणि खालील बटणावर टॅप करा.'
            : 'Color & clothing matcher active. Point camera at clothing and tap scan.',
        interrupt: true,
      );
    } catch (e) {
      debugPrint('[ColorMatcherScreen] Camera error: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (!_isCameraReady || _cameraController == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    final haptic = ref.read(hapticServiceProvider);
    final tts = ref.read(ttsServiceProvider);
    final prefs = ref.read(preferencesServiceProvider);
    final strings = AppStrings.of(context);
    final lang = strings.locale.languageCode;
    final isMr = lang.startsWith('mr');

    await haptic.trigger(HapticPattern.scanningStarted);
    await tts.speak(isMr ? 'रंग आणि पॅटर्न तपासत आहे...' : 'Analyzing clothing color and pattern...');

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      // Check low light
      final lightNotice = await _luminanceService.checkAndAdjustLighting(
        imageBytes: bytes,
        cameraController: _cameraController,
        autoTorchEnabled: prefs.autoTorchEnabled,
        languageCode: lang,
      );
      if (lightNotice != null) {
        await tts.speak(lightNotice, interrupt: false);
      }

      final result = await _colorService.analyzeClothing(image, languageCode: lang);

      if (!mounted) return;
      setState(() {
        _currentResult = result;
      });

      await haptic.trigger(HapticPattern.actionSuccess);
      await tts.speak(result.spokenSummary, interrupt: true);
    } catch (e) {
      debugPrint('[ColorMatcherScreen] Capture error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final tts = ref.read(ttsServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    final lang = strings.locale.languageCode;
    final isMr = lang.startsWith('mr');

    return AccessibleGestureDetector(
      ttsService: tts,
      hapticService: haptic,
      languageCode: lang,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceDark,
          title: Text(
            isMr ? 'कलर आणि कपडे मॅचिंग' : 'Color & Clothing Matcher',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _luminanceService.isTorchCurrentlyOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _luminanceService.isTorchCurrentlyOn ? Colors.amber : Colors.white,
              ),
              onPressed: () async {
                final state = await _luminanceService.toggleTorch(_cameraController);
                setState(() {});
                await tts.speak(state ? 'फ्लॅशलाइट चालू केली' : 'फ्लॅशलाइट बंद केली');
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_isCameraReady && _cameraController != null)
              Positioned.fill(
                child: CameraPreview(_cameraController!),
              )
            else
              const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)),

            // Color analysis card
            if (_currentResult != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 120,
                child: GestureDetector(
                  onTap: () {
                    tts.speak(_currentResult!.spokenSummary, interrupt: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEC4899), width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.palette_rounded, color: Color(0xFFEC4899), size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_currentResult!.itemType}: ${_currentResult!.primaryColor}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_currentResult!.pattern.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '✨ पॅटर्न: ${_currentResult!.pattern}',
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                          ),
                        if (_currentResult!.matchingAdvice.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '💡 मॅचिंग सल्ला: ${_currentResult!.matchingAdvice}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryCyan,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Scan Trigger
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: SizedBox(
                height: AccessibilityTokens.minTouchTarget + 16,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAnalyzing ? Colors.grey : const Color(0xFFEC4899),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _isAnalyzing ? null : _captureAndAnalyze,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                  label: Text(
                    _isAnalyzing ? 'ओळखत आहे...' : (isMr ? 'रंग ओळखा' : 'Identify Color'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
