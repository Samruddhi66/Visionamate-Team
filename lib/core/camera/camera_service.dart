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
      if (!ready || _controller == null) {
        return null;
      }
    }

    try {
      if (_controller!.value.isTakingPicture) {
        return null;
      }
      return await _controller!.takePicture();
    } catch (e) {
      debugPrint('[CameraService] takePicture error: $e');
      return null;
    }
  }

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
