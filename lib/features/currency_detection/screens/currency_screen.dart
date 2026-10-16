import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/widgets/live_camera_viewport.dart';
import '../services/currency_detection_service.dart';

class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen> {
  bool _isScanning = false;
  int _detectedValue = 500;
  bool _hasDetected = true;
  int _runningWalletTotal = 500;
  int _scannedNotesCount = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strings = AppStrings.of(context);
      ref.read(unifiedVoiceControllerProvider).speak(
            '${strings.cashDetectorTitle}. ${strings.tapToScan}',
          );
      _scanCurrency();
    });
  }

  Future<void> _scanCurrency() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    final strings = AppStrings.of(context);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final currencyService = ref.read(currencyDetectionServiceProvider);
    final cameraService = ref.read(cameraServiceProvider);
    final historyRepo = ref.read(historyRepositoryProvider);

    await haptics.trigger(HapticPattern.processingStarted);
    await voice.speak(strings.tapToScan);

    final frame = await cameraService.takePicture();
    if (frame == null) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      await haptics.trigger(HapticPattern.actionError);
      await voice.speak('Camera is not ready. Please verify camera permissions.');
      return;
    }

    final result = await currencyService.identifyCurrency(
      frame,
      languageCode: strings.locale.languageCode,
    );

    if (!mounted) return;

    final isDetected = result.isConfident && result.denomination.numericValue > 0;

    setState(() {
      _isScanning = false;
      _hasDetected = isDetected;
      _detectedValue = isDetected ? result.denomination.numericValue : 0;
    });

    if (isDetected) {
      final noteVal = result.denomination.numericValue;
      setState(() {
        _runningWalletTotal += noteVal;
        _scannedNotesCount += 1;
      });

      await historyRepo.addEntry(HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Currency: ₹$noteVal (Total: ₹$_runningWalletTotal)',
        category: 'currency',
        content: result.spokenMessage,
        timestamp: DateTime.now(),
      ));
      await haptics.trigger(HapticPattern.actionSuccess);

      await voice.speak(result.spokenMessage);
    } else {
      await haptics.trigger(HapticPattern.actionError);
      final guidance = result.retryInstructions ?? 'Note not identified. Please place note flat under good light.';
      await voice.speak(result.spokenMessage.isNotEmpty ? result.spokenMessage : guidance);
    }
  }

  String? _lastCurrencyTouchZone;
  DateTime _lastCurrencyTouchTime = DateTime.now();

  void _handleScreenTouch(Offset localPos, Size size, AppStrings strings) {
    final normY = (localPos.dy / size.height).clamp(0.0, 1.0);
    final isMr = strings.locale.languageCode.startsWith('mr');
    final isHi = strings.locale.languageCode.startsWith('hi');

    String zone;
    String feedback;

    if (normY < 0.60) {
      zone = 'viewfinder';
      feedback = isMr
          ? 'कॅमेरा दृश्य. नोट तपासण्यासाठी सपाट ठेवा.'
          : (isHi
              ? 'कैमरा दृश्य। नोट पहचानने के लिए सीधा रखें।'
              : 'Banknote camera viewfinder. Place note flat to scan.');
    } else if (normY < 0.82) {
      zone = 'total_value';
      feedback = isMr
          ? 'एकूण मूल्य: ₹$_detectedValue. ${strings.notesFound}.'
          : (isHi
              ? 'कुल मूल्य: ₹$_detectedValue. ${strings.notesFound}।'
              : 'Total value: ₹$_detectedValue. ${strings.notesFound}.');
    } else {
      zone = 'scan_button';
      feedback = isMr
          ? 'स्कॅन बटण. नोट ओळखण्यासाठी दोनदा टॅप करा.'
          : (isHi
              ? 'स्कैन बटन। नोट पहचानने के लिए दो बार टैप करें।'
              : 'Scan banknote button. Double tap to capture and identify.');
    }

    final now = DateTime.now();
    if (zone != _lastCurrencyTouchZone || now.difference(_lastCurrencyTouchTime).inMilliseconds > 2200) {
      _lastCurrencyTouchZone = zone;
      _lastCurrencyTouchTime = now;
      ref.read(hapticServiceProvider).trigger(HapticPattern.lightTap);
      ref.read(unifiedVoiceControllerProvider).speak(feedback, interrupt: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final strings = AppStrings.of(context);
    final haptics = ref.watch(hapticServiceProvider);

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
          strings.cashDetectorTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _handleScreenTouch(e.localPosition, screenSize, strings),
              onPointerMove: (e) => _handleScreenTouch(e.localPosition, screenSize, strings),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banknote Viewfinder Container with Neon Focus Frame & Live Camera
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                    border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                  ),
                  child: LiveCameraViewport(
                    cameraService: ref.watch(cameraServiceProvider),
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                    overlay: Stack(
                      children: [
                        // Viewfinder Frame Corners
                        Center(
                          child: Container(
                            width: 260,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.successGreen,
                                width: 2.5,
                              ),
                              color: AppColors.successGreen.withValues(alpha: 0.08),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.currency_rupee_rounded,
                                    size: 48,
                                    color: AppColors.successGreen.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isScanning ? 'Scanning...' : '₹$_detectedValue',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Green Confirmation Pill Badge (Matching Reference Screen 7)
                        if (_hasDetected)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen,
                                  borderRadius: BorderRadius.circular(AccessibilityTokens.radiusPill),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.successGreen.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      '₹$_detectedValue ${strings.noteDetected}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
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
              ),
              const SizedBox(height: 18),

              // Total Value Card (Matching Reference Screen 7)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                  border: Border.all(color: AppColors.cardBorderDark, width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.successGreen,
                      ),
                      child: const Center(
                        child: Icon(Icons.currency_rupee_rounded, color: Colors.black, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.totalValue,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹$_detectedValue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          strings.notesFound,
                          style: const TextStyle(
                            color: AppColors.successGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.restart_alt_rounded, color: Colors.white60),
                      tooltip: 'Reset wallet counter ($_scannedNotesCount notes)',
                      onPressed: () {
                        setState(() {
                          _runningWalletTotal = 0;
                          _scannedNotesCount = 0;
                          _detectedValue = 0;
                        });
                        ref.read(hapticServiceProvider).trigger(HapticPattern.lightTap);
                        ref.read(unifiedVoiceControllerProvider).speak('Wallet total reset to zero.');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Elevated Glowing Mic / Scan Button (Matching Reference Screen 7)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: strings.tapToScan,
                      child: InkWell(
                        onTap: () {
                          haptics.trigger(HapticPattern.actionSuccess);
                          _scanCurrency();
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
                            _isScanning ? Icons.sync_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.tapToScan,
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
      );
    },
  ),
),
);
}
}
