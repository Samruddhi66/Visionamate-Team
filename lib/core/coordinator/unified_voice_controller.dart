import 'dart:async';
import 'package:flutter/foundation.dart';
import '../audio/tts_service.dart';
import '../speech/speech_service.dart';
import '../speech/voice_command_router.dart';
import '../haptics/haptic_patterns.dart';
import '../haptics/haptic_service.dart';

enum VoiceSessionState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

class VoiceSessionSnapshot {
  final VoiceSessionState state;
  final String activeTranscript;
  final double confidence;
  final ParsedVoiceCommand? lastCommand;
  final String? errorMessage;

  const VoiceSessionSnapshot({
    required this.state,
    this.activeTranscript = '',
    this.confidence = 0.0,
    this.lastCommand,
    this.errorMessage,
  });

  VoiceSessionSnapshot copyWith({
    VoiceSessionState? state,
    String? activeTranscript,
    double? confidence,
    ParsedVoiceCommand? lastCommand,
    String? errorMessage,
  }) {
    return VoiceSessionSnapshot(
      state: state ?? this.state,
      activeTranscript: activeTranscript ?? this.activeTranscript,
      confidence: confidence ?? this.confidence,
      lastCommand: lastCommand ?? this.lastCommand,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Centralized coordinator for voice input, audio output, haptic feedback, and accessibility announcements.
class UnifiedVoiceController extends ChangeNotifier {
  final TtsService ttsService;
  final SpeechService speechService;
  final HapticService hapticService;

  VoiceSessionSnapshot _snapshot = const VoiceSessionSnapshot(state: VoiceSessionState.idle);
  VoiceSessionSnapshot get snapshot => _snapshot;

  final StreamController<VoiceSessionSnapshot> _snapshotController =
      StreamController<VoiceSessionSnapshot>.broadcast();
  Stream<VoiceSessionSnapshot> get snapshotStream => _snapshotController.stream;

  StreamSubscription<TtsState>? _ttsSubscription;
  StreamSubscription<SpeechState>? _speechSubscription;

  // Command dispatch listener callback
  Function(ParsedVoiceCommand command)? onCommandDispatched;

  UnifiedVoiceController({
    required this.ttsService,
    required this.speechService,
    required this.hapticService,
  }) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _ttsSubscription = ttsService.stateStream.listen((ttsState) {
      if (ttsState == TtsState.speaking && _snapshot.state == VoiceSessionState.idle) {
        _updateState(VoiceSessionState.speaking);
      } else if (ttsState == TtsState.idle && _snapshot.state == VoiceSessionState.speaking) {
        _updateState(VoiceSessionState.idle);
      }
    });

    _speechSubscription = speechService.stateStream.listen((speechState) {
      if (speechState == SpeechState.error) {
        _updateState(VoiceSessionState.error, errorMessage: 'Microphone unavailable or speech timed out.');
      }
    });
  }

  void _updateState(
    VoiceSessionState sessionState, {
    String? transcript,
    double? confidence,
    ParsedVoiceCommand? command,
    String? errorMessage,
  }) {
    _snapshot = _snapshot.copyWith(
      state: sessionState,
      activeTranscript: transcript,
      confidence: confidence,
      lastCommand: command,
      errorMessage: errorMessage,
    );
    _snapshotController.add(_snapshot);
    notifyListeners();
  }

  /// Start an accessible Tap-to-Talk session
  Future<void> startListening() async {
    // 1. Immediately silence TTS to prevent recording internal audio
    await ttsService.stop();

    // 2. Tactile cue that microphone is opening
    await hapticService.trigger(HapticPattern.listeningStarted);

    _updateState(VoiceSessionState.listening, transcript: '', confidence: 0.0);

    // 3. Begin STT capture
    await speechService.startListening(
      onResult: (data) async {
        _updateState(
          data.isFinal ? VoiceSessionState.processing : VoiceSessionState.listening,
          transcript: data.recognizedWords,
          confidence: data.confidence,
        );

        if (data.isFinal && data.recognizedWords.isNotEmpty) {
          await _processRecognizedWords(data.recognizedWords, data.confidence);
        }
      },
    );
  }

  Future<void> _processRecognizedWords(String words, double confidence) async {
    _updateState(VoiceSessionState.processing);
    await hapticService.trigger(HapticPattern.processingStarted);

    final command = VoiceCommandRouter.parse(words, confidence: confidence);

    _updateState(VoiceSessionState.idle, command: command);

    if (command.actionType == VoiceActionType.unknown) {
      await hapticService.trigger(HapticPattern.actionError);
      final spoken = command.confirmationPrompt ?? 'Command not recognized. Please try again.';
      await ttsService.speak(spoken);
    } else {
      await hapticService.trigger(HapticPattern.actionSuccess);
      onCommandDispatched?.call(command);
    }
  }

  /// Cancel listening immediately
  Future<void> cancelListening() async {
    await speechService.cancelListening();
    await hapticService.cancel();
    _updateState(VoiceSessionState.idle, transcript: '');
  }

  /// Speak accessible text safely through TTS
  Future<void> speak(String text, {bool interrupt = true}) async {
    // If currently listening, cancel STT before speaking
    if (_snapshot.state == VoiceSessionState.listening) {
      await speechService.cancelListening();
    }
    await ttsService.speak(text, interrupt: interrupt);
  }

  /// Stop any active speech
  Future<void> stopSpeaking() async {
    await ttsService.stop();
  }

  /// Repeat the last spoken prompt
  Future<void> repeatLast() async {
    await ttsService.repeatLast();
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    _speechSubscription?.cancel();
    _snapshotController.close();
    super.dispose();
  }
}
