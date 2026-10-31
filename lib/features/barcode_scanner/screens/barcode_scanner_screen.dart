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
import '../services/barcode_scanner_service.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isAnalyzing = false;
  BarcodeProductResult? _currentResult;

  final CameraLuminanceService _luminanceService = CameraLuminanceService();
  late final BarcodeScannerService _barcodeService;

  @override
  void initState() {
    super.initState();
    _barcodeService = BarcodeScannerService(
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
            ? 'बारकोड स्कॅनर सुरू झाले आहे. कॅमेरा उत्पादनाच्या बारकोडवर धरा आणि खालील बटणावर टॅप करा.'
            : 'Barcode scanner active. Point camera at product barcode and tap scan.',
        interrupt: true,
      );
    } catch (e) {
      debugPrint('[BarcodeScannerScreen] Camera init error: $e');
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
    await tts.speak(isMr ? 'बारकोड तपासत आहे...' : 'Scanning barcode...');

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

      final result = await _barcodeService.scanBarcodeFromImage(image, languageCode: lang);

      if (!mounted) return;
      setState(() {
        _currentResult = result;
      });

      if (result.barcodeValue.isNotEmpty) {
        await haptic.trigger(HapticPattern.actionSuccess);
      } else {
        await haptic.trigger(HapticPattern.hazardDetected);
      }

      await tts.speak(result.spokenSummary, interrupt: true);
    } catch (e) {
      debugPrint('[BarcodeScannerScreen] Capture error: $e');
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
    _barcodeService.dispose();
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
            isMr ? 'बारकोड व वस्तू ओळख' : 'Product Barcode Identifier',
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

            // Barcode result card
            if (_currentResult != null && _currentResult!.barcodeValue.isNotEmpty)
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
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentResult!.productName.isNotEmpty
                                    ? _currentResult!.productName
                                    : 'बारकोड: ${_currentResult!.barcodeValue}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_currentResult!.category.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '🏷️ श्रेणी: ${_currentResult!.category}',
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          _currentResult!.spokenSummary,
                          style: const TextStyle(fontSize: 13, color: AppColors.primaryCyan),
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
                    backgroundColor: _isAnalyzing ? Colors.grey : const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _isAnalyzing ? null : _captureAndAnalyze,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner_rounded, color: Colors.black, size: 28),
                  label: Text(
                    _isAnalyzing ? 'स्कॅन करत आहे...' : (isMr ? 'बारकोड स्कॅन करा' : 'Scan Barcode'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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
