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

  Future<void> initialize();
  Future<void> speak(String text, {bool interrupt = true});
  Future<void> pause();
  Future<void> stop();
  Future<void> repeatLast();
  Future<void> setLanguage(String languageCode);
  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> dispose();
}

class FlutterTtsService implements TtsService {
  final FlutterTts _flutterTts;
  final StreamController<TtsState> _stateController = StreamController<TtsState>.broadcast();

  TtsState _state = TtsState.idle;
  String? _lastSpokenText;
  bool _isInitialized = false;

  FlutterTtsService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts();

  @override
  TtsState get state => _state;

  @override
  Stream<TtsState> get stateStream => _stateController.stream;

  @override
  String? get lastSpokenText => _lastSpokenText;

  void _setState(TtsState newState) {
    _state = newState;
    _stateController.add(newState);
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
        debugPrint('[TTS] Engine error: $msg');
        _setState(TtsState.error);
      });

      // Default accessibility speech properties
      await _flutterTts.setSpeechRate(0.5); // Calm, accessible pacing
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setLanguage('en-US');

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

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TTS] Init error: $e');
    }
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (text.trim().isEmpty) return;
    await initialize();

    try {
      if (interrupt && _state == TtsState.speaking) {
        await _flutterTts.stop();
      }

      _lastSpokenText = text;
      _setState(TtsState.speaking);
      final result = await _flutterTts.speak(text);
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
      // Map short codes (e.g., 'en', 'hi', 'mr') to BCP-47 locale tags
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
      await _flutterTts.setLanguage(locale);
    } catch (e) {
      debugPrint('[TTS] setLanguage error: $e');
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await initialize();
    try {
      // FlutterTts takes 0.0 to 1.0 (clamped safely)
      final clamped = rate.clamp(0.1, 1.0);
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
      await _flutterTts.setPitch(clamped);
    } catch (e) {
      debugPrint('[TTS] setPitch error: $e');
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
  final List<String> spokenHistory = [];

  @override
  TtsState get state => _state;

  @override
  Stream<TtsState> get stateStream => _controller.stream;

  @override
  String? get lastSpokenText => _lastSpokenText;

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
  Future<void> dispose() async {
    await _controller.close();
  }
}
