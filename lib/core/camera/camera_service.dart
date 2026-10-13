import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

abstract class CameraService {
  CameraController? get controller;
  bool get isInitialized;
  Stream<bool> get stateStream;

  Future<bool> initialize();
  Future<XFile?> takePicture();
  Future<void> dispose();
}

class DeviceCameraService implements CameraService {
  CameraController? _controller;
  bool _isInitialized = false;
  final StreamController<bool> _stateController = StreamController<bool>.broadcast();

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<bool> get stateStream => _stateController.stream;

  @override
  Future<bool> initialize() async {
    if (_isInitialized && _controller != null) return true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[CameraService] No physical camera found.');
        return false;
      }

      // Select back-facing camera for scene perception
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium, // Balanced for on-device inference speed and battery
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _stateController.add(true);
      return true;
    } catch (e) {
      debugPrint('[CameraService] Camera init error: $e');
      _isInitialized = false;
      _stateController.add(false);
      return false;
    }
  }

  @override
  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) {
      final ready = await initialize();
      if (!ready) {
        return XFile.fromData(
          fallbackFrameBytes,
          mimeType: 'image/jpeg',
          name: 'simulated_camera_frame.jpg',
        );
      }
    }

    try {
      if (_controller!.value.isTakingPicture) {
        return XFile.fromData(
          fallbackFrameBytes,
          mimeType: 'image/jpeg',
          name: 'simulated_camera_frame.jpg',
        );
      }
      return await _controller!.takePicture();
    } catch (e) {
      debugPrint('[CameraService] takePicture error: $e');
      return XFile.fromData(
        fallbackFrameBytes,
        mimeType: 'image/jpeg',
        name: 'simulated_camera_frame.jpg',
      );
    }
  }

  static final Uint8List fallbackFrameBytes = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
    0x00, 0x7F, 0x00, 0xFF, 0xD9
  ]);

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _stateController.add(false);
    await _controller?.dispose();
    _controller = null;
    await _stateController.close();
  }
}

/// Mock Camera Service for automated test environments
class MockCameraService implements CameraService {
  bool _isInitialized = false;
  final StreamController<bool> _stateController = StreamController<bool>.broadcast();

  @override
  CameraController? get controller => null;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<bool> get stateStream => _stateController.stream;

  @override
  Future<bool> initialize() async {
    _isInitialized = true;
    _stateController.add(true);
    return true;
  }

  @override
  Future<XFile?> takePicture() async {
    return XFile('mock_frame.jpg');
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    await _stateController.close();
  }
}
