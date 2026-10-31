import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Provides 3D Binaural Spatial Audio for blind and visually impaired users.
/// Renders directional auditory cues (Left Ear, Center, Right Ear)
/// so users can instinctively perceive hazard locations through earphones.
class BinauralAudioService {
  final AudioPlayer _player = AudioPlayer();
  Uint8List? _warningToneBytes;
  Uint8List? _noticeToneBytes;

  BinauralAudioService() {
    _initializeTones();
  }

  void _initializeTones() {
    _warningToneBytes = _generateBeepWav(frequency: 1046, durationMs: 140, sampleRate: 22050); // C6 sharp beep
    _noticeToneBytes = _generateBeepWav(frequency: 659, durationMs: 100, sampleRate: 22050); // E5 gentle blip
  }

  /// Plays a binaural spatial auditory cue directed toward the hazard:
  /// - [balance] = -1.0 (Full Left Ear)
  /// - [balance] = 0.0 (Center / Both Ears)
  /// - [balance] = 1.0 (Full Right Ear)
  Future<void> playSpatialCue({
    required double balance,
    bool isCritical = false,
  }) async {
    try {
      final clampedBalance = balance.clamp(-1.0, 1.0);
      final bytes = isCritical ? _warningToneBytes : _noticeToneBytes;
      if (bytes == null) return;

      await _player.stop();
      await _player.setBalance(clampedBalance);
      await _player.setVolume(isCritical ? 1.0 : 0.7);
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('[BinauralAudioService] Play error: $e');
    }
  }

  /// Maps horizontal position (0.0 = full left, 1.0 = full right) to balance (-1.0 to 1.0)
  static double horizontalPositionToBalance(double x) {
    return ((x.clamp(0.0, 1.0) * 2.0) - 1.0);
  }

  /// Generates a valid standard RIFF WAV byte array in memory
  static Uint8List _generateBeepWav({
    required int frequency,
    required int durationMs,
    required int sampleRate,
  }) {
    final int numSamples = (sampleRate * durationMs / 1000).toInt();
    final int byteRate = sampleRate * 2; // 16-bit mono = 2 bytes per sample
    final int subChunk2Size = numSamples * 2;
    final int chunkSize = 36 + subChunk2Size;

    final ByteData byteData = ByteData(44 + subChunk2Size);

    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, chunkSize, Endian.little);
    byteData.setUint8(8, 0x57); // 'W'
    byteData.setUint8(9, 0x41); // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    byteData.setUint16(22, 1, Endian.little); // NumChannels (1 = Mono)
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, 2, Endian.little); // BlockAlign (NumChannels * BitsPerSample/8)
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, subChunk2Size, Endian.little);

    // PCM samples: sine wave with smooth attack/decay envelope to prevent clicking
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double envelope = sin((i / numSamples) * pi); // Hanning-style smooth envelope
      final double sample = sin(2 * pi * frequency * t) * envelope * 0.85;
      final int intSample = (sample * 32767).toInt().clamp(-32768, 32767);
      byteData.setInt16(44 + i * 2, intSample, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  void dispose() {
    _player.dispose();
  }
}
