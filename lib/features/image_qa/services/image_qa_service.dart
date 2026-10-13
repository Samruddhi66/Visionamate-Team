import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/gemini_service.dart';

class ImageQaResult {
  final String answer;
  final double confidence;
  final bool isLocal;
  final String? followupSuggestion;

  const ImageQaResult({
    required this.answer,
    required this.confidence,
    required this.isLocal,
    this.followupSuggestion,
  });
}

abstract class ImageQaService {
  Future<ImageQaResult> answerQuestion({
    required XFile imageFile,
    required String question,
  });
}

class DefaultImageQaService implements ImageQaService {
  final GeminiVisionService? geminiService;

  DefaultImageQaService({this.geminiService});

  @override
  Future<ImageQaResult> answerQuestion({
    required XFile imageFile,
    required String question,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) {
        return const ImageQaResult(
          answer: 'Unable to capture frame to analyze. Please hold phone steady and try again.',
          confidence: 0.1,
          isLocal: false,
        );
      }

      if (geminiService != null) {
        final prompt = 'You are an assistive visual Q&A companion for a blind person. '
            'Looking at this camera image, answer the user\'s spoken question accurately, directly, and concisely:\n'
            '"$question"\n'
            '- Answer in 1 to 3 clear sentences optimized for speech reading.\n'
            '- If the answer cannot be determined from the frame, politely explain what is missing (e.g. need to tilt camera, closer view, or better lighting).';

        final response = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          mimeType: 'image/jpeg',
        );

        return ImageQaResult(
          answer: response.trim(),
          confidence: 0.95,
          isLocal: false,
        );
      }

      return const ImageQaResult(
        answer: 'Gemini AI service unconfigured. Please configure API key in Settings.',
        confidence: 0.0,
        isLocal: false,
      );
    } catch (e) {
      debugPrint('[ImageQaService] Error: $e');
      return ImageQaResult(
        answer: 'Failed to answer question: $e',
        confidence: 0.0,
        isLocal: false,
      );
    }
  }
}
