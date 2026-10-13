import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  static const List<String> supportedModels = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-3.1-flash-lite',
    'gemini-flash-latest',
    'gemini-3.8-flash',
  ];

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  String _lastWorkingModel = supportedModels.first;
  String get activeModel => _lastWorkingModel;

  GeminiVisionService({
    required this.preferencesService,
    Dio? dio,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 25),
                sendTimeout: const Duration(seconds: 25),
                headers: {
                  'Content-Type': 'application/json',
                },
              ),
            );

  String get _apiKey => preferencesService.geminiApiKey;

  /// High-level method to ask Gemini with an optional image and text prompt,
  /// automatically cascading through available multimodal models.
  Future<String> askGemini({
    required String prompt,
    List<int>? imageBytes,
    String mimeType = 'image/jpeg',
    String? systemInstruction,
  }) async {
    dynamic lastError;

    // Prioritize the last known working model, then try the rest
    final orderedModels = [
      _lastWorkingModel,
      ...supportedModels.where((m) => m != _lastWorkingModel),
    ];

    for (final model in orderedModels) {
      try {
        final result = await _callGenerateContent(
          model: model,
          prompt: prompt,
          imageBytes: imageBytes,
          mimeType: mimeType,
          systemInstruction: systemInstruction,
        );
        _lastWorkingModel = model;
        return result;
      } catch (e) {
        lastError = e;
        debugPrint('[GeminiVisionService] Model $model failed: $e. Trying next available model...');
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
    List<int>? imageBytes,
    String mimeType = 'image/jpeg',
    String? systemInstruction,
  }) async {
    final key = _apiKey.trim();
    if (key.isEmpty) {
      throw const GeminiApiException('Gemini API key is not configured.');
    }

    final url = '$_baseUrl/$model:generateContent?key=$key';

    final parts = <Map<String, dynamic>>[];
    parts.add({'text': prompt});

    if (imageBytes != null && imageBytes.isNotEmpty) {
      parts.add({
        'inline_data': {
          'mime_type': mimeType,
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
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 429) {
        throw const GeminiApiException(
          'Gemini AI quota rate limit reached (HTTP 429). Please wait a moment before trying again.',
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
      throw GeminiApiException('Gemini API returned HTTP status ${response.statusCode}', statusCode: response.statusCode);
    }
  }

  /// Verify API key connectivity
  Future<bool> testConnection() async {
    try {
      final res = await askGemini(prompt: 'Respond with exactly: OK');
      return res.isNotEmpty;
    } catch (e) {
      debugPrint('[GeminiVisionService] Test connection failed: $e');
      return false;
    }
  }
}
