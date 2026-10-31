import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _vaultSalt = 'VM_SecVault_2026_Key';

  static String _secureEncrypt(String plain) {
    if (plain.isEmpty) return '';
    final bytes = utf8.encode(plain);
    final salt = utf8.encode(_vaultSalt);
    final enc = List<int>.generate(bytes.length, (i) => bytes[i] ^ salt[i % salt.length]);
    return 'vm_enc_${base64Encode(enc)}';
  }

  static String _secureDecrypt(String? encoded) {
    if (encoded == null || encoded.isEmpty) return '';
    if (!encoded.startsWith('vm_enc_')) return encoded.trim(); // Backward compatible with plain keys
    try {
      final raw = base64Decode(encoded.substring(7));
      final salt = utf8.encode(_vaultSalt);
      final dec = List<int>.generate(raw.length, (i) => raw[i] ^ salt[i % salt.length]);
      return utf8.decode(dec).trim();
    } catch (_) {
      return '';
    }
  }

  static const String _keyThemeMode = 'vm_theme_mode';
  static const String _keyLanguage = 'vm_language';
  static const String _keyHapticsEnabled = 'vm_haptics_enabled';
  static const String _keySpeechRate = 'vm_speech_rate';
  static const String _keyAutoTorch = 'vm_auto_torch';
  static const String _keyShakeSos = 'vm_shake_sos';
  static const String _keySmartMotion = 'vm_smart_motion';
  static const String _keyVerbosity = 'vm_verbosity';
  static const String _keyEmergencyContactName = 'vm_emergency_name';
  static const String _keyEmergencyContactPhone = 'vm_emergency_phone';
  static const String _keyOnboardingCompleted = 'vm_onboarding_done';
  static const String _keyGeminiApiKey = 'vm_gemini_api_key';
  static const String _keyVoicePersona = 'vm_voice_persona';
  static const String _keyVoicePitch = 'vm_voice_pitch';
  static const String _keyAiVoiceProvider = 'vm_ai_voice_provider';
  static const String _keyElevenLabsApiKey = 'vm_elevenlabs_api_key';
  static const String _keyElevenLabsVoiceId = 'vm_elevenlabs_voice_id';
  static const String _keyOpenAiApiKey = 'vm_openai_api_key';
  static const String _keyOpenAiVoice = 'vm_openai_voice';
  static const String defaultGeminiApiKey = '';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String get geminiApiKey {
    final raw = _prefs.getString(_keyGeminiApiKey);
    final decrypted = _secureDecrypt(raw);
    if (decrypted.isNotEmpty) {
      if (decrypted.startsWith('Q.Ab8RN')) return 'A$decrypted';
      return decrypted;
    }
    if (defaultGeminiApiKey.trim().isNotEmpty) return defaultGeminiApiKey;
    return '';
  }

  bool get hasGeminiApiKey => geminiApiKey.trim().isNotEmpty;
  Future<void> setGeminiApiKey(String key) {
    var clean = key.trim();
    if (clean.startsWith('Q.Ab8RN')) {
      clean = 'A$clean';
    }
    return _prefs.setString(_keyGeminiApiKey, _secureEncrypt(clean));
  }

  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'dark';
  Future<void> setThemeMode(String mode) => _prefs.setString(_keyThemeMode, mode);

  String get language => _prefs.getString(_keyLanguage) ?? 'en';
  Future<void> setLanguage(String lang) => _prefs.setString(_keyLanguage, lang);

  bool get hapticsEnabled => _prefs.getBool(_keyHapticsEnabled) ?? true;
  Future<void> setHapticsEnabled(bool enabled) => _prefs.setBool(_keyHapticsEnabled, enabled);

  double get speechRate => _prefs.getDouble(_keySpeechRate) ?? 0.55;
  Future<void> setSpeechRate(double rate) => _prefs.setDouble(_keySpeechRate, rate);

  bool get autoTorchEnabled => _prefs.getBool(_keyAutoTorch) ?? true;
  Future<void> setAutoTorchEnabled(bool enabled) => _prefs.setBool(_keyAutoTorch, enabled);

  bool get shakeSosEnabled => _prefs.getBool(_keyShakeSos) ?? true;
  Future<void> setShakeSosEnabled(bool enabled) => _prefs.setBool(_keyShakeSos, enabled);

  bool get smartMotionEnabled => _prefs.getBool(_keySmartMotion) ?? true;
  Future<void> setSmartMotionEnabled(bool enabled) => _prefs.setBool(_keySmartMotion, enabled);

  String get verbosity => _prefs.getString(_keyVerbosity) ?? 'concise';
  Future<void> setVerbosity(String verbosity) => _prefs.setString(_keyVerbosity, verbosity);

  String get voicePersona => _prefs.getString(_keyVoicePersona) ?? 'warm_female';
  Future<void> setVoicePersona(String persona) => _prefs.setString(_keyVoicePersona, persona);

  double get voicePitch => _prefs.getDouble(_keyVoicePitch) ?? 1.04;
  Future<void> setVoicePitch(double pitch) => _prefs.setDouble(_keyVoicePitch, pitch);

  String get aiVoiceProvider {
    final saved = _prefs.getString(_keyAiVoiceProvider);
    if (saved != null && saved.isNotEmpty) return saved;
    return 'device';
  }
  Future<void> setAiVoiceProvider(String provider) => _prefs.setString(_keyAiVoiceProvider, provider);

  String get elevenLabsApiKey => _secureDecrypt(_prefs.getString(_keyElevenLabsApiKey));
  Future<void> setElevenLabsApiKey(String key) => _prefs.setString(_keyElevenLabsApiKey, _secureEncrypt(key));

  String get elevenLabsVoiceId => _prefs.getString(_keyElevenLabsVoiceId) ?? '21m00Tcm4TlvDq8ikWAM';
  Future<void> setElevenLabsVoiceId(String id) => _prefs.setString(_keyElevenLabsVoiceId, id);

  String get openAiApiKey => _secureDecrypt(_prefs.getString(_keyOpenAiApiKey));
  Future<void> setOpenAiApiKey(String key) => _prefs.setString(_keyOpenAiApiKey, _secureEncrypt(key));

  String get openAiVoice => _prefs.getString(_keyOpenAiVoice) ?? 'nova';
  Future<void> setOpenAiVoice(String voice) => _prefs.setString(_keyOpenAiVoice, voice);

  String? get emergencyContactName => _prefs.getString(_keyEmergencyContactName);
  String? get emergencyContactPhone { final v = _secureDecrypt(_prefs.getString(_keyEmergencyContactPhone)); return v.isEmpty ? null : v; }
  Future<void> setEmergencyContact(String name, String phone) async {
    await _prefs.setString(_keyEmergencyContactName, name);
    await _prefs.setString(_keyEmergencyContactPhone, phone);
  }

  bool get isOnboardingCompleted => _prefs.getBool(_keyOnboardingCompleted) ?? false;
  Future<void> setOnboardingCompleted(bool completed) => _prefs.setBool(_keyOnboardingCompleted, completed);

  Future<void> clearAll() => _prefs.clear();
}
