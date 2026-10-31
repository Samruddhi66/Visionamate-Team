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
import '../services/medicine_scanner_service.dart';

class MedicineScannerScreen extends ConsumerStatefulWidget {
  const MedicineScannerScreen({super.key});

  @override
  ConsumerState<MedicineScannerScreen> createState() => _MedicineScannerScreenState();
}

class _MedicineScannerScreenState extends ConsumerState<MedicineScannerScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isAnalyzing = false;
  MedicineAnalysisResult? _currentResult;

  final CameraLuminanceService _luminanceService = CameraLuminanceService();
  late final MedicineScannerService _scannerService;

  @override
  void initState() {
    super.initState();
    _scannerService = MedicineScannerService(
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
            ? 'औषध स्कॅनर सुरू झाले आहे. कॅमेरा औषधाच्या पाकिटावर धरा आणि खालील बटणावर टॅप करा.'
            : 'Medicine scanner active. Point camera at medicine label or blister pack and tap scan.',
        interrupt: true,
      );
    } catch (e) {
      debugPrint('[MedicineScannerScreen] Camera error: $e');
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
    await tts.speak(isMr ? 'औषध तपासले जात आहे...' : 'Analyzing medicine...');

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      // Auto-light check
      final lightNotice = await _luminanceService.checkAndAdjustLighting(
        imageBytes: bytes,
        cameraController: _cameraController,
        autoTorchEnabled: prefs.autoTorchEnabled,
        languageCode: lang,
      );
      if (lightNotice != null) {
        await tts.speak(lightNotice, interrupt: false);
      }

      final result = await _scannerService.scanMedicine(image, languageCode: lang);

      if (!mounted) return;
      setState(() {
        _currentResult = result;
      });

      if (result.isExpired) {
        await haptic.trigger(HapticPattern.hazardDetected);
      } else {
        await haptic.trigger(HapticPattern.actionSuccess);
      }

      await tts.speak(result.spokenSummary, interrupt: true);
    } catch (e) {
      debugPrint('[MedicineScannerScreen] Capture error: $e');
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
            isMr ? 'औषध व एक्सपायरी स्कॅनर' : 'Medicine & Expiry Scanner',
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

            // Result Display Card
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
                      color: _currentResult!.isExpired
                          ? const Color(0xFF7F1D1D).withValues(alpha: 0.95)
                          : AppColors.surfaceDark.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _currentResult!.isExpired ? Colors.redAccent : AppColors.primaryCyan,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _currentResult!.isExpired ? Icons.warning_rounded : Icons.medical_services_rounded,
                              color: _currentResult!.isExpired ? Colors.redAccent : AppColors.primaryCyan,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentResult!.medicineName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '📅 एक्सपायरी: ${_currentResult!.expiryDate}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _currentResult!.isExpired ? Colors.yellowAccent : Colors.white70,
                          ),
                        ),
                        if (_currentResult!.dosage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '💊 डोस: ${_currentResult!.dosage}',
                              style: const TextStyle(fontSize: 14, color: Colors.white),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          _currentResult!.spokenSummary,
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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
                    backgroundColor: _isAnalyzing ? Colors.grey : AppColors.primaryCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _isAnalyzing ? null : _captureAndAnalyze,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 28),
                  label: Text(
                    _isAnalyzing ? 'तपासत आहे...' : (isMr ? 'औषध स्कॅन करा' : 'Scan Medicine'),
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
