import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../storage/preferences_service.dart';

class GeminiApiException implements Exception {
  final String message;
  final int? statusCode;

  const GeminiApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class GeminiVisionService {
  final Dio _dio;
  final PreferencesService preferencesService;

  /// Request cache to avoid redundant API calls for identical images
  final Map<String, String> _requestCache = {};

  /// Real, active Gemini model IDs supported for this project.
  /// Order matters — fastest and verified working first, fallback in order.
  static const List<String> supportedModels = [
    'gemini-2.0-flash',        // Google's fastest multimodal model with near-instant inference
    'gemini-2.0-flash-lite',   // Ultra-lightweight low-latency fallback
    'gemini-1.5-flash',        // High throughput fallback
    'gemini-2.5-flash',        // High intelligence & reasoning
    'gemini-flash-latest',     // Auto-updated flash
  ];

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  String _lastWorkingModel = supportedModels.first;
  String get activeModel => _lastWorkingModel;
  int _lastLatencyMs = 0;
  int get lastLatencyMs => _lastLatencyMs;

  GeminiVisionService({
    required this.preferencesService,
    Dio? dio,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                },
              ),
            );

  String get _apiKey => preferencesService.geminiApiKey;

  /// Compress image to reduce payload size and improve API response time.
  /// Targets max 512KB and max dimension 1024px for optimal speed/quality balance.
  static Uint8List _compressImage(Uint8List imageBytes, {int maxDimension = 1024, int quality = 85}) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // Resize if too large
    if (image.width > maxDimension || image.height > maxDimension) {
      final resized = img.copyResize(image, width: maxDimension, height: maxDimension);
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Generate a cache key from image bytes and prompt
  String _cacheKey(Uint8List imageBytes, String prompt) {
    final hash = _simpleHash(imageBytes);
    return '$hash:${prompt.hashCode}';
  }

  /// Simple hash for cache key generation
  int _simpleHash(Uint8List bytes) {
    int hash = 0;
    for (int i = 0; i < bytes.length; i += 4) { // Sample every 4th byte for speed
      hash = ((hash << 5) - hash) + bytes[i];
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash.abs();
  }

  /// High-level method to ask Gemini with an optional image and text prompt,
  /// automatically cascading through available multimodal models with speed benchmarking.
  Future<String> askGemini({
    required String prompt,
    List<int>? imageBytes,
    String mimeType = 'image/jpeg',
    String? systemInstruction,
    int? maxTokens,
  }) async {
    // Compress image if provided to reduce payload size and improve speed
    Uint8List? compressedImage;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      compressedImage = _compressImage(Uint8List.fromList(imageBytes));
      debugPrint('[GeminiVisionService] Compressed image from ${imageBytes.length} to ${compressedImage.length} bytes');
    }

    // Check cache for identical request
    if (compressedImage != null) {
      final cacheKey = _cacheKey(compressedImage, prompt);
      if (_requestCache.containsKey(cacheKey)) {
        debugPrint('[GeminiVisionService] Cache hit - returning cached response');
        return _requestCache[cacheKey]!;
      }
    }

    dynamic lastError;

    // Prioritize the last known working model, then try the rest
    final orderedModels = [
      _lastWorkingModel,
      ...supportedModels.where((m) => m != _lastWorkingModel),
    ];

    for (final model in orderedModels) {
      try {
        final stopwatch = Stopwatch()..start();
        final result = await _callGenerateContent(
          model: model,
          prompt: prompt,
          imageBytes: compressedImage,
          mimeType: mimeType,
          systemInstruction: systemInstruction,
          maxTokens: maxTokens,
        );
        stopwatch.stop();
        _lastWorkingModel = model;
        _lastLatencyMs = stopwatch.elapsedMilliseconds;
        debugPrint('[GeminiVisionService] Model $model responded in ${_lastLatencyMs}ms');

        // Cache successful response
        if (compressedImage != null) {
          final cacheKey = _cacheKey(compressedImage, prompt);
          _requestCache[cacheKey] = result;
          // Limit cache size
          if (_requestCache.length > 50) {
            _requestCache.remove(_requestCache.keys.first);
          }
        }

        return result;
      } on GeminiApiException catch (e) {
        lastError = e;
        // If authentication failed (401/403) do not retry
        if (e.statusCode == 401 || e.statusCode == 403) {
          debugPrint('[GeminiVisionService] Fatal auth error on $model: ${e.message}. Halting cascade.');
          rethrow;
        }
        // Rate limit — wait briefly then try next model
        if (e.statusCode == 429) {
          debugPrint('[GeminiVisionService] Rate limited on $model, trying next model...');
          await Future.delayed(const Duration(milliseconds: 300));
        }
        debugPrint('[GeminiVisionService] Model $model failed: $e. Trying next...');
      } catch (e) {
        lastError = e;
        debugPrint('[GeminiVisionService] Model $model error: $e. Trying next...');
      }
    }

    debugPrint('[GeminiVisionService] All Gemini models failed. Last error: $lastError');
    if (lastError is Exception) {
      throw lastError;
    }
    throw GeminiApiException('All Gemini vision models failed: $lastError');
  }

  /// Internal request execution
  Future<String> _callGenerateContent({
    required String model,
    required String prompt,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
    String? systemInstruction,
    int? maxTokens,
  }) async {
    final key = _apiKey.trim();
    if (key.isEmpty) {
      throw const GeminiApiException(
        'Gemini API key is not configured. Please configure your API key in Settings.',
        statusCode: 401,
      );
    }

    final url = '$_baseUrl/$model:generateContent?key=$key';

    final parts = <Map<String, dynamic>>[];
    parts.add({'text': prompt});

    if (imageBytes != null && imageBytes.isNotEmpty) {
      parts.add({
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Encode(imageBytes),
        }
      });
    }

    final payload = <String, dynamic>{
      'contents': [
        {
          'parts': parts,
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'topP': 0.8,
        'maxOutputTokens': maxTokens ?? 256, // Reduced for faster response
      },
    };

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      payload['system_instruction'] = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    Response response;
    try {
      response = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            'x-goog-api-key': key,
            'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        throw const GeminiApiException(
          'Gemini API key is invalid or unauthorized. Please verify your API key in Settings.',
          statusCode: 401,
        );
      }
      if (statusCode == 429) {
        throw GeminiApiException(
          'Gemini AI quota rate limit reached. Please wait before retrying.',
          statusCode: 429,
        );
      }
      String? serverMsg;
      if (e.response?.data is Map) {
        final dataMap = e.response!.data as Map;
        final err = dataMap['error'];
        if (err is Map) {
          serverMsg = err['message']?.toString();
        }
      }
      throw GeminiApiException(
        serverMsg ?? 'Unable to connect to AI service (Status: ${statusCode ?? 'network offline'}).',
        statusCode: statusCode,
      );
    }

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data is Map && data.containsKey('candidates')) {
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final firstCandidate = candidates[0] as Map;
          // Check finish reason for safety blocks
          final finishReason = firstCandidate['finishReason']?.toString();
          if (finishReason == 'SAFETY') {
            return 'Scene analyzed. Detailed description not available due to safety filters.';
          }
          final content = firstCandidate['content'] as Map?;
          final resParts = content?['parts'] as List?;
          if (resParts != null && resParts.isNotEmpty) {
            for (final part in resParts) {
              if (part is Map && part.containsKey('text')) {
                final text = part['text']?.toString().trim() ?? '';
                if (text.isNotEmpty) return text;
              }
            }
          }
        }
      }
      return 'No response content returned by Gemini.';
    } else {
      throw GeminiApiException(
        'Gemini API returned HTTP status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Verify API key connectivity
  Future<bool> testConnection({String? customKey}) async {
    try {
      final key = (customKey ?? _apiKey).trim();
      if (key.isEmpty) return false;

      // Test with the fastest verified active model
      final url = '$_baseUrl/gemini-2.0-flash:generateContent?key=$key';
      final payload = {
        'contents': [
          {
            'parts': [
              {'text': 'Ping. Reply with OK.'}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 10,
        }
      };
      final res = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            'x-goog-api-key': key,
            'Content-Type': 'application/json',
          },
        ),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[GeminiVisionService] Test connection failed: $e');
      return false;
    }
  }

  /// Clear the request cache
  void clearCache() {
    _requestCache.clear();
  }
}
