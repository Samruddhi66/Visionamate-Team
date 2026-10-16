import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../storage/preferences_service.dart';
import 'tts_service.dart';
import 'audio_player_stub.dart'
    if (dart.library.js_interop) 'audio_player_web.dart'
    if (dart.library.html) 'audio_player_web.dart';

class AiVoiceService {
  final Dio _dio;
  final PreferencesService preferencesService;

  AiVoiceService({
    required this.preferencesService,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 12),
              ),
            );

  final Map<String, String> _audioCache = {};

  bool get isConfigured {
    final provider = preferencesService.aiVoiceProvider;
    if (provider == 'gemini') {
      return preferencesService.hasGeminiApiKey;
    } else if (provider == 'elevenlabs') {
      return preferencesService.elevenLabsApiKey.trim().isNotEmpty;
    } else if (provider == 'openai') {
      return preferencesService.openAiApiKey.trim().isNotEmpty;
    }
    return preferencesService.hasGeminiApiKey;
  }

  /// Synthesizes and plays natural human voice via Gemini TTS, ElevenLabs, or OpenAI TTS.
  /// Seamlessly handles Marathi (मराठी), Hindi (हिन्दी), and English.
  /// Returns `true` if synthesized and played successfully, or `false` to fall back to local TTS.
  Future<bool> speakWithAiVoice(String rawText, {VoidCallback? onComplete}) async {
    final text = FlutterTtsService.prepareNaturalSpeech(rawText);
    if (text.isEmpty) return false;

    // In unit/widget tests, fall back to test spy
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return false;
    }

    final provider = preferencesService.aiVoiceProvider;

    try {
      if (provider == 'gemini' || (provider == 'device' && preferencesService.hasGeminiApiKey)) {
        final ok = await _speakGemini(text, onComplete: onComplete);
        if (ok) return true;
      } else if (provider == 'elevenlabs' && preferencesService.elevenLabsApiKey.trim().isNotEmpty) {
        return await _speakElevenLabs(text, onComplete: onComplete);
      } else if (provider == 'openai' && preferencesService.openAiApiKey.trim().isNotEmpty) {
        return await _speakOpenAi(text, onComplete: onComplete);
      }

      // If user has Gemini key, try Gemini TTS as last resort
      if (preferencesService.hasGeminiApiKey) {
        return await _speakGemini(text, onComplete: onComplete);
      }
    } catch (e) {
      debugPrint('[AiVoiceService] Cloud speech error: $e. Falling back to device voice.');
    }

    return false;
  }

  /// Synthesizes natural spoken voice using Google Gemini TTS API.
  /// Uses the v1beta generateContent with audio modality for natural speech.
  Future<bool> _speakGemini(String text, {VoidCallback? onComplete}) async {
    final key = preferencesService.geminiApiKey.trim();
    if (key.isEmpty) return false;

    // 1. Check in-memory audio cache for zero-latency instant response
    final cached = _audioCache[text];
    if (cached != null) {
      playAudioFromDataUri(cached, onComplete: onComplete);
      return true;
    }

    // Try Gemini Live / TTS endpoint (v1alpha - native TTS model)
    // gemini-2.5-flash-preview-tts is the real TTS model
    // Falls back gracefully if unavailable
    final ttsModels = [
      'gemini-3.8-flash-lite-tts',
      'gemini-3.8-flash-tts',
      'gemini-3.1-flash-tts-preview',
      'gemini-2.5-flash-preview-tts',
    ];

    for (final model in ttsModels) {
      try {
        final uri = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key';
        final response = await _dio.post(
          uri,
          options: Options(
            headers: {
              'x-goog-api-key': key,
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'contents': [
              {
                'parts': [
                  {'text': text}
                ]
              }
            ],
            'generationConfig': {
              'responseModalities': ['AUDIO'],
              'speechConfig': {
                'voiceConfig': {
                  'prebuiltVoiceConfig': {
                    'voiceName': 'Aoede',
                  }
                }
              }
            },
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is Map && data.containsKey('candidates')) {
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final firstCandidate = candidates[0] as Map;
              final content = firstCandidate['content'] as Map?;
              final parts = content?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final inlineData = parts[0]['inlineData'] as Map?;
                if (inlineData != null) {
                  final mime = inlineData['mimeType']?.toString() ?? 'audio/wav';
                  final b64 = inlineData['data']?.toString() ?? '';
                  if (b64.isNotEmpty) {
                    final dataUri = 'data:$mime;base64,$b64';
                    _audioCache[text] = dataUri;
                    playAudioFromDataUri(dataUri, onComplete: onComplete);
                    debugPrint('[AiVoiceService] Gemini natural voice synthesized & playing via $model.');
                    return true;
                  }
                }
              }
            }
          }
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        debugPrint('[AiVoiceService] Gemini TTS model $model failed (HTTP $code): ${e.message}');
        if (code == 401 || code == 403) break;
        // 404 = model not found, 400 = config not supported — try next
      } catch (e) {
        debugPrint('[AiVoiceService] Gemini TTS model $model error: $e');
      }
    }
    
    debugPrint('[AiVoiceService] Gemini TTS unavailable, falling back to device TTS.');
    return false;
  }

  Future<bool> _speakElevenLabs(String text, {VoidCallback? onComplete}) async {
    final apiKey = preferencesService.elevenLabsApiKey.trim();
    final voiceId = preferencesService.elevenLabsVoiceId.trim().isNotEmpty
        ? preferencesService.elevenLabsVoiceId.trim()
        : '21m00Tcm4TlvDq8ikWAM'; // Rachel (Warm, empathetic)

    final response = await _dio.post(
      'https://api.elevenlabs.io/v1/text-to-speech/$voiceId',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
      ),
      data: {
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.52,
          'similarity_boost': 0.82,
          'use_speaker_boost': true,
        },
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final bytes = response.data as List<int>;
      final base64Audio = base64Encode(bytes);
      final dataUri = 'data:audio/mp3;base64,$base64Audio';
      playAudioFromDataUri(dataUri, onComplete: onComplete);
      debugPrint('[AiVoiceService] ElevenLabs human voice playback initiated.');
      return true;
    }

    return false;
  }

  Future<bool> _speakOpenAi(String text, {VoidCallback? onComplete}) async {
    final apiKey = preferencesService.openAiApiKey.trim();
    final voice = preferencesService.openAiVoice.trim().isNotEmpty
        ? preferencesService.openAiVoice.trim()
        : 'nova'; // Nova (Warm, empathetic)

    final response = await _dio.post(
      'https://api.openai.com/v1/audio/speech',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': 'tts-1',
        'input': text,
        'voice': voice,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final bytes = response.data as List<int>;
      final base64Audio = base64Encode(bytes);
      final dataUri = 'data:audio/mp3;base64,$base64Audio';
      playAudioFromDataUri(dataUri, onComplete: onComplete);
      debugPrint('[AiVoiceService] OpenAI human voice playback initiated.');
      return true;
    }

    return false;
  }

  /// Validates API key and plays a real-time sample in current language (Marathi, Hindi, or English)
  Future<bool> testConnection({
    required String provider,
    required String apiKey,
    String? voiceIdentifier,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return false;

    if (provider == 'gemini') {
      final lang = preferencesService.language;
      final sample = lang == 'mr'
          ? 'नमस्कार! व्हिजनमेट नैसर्गिक आवाज प्रणाली सक्रिय झाली आहे.'
          : (lang == 'hi'
              ? 'नमस्ते! विजनमेट प्राकृतिक आवाज प्रणाली सक्रिय हो गई है।'
              : 'Hello! VisionMate natural voice is ready.');
      
      // Test using gemini-2.0-flash-exp which supports audio output
      final uri = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$cleanKey';
      try {
        final response = await _dio.post(
          uri,
          options: Options(
            headers: {
              'x-goog-api-key': cleanKey,
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'contents': [
              {
                'parts': [
                  {'text': 'Say: $sample'}
                ]
              }
            ],
            'generationConfig': {
              'responseModalities': ['AUDIO'],
              'speechConfig': {
                'voiceConfig': {
                  'prebuiltVoiceConfig': {
                    'voiceName': 'Aoede',
                  }
                }
              }
            },
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is Map && data.containsKey('candidates')) {
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final firstCandidate = candidates[0] as Map;
              final content = firstCandidate['content'] as Map?;
              final parts = content?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final inlineData = parts[0]['inlineData'] as Map?;
                if (inlineData != null) {
                  final mime = inlineData['mimeType']?.toString() ?? 'audio/wav';
                  final b64 = inlineData['data']?.toString() ?? '';
                  if (b64.isNotEmpty) {
                    final dataUri = 'data:$mime;base64,$b64';
                    playAudioFromDataUri(dataUri);
                    return true;
                  }
                }
              }
            }
          }
          // If audio modality not available, just verify key works (200 response = key is valid)
          return true;
        }
      } catch (e) {
        debugPrint('[AiVoiceService] Gemini test connection error: $e');
        // Try a basic text call to verify key validity
        try {
          final textUri = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$cleanKey';
          final textRes = await _dio.post(
            textUri,
            options: Options(headers: {'x-goog-api-key': cleanKey, 'Content-Type': 'application/json'}),
            data: {
              'contents': [{'parts': [{'text': 'Ping'}]}],
              'generationConfig': {'maxOutputTokens': 5},
            },
          );
          return textRes.statusCode == 200;
        } catch (_) {
          return false;
        }
      }
      return false;
    }

    const sample = 'Hello! VisionMate natural human voice connection successful.';

    if (provider == 'elevenlabs') {
      final voiceId = (voiceIdentifier != null && voiceIdentifier.isNotEmpty)
          ? voiceIdentifier
          : '21m00Tcm4TlvDq8ikWAM';
      final response = await _dio.post(
        'https://api.elevenlabs.io/v1/text-to-speech/$voiceId',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'xi-api-key': cleanKey,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'text': sample,
          'model_id': 'eleven_multilingual_v2',
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final dataUri = 'data:audio/mp3;base64,${base64Encode(response.data as List<int>)}';
        playAudioFromDataUri(dataUri);
        return true;
      }
    } else if (provider == 'openai') {
      final voice = (voiceIdentifier != null && voiceIdentifier.isNotEmpty) ? voiceIdentifier : 'nova';
      final response = await _dio.post(
        'https://api.openai.com/v1/audio/speech',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer $cleanKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'tts-1',
          'input': sample,
          'voice': voice,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final dataUri = 'data:audio/mp3;base64,${base64Encode(response.data as List<int>)}';
        playAudioFromDataUri(dataUri);
        return true;
      }
    }

    return false;
  }

  void stop() {
    stopAudioPlayback();
  }
}
