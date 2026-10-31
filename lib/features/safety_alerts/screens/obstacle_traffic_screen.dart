import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/audio/binaural_audio_service.dart';
import '../../../core/widgets/live_camera_viewport.dart';
import '../services/obstacle_traffic_service.dart';

// Provider for ObstacleTrafficService
final obstacleTrafficServiceProvider = Provider<ObstacleTrafficService>((ref) {
  final gemini = ref.watch(geminiVisionServiceProvider);
  return DefaultObstacleTrafficService(geminiService: gemini);
});

class ObstacleTrafficScreen extends ConsumerStatefulWidget {
  const ObstacleTrafficScreen({super.key});

  @override
  ConsumerState<ObstacleTrafficScreen> createState() => _ObstacleTrafficScreenState();
}

class _ObstacleTrafficScreenState extends ConsumerState<ObstacleTrafficScreen> {
  bool _isScanning = false;
  ObstacleTrafficScanResult? _lastScanResult;
  String _activeFilter = 'all'; // 'all', 'obstacle', 'traffic', 'signal'
  Offset? _touchPosition;
  String? _currentTouchAnnouncement;
  String? _lastSpokenZone;
  DateTime _lastSpokenTime = DateTime.now();
  final BinauralAudioService _binauralAudio = BinauralAudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strings = AppStrings.of(context);
      final isMr = strings.locale.languageCode.startsWith('mr');
      final isHi = strings.locale.languageCode.startsWith('hi');

      final welcomeMsg = isMr
          ? 'अडथळा आणि ट्रॅफिक स्कॅनर सक्रिय झाला आहे. पायऱ्या, वाहने आणि सिग्नल तपासण्यासाठी स्कॅन करा किंवा स्क्रीनला स्पर्श करा.'
          : (isHi
              ? 'बाधा और ट्रैफिक स्कैनर सक्रिय हो गया है। सीढ़ियां, गाड़ियां और सिग्नल जांचने के लिए स्कैन करें या स्क्रीन को स्पर्श करें।'
              : 'Obstacle and traffic scanner active. Scanning for stairs, vehicles, obstacles, and pedestrian signals. Touch anywhere to explore.');

      ref.read(unifiedVoiceControllerProvider).speak(welcomeMsg);
      _triggerScan();
    });
  }

  Future<void> _triggerScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    final strings = AppStrings.of(context);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final cameraService = ref.read(cameraServiceProvider);
    final obstacleService = ref.read(obstacleTrafficServiceProvider);

    await haptics.trigger(HapticPattern.processingStarted);

    final frame = await cameraService.takePicture();
    if (frame == null) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      await haptics.trigger(HapticPattern.actionError);
      final isMr = strings.locale.languageCode.startsWith('mr');
      await voice.speak(isMr ? 'कॅमेरा तयार नाही. कृपया पुन्हा प्रयत्न करा.' : 'Camera not ready. Please try again.');
      return;
    }

    final result = await obstacleService.scanSurroundings(
      frame,
      languageCode: strings.locale.languageCode,
    );

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _lastScanResult = result;
    });

    if (result.items.isNotEmpty) {
      final keyItem = result.items.firstWhere((i) => i.isCritical, orElse: () => result.items.first);
      final balance = BinauralAudioService.horizontalPositionToBalance(keyItem.x);
      _binauralAudio.playSpatialCue(balance: balance, isCritical: keyItem.isCritical);
    }

    if (result.criticalWarning != null) {
      await haptics.trigger(HapticPattern.hazardDetected);
      await voice.speak('सावधान! ${result.criticalWarning}', interrupt: true);
    } else {
      await haptics.trigger(HapticPattern.actionSuccess);
      await voice.speak(result.spokenSummary, interrupt: true);
    }
  }

  void _handleTouch(Offset localPos, Size screenSize, AppStrings strings) {
    if (localPos.dy > screenSize.height - 140 || (localPos.dy / screenSize.height) > 0.65) {
      return;
    }
    final w = screenSize.width;
    final h = screenSize.height;
    final normX = (localPos.dx / w).clamp(0.0, 1.0);
    final normY = (localPos.dy / h).clamp(0.0, 1.0);

    final isMr = strings.locale.languageCode.startsWith('mr');
    final isHi = strings.locale.languageCode.startsWith('hi');

    String zone;
    String feedback;
    HapticPattern haptic = HapticPattern.lightTap;

    // 1. Check if user touched near any detected obstacle/vehicle
    ObstacleTrafficItem? hitItem;
    if (_lastScanResult != null && _lastScanResult!.items.isNotEmpty) {
      for (final item in _lastScanResult!.items) {
        if ((normX - item.x).abs() < 0.20 && (normY - item.y).abs() < 0.20) {
          hitItem = item;
          break;
        }
      }
    }

    if (hitItem != null) {
      zone = 'item_${hitItem.label}';
      feedback = hitItem.spokenAlert;
      haptic = hitItem.isCritical ? HapticPattern.hazardDetected : HapticPattern.selectionClick;
      final balance = BinauralAudioService.horizontalPositionToBalance(hitItem.x);
      _binauralAudio.playSpatialCue(balance: balance, isCritical: hitItem.isCritical);
    } else {
      // 2. Spatial Directional Sector Feedback
      if (normY < 0.35) {
        if (normX < 0.33) {
          zone = 'upper_left';
          feedback = isMr ? 'वर डावीकडे: मोकळा परिसर' : (isHi ? 'ऊपर बाईं ओर: खाली क्षेत्र' : 'Upper left area clear');
        } else if (normX > 0.67) {
          zone = 'upper_right';
          feedback = isMr ? 'वर उजवीकडे: मोकळा परिसर' : (isHi ? 'ऊपर दाईं ओर: खाली क्षेत्र' : 'Upper right area clear');
        } else {
          zone = 'upper_center';
          feedback = isMr ? 'थेट समोर अंतरंग' : (isHi ? 'सीधे सामने दूर का दृश्य' : 'Ahead in distance');
        }
      } else if (normY <= 0.70) {
        if (normX < 0.33) {
          zone = 'mid_left';
          feedback = isMr ? 'डावी बाजू: सुरक्षित' : (isHi ? 'बाईं ओर: सुरक्षित' : 'Left side safe');
        } else if (normX > 0.67) {
          zone = 'mid_right';
          feedback = isMr ? 'उजवी बाजू: सुरक्षित' : (isHi ? 'दाईं ओर: सुरक्षित' : 'Right side safe');
        } else {
          zone = 'mid_center';
          feedback = isMr ? 'थेट समोर चालण्याचा मार्ग' : (isHi ? 'सीधे सामने पैदल रास्ता' : 'Straight ahead walking path');
        }
      } else {
        if (normX < 0.33) {
          zone = 'bottom_left';
          feedback = isMr ? 'खाली डावीकडील जमीन' : (isHi ? 'नीचे बाईं ओर ज़मीन' : 'Lower left ground');
        } else if (normX > 0.67) {
          zone = 'bottom_right';
          feedback = isMr ? 'खाली उजवीकडील जमीन' : (isHi ? 'नीचे दाईं ओर ज़मीन' : 'Lower right ground');
        } else {
          zone = 'bottom_center';
          feedback = isMr ? 'खाली थेट समोर पायवाट' : (isHi ? 'नीचे सीधे सामने रास्ता' : 'Ground path directly ahead');
        }
      }
    }

    setState(() {
      _touchPosition = localPos;
      _currentTouchAnnouncement = feedback;
    });

    final now = DateTime.now();
    final timeDiff = now.difference(_lastSpokenTime).inMilliseconds;

    if (zone != _lastSpokenZone || timeDiff > 1600) {
      _lastSpokenZone = zone;
      _lastSpokenTime = now;
      ref.read(hapticServiceProvider).trigger(haptic);
      ref.read(unifiedVoiceControllerProvider).speak(feedback, interrupt: true);
    }
  }

  void _clearTouch() {
    setState(() {
      _touchPosition = null;
      _currentTouchAnnouncement = null;
    });
    _lastSpokenZone = null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isMr = strings.locale.languageCode.startsWith('mr');
    final isHi = strings.locale.languageCode.startsWith('hi');
    final haptics = ref.watch(hapticServiceProvider);

    final titleText = isMr
        ? 'अडथळा आणि ट्रॅफिक स्कॅनर'
        : (isHi ? 'बाधा और ट्रैफिक स्कैनर' : 'Obstacle & Traffic Scanner');

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
          titleText,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryCyan),
            tooltip: 'Repeat Description',
            onPressed: () {
              if (_lastScanResult != null) {
                haptics.trigger(HapticPattern.buttonTap);
                ref.read(unifiedVoiceControllerProvider).speak(
                      _lastScanResult!.spokenSummary,
                      interrupt: true,
                    );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _handleTouch(e.localPosition, screenSize, strings),
              onPointerMove: (e) => _handleTouch(e.localPosition, screenSize, strings),
              onPointerUp: (_) => _clearTouch(),
              onPointerCancel: (_) => _clearTouch(),
              child: Stack(
                children: [
                  // 1. Live Camera Viewport
                  Positioned.fill(
                    child: LiveCameraViewport(
                      cameraService: ref.watch(cameraServiceProvider),
                      overlay: Stack(
                        children: [
                          // Render bounding markers for detected items
                          if (_lastScanResult != null)
                            ..._lastScanResult!.items.map((item) {
                              if (_activeFilter != 'all') {
                                if (_activeFilter == 'obstacle' && item.category != HazardCategory.obstacle) {
                                  return const SizedBox.shrink();
                                }
                                if (_activeFilter == 'traffic' && item.category != HazardCategory.traffic) {
                                  return const SizedBox.shrink();
                                }
                                if (_activeFilter == 'signal' && item.category != HazardCategory.trafficSignal) {
                                  return const SizedBox.shrink();
                                }
                              }

                              final left = (item.x * constraints.maxWidth) - 60;
                              final top = (item.y * (constraints.maxHeight - 160)) - 30;

                              return Positioned(
                                left: left.clamp(16.0, constraints.maxWidth - 140),
                                top: top.clamp(80.0, constraints.maxHeight - 240),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: item.highlightColor.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: item.highlightColor.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.isCritical
                                            ? Icons.warning_rounded
                                            : (item.category == HazardCategory.traffic
                                                ? Icons.directions_car_rounded
                                                : Icons.accessibility_new_rounded),
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${item.label} (${item.distanceMeters.toStringAsFixed(1)}m)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                          // Touch Cursor Indicator
                          if (_touchPosition != null)
                            Positioned(
                              left: _touchPosition!.dx - 32,
                              top: _touchPosition!.dy - 32,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primaryCyan, width: 2.5),
                                  color: AppColors.primaryCyan.withValues(alpha: 0.25),
                                ),
                                child: const Icon(
                                  Icons.touch_app_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Top Status & Critical Warning Banner
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Critical Alert Banner (e.g. Stairs or Car)
                        if (_lastScanResult?.criticalWarning != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 8),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _lastScanResult!.criticalWarning!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Touch Feedback Live Readout Banner
                        if (_currentTouchAnnouncement != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primaryCyan, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.touch_app_rounded, color: AppColors.primaryCyan, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentTouchAnnouncement!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 3. Filter Selector Chips (Obstacles, Traffic, Crossings)
                  Positioned(
                    bottom: 100,
                    left: 16,
                    right: 16,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: isMr ? 'सर्व' : (isHi ? 'सभी' : 'All'),
                            filterKey: 'all',
                            icon: Icons.all_inclusive_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: isMr ? 'अडथळे व पायऱ्या' : (isHi ? 'बाधाएं और सीढ़ियां' : 'Obstacles & Stairs'),
                            filterKey: 'obstacle',
                            icon: Icons.stairs_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: isMr ? 'वाहने व ट्रॅफिक' : (isHi ? 'गाड़ियां और ट्रैफिक' : 'Vehicles & Traffic'),
                            filterKey: 'traffic',
                            icon: Icons.directions_car_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: isMr ? 'सिग्नल व झेब्रा क्रॉसिंग' : (isHi ? 'सिग्नल और क्रॉसिंग' : 'Signals & Crossing'),
                            filterKey: 'signal',
                            icon: Icons.traffic_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Accessible Bottom Action Dock
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                        border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Scan / Rescan Button
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                icon: _isScanning
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.camera_alt_rounded, size: 22),
                                label: Text(
                                  _isScanning
                                      ? (isMr ? 'स्कॅनिंग...' : (isHi ? 'स्कैनिंग...' : 'Scanning...'))
                                      : (isMr ? 'पुन्हा स्कॅन करा' : (isHi ? 'पुनः स्कैन करें' : 'Scan Surroundings')),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                onPressed: _isScanning ? null : _triggerScan,
                              ),
                            ),
                          ),

                          // Touch Guide Pill
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cardBorderDark),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.touch_app_rounded, color: AppColors.primaryCyan, size: 24),
                              tooltip: 'Touch anywhere to explore',
                              onPressed: () {
                                final isMr = strings.locale.languageCode.startsWith('mr');
                                final msg = isMr
                                    ? 'टच मार्गदर्शन: स्क्रीनवर कुठेही बोट फिरवा. अडथळे, वाहने आणि दिशांचा आवाज ऐकू येईल.'
                                    : 'Touch exploration: Glide finger on screen to hear obstacles, traffic, and directions.';
                                ref.read(unifiedVoiceControllerProvider).speak(msg, interrupt: true);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    required IconData icon,
  }) {
    final isSelected = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).trigger(HapticPattern.selectionClick);
        setState(() => _activeFilter = filterKey);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryCyan : const Color(0xFF0F172A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : AppColors.cardBorderDark,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
