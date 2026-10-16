import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web implementation using HTML5 navigator.vibrate
void triggerWebHaptic(int durationMs) {
  try {
    web.window.navigator.vibrate(durationMs.toJS);
  } catch (e) {
    debugPrint('[WebHaptic] Vibration not supported or not allowed: $e');
  }
}

void cancelWebHaptic() {
  try {
    web.window.navigator.vibrate(0.toJS);
  } catch (_) {}
}
