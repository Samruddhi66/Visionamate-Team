import 'package:flutter/foundation.dart';

void playAudioFromDataUri(String dataUri, {VoidCallback? onComplete}) {
  debugPrint('[AudioPlayer] Audio playback stub called on native runtime');
  onComplete?.call();
}

void stopAudioPlayback() {
  debugPrint('[AudioPlayer] Stop audio playback stub called on native runtime');
}
