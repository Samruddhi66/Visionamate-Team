import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

web.HTMLAudioElement? _activeAudio;

void playAudioFromDataUri(String dataUri, {VoidCallback? onComplete}) {
  try {
    stopAudioPlayback();
    final audio = web.HTMLAudioElement();
    _activeAudio = audio;
    audio.src = dataUri;

    if (onComplete != null) {
      audio.onended = ((web.Event event) {
        onComplete();
      }).toJS;
    }

    audio.play();
  } catch (e) {
    debugPrint('[AudioPlayerWeb] Play error: $e');
    onComplete?.call();
  }
}

void stopAudioPlayback() {
  try {
    if (_activeAudio != null) {
      _activeAudio!.pause();
      _activeAudio!.currentTime = 0;
      _activeAudio = null;
    }
  } catch (e) {
    debugPrint('[AudioPlayerWeb] Stop error: $e');
  }
}
