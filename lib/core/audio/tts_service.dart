import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState {
  idle,
  speaking,
  paused,
  stopped,
  error,
}

abstract class TtsService {
  TtsState get state;
  Stream<TtsState> get stateStream;
  String? get lastSpokenText;
  String? get currentVoiceName;
  String get activePersona;

  Future<void> initialize();
  Future<void> speak(String text, {bool interrupt = true});
  Future<void> pause();
  Future<void> stop();
  Future<void> repeatLast();
  Future<void> setLanguage(String languageCode);
  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVoicePersona(String persona);
  Future<List<Map<String, String>>> getAvailableVoices();
  Future<void> setVoiceByName(String voiceName);
  Future<void> dispose();
}

class FlutterTtsService implements TtsService {
  final FlutterTts _flutterTts;
  final StreamController<TtsState> _stateController = StreamController<TtsState>.broadcast();

  TtsState _state = TtsState.idle;
  String? _lastSpokenText;
  String? _currentVoiceName;
  String _currentPersona = 'warm_female';
  String _currentLocale = 'en-US';
  double _currentPitch = 1.04;
  double _currentSpeechRate = 0.55; // Increased for faster, more natural speech
  bool _isInitialized = false;
  
  /// Cache for synthesized audio to avoid redundant API calls
  final Map<String, String> _audioCache = {};

  FlutterTtsService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts();

  @override
  TtsState get state => _state;

  @override
  Stream<TtsState> get stateStream => _stateController.stream;

  @override
  String? get lastSpokenText => _lastSpokenText;

  @override
  String? get currentVoiceName => _currentVoiceName;

  @override
  String get activePersona => _currentPersona;

  void _setState(TtsState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Transforms text to eliminate robotic artifacts and produce smooth, natural spoken prosody.
  static String prepareNaturalSpeech(String raw) {
    if (raw.trim().isEmpty) return '';

    String text = raw;

    // 1. Remove markdown formatting characters
    text = text.replaceAll(RegExp(r'[*_`#~]'), '');

    // 2. Strip decorative emojis that trip up synthesizers
    text = text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}]',
        unicode: true,
      ),
      '',
    );

    // 3. Natural currency conversion: ₹500 -> 500 rupees, ₹ -> rupees
    text = text.replaceAllMapped(RegExp(r'₹\s*(\d+)'), (m) => '${m[1]} rupees');
    text = text.replaceAll('₹', 'rupees');

    // 4. Natural distance conversion: 50m / 50 m -> 50 meters
    text = text.replaceAllMapped(RegExp(r'(\d+)\s*m\b'), (m) => '${m[1]} meters');

    // 5. Expand acronyms to phonetic letters
    text = text.replaceAllMapped(RegExp(r'\bSOS\b', caseSensitive: true), (_) => 'S.O.S');
    text = text.replaceAllMapped(RegExp(r'\bOCR\b', caseSensitive: true), (_) => 'O.C.R');
    text = text.replaceAllMapped(RegExp(r'\bAR\b', caseSensitive: true), (_) => 'A.R');
    text = text.replaceAllMapped(RegExp(r'\bAI\b', caseSensitive: true), (_) => 'A.I');

    // 6. Colons, semicolons, and bullets to gentle conversational pauses
    text = text.replaceAll(RegExp(r'[:;•|]'), ',');

    // 7. Collapse multiple commas or extra whitespace
    text = text.replaceAll(RegExp(r',\s*,'), ',');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts.setStartHandler(() {
        _setState(TtsState.speaking);
      });

      _flutterTts.setCompletionHandler(() {
        _setState(TtsState.idle);
      });

      _flutterTts.setCancelHandler(() {
        _setState(TtsState.stopped);
      });

      _flutterTts.setPauseHandler(() {
        _setState(TtsState.paused);
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('[TTS] Engine notice: $msg');
        _setState(TtsState.error);
      });

      // Default natural speech properties: warm inflection and conversational cadence
      await _flutterTts.setSpeechRate(_currentSpeechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(_currentPitch);
      await _flutterTts.setLanguage(_currentLocale);
      await _flutterTts.setEngine('google-tts');

      // On iOS, configure audio category to speak even when device is on silent
      if (!kIsWeb) {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      // Automatically search and assign the highest quality natural/neural voice
      await _applyBestNaturalVoice();

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TTS] Init error: $e');
    }
  }

  /// Automatically locates, ranks, and assigns the best neural/natural voice available on the device.
  Future<void> _applyBestNaturalVoice({String? targetLocale, String? persona}) async {
    try {
      var voicesData = await _flutterTts.getVoices;
      if (kIsWeb) {
        // Browser voices (Chrome/Edge/Safari) load asynchronously from Web Speech API
        for (int i = 0; i < 4; i++) {
          if (voicesData != null && voicesData is List && voicesData.isNotEmpty) break;
          await Future.delayed(Duration(milliseconds: 200 + (i * 200)));
          voicesData = await _flutterTts.getVoices;
        }
      }
      if (voicesData == null || voicesData is! List || voicesData.isEmpty) {
        return;
      }

      final locale = (targetLocale ?? _currentLocale).toLowerCase();
      final langPrefix = locale.split('-').first;

      final voices = <Map<String, String>>[];
      for (final item in voicesData) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final voiceLocale = (item['locale'] ?? item['lang'] ?? '').toString();
          if (name.isNotEmpty) {
            voices.add({'name': name, 'locale': voiceLocale});
          }
        }
      }

      if (voices.isEmpty) return;

      // Filter by language code
      var matchingVoices = voices.where((v) {
        final vLoc = v['locale']?.toLowerCase() ?? '';
        return vLoc.startsWith(langPrefix) || vLoc.contains(langPrefix);
      }).toList();

      // If Marathi is selected but no specific mr-IN voice is on device, fallback to Indian Hindi neural voices (Swara, Madhur, Aarav, Kalpana)
      if (matchingVoices.isEmpty && langPrefix == 'mr') {
        matchingVoices = voices.where((v) {
          final vLoc = v['locale']?.toLowerCase() ?? '';
          final vName = v['name']?.toLowerCase() ?? '';
          return vLoc.startsWith('hi') ||
              vLoc.contains('india') ||
              vName.contains('hindi') ||
              vName.contains('swara') ||
              vName.contains('madhur') ||
              vName.contains('aarav');
        }).toList();
      }

      final pool = matchingVoices.isNotEmpty ? matchingVoices : voices;

      final personaKey = (persona ?? _currentPersona).toLowerCase();
      final wantsFemale = personaKey.contains('female');
      final wantsMale = personaKey.contains('male');

      Map<String, String>? bestVoice;
      int highestScore = -200;

      for (final v in pool) {
        final nameLower = v['name']!.toLowerCase();
        int score = 0;

        // Neural, natural, and cloud voice indicators
        if (nameLower.contains('natural')) score += 95;
        if (nameLower.contains('neural')) score += 90;
        if (nameLower.contains('online')) score += 85;
        if (nameLower.contains('wavenet')) score += 80;
        if (nameLower.contains('google')) score += 75;
        if (nameLower.contains('premium')) score += 55;
        if (nameLower.contains('enhanced')) score += 50;
        if (nameLower.contains('siri')) score += 40;

        // Named high quality natural Indian, Marathi, and Hindi personas
        if (nameLower.contains('swara') || nameLower.contains('aarav')) {
          score += (langPrefix == 'mr') ? 130 : 90;
        }
        if (nameLower.contains('madhur') || nameLower.contains('kalpana')) {
          score += (langPrefix == 'hi') ? 130 : 90;
        }
        if (nameLower.contains('neerja') || nameLower.contains('prabhat')) {
          score += 85;
        }
        if (nameLower.contains('marathi') || nameLower.contains('मराठी')) {
          score += 150;
        }
        if (nameLower.contains('hindi') || nameLower.contains('हिन्दी')) {
          score += 120;
        }

        // Named high quality natural English personas
        if (nameLower.contains('jenny') || nameLower.contains('aria')) {
          score += wantsFemale ? 55 : 25;
        }
        if (nameLower.contains('guy') || nameLower.contains('alex')) {
          score += wantsMale ? 55 : 25;
        }

        // Gender preference weighting
        if (wantsFemale &&
            (nameLower.contains('female') ||
                nameLower.contains('woman') ||
                nameLower.contains('samantha'))) {
          score += 25;
        }
        if (wantsMale &&
            (nameLower.contains('male') ||
                nameLower.contains('man'))) {
          score += 25;
        }

        // Heavily penalize harsh mechanical desktop/legacy synthesizers
        if (nameLower.contains('desktop') ||
            nameLower.contains('david') ||
            nameLower.contains('zira') ||
            nameLower.contains('george') ||
            nameLower.contains('mark') ||
            nameLower.contains('espeak')) {
          score -= 150;
        }

        if (score > highestScore) {
          highestScore = score;
          bestVoice = v;
        }
      }

      if (bestVoice != null) {
        _currentVoiceName = bestVoice['name'];
        await _flutterTts.setVoice({
          'name': bestVoice['name']!,
          'locale': bestVoice['locale'] ?? locale,
        });
        debugPrint('[TTS] Activated natural voice: ${bestVoice['name']} (score: $highestScore)');
      }
    } catch (e) {
      debugPrint('[TTS] Could not set natural voice: $e');
    }
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    final naturalText = prepareNaturalSpeech(text);
    if (naturalText.isEmpty) return;
    await initialize();

    try {
      if (interrupt && _state == TtsState.speaking) {
        await _flutterTts.stop();
      }

      _lastSpokenText = text;
      _setState(TtsState.speaking);
      final result = await _flutterTts.speak(naturalText);
      if (result != 1) {
        debugPrint('[TTS] Speech returned code $result');
      }
    } catch (e) {
      debugPrint('[TTS] Speech error: $e');
      _setState(TtsState.error);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _setState(TtsState.paused);
    } catch (e) {
      debugPrint('[TTS] Pause error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _setState(TtsState.stopped);
    } catch (e) {
      debugPrint('[TTS] Stop error: $e');
    }
  }

  @override
  Future<void> repeatLast() async {
    if (_lastSpokenText != null && _lastSpokenText!.isNotEmpty) {
      await speak(_lastSpokenText!, interrupt: true);
    }
  }

  @override
  Future<void> setLanguage(String languageCode) async {
    await initialize();
    try {
      String locale;
      switch (languageCode.toLowerCase()) {
        case 'hi':
          locale = 'hi-IN';
          break;
        case 'mr':
          locale = 'mr-IN';
          break;
        case 'en':
        default:
          locale = 'en-US';
          break;
      }
      _currentLocale = locale;
      await _flutterTts.setLanguage(locale);
      await _applyBestNaturalVoice(targetLocale: locale);
    } catch (e) {
      debugPrint('[TTS] setLanguage error: $e');
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await initialize();
    try {
      final clamped = rate.clamp(0.1, 1.0);
      _currentSpeechRate = clamped;
      await _flutterTts.setSpeechRate(clamped);
    } catch (e) {
      debugPrint('[TTS] setSpeechRate error: $e');
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    await initialize();
    try {
      final clamped = pitch.clamp(0.5, 2.0);
      _currentPitch = clamped;
      await _flutterTts.setPitch(clamped);
    } catch (e) {
      debugPrint('[TTS] setPitch error: $e');
    }
  }

  @override
  Future<void> setVoicePersona(String persona) async {
    await initialize();
    _currentPersona = persona;

    // Apply nuanced pitch and pacing according to the selected persona
    if (persona == 'warm_female') {
      _currentPitch = 1.04; // Friendly, warm, natural feminine presence
      _currentSpeechRate = 0.55; // Faster, more natural conversational pacing
    } else if (persona == 'clear_male') {
      _currentPitch = 0.96; // Grounded, clear, natural masculine presence
      _currentSpeechRate = 0.55;
    } else {
      _currentPitch = 1.0;
      _currentSpeechRate = 0.55;
    }
    
    // Clear audio cache when persona changes to avoid stale voices
    _audioCache.clear();
    
    await _flutterTts.setPitch(_currentPitch);
    await _flutterTts.setSpeechRate(_currentSpeechRate);
    await _applyBestNaturalVoice(persona: persona);
  }
  
  /// Pre-warms the TTS engine to reduce first-speech latency
  Future<void> _prewarmTts() async {
    try {
      await _flutterTts.speak(' '); // Warm up the engine
      await _flutterTts.stop();
    } catch (e) {
      // Ignore warm-up errors
    }
  }
  
  /// Clear cached audio to free memory
  void clearAudioCache() {
    _audioCache.clear();
  }

  @override
  Future<List<Map<String, String>>> getAvailableVoices() async {
    await initialize();
    try {
      final voicesData = await _flutterTts.getVoices;
      if (voicesData is List) {
        final list = <Map<String, String>>[];
        for (final item in voicesData) {
          if (item is Map) {
            final name = item['name']?.toString() ?? '';
            final locale = (item['locale'] ?? item['lang'] ?? '').toString();
            if (name.isNotEmpty) {
              list.add({'name': name, 'locale': locale});
            }
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('[TTS] getAvailableVoices error: $e');
    }
    return [];
  }

  @override
  Future<void> setVoiceByName(String voiceName) async {
    await initialize();
    try {
      final voices = await getAvailableVoices();
      final match = voices.firstWhere(
        (v) => v['name'] == voiceName,
        orElse: () => {'name': voiceName, 'locale': _currentLocale},
      );
      _currentVoiceName = voiceName;
      await _flutterTts.setVoice(match);
    } catch (e) {
      debugPrint('[TTS] setVoiceByName error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }
}

/// Mock TTS implementation for automated tests
class MockTtsService implements TtsService {
  final StreamController<TtsState> _controller = StreamController<TtsState>.broadcast();
  TtsState _state = TtsState.idle;
  String? _lastSpokenText;
  String? _currentVoiceName = 'Natural Jenny Mock';
  String _activePersona = 'warm_female';
  final List<String> spokenHistory = [];

  @override
  TtsState get state => _state;

  @override
  Stream<TtsState> get stateStream => _controller.stream;

  @override
  String? get lastSpokenText => _lastSpokenText;

  @override
  String? get currentVoiceName => _currentVoiceName;

  @override
  String get activePersona => _activePersona;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (text.trim().isEmpty) return;
    _lastSpokenText = text;
    spokenHistory.add(text);
    _state = TtsState.speaking;
    _controller.add(_state);
    // Simulate speech completion
    _state = TtsState.idle;
    _controller.add(_state);
  }

  @override
  Future<void> pause() async {
    _state = TtsState.paused;
    _controller.add(_state);
  }

  @override
  Future<void> stop() async {
    _state = TtsState.stopped;
    _controller.add(_state);
  }

  @override
  Future<void> repeatLast() async {
    if (_lastSpokenText != null) {
      await speak(_lastSpokenText!);
    }
  }

  @override
  Future<void> setLanguage(String languageCode) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setVoicePersona(String persona) async {
    _activePersona = persona;
  }

  @override
  Future<List<Map<String, String>>> getAvailableVoices() async {
    return [
      {'name': 'Natural Jenny Mock', 'locale': 'en-US'},
      {'name': 'Natural Guy Mock', 'locale': 'en-US'},
    ];
  }

  @override
  Future<void> setVoiceByName(String voiceName) async {
    _currentVoiceName = voiceName;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
