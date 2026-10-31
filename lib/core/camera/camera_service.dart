import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Completer<bool>? _initCompleter;
  final StreamController<bool> _stateController = StreamController<bool>.broadcast();

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized =>
      _isInitialized && _controller != null && (_controller?.value.isInitialized ?? false);

  @override
  Stream<bool> get stateStream => _stateController.stream;

  @override
  Future<bool> initialize() async {
    // If already fully initialized and controller is active, return immediately
    if (_isInitialized && _controller != null && (_controller?.value.isInitialized ?? false)) {
      return true;
    }

    // If an initialization is already ongoing, join it instead of starting a concurrent request
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    final completer = Completer<bool>();
    _initCompleter = completer;

    try {
      // 1. Ensure camera runtime permission is granted on mobile
      if (!kIsWeb) {
        final permStatus = await Permission.camera.status;
        if (!permStatus.isGranted) {
          final reqResult = await Permission.camera.request();
          if (!reqResult.isGranted) {
            debugPrint('[CameraService] Camera permission not granted.');
            _isInitialized = false;
            _stateController.add(false);
            completer.complete(false);
            _initCompleter = null;
            return false;
          }
        }
      }

      // 2. Discover camera hardware
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[CameraService] No physical camera found.');
        _isInitialized = false;
        _stateController.add(false);
        completer.complete(false);
        _initCompleter = null;
        return false;
      }

      // 3. Select back-facing camera for scene perception
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Clean up previous controller if any
      final prevController = _controller;
      _controller = null;
      if (prevController != null) {
        try {
          await prevController.dispose();
        } catch (_) {}
      }

      final newController = CameraController(
        backCamera,
        ResolutionPreset.medium, // Balanced for on-device inference speed and battery
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await newController.initialize();

      _controller = newController;
      _isInitialized = true;
      _stateController.add(true);
      completer.complete(true);
      _initCompleter = null;
      return true;
    } catch (e) {
      debugPrint('[CameraService] Camera init error: $e');
      _isInitialized = false;
      _stateController.add(false);
      completer.complete(false);
      _initCompleter = null;
      return false;
    }
  }

  @override
  Future<XFile?> takePicture() async {
    // 1. If initialization is underway, wait for it to complete
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }

    // 2. If not initialized, trigger initialize and wait
    if (!isInitialized) {
      final ready = await initialize();
      if (!ready || !isInitialized) {
        debugPrint('[CameraService] Camera hardware not ready for capture.');
        return null;
      }
    }

    // 3. Verify controller state and wait briefly if camera preview is still attaching
    for (int i = 0; i < 12; i++) {
      final ctrl = _controller;
      if (ctrl != null && ctrl.value.isInitialized) {
        if (!ctrl.value.isTakingPicture) {
          break;
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      debugPrint('[CameraService] CameraController was not initialized in time.');
      return null;
    }

    try {
      if (ctrl.value.isTakingPicture) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return await ctrl.takePicture();
    } catch (e) {
      debugPrint('[CameraService] takePicture error: $e');
      // If controller had a transient session error, reset initialized flag so next call cleanly reconnects
      if (e.toString().contains('Uninitialized CameraController') ||
          e.toString().contains('CameraException')) {
        _isInitialized = false;
        _stateController.add(false);
      }
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _stateController.add(false);
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      try {
        await ctrl.dispose();
      } catch (_) {}
    }
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      _initCompleter!.complete(false);
      _initCompleter = null;
    }
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
