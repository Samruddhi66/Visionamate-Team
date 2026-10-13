import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyThemeMode = 'vm_theme_mode';
  static const String _keyLanguage = 'vm_language';
  static const String _keyHapticsEnabled = 'vm_haptics_enabled';
  static const String _keySpeechRate = 'vm_speech_rate';
  static const String _keyVerbosity = 'vm_verbosity';
  static const String _keyEmergencyContactName = 'vm_emergency_name';
  static const String _keyEmergencyContactPhone = 'vm_emergency_phone';
  static const String _keyOnboardingCompleted = 'vm_onboarding_done';
  static const String _keyGeminiApiKey = 'vm_gemini_api_key';
  static const String defaultGeminiApiKey = 'AQ.Ab8RN6LAE6OX187AapJ84YNh4J55dpO_vLm3RHmPYeIgF67Z4w';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String get geminiApiKey => _prefs.getString(_keyGeminiApiKey) ?? defaultGeminiApiKey;
  Future<void> setGeminiApiKey(String key) => _prefs.setString(_keyGeminiApiKey, key);

  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'dark';
  Future<void> setThemeMode(String mode) => _prefs.setString(_keyThemeMode, mode);

  String get language => _prefs.getString(_keyLanguage) ?? 'en';
  Future<void> setLanguage(String lang) => _prefs.setString(_keyLanguage, lang);

  bool get hapticsEnabled => _prefs.getBool(_keyHapticsEnabled) ?? true;
  Future<void> setHapticsEnabled(bool enabled) => _prefs.setBool(_keyHapticsEnabled, enabled);

  double get speechRate => _prefs.getDouble(_keySpeechRate) ?? 0.5;
  Future<void> setSpeechRate(double rate) => _prefs.setDouble(_keySpeechRate, rate);

  String get verbosity => _prefs.getString(_keyVerbosity) ?? 'concise';
  Future<void> setVerbosity(String verbosity) => _prefs.setString(_keyVerbosity, verbosity);

  String? get emergencyContactName => _prefs.getString(_keyEmergencyContactName);
  String? get emergencyContactPhone => _prefs.getString(_keyEmergencyContactPhone);
  Future<void> setEmergencyContact(String name, String phone) async {
    await _prefs.setString(_keyEmergencyContactName, name);
    await _prefs.setString(_keyEmergencyContactPhone, phone);
  }

  bool get isOnboardingCompleted => _prefs.getBool(_keyOnboardingCompleted) ?? false;
  Future<void> setOnboardingCompleted(bool completed) => _prefs.setBool(_keyOnboardingCompleted, completed);

  Future<void> clearAll() => _prefs.clear();
}
