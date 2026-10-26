import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/audio/tts_service.dart';
import '../core/audio/ai_voice_service.dart';
import '../core/speech/speech_service.dart';
import '../core/haptics/haptic_service.dart';
import '../core/haptics/haptic_patterns.dart';
import '../core/coordinator/unified_voice_controller.dart';
import '../core/storage/preferences_service.dart';
import '../core/storage/history_repository.dart';
import '../core/storage/saved_places_repository.dart';
import '../core/camera/camera_service.dart';
import '../features/navigation/services/location_service.dart';
import '../features/navigation/services/routing_service.dart';
import '../features/safety_alerts/services/safety_alert_manager.dart';
import '../features/scene_analysis/services/scene_understanding_service.dart';
import '../features/ocr/services/ocr_service.dart';
import '../features/currency_detection/services/currency_detection_service.dart';
import '../features/object_recognition/services/object_detection_service.dart';
import '../features/image_qa/services/image_qa_service.dart';
import '../features/emergency/services/emergency_service.dart';
import '../core/network/gemini_service.dart';
import 'theme/app_theme.dart';

// SharedPreferences provider (overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// Preferences Service
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

// Repositories
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HistoryRepository(prefs);
});

final savedPlacesRepositoryProvider = Provider<SavedPlacesRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SavedPlacesRepository(prefs);
});

// Camera Service
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = DeviceCameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Location & Routing
final locationServiceProvider = Provider<LocationService>((ref) {
  return DeviceLocationService();
});

final routingServiceProvider = Provider<RoutingService>((ref) {
  return OsrmRoutingService();
});

// TTS Service
final ttsServiceProvider = Provider<TtsService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final service = FlutterTtsService();
  service.setLanguage(prefs.language);
  service.setSpeechRate(prefs.speechRate);
  service.setVoicePersona(prefs.voicePersona);
  ref.onDispose(() => service.dispose());
  return service;
});

// Speech Recognition Service
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SttSpeechService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Haptic Feedback Service
final hapticServiceProvider = Provider<HapticService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return DeviceHapticService(isEnabled: prefs.hapticsEnabled);
});

// Safety Alert Coordinator
final safetyAlertManagerProvider = Provider<SafetyAlertManager>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final haptics = ref.watch(hapticServiceProvider);
  return SafetyAlertManager(tts: tts, haptics: haptics);
});

// Gemini Vision Service
final geminiVisionServiceProvider = Provider<GeminiVisionService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return GeminiVisionService(preferencesService: prefs);
});

// Emergency Service (Real phone calls, SMS, location sharing)
final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final historyRepo = ref.watch(historyRepositoryProvider);
  final tts = ref.watch(ttsServiceProvider);
  final haptics = ref.watch(hapticServiceProvider);
  return EmergencyService(
    prefs: prefs,
    historyRepo: historyRepo,
    tts: tts,
    haptics: haptics,
  );
});

// AI & Vision Inference Services
final sceneUnderstandingServiceProvider = Provider<SceneUnderstandingService>((ref) {
  final gemini = ref.watch(geminiVisionServiceProvider);
  return DefaultSceneUnderstandingService(geminiService: gemini);
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  final gemini = ref.watch(geminiVisionServiceProvider);
  return DefaultOcrService(geminiService: gemini);
});

final currencyDetectionServiceProvider = Provider<CurrencyDetectionService>((ref) {
  final gemini = ref.watch(geminiVisionServiceProvider);
  return DefaultCurrencyDetectionService(geminiService: gemini);
});

final objectDetectionServiceProvider = Provider<ObjectDetectionService>((ref) {
  final gemini = ref.watch(geminiVisionServiceProvider);
  return DefaultObjectDetectionService(geminiService: gemini);
});

final imageQaServiceProvider = Provider<ImageQaService>((ref) {
  final gemini = ref.watch(geminiVisionServiceProvider);
  return DefaultImageQaService(geminiService: gemini);
});

// AI Voice Service (Cloud Human Voice Provider)
final aiVoiceServiceProvider = Provider<AiVoiceService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return AiVoiceService(preferencesService: prefs);
});

// Unified Voice Controller Provider
final unifiedVoiceControllerProvider = Provider<UnifiedVoiceController>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final speech = ref.watch(speechServiceProvider);
  final haptics = ref.watch(hapticServiceProvider);
  final aiVoice = ref.watch(aiVoiceServiceProvider);

  final controller = UnifiedVoiceController(
    ttsService: tts,
    speechService: speech,
    hapticService: haptics,
    aiVoiceService: aiVoice,
  );

  ref.onDispose(() => controller.dispose());
  return controller;
});

// Theme Mode State Notifier
class ThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final prefs = ref.watch(preferencesServiceProvider);
    switch (prefs.themeMode) {
      case 'highContrast':
        return AppThemeMode.highContrast;
      case 'light':
        return AppThemeMode.light;
      case 'dark':
      default:
        return AppThemeMode.dark;
    }
  }

  void setTheme(AppThemeMode mode) {
    state = mode;
    final prefs = ref.read(preferencesServiceProvider);
    String modeString;
    switch (mode) {
      case AppThemeMode.highContrast:
        modeString = 'highContrast';
        break;
      case AppThemeMode.light:
        modeString = 'light';
        break;
      case AppThemeMode.dark:
        modeString = 'dark';
        break;
    }
    prefs.setThemeMode(modeString);
  }
}

final themeModeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(() {
  return ThemeNotifier();
});

// Locale State Notifier
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return Locale(prefs.language);
  }

  Future<void> setLocale(String langCode) async {
    state = Locale(langCode);
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setLanguage(langCode);

    final tts = ref.read(ttsServiceProvider);
    await tts.setLanguage(langCode);

    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticPattern.actionSuccess);

    String message;
    switch (langCode) {
      case 'hi':
        message = 'भाषा बदलकर हिन्दी कर दी गई है। विज़नमेट तैयार है।';
        break;
      case 'mr':
        message = 'भाषा बदलून मराठी करण्यात आली आहे. व्हिजनमेट तयार आहे.';
        break;
      case 'en':
      default:
        message = 'Language switched to English. VisionMate is ready.';
        break;
    }
    await tts.speak(message, interrupt: true);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});
