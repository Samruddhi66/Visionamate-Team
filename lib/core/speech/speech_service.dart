import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

enum SpeechState {
  notInitialized,
  ready,
  listening,
  processing,
  error,
}

class SpeechRecognitionData {
  final String recognizedWords;
  final double confidence;
  final bool isFinal;

  const SpeechRecognitionData({
    required this.recognizedWords,
    required this.confidence,
    required this.isFinal,
  });
}

abstract class SpeechService {
  SpeechState get state;
  Stream<SpeechState> get stateStream;
  Stream<SpeechRecognitionData> get resultStream;
  Stream<double> get soundLevelStream;

  Future<bool> initialize();
  Future<void> startListening({
    required Function(SpeechRecognitionData data) onResult,
    String? localeId,
  });
  Future<void> stopListening();
  Future<void> cancelListening();
  Future<void> dispose();
}

class SttSpeechService implements SpeechService {
  final stt.SpeechToText _speech;
  final StreamController<SpeechState> _stateController = StreamController<SpeechState>.broadcast();
  final StreamController<SpeechRecognitionData> _resultController = StreamController<SpeechRecognitionData>.broadcast();
  final StreamController<double> _soundLevelController = StreamController<double>.broadcast();

  SpeechState _state = SpeechState.notInitialized;
  bool _isAvailable = false;

  SttSpeechService({stt.SpeechToText? speech}) : _speech = speech ?? stt.SpeechToText();

  @override
  SpeechState get state => _state;

  @override
  Stream<SpeechState> get stateStream => _stateController.stream;

  @override
  Stream<SpeechRecognitionData> get resultStream => _resultController.stream;

  @override
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  void _setState(SpeechState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @override
  Future<bool> initialize() async {
    if (_state != SpeechState.notInitialized && _isAvailable) {
      return true;
    }

    try {
      _isAvailable = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('[SpeechToText] Error: ${error.errorMsg} - permanent: ${error.permanent}');
          _setState(SpeechState.error);
        },
        onStatus: (String status) {
          debugPrint('[SpeechToText] Status: $status');
          switch (status) {
            case 'listening':
              _setState(SpeechState.listening);
              break;
            case 'notListening':
              if (_state == SpeechState.listening) {
                _setState(SpeechState.processing);
              }
              break;
            case 'done':
              _setState(SpeechState.ready);
              break;
          }
        },
      );

      if (_isAvailable) {
        _setState(SpeechState.ready);
      } else {
        _setState(SpeechState.error);
      }
      return _isAvailable;
    } catch (e) {
      debugPrint('[SpeechToText] Exception during init: $e');
      _setState(SpeechState.error);
      return false;
    }
  }

  @override
  Future<void> startListening({
    required Function(SpeechRecognitionData data) onResult,
    String? localeId,
  }) async {
    final ready = await initialize();
    if (!ready) {
      _setState(SpeechState.error);
      return;
    }

    try {
      _setState(SpeechState.listening);
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final data = SpeechRecognitionData(
            recognizedWords: result.recognizedWords,
            confidence: result.confidence > 0 ? result.confidence : 0.85,
            isFinal: result.finalResult,
          );
          _resultController.add(data);
          onResult(data);

          if (result.finalResult) {
            _setState(SpeechState.ready);
          }
        },
        onSoundLevelChange: (level) {
          _soundLevelController.add(level);
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          cancelOnError: true,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('[SpeechToText] Listen error: $e');
      _setState(SpeechState.error);
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _setState(SpeechState.ready);
    } catch (e) {
      debugPrint('[SpeechToText] Stop error: $e');
    }
  }

  @override
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
      _setState(SpeechState.ready);
    } catch (e) {
      debugPrint('[SpeechToText] Cancel error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await cancelListening();
    await _stateController.close();
    await _resultController.close();
    await _soundLevelController.close();
  }
}

/// Mock Speech Service for deterministic automated testing
class MockSpeechService implements SpeechService {
  final StreamController<SpeechState> _stateController = StreamController<SpeechState>.broadcast();
  final StreamController<SpeechRecognitionData> _resultController = StreamController<SpeechRecognitionData>.broadcast();
  final StreamController<double> _soundLevelController = StreamController<double>.broadcast();

  SpeechState _state = SpeechState.ready;
  Function(SpeechRecognitionData)? _currentCallback;

  @override
  SpeechState get state => _state;

  @override
  Stream<SpeechState> get stateStream => _stateController.stream;

  @override
  Stream<SpeechRecognitionData> get resultStream => _resultController.stream;

  @override
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> startListening({
    required Function(SpeechRecognitionData data) onResult,
    String? localeId,
  }) async {
    _state = SpeechState.listening;
    _stateController.add(_state);
    _currentCallback = onResult;
  }

  void simulateSpeech(String phrase, {double confidence = 0.95, bool isFinal = true}) {
    final data = SpeechRecognitionData(
      recognizedWords: phrase,
      confidence: confidence,
      isFinal: isFinal,
    );
    _resultController.add(data);
    _currentCallback?.call(data);

    if (isFinal) {
      _state = SpeechState.ready;
      _stateController.add(_state);
    }
  }

  @override
  Future<void> stopListening() async {
    _state = SpeechState.ready;
    _stateController.add(_state);
  }

  @override
  Future<void> cancelListening() async {
    _state = SpeechState.ready;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _resultController.close();
    await _soundLevelController.close();
  }
}
