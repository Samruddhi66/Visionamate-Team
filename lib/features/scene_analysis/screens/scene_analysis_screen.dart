import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/widgets/live_camera_viewport.dart';
import '../services/scene_understanding_service.dart';

class SceneAnalysisScreen extends ConsumerStatefulWidget {
  const SceneAnalysisScreen({super.key});

  @override
  ConsumerState<SceneAnalysisScreen> createState() => _SceneAnalysisScreenState();
}

class _SceneAnalysisScreenState extends ConsumerState<SceneAnalysisScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnalyzing = false;
  String? _lastDescription;
  final String _mode = 'concise';
  Offset? _touchPosition;
  String? _currentTouchZone;
  String? _lastSpokenZone;
  DateTime _lastSpokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  late AnimationController _scannerPulseController;
  bool _isContinuousScan = false;
  Timer? _continuousScanTimer;
  int _lastLatencyMs = 0;
  bool _isLocalMode = true;
  List<ArDetectedObject> _realDetectedObjects = const [];

  @override
  void initState() {
    super.initState();
    _scannerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _scannerPulseController.repeat(reverse: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strings = AppStrings.of(context);
      ref.read(unifiedVoiceControllerProvider).speak(
            '${strings.aiVision}. Starting real-time camera analysis. Touch anywhere on the screen to explore surroundings.',
          );
      _captureAndAnalyze();
    });
  }

  @override
  void dispose() {
    _continuousScanTimer?.cancel();
    _scannerPulseController.dispose();
    super.dispose();
  }

  TouchFeedbackInfo _evaluateTouch(Offset localPos, Size screenSize) {
    final w = screenSize.width;
    final h = screenSize.height - 80;
    final x = localPos.dx;
    final y = localPos.dy;

    // 1. Bottom 3 Control Buttons (Shutter, Mic, Speaker)
    if (y > h - 110) {
      if (x < w * 0.35) {
        return const TouchFeedbackInfo(
          zone: 'Capture Button',
          description: 'Camera capture button. Tap to scan scene.',
          haptic: HapticPattern.buttonTap,
        );
      } else if (x > w * 0.65) {
        return const TouchFeedbackInfo(
          zone: 'Listen Button',
          description: 'Listen button. Tap to hear scene description.',
          haptic: HapticPattern.selectionClick,
        );
      } else {
        return const TouchFeedbackInfo(
          zone: 'Microphone Button',
          description: 'Voice assistant microphone. Tap to speak.',
          haptic: HapticPattern.listeningStarted,
        );
      }
    }

    // 2. Floating AI Analysis Card
    if (y > h - 230) {
      final desc = _lastDescription != null
          ? 'AI Analysis: $_lastDescription'
          : 'AI Analysis Card. Camera is scanning your surroundings.';
      return TouchFeedbackInfo(
        zone: 'AI Analysis Card',
        description: desc,
        haptic: HapticPattern.selectionClick,
      );
    }

    // 3. Camera Viewport Spatial Sectors (Explore by Touch)
    final camHeight = (h - 260).clamp(100.0, 2000.0);
    final normX = (x / w).clamp(0.0, 1.0);
    final normY = (y / camHeight).clamp(0.0, 1.0);

    // If a real object was detected by the AI in this location, report the real object!
    for (final obj in _realDetectedObjects) {
      if ((normX - obj.x).abs() < 0.22 && (normY - obj.y).abs() < 0.22) {
        return TouchFeedbackInfo(
          zone: obj.label,
          description: '${obj.label}, estimated ${obj.distance}',
          haptic: HapticPattern.selectionClick,
        );
      }
    }

    final lang = ref.read(preferencesServiceProvider).language;
    final isMr = lang == 'mr';
    final isHi = lang == 'hi';

    // Upper Sector (distant view)
    if (normY < 0.33) {
      if (normX < 0.33) {
        return TouchFeedbackInfo(
          zone: 'Upper Left',
          description: isMr ? 'वर डावीकडे' : (isHi ? 'ऊपर बाईं ओर' : 'Upper left sector in view.'),
          haptic: HapticPattern.lightTap,
        );
      } else if (normX > 0.67) {
        return TouchFeedbackInfo(
          zone: 'Upper Right',
          description: isMr ? 'वर उजवीकडे' : (isHi ? 'ऊपर दाईं ओर' : 'Upper right sector in view.'),
          haptic: HapticPattern.lightTap,
        );
      } else {
        return TouchFeedbackInfo(
          zone: 'Ahead in Distance',
          description: isMr ? 'थेट समोर वरची बाजू' : (isHi ? 'सीधे सामने ऊपर' : 'Directly ahead in distance.'),
          haptic: HapticPattern.lightTap,
        );
      }
    }

    // Mid / Eye-Level Sector
    if (normY <= 0.67) {
      if (normX < 0.33) {
        return TouchFeedbackInfo(
          zone: 'Left Side',
          description: isMr ? 'डावी बाजू' : (isHi ? 'बाईं ओर' : 'Left side view.'),
          haptic: HapticPattern.lightTap,
        );
      } else if (normX > 0.67) {
        return TouchFeedbackInfo(
          zone: 'Right Side',
          description: isMr ? 'उजवी बाजू' : (isHi ? 'दाईं ओर' : 'Right side view.'),
          haptic: HapticPattern.lightTap,
        );
      } else {
        return TouchFeedbackInfo(
          zone: 'Center Ahead',
          description: isMr ? 'थेट समोर मध्यभागी मार्ग' : (isHi ? 'सीधे सामने केंद्र रास्ता' : 'Front center pathway directly ahead.'),
          haptic: HapticPattern.lightTap,
        );
      }
    }

    // Lower / Ground Sector
    if (normX < 0.33) {
      return TouchFeedbackInfo(
        zone: 'Lower Left Ground',
        description: isMr ? 'खाली डावीकडे जमीन' : (isHi ? 'नीचे बाईं ओर ज़मीन' : 'Lower left ground area.'),
        haptic: HapticPattern.lightTap,
      );
    } else if (normX > 0.67) {
      return TouchFeedbackInfo(
        zone: 'Lower Right Ground',
        description: isMr ? 'खाली उजवीकडे जमीन' : (isHi ? 'नीचे दाईं ओर ज़मीन' : 'Lower right ground area.'),
        haptic: HapticPattern.lightTap,
      );
    } else {
      return TouchFeedbackInfo(
        zone: 'Ground Level Ahead',
        description: isMr ? 'थेट समोर जमिनीचा चालण्याचा मार्ग' : (isHi ? 'सीधे सामने ज़मीनी रास्ता' : 'Ground walking path directly ahead.'),
        haptic: HapticPattern.lightTap,
      );
    }
  }

  void _handlePointerEvent(PointerEvent event, Size screenSize) {
    final info = _evaluateTouch(event.localPosition, screenSize);
    final now = DateTime.now();
    final isNewZone = info.zone != _lastSpokenZone;
    final timeSinceLastSpeak = now.difference(_lastSpokenTime).inMilliseconds;

    setState(() {
      _touchPosition = event.localPosition;
      _currentTouchZone = info.zone;
    });

    if (isNewZone || timeSinceLastSpeak > 2400) {
      _lastSpokenZone = info.zone;
      _lastSpokenTime = now;
      ref.read(hapticServiceProvider).trigger(info.haptic);
      ref.read(unifiedVoiceControllerProvider).speak(info.description, interrupt: true);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    setState(() {
      _touchPosition = null;
      _currentTouchZone = null;
    });
    _lastSpokenZone = null;
  }

  Future<void> _captureAndAnalyze() async {
    if (_isAnalyzing) return;
    setState(() => _isAnalyzing = true);

    final strings = AppStrings.of(context);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final sceneService = ref.read(sceneUnderstandingServiceProvider);
    final cameraService = ref.read(cameraServiceProvider);
    final historyRepo = ref.read(historyRepositoryProvider);
    final lang = ref.read(preferencesServiceProvider).language;

    await haptics.trigger(HapticPattern.processingStarted);
    if (!_isContinuousScan) {
      await voice.speak(strings.analyzingSurroundings);
    }

    final frame = await cameraService.takePicture();
    if (frame == null) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      await haptics.trigger(HapticPattern.actionError);
      if (!_isContinuousScan) {
        await voice.speak('Camera is not ready. Please check camera permissions.');
      }
      return;
    }

    final stopwatch = Stopwatch()..start();
    final result = await sceneService.analyzeScene(
      imageFile: frame,
      verbosity: _mode == 'detailed' ? DescriptionVerbosity.detailed : DescriptionVerbosity.concise,
      languageCode: lang,
    );
    stopwatch.stop();

    if (!mounted) return;

    final isNewDesc = result.descriptionText != _lastDescription;
    setState(() {
      _isAnalyzing = false;
      _lastDescription = result.descriptionText;
      _lastLatencyMs = stopwatch.elapsedMilliseconds;
      _isLocalMode = result.isLocalInference;
      _realDetectedObjects = result.realWorldObjects;
    });

    await historyRepo.addEntry(HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Scene: ${_mode.toUpperCase()}',
      category: 'scene',
      content: result.descriptionText,
      timestamp: DateTime.now(),
    ));

    await haptics.trigger(HapticPattern.actionSuccess);
    if (!_isContinuousScan || isNewDesc) {
      await voice.speak(result.descriptionText);
    }
  }

  void _toggleContinuousScan() {
    final haptics = ref.read(hapticServiceProvider);
    final voice = ref.read(unifiedVoiceControllerProvider);
    haptics.trigger(HapticPattern.buttonTap);

    setState(() {
      _isContinuousScan = !_isContinuousScan;
    });

    if (_isContinuousScan) {
      voice.speak('Continuous fast scanning activated.');
      _continuousScanTimer?.cancel();
      _continuousScanTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
        if (!_isAnalyzing && mounted) {
          _captureAndAnalyze();
        }
      });
    } else {
      voice.speak('Continuous scanning stopped.');
      _continuousScanTimer?.cancel();
      _continuousScanTimer = null;
    }
  }

  void _showQuickApiKeyModal(BuildContext context) {
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
          builder: (ctx, setModalState) {
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
                              'Gemini AI Vision Key',
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
                    const SizedBox(height: 10),
                    const Text(
                      'Paste your Google AI Studio Gemini API key. Get yours free at aistudio.google.com → "Get API key".',
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
                                    final candidate = keyController.text.trim();
                                    if (candidate.isEmpty) {
                                      setModalState(() {
                                        testSuccess = false;
                                        testStatus = 'Please paste your API key first.';
                                      });
                                      return;
                                    }
                                    setModalState(() {
                                      isTesting = true;
                                      testStatus = 'Testing key...';
                                      testSuccess = null;
                                    });
                                    final ok = await gemini.testConnection(customKey: candidate);
                                    setModalState(() {
                                      isTesting = false;
                                      testSuccess = ok;
                                      testStatus = ok
                                          ? '✅ Connected! Real-time vision is ready.'
                                          : 'Connection failed. Key may be invalid or has no quota.';
                                    });
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
                              final savedKey = keyController.text.trim();
                              await prefs.setGeminiApiKey(savedKey);
                              haptics.trigger(HapticPattern.actionSuccess);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() {
                                  _isLocalMode = savedKey.isEmpty;
                                });
                                _captureAndAnalyze();
                              }
                              voice.speak('Key saved. Re-scanning scene.');
                            },
                            child: const Text('Save & Scan', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final strings = AppStrings.of(context);
    final voice = ref.watch(unifiedVoiceControllerProvider);
    final haptics = ref.watch(hapticServiceProvider);
    final cameraService = ref.watch(cameraServiceProvider);
    final hasApiKey = ref.watch(preferencesServiceProvider).hasGeminiApiKey;

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            haptics.trigger(HapticPattern.lightTap);
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          strings.aiVision,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Obstacle & Traffic Scanner',
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
            ),
            onPressed: () {
              haptics.trigger(HapticPattern.lightTap);
              context.push('/obstacle-traffic');
            },
          ),
          IconButton(
            tooltip: _isContinuousScan ? 'Pause Auto-Scan' : 'Enable Fast Continuous Scan',
            icon: Icon(
              _isContinuousScan ? Icons.bolt_rounded : Icons.flash_off_rounded,
              color: _isContinuousScan ? AppColors.warningAmber : Colors.white70,
            ),
            onPressed: _toggleContinuousScan,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                onTap: () => _showQuickApiKeyModal(context),
                borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isLocalMode
                        ? AppColors.primaryCyan.withValues(alpha: 0.15)
                        : AppColors.successGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                    border: Border.all(
                      color: _isLocalMode ? AppColors.primaryCyan : AppColors.successGreen,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isLocalMode ? AppColors.primaryCyan : AppColors.successGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isContinuousScan ? 'Auto-Scan ⚡' : strings.liveAnalysis,
                        style: TextStyle(
                          color: _isLocalMode ? AppColors.primaryCyan : AppColors.successGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _handlePointerEvent(e, screenSize),
          onPointerMove: (e) => _handlePointerEvent(e, screenSize),
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerUp,
          child: Stack(
            children: [
              // 1. REAL LIVE CAMERA VIEWPORT IN BACKGROUND (CLEAN - NO DUMMY BOXES)
              Positioned.fill(
                child: LiveCameraViewport(
                  cameraService: cameraService,
                  onCameraReady: () {
                    if (!_isAnalyzing && _lastDescription == null) {
                      _captureAndAnalyze();
                    }
                  },
                  overlay: Stack(
                    children: [
                      // Dynamic AR Scanning Crosshair / Radar
                      if (_isAnalyzing)
                        Center(
                          child: AnimatedBuilder(
                            animation: _scannerPulseController,
                            builder: (context, _) {
                              final scale = 0.8 + 0.3 * _scannerPulseController.value;
                              return Container(
                                width: 220 * scale,
                                height: 220 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryCyan.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryCyan,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Explore by Touch Top Indicator Pill
                      Positioned(
                        top: 14,
                        left: 16,
                        right: 16,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                              border: Border.all(
                                color: AppColors.primaryCyan.withValues(alpha: 0.5),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app_rounded, color: AppColors.primaryCyan, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Explore by Touch: Touch anywhere for voice & haptics',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Interactive Tactile Sonar Ripple Indicator
              if (_touchPosition != null)
                Positioned(
                  left: _touchPosition!.dx - 40,
                  top: _touchPosition!.dy - 40,
                  child: IgnorePointer(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Sonar glowing pulse halo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryCyan.withValues(alpha: 0.85),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(alpha: 0.45),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // Sonar Center Dot
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        // Floating HUD zone pill above finger
                        if (_currentTouchZone != null)
                          Positioned(
                            top: -38,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primaryCyan, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.touch_app_rounded, color: AppColors.primaryCyan, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentTouchZone!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // 3. Bottom Section: Floating AI Analysis Card & 3 Control Buttons
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Floating AI Analysis Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                        border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.camera_alt_rounded, color: AppColors.primaryCyan, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                strings.aiAnalysisTitle,
                                style: const TextStyle(
                                  color: AppColors.primaryCyan,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasApiKey
                                      ? AppColors.successGreen.withValues(alpha: 0.15)
                                      : AppColors.warningAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasApiKey
                                        ? AppColors.successGreen.withValues(alpha: 0.4)
                                        : AppColors.warningAmber.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final m = ref.watch(geminiVisionServiceProvider).activeModel;
                                    final display = m.contains('flash-lite')
                                        ? 'Gemini Lite'
                                        : m.contains('3.8')
                                            ? 'Gemini 3.8'
                                            : m.contains('3.5')
                                                ? 'Gemini 3.5'
                                                : 'Gemini Vision';
                                    return Text(
                                      hasApiKey
                                          ? '$display ⚡ ${_lastLatencyMs > 0 ? '${_lastLatencyMs}ms' : 'Live'}'
                                          : 'Key Required 🔑',
                                      style: TextStyle(
                                        color: hasApiKey ? AppColors.successGreen : AppColors.warningAmber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Spacer(),
                              if (!ref.read(preferencesServiceProvider).hasGeminiApiKey)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: AppColors.primaryCyan,
                                  ),
                                  icon: const Icon(Icons.key_rounded, size: 14),
                                  label: const Text('Add Key', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => _showQuickApiKeyModal(context),
                                ),
                              if (_isAnalyzing)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _lastDescription ?? strings.analyzingSurroundings,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3 Floating Action Controls: Camera, Elevated Cyan Mic, Listen
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Shutter / Capture Button (Left)
                        Semantics(
                          button: true,
                          label: strings.capture,
                          child: InkWell(
                            onTap: _isAnalyzing
                                ? null
                                : () {
                                    haptics.trigger(HapticPattern.buttonTap);
                                    _captureAndAnalyze();
                                  },
                            borderRadius: BorderRadius.circular(32),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cardDark,
                                border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ),

                        // 2. Elevated Cyan Mic Button (Center Hero)
                        Semantics(
                          button: true,
                          label: strings.tapToSpeak,
                          child: InkWell(
                            onTap: () {
                              haptics.trigger(HapticPattern.listeningStarted);
                              _captureAndAnalyze();
                            },
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
                            ),
                          ),
                        ),

                        // 3. Speaker / Listen Button (Right)
                        Semantics(
                          button: true,
                          label: strings.listen,
                          child: InkWell(
                            onTap: () {
                              haptics.trigger(HapticPattern.selectionClick);
                              if (_lastDescription != null && _lastDescription!.isNotEmpty) {
                                voice.speak(_lastDescription!);
                              } else {
                                voice.speak(strings.analyzingSurroundings);
                              }
                            },
                            borderRadius: BorderRadius.circular(32),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cardDark,
                                border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                              ),
                              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                      ],
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

class TouchFeedbackInfo {
  final String zone;
  final String description;
  final HapticPattern haptic;

  const TouchFeedbackInfo({
    required this.zone,
    required this.description,
    required this.haptic,
  });
}
