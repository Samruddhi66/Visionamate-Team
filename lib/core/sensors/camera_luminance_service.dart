import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Evaluates ambient brightness of captured frames to automatically
/// control the camera flashlight in low-light environments for blind users.
class CameraLuminanceService {
  static const double lowLightThreshold = 45.0; // Luminance 0-255
  static const double adequateLightThreshold = 85.0;

  bool _isTorchCurrentlyOn = false;
  bool get isTorchCurrentlyOn => _isTorchCurrentlyOn;

  /// Analyzes byte luminance and automatically turns on/off flashlight if [autoTorch] is true.
  /// Returns a spoken notice if the flashlight state changed.
  Future<String?> checkAndAdjustLighting({
    required List<int> imageBytes,
    required CameraController? cameraController,
    required bool autoTorchEnabled,
    String languageCode = 'mr',
  }) async {
    if (cameraController == null || !cameraController.value.isInitialized) {
      return null;
    }

    try {
      final double luminance = await compute(_calculateLuminance, imageBytes);
      final isMr = languageCode.startsWith('mr');
      final isHi = languageCode.startsWith('hi');

      if (autoTorchEnabled && luminance < lowLightThreshold && !_isTorchCurrentlyOn) {
        await cameraController.setFlashMode(FlashMode.torch);
        _isTorchCurrentlyOn = true;
        return isMr
            ? 'कमी प्रकाश असल्याने फ्लॅशलाइट चालू केली आहे.'
            : (isHi
                ? 'कम रोशनी के कारण फ्लैशलाइट चालू की गई है।'
                : 'Low light detected. Flashlight turned on.');
      } else if (_isTorchCurrentlyOn && luminance > adequateLightThreshold) {
        await cameraController.setFlashMode(FlashMode.off);
        _isTorchCurrentlyOn = false;
      }
    } catch (e) {
      debugPrint('[CameraLuminanceService] Luminance check error: $e');
    }
    return null;
  }

  /// Manually toggles the camera torch
  Future<bool> toggleTorch(CameraController? cameraController) async {
    if (cameraController == null || !cameraController.value.isInitialized) {
      return false;
    }
    try {
      if (_isTorchCurrentlyOn) {
        await cameraController.setFlashMode(FlashMode.off);
        _isTorchCurrentlyOn = false;
      } else {
        await cameraController.setFlashMode(FlashMode.torch);
        _isTorchCurrentlyOn = true;
      }
      return _isTorchCurrentlyOn;
    } catch (e) {
      debugPrint('[CameraLuminanceService] Toggle error: $e');
      return false;
    }
  }

  static double _calculateLuminance(List<int> bytes) {
    try {
      final image = img.decodeImage(Uint8List.fromList(bytes));
      if (image == null) return 128.0;

      // Sample a grid of pixels (downsample to 40x40 for blazing speed <5ms)
      final stepX = (image.width / 40).clamp(1, image.width).toInt();
      final stepY = (image.height / 40).clamp(1, image.height).toInt();

      double totalLuminance = 0.0;
      int count = 0;

      for (int y = 0; y < image.height; y += stepY) {
        for (int x = 0; x < image.width; x += stepX) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          totalLuminance += lum;
          count++;
        }
      }

      return count > 0 ? (totalLuminance / count) : 128.0;
    } catch (_) {
      return 128.0;
    }
  }
}

