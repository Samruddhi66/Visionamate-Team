import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/widgets/live_camera_viewport.dart';
import '../services/object_detection_service.dart';

class ObjectRecognitionScreen extends ConsumerStatefulWidget {
  const ObjectRecognitionScreen({super.key});

  @override
  ConsumerState<ObjectRecognitionScreen> createState() => _ObjectRecognitionScreenState();
}

class _ObjectRecognitionScreenState extends ConsumerState<ObjectRecognitionScreen> {
  bool _isDetecting = false;
  bool _hasScanned = false;
  List<DetectedObject> _detections = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strings = AppStrings.of(context);
      ref.read(unifiedVoiceControllerProvider).speak(
            '${strings.objectRecognitionTitle}. ${strings.tapToHear}',
          );
      _detectObjects();
    });
  }

  Future<void> _detectObjects() async {
    if (_isDetecting) return;
    setState(() => _isDetecting = true);

    final strings = AppStrings.of(context);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);
    final objectService = ref.read(objectDetectionServiceProvider);
    final cameraService = ref.read(cameraServiceProvider);
    final historyRepo = ref.read(historyRepositoryProvider);

    await haptics.trigger(HapticPattern.processingStarted);
    await voice.speak(strings.processing);

    final frame = await cameraService.takePicture();
    if (frame == null) {
      if (!mounted) return;
      setState(() => _isDetecting = false);
      await haptics.trigger(HapticPattern.actionError);
      await voice.speak('Camera is not ready. Please verify camera permissions.');
      return;
    }

    final lang = strings.locale.languageCode;
    final detections = await objectService.detectObjects(
      frame,
      languageCode: lang,
    );

    if (!mounted) return;

    setState(() {
      _isDetecting = false;
      _hasScanned = true;
      _detections = detections;
    });

    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    final emptyMsg = isMr
        ? 'या कॅमेरा दृश्यात कोणतीही ठळक वस्तू आढळली नाही. कॅमेरा चांगल्या प्रकाशात वस्तूकडे वळवा.'
        : (isHi
            ? 'इस कैमरा दृश्य में कोई वस्तु नहीं मिली। कैमरे को रोशनी में किसी वस्तु की ओर करें।'
            : 'No distinct physical objects identified in this camera view. Point camera towards well-lit objects.');

    final summary = _detections.isNotEmpty
        ? _detections.map((d) => d.toSpokenPhrase(lang)).join('. ')
        : emptyMsg;

    if (_detections.isNotEmpty) {
      await historyRepo.addEntry(HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Objects: ${_detections.first.label}',
        category: 'object',
        content: summary,
        timestamp: DateTime.now(),
      ));
      await haptics.trigger(HapticPattern.actionSuccess);
    } else {
      await haptics.trigger(HapticPattern.lightTap);
    }

    await voice.speak(summary);
  }

  String? _lastObjectTouchZone;
  DateTime _lastObjectTouchTime = DateTime.now();

  void _handleObjectTouch(Offset localPos, Size size, AppStrings strings) {
    if (localPos.dy > size.height - 140) {
      return;
    }
    final normX = (localPos.dx / size.width).clamp(0.0, 1.0);
    final normY = (localPos.dy / size.height).clamp(0.0, 1.0);
    final lang = strings.locale.languageCode;
    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    String zone;
    String feedback;

    if (normY < 0.60) {
      RelativePosition targetPos = RelativePosition.centerAhead;
      String posName = isMr ? 'थेट समोर' : (isHi ? 'सीधे सामने' : 'directly ahead');
      if (normX < 0.33) {
        targetPos = RelativePosition.left;
        posName = isMr ? 'डावी बाजू' : (isHi ? 'बाईं ओर' : 'left side');
      } else if (normX > 0.67) {
        targetPos = RelativePosition.right;
        posName = isMr ? 'उजवी बाजू' : (isHi ? 'दाईं ओर' : 'right side');
      }

      zone = 'viewfinder_${targetPos.name}';
      final match = _detections.where((d) => d.position == targetPos).toList();
      if (match.isNotEmpty) {
        feedback = match.map((d) => d.toSpokenPhrase(lang)).join(', ');
      } else if (_detections.isNotEmpty) {
        feedback = isMr
            ? '$posName: मार्ग मोकळा आहे.'
            : (isHi ? '$posName: रास्ता साफ है।' : '$posName: area clear.');
      } else {
        feedback = isMr
            ? 'कॅमेरा दृश्य ($posName). वस्तू शोधण्यासाठी खालील माइक बटणावर टॅप करा.'
            : (isHi
                ? 'कैमरा दृश्य ($posName)। वस्तु खोजने के लिए नीचे माइक बटन पर टैप करें।'
                : 'Camera viewfinder ($posName). Tap microphone below to identify objects.');
      }
    } else if (normY < 0.82) {
      zone = 'detections_card';
      if (_detections.isNotEmpty) {
        feedback = isMr
            ? 'सापडलेल्या वस्तू: ${_detections.length} वस्तू ओळखल्या.'
            : (isHi
                ? 'पहचानी गई वस्तुएं: ${_detections.length} वस्तुएं मिलीं।'
                : 'Detected objects list: ${_detections.length} objects found.');
      } else {
        feedback = isMr
            ? 'वस्तू यादी रिकामी आहे. तपासण्यासाठी माइक बटण दाबा.'
            : (isHi
                ? 'वस्तु सूची खाली है। पहचानने के लिए माइक दबाएं।'
                : 'Objects list empty. Tap microphone to scan.');
      }
    } else {
      zone = 'mic_button';
      feedback = isMr
          ? 'वस्तू ओळख बटण. स्कॅन करण्यासाठी दोनदा टॅप करा.'
          : (isHi
              ? 'वस्तु पहचान बटन। स्कैन करने के लिए दो बार टैप करें।'
              : 'Object scan button. Double tap to detect physical objects.');
    }

    final now = DateTime.now();
    if (zone != _lastObjectTouchZone || now.difference(_lastObjectTouchTime).inMilliseconds > 800) {
      _lastObjectTouchZone = zone;
      _lastObjectTouchTime = now;
      ref.read(hapticServiceProvider).trigger(HapticPattern.lightTap);
      ref.read(unifiedVoiceControllerProvider).speak(feedback, interrupt: true);
    }
  }

  IconData _getIconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('car') || l.contains('vehicle')) return Icons.directions_car_rounded;
    if (l.contains('road') || l.contains('path') || l.contains('walkway')) return Icons.add_road_rounded;
    if (l.contains('tree') || l.contains('plant')) return Icons.park_rounded;
    if (l.contains('chair') || l.contains('seat') || l.contains('bench')) return Icons.chair_rounded;
    if (l.contains('door') || l.contains('entrance')) return Icons.door_front_door_rounded;
    if (l.contains('person') || l.contains('human')) return Icons.person_rounded;
    if (l.contains('table') || l.contains('desk')) return Icons.table_restaurant_rounded;
    if (l.contains('laptop') || l.contains('screen')) return Icons.laptop_chromebook_rounded;
    return Icons.visibility_rounded;
  }

  Color _getColorForIndex(int index) {
    const palette = [
      Color(0xFF0284C7),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
    ];
    return palette[index % palette.length];
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
          strings.objectRecognitionTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _handleObjectTouch(e.localPosition, screenSize, strings),
              onPointerMove: (e) => _handleObjectTouch(e.localPosition, screenSize, strings),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Camera Viewport with Real-World AR Bounding Boxes
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                    border: Border.all(color: AppColors.cardBorderDark, width: 1.5),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boxWidth = constraints.maxWidth;
                      final boxHeight = constraints.maxHeight;

                      return LiveCameraViewport(
                        cameraService: cameraService,
                        borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                        overlay: Stack(
                          children: [
                            // Dynamic AR Bounding Boxes for all detected objects
                            for (int i = 0; i < _detections.length; i++) ...[
                              _buildArOverlayBox(
                                object: _detections[i],
                                index: i,
                                total: _detections.length,
                                containerWidth: boxWidth,
                                containerHeight: boxHeight,
                                color: _getColorForIndex(i),
                                onTap: () {
                                  haptics.trigger(HapticPattern.lightTap);
                                  voice.speak(
                                    '${_detections[i].label}, ${_detections[i].toRelativeClockString()}',
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Dynamic Detections List Card (Matching Real Camera Analysis)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AccessibilityTokens.radiusL),
                  border: Border.all(color: AppColors.cardBorderDark, width: 1.2),
                ),
                child: _isDetecting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCyan),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Detecting real-world objects...',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _detections.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                _hasScanned
                                    ? 'No objects detected. Tap microphone to rescan.'
                                    : strings.tapToHear,
                                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < _detections.length; i++) ...[
                                if (i > 0) const Divider(color: AppColors.cardBorderDark, height: 16),
                                _buildDetectionRow(
                                  icon: _getIconForLabel(_detections[i].label),
                                  iconBg: _getColorForIndex(i),
                                  name: _detections[i].label,
                                  detail: _detections[i].toRelativeClockString(),
                                  statusColor: _getColorForIndex(i),
                                ),
                              ],
                            ],
                          ),
              ),
              const SizedBox(height: 20),

              // Bottom Elevated Glowing Mic / Hear Button (Matching Reference Screen 8)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: strings.tapToHear,
                      child: InkWell(
                        onTap: () {
                          haptics.trigger(HapticPattern.actionSuccess);
                          _detectObjects();
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
                            _isDetecting ? Icons.sync_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.tapToHear,
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

  Widget _buildArOverlayBox({
    required DetectedObject object,
    required int index,
    required int total,
    required double containerWidth,
    required double containerHeight,
    required Color color,
    required VoidCallback onTap,
  }) {
    final width = (containerWidth * 0.44).clamp(110.0, 180.0);
    final height = (containerHeight * 0.32).clamp(70.0, 120.0);

    double left;
    switch (object.position) {
      case RelativePosition.left:
        left = 16.0;
        break;
      case RelativePosition.right:
        left = (containerWidth - width - 16.0).clamp(16.0, containerWidth - width);
        break;
      case RelativePosition.centerAhead:
      case RelativePosition.unknown:
        left = ((containerWidth - width) / 2).clamp(16.0, containerWidth - width);
        break;
    }

    final rowOffset = index % 3;
    final top = (24.0 + rowOffset * (height * 0.75)).clamp(
      16.0,
      (containerHeight - height - 16.0).clamp(16.0, containerHeight),
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 2.2),
            color: color.withValues(alpha: 0.14),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -12,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '${object.label} • ${object.toRelativeClockString()}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${(object.confidence * 100).toInt()}% conf',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionRow({
    required IconData icon,
    required Color iconBg,
    required String name,
    required String detail,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          detail,
          style: TextStyle(
            color: statusColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
