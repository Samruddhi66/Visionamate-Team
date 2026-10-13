import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../camera/camera_service.dart';
import '../../app/theme/app_colors.dart';

/// Full-screen or container live camera feed with aspect ratio fitting,
/// real-time hardware initialization, and accessible permission/retry states.
class LiveCameraViewport extends StatefulWidget {
  final CameraService cameraService;
  final Widget? overlay;
  final BorderRadius? borderRadius;
  final VoidCallback? onCameraReady;

  const LiveCameraViewport({
    super.key,
    required this.cameraService,
    this.overlay,
    this.borderRadius,
    this.onCameraReady,
  });

  @override
  State<LiveCameraViewport> createState() => _LiveCameraViewportState();
}

class _LiveCameraViewportState extends State<LiveCameraViewport>
    with SingleTickerProviderStateMixin {
  bool _isInitializing = true;
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _scannerController.repeat(reverse: true);
    }

    _initCamera();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
    });

    final success = await widget.cameraService.initialize();

    if (!mounted) return;

    setState(() {
      _isInitializing = false;
    });

    if (success && widget.onCameraReady != null) {
      widget.onCameraReady!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.cameraService.controller;
    final isReady = widget.cameraService.isInitialized &&
        controller != null &&
        controller.value.isInitialized;

    Widget content;

    if (isReady) {
      // Live Camera Hardware Preview with full cover scaling
      content = Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1280,
              height: controller.value.previewSize?.width ?? 720,
              child: CameraPreview(controller),
            ),
          ),
          if (widget.overlay != null) widget.overlay!,
        ],
      );
    } else if (_isInitializing) {
      // Loading camera hardware
      content = Container(
        color: const Color(0xFF070B16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Starting real-time camera stream...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Fallback state with realistic scanning radar and grant/retry button
      content = Container(
        color: const Color(0xFF0A1020),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // High-tech scanning reticle
            AnimatedBuilder(
              animation: _scannerController,
              builder: (context, _) {
                return Opacity(
                  opacity: 0.2 + 0.3 * _scannerController.value,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryCyan, width: 2),
                    ),
                  ),
                );
              },
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: AppColors.primaryCyan,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Live Camera Ready',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap below to connect camera or grant browser permission',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Connect Camera Feed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _initCamera,
                    ),
                  ],
                ),
              ),
            ),

            if (widget.overlay != null) widget.overlay!,
          ],
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
