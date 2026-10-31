import 'dart:convert';
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

/// Top-level worker for compute() isolate to perform image compression off the UI isolate
Uint8List _compressImageWorker(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'] as Uint8List;
  final int maxDim = (params['maxDimension'] as int?) ?? 640;
  final int quality = (params['quality'] as int?) ?? 75;
  return GeminiVisionService.compressImageSync(bytes, maxDimension: maxDim, quality: quality);
}

class GeminiVisionService {
  final Dio _dio;
  final PreferencesService preferencesService;

  /// Request cache to avoid redundant API calls for identical images
  final Map<String, String> _requestCache = {};

  /// Real, active Gemini model IDs supported for this project.
  /// Order matters — ultra-fast multimodal first for instant responsiveness.
  static const List<String> supportedModels = [
    'gemini-2.5-flash-lite',   // Ultra-fast, lowest latency multimodal model (<350ms TTFT)
    'gemini-2.5-flash',        // High-throughput, fast reasoning multimodal model
    'gemini-3.5-flash-lite',   // Next-gen ultra-high throughput
    'gemini-2.0-flash',        // Google's 2.0 multimodal fallback
    'gemini-2.0-flash-lite',   // Lightweight fallback
    'gemini-1.5-flash',        // Stable high-throughput fallback
    'gemini-flash-latest',     // Auto-updated flash alias
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
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 8),
                headers: {
                  'Content-Type': 'application/json',
                },
              ),
            );

  String get _apiKey => preferencesService.geminiApiKey;

  /// Synchronous compression helper with aspect ratio preservation and fast linear interpolation.
  /// If the image is already lightweight, re-encoding is skipped for zero latency overhead.
  static Uint8List compressImageSync(Uint8List imageBytes, {int maxDimension = 640, int quality = 75}) {
    if (imageBytes.length <= 90 * 1024) {
      return imageBytes;
    }

    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    if (image.width > maxDimension || image.height > maxDimension) {
      int targetWidth;
      int targetHeight;
      if (image.width >= image.height) {
        targetWidth = maxDimension;
        targetHeight = (image.height * maxDimension / image.width).round();
      } else {
        targetHeight = maxDimension;
        targetWidth = (image.width * maxDimension / image.height).round();
      }
      final resized = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }


  /// Generate a cache key from image bytes and prompt
  String _cacheKey(Uint8List imageBytes, String prompt) {
    final hash = _simpleHash(imageBytes);
    return '$hash:${prompt.hashCode}';
  }

  /// High-speed sampled hash for cache key generation
  int _simpleHash(Uint8List bytes) {
    int hash = 0;
    final step = (bytes.length / 128).clamp(1, 64).toInt();
    for (int i = 0; i < bytes.length; i += step) {
      hash = ((hash << 5) - hash) + bytes[i];
      hash = hash & 0x7FFFFFFF;
    }
    return hash;
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
    // Ultra-fast background compression using isolate (compute) to keep UI thread at 60/120fps
    Uint8List? compressedImage;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final inputBytes = Uint8List.fromList(imageBytes);
      if (inputBytes.length <= 90 * 1024) {
        compressedImage = inputBytes;
      } else {
        try {
          compressedImage = await compute(_compressImageWorker, {
            'bytes': inputBytes,
            'maxDimension': 640,
            'quality': 75,
          });
        } catch (_) {
          compressedImage = compressImageSync(inputBytes, maxDimension: 640, quality: 75);
        }
      }
      debugPrint('[GeminiVisionService] Optimized image from ${imageBytes.length} to ${compressedImage?.length} bytes');
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
          await Future.delayed(const Duration(milliseconds: 250));
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

    final url = '$_baseUrl/$model:generateContent';

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
        'maxOutputTokens': maxTokens ?? 200, // Compact for fast inference
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
      final url = '$_baseUrl/gemini-2.5-flash-lite:generateContent';
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
