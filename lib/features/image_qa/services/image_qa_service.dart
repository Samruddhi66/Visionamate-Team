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
    String languageCode = 'en',
  });
}

class DefaultImageQaService implements ImageQaService {
  final GeminiVisionService? geminiService;

  DefaultImageQaService({this.geminiService});

  @override
  Future<ImageQaResult> answerQuestion({
    required XFile imageFile,
    required String question,
    String languageCode = 'en',
  }) async {
    final isMr = languageCode.startsWith('mr');
    final isHi = languageCode.startsWith('hi');

    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) {
        final emptyMsg = isMr
            ? 'विश्लेषण करण्यासाठी फ्रेम घेता आली नाही. कृपया फोन स्थिर ठेवा आणि पुन्हा प्रयत्न करा.'
            : (isHi
                ? 'विश्लेषण के लिए फ्रेम नहीं मिल सकी। कृपया फोन स्थिर रखें और पुनः प्रयास करें।'
                : 'Unable to capture frame to analyze. Please hold phone steady and try again.');
        return ImageQaResult(
          answer: emptyMsg,
          confidence: 0.1,
          isLocal: false,
        );
      }

      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
        final langInstruction = isMr
            ? 'The user speaks Marathi (मराठी). You MUST formulate your answer in natural, fluent, grammatically correct Marathi (मराठी) suitable for Text-to-Speech.'
            : (isHi
                ? 'The user speaks Hindi (हिंदी). You MUST formulate your answer in natural, fluent, grammatically correct Hindi (हिंदी) suitable for Text-to-Speech.'
                : 'Answer in clear, concise English suitable for speech reading.');

        final prompt = 'You are an assistive visual Q&A companion for a blind person. '
            'Looking at this camera image, answer the user\'s spoken question accurately, directly, and concisely:\n'
            '"$question"\n'
            '- Answer in 1 to 3 clear sentences optimized for speech reading.\n'
            '- $langInstruction\n'
            '- If the answer cannot be determined from the frame, politely explain what is missing (e.g. need to tilt camera, closer view, or better lighting).';

        final response = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          maxTokens: 180,
          mimeType: 'image/jpeg',
        );

        return ImageQaResult(
          answer: response.trim(),
          confidence: 0.95,
          isLocal: false,
        );
      }

      final unconfigMsg = isMr
          ? 'जेमिनी एआय सेवा कॉन्फिगर केलेली नाही. कृपया सेटिंग्जमध्ये जाऊन एपीआय की टाका.'
          : (isHi
              ? 'जेमिनी एआई सेवा कॉन्फ़िगर नहीं है। कृपया सेटिंग्स में एपीआई की दर्ज करें।'
              : 'Gemini AI service is not configured. Please configure your API key in Settings.');
      return ImageQaResult(
        answer: unconfigMsg,
        confidence: 0.0,
        isLocal: false,
      );
    } catch (e) {
      debugPrint('[ImageQaService] Error: $e');
      final errMsg = isMr
          ? 'प्रश्नाचे उत्तर मिळवण्यात समस्या आली. कृपया सेटिंग्जमध्ये एपीआय की तपासा.'
          : (isHi ? 'उत्तर प्राप्त करने में विफल। कृपया सेटिंग्स में एपीआई की जांचें।' : 'Failed to answer visual question. Please verify your Gemini API key in Settings.');
      return ImageQaResult(
        answer: errMsg,
        confidence: 0.0,
        isLocal: false,
      );
    }
  }
}
