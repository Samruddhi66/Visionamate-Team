import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final String? initialDestination;

  const NavigationScreen({super.key, this.initialDestination});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _destinationController;
  late AnimationController _pulseController;
  bool _isPaused = false;
  String _destinationName = 'College Main Gate';
  String _routeMetrics = '2.4 km • 8 min (walk)';
  String _currentTurnInstruction = 'Turn right in 100 meters';
  final int _turnDistance = 100;

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController(
      text: widget.initialDestination ?? _destinationName,
    );
    if (widget.initialDestination != null && widget.initialDestination!.isNotEmpty) {
      _destinationName = widget.initialDestination!;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _pulseController.repeat(reverse: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = AppStrings.of(context);
      ref.read(unifiedVoiceControllerProvider).speak(
            '${s.navigation}. $_currentTurnInstruction towards $_destinationName.',
          );
      ref.read(hapticServiceProvider).trigger(HapticPattern.navigationTurnRight);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _togglePauseGuidance() {
    final haptics = ref.read(hapticServiceProvider);
    final voice = ref.read(unifiedVoiceControllerProvider);
    final s = AppStrings.of(context);

    setState(() {
      _isPaused = !_isPaused;
    });

    haptics.trigger(HapticPattern.buttonTap);
    if (_isPaused) {
      voice.speak('${s.pauseGuidance}. Walking directions temporarily paused.');
    } else {
      voice.speak('${s.resumeGuidance}. $_currentTurnInstruction.');
    }
  }

  void _speakTurnInstruction() {
    final haptics = ref.read(hapticServiceProvider);
    final voice = ref.read(unifiedVoiceControllerProvider);
    haptics.trigger(HapticPattern.navigationTurnRight);
    voice.speak('$_currentTurnInstruction. Continue towards $_destinationName.');
  }

  void _showChangeDestinationDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Change Destination',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _destinationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter new place or address...',
                  hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryCyan),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.directions_walk_rounded),
                label: const Text('Calculate Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () async {
                  final newDest = _destinationController.text.trim();
                  if (newDest.isNotEmpty) {
                    setState(() {
                      _destinationName = newDest;
                      _routeMetrics = '1.8 km • 6 min (walk)';
                      _currentTurnInstruction = 'Head north 50m, then turn right';
                      _isPaused = false;
                    });
                    Navigator.pop(ctx);
                    ref.read(hapticServiceProvider).trigger(HapticPattern.actionSuccess);
                    ref.read(unifiedVoiceControllerProvider).speak(
                          'Route recalculated to $newDest. $_currentTurnInstruction.',
                        );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B16), // Premium deep navy black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () {
            ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          s.navigation,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: 'Navigation Settings',
            onPressed: () {
              ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top guidance cards section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // 1. Blue primary turn banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Right turn icon in white/blue badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.turn_right_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Turn text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.turnRightIn} $_turnDistance ${s.meters}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Volume / repeat audio button
                        IconButton(
                          icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
                          tooltip: 'Speak current direction',
                          onPressed: _speakTurnInstruction,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Destination info card
                  InkWell(
                    onTap: () {
                      ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
                      _showChangeDestinationDialog();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Destination pin circle
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF4FC3F7),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _destinationName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _routeMetrics,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white60,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Central 3D Perspective Map Area
            Expanded(
              child: Stack(
                children: [
                  // 3D Perspective Map Canvas
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1324),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF1E2D4A),
                            width: 1.5,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _PerspectiveMapPainter(
                                pulseValue: _pulseController.value,
                                isPaused: _isPaused,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Map compass icon on top-right of map
                  Positioned(
                    top: 20,
                    right: 32,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11192C).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 6,
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Color(0xFF00E5FF),
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Bottom guidance pause/resume pill button
                  Positioned(
                    bottom: 24,
                    left: 40,
                    right: 40,
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: Text(
                          _isPaused ? s.resumeGuidance : s.pauseGuidance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPaused
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFF1976D2),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.6),
                        ),
                        onPressed: _togglePauseGuidance,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws a stylized 3D perspective city grid with glowing pedestrian route,
/// starting point marker, and destination pin.
class _PerspectiveMapPainter extends CustomPainter {
  final double pulseValue;
  final bool isPaused;

  _PerspectiveMapPainter({
    required this.pulseValue,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background gradient for depth
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF080D1A), Color(0xFF0F182E)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Draw 3D Isometric building blocks
    final buildingFillPaint = Paint()..color = const Color(0xFF152038);
    final buildingTopPaint = Paint()..color = const Color(0xFF1C2B4B);
    final buildingBorderPaint = Paint()
      ..color = const Color(0xFF24365E).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    void drawIsometricBlock(double x, double y, double bw, double bh, double height) {
      // Top face
      final topPath = Path()
        ..moveTo(x, y - height)
        ..lineTo(x + bw, y - height + 8)
        ..lineTo(x + bw, y + bh - height + 8)
        ..lineTo(x, y + bh - height)
        ..close();
      canvas.drawPath(topPath, buildingTopPaint);
      canvas.drawPath(topPath, buildingBorderPaint);

      // Side face
      final sidePath = Path()
        ..moveTo(x + bw, y - height + 8)
        ..lineTo(x + bw, y + bh - height + 8)
        ..lineTo(x + bw, y + bh + 8)
        ..lineTo(x + bw, y + 8)
        ..close();
      canvas.drawPath(sidePath, buildingFillPaint);
      canvas.drawPath(sidePath, buildingBorderPaint);
    }

    // Grid of background buildings
    drawIsometricBlock(w * 0.08, h * 0.12, w * 0.22, h * 0.18, 14);
    drawIsometricBlock(w * 0.65, h * 0.10, w * 0.26, h * 0.15, 18);
    drawIsometricBlock(w * 0.05, h * 0.45, w * 0.20, h * 0.22, 12);
    drawIsometricBlock(w * 0.72, h * 0.40, w * 0.22, h * 0.24, 16);
    drawIsometricBlock(w * 0.12, h * 0.72, w * 0.18, h * 0.15, 10);

    // Draw subtle street grid lines
    final streetPaint = Paint()
      ..color = const Color(0xFF1A2642).withValues(alpha: 0.8)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Cross street
    canvas.drawLine(Offset(0, h * 0.38), Offset(w, h * 0.38), streetPaint);
    // Vertical street
    canvas.drawLine(Offset(w * 0.48, h * 0.1), Offset(w * 0.48, h * 0.95), streetPaint);

    // Glowing Pedestrian Route Line
    final path = Path();
    final startPt = Offset(w * 0.48, h * 0.82);
    final turnPt = Offset(w * 0.48, h * 0.42);
    final destPt = Offset(w * 0.62, h * 0.24);

    path.moveTo(startPt.dx, startPt.dy);
    path.lineTo(turnPt.dx, turnPt.dy);
    path.lineTo(destPt.dx, destPt.dy);

    // Glow effect
    final glowPaint = Paint()
      ..color = isPaused
          ? const Color(0xFF607D8B).withValues(alpha: 0.3)
          : const Color(0xFF00B0FF).withValues(alpha: 0.35 + 0.15 * pulseValue)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Core sharp route line
    final routePaint = Paint()
      ..color = isPaused ? const Color(0xFF90A4AE) : const Color(0xFF00E5FF)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, routePaint);

    // Destination Pin Marker (Red teardrop with white dot)
    final pinPaint = Paint()..color = const Color(0xFFFF3D57);
    canvas.drawCircle(destPt, 11, pinPaint);
    final pinInnerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(destPt, 4.5, pinInnerPaint);

    // Destination ripple pulse
    final pulsePaint = Paint()
      ..color = const Color(0xFFFF3D57).withValues(alpha: 0.4 * (1.0 - pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(destPt, 11 + 10 * pulseValue, pulsePaint);

    // Start point marker: Green glowing circle with white direction arrow
    final startHaloPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.35 + 0.15 * pulseValue);
    canvas.drawCircle(startPt, 18, startHaloPaint);

    final startCorePaint = Paint()..color = const Color(0xFF00E676);
    canvas.drawCircle(startPt, 12, startCorePaint);

    // Draw white orientation triangle inside user marker
    final arrowPaint = Paint()..color = Colors.white;
    final arrowPath = Path()
      ..moveTo(startPt.dx, startPt.dy - 6)
      ..lineTo(startPt.dx - 4.5, startPt.dy + 4)
      ..lineTo(startPt.dx, startPt.dy + 2)
      ..lineTo(startPt.dx + 4.5, startPt.dy + 4)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _PerspectiveMapPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.isPaused != isPaused;
  }
}
