/// Typed application exceptions for VisionMate 2.0
/// Provides structured error classification and user-friendly spoken descriptions.
sealed class VisionMateException implements Exception {
  final String message;
  final String? technicalDetails;
  final bool isRecoverable;

  const VisionMateException({
    required this.message,
    this.technicalDetails,
    this.isRecoverable = true,
  });

  @override
  String toString() => '$runtimeType: $message (${technicalDetails ?? 'No tech details'})';

  /// Human-friendly speech string for TTS accessibility announcements.
  String toSpokenMessage() => message;
}

class PermissionDeniedException extends VisionMateException {
  final String permissionName;
  const PermissionDeniedException({
    required this.permissionName,
    String? message,
    super.technicalDetails,
  }) : super(
          message: message ?? '$permissionName permission was denied. Please enable it in Settings.',
          isRecoverable: true,
        );
}

class HardwareUnavailableException extends VisionMateException {
  final String hardwareComponent;
  const HardwareUnavailableException({
    required this.hardwareComponent,
    String? message,
    super.technicalDetails,
  }) : super(
          message: message ?? '$hardwareComponent is unavailable on this device.',
          isRecoverable: false,
        );
}

class SpeechRecognitionException extends VisionMateException {
  const SpeechRecognitionException({
    required super.message,
    super.technicalDetails,
    super.isRecoverable,
  });
}

class TtsEngineException extends VisionMateException {
  const TtsEngineException({
    required super.message,
    super.technicalDetails,
    super.isRecoverable,
  });
}

class NetworkException extends VisionMateException {
  const NetworkException({
    required super.message,
    super.technicalDetails,
    super.isRecoverable,
  });
}

class ModelInferenceException extends VisionMateException {
  final String modelName;
  const ModelInferenceException({
    required this.modelName,
    required super.message,
    super.technicalDetails,
    super.isRecoverable,
  });
}
