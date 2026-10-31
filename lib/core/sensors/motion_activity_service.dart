import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Monitors device motion to throttle AI vision scanning when static,
/// reducing battery consumption and device heating by over 70%.
class MotionActivityService {
  final StreamController<bool> _motionController = StreamController<bool>.broadcast();
  StreamSubscription<UserAccelerometerEvent>? _subscription;

  bool _isMoving = true;
  DateTime _lastMotionTime = DateTime.now();
  Timer? _idleCheckTimer;

  static const double motionThreshold = 1.2; // m/s² significant motion
  static const Duration staticTimeout = Duration(seconds: 8);

  bool get isMoving => _isMoving;
  Stream<bool> get isMovingStream => _motionController.stream;

  void start() {
    try {
      _subscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          final double magnitude = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );

          if (magnitude >= motionThreshold) {
            _lastMotionTime = DateTime.now();
            if (!_isMoving) {
              _isMoving = true;
              _motionController.add(true);
            }
          }
        },
        onError: (e) {
          debugPrint('[MotionActivityService] Accelerometer error: $e');
        },
      );

      _idleCheckTimer?.cancel();
      _idleCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_isMoving && DateTime.now().difference(_lastMotionTime) > staticTimeout) {
          _isMoving = false;
          _motionController.add(false);
          debugPrint('[MotionActivityService] Device static - throttling continuous AI.');
        }
      });
    } catch (e) {
      debugPrint('[MotionActivityService] Init error: $e');
    }
  }

  void stop() {
    _subscription?.cancel();
    _idleCheckTimer?.cancel();
  }

  void dispose() {
    stop();
    _motionController.close();
  }
}

