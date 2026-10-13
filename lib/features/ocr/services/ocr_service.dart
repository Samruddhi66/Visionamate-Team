import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/gemini_service.dart';

class OcrTextResult {
  final String fullText;
  final List<String> textLines;
  final double confidence;
  final bool isLegible;
  final String? adviceMessage;

  const OcrTextResult({
    required this.fullText,
    required this.textLines,
    required this.confidence,
    required this.isLegible,
    this.adviceMessage,
  });
}

abstract class OcrService {
  Future<OcrTextResult> recognizeText(XFile imageFile);
}

class DefaultOcrService implements OcrService {
  final GeminiVisionService? geminiService;

  DefaultOcrService({this.geminiService});

  @override
  Future<OcrTextResult> recognizeText(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      if (bytes.isEmpty) {
        return const OcrTextResult(
          fullText: '',
          textLines: [],
          confidence: 0.0,
          isLegible: false,
          adviceMessage: 'No image data captured. Please hold phone steady and try again.',
        );
      }

      if (geminiService != null) {
        const prompt = 'You are an accurate OCR text reader for a visually impaired user. '
            'Examine this camera image and transcribe all visible text, street signs, document content, '
            'ingredient labels, notices, or instructions accurately.\n'
            '- Format each distinct sentence or sign on its own line.\n'
            '- Preserve punctuation, capitalization, and numbers.\n'
            '- If there is NO visible or legible text, or if the frame is completely blurry/dark/blank, start your response with "NO_TEXT_FOUND:" followed by brief guidance for the user.\n'
            '- Do NOT output conversational chit-chat, disclaimers, or code blocks; just output the transcribed text.';

        final response = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          mimeType: 'image/jpeg',
        );

        final trimmed = response.trim();

        if (trimmed.startsWith('NO_TEXT_FOUND:')) {
          final advice = trimmed.replaceFirst('NO_TEXT_FOUND:', '').trim();
          return OcrTextResult(
            fullText: '',
            textLines: const [],
            confidence: 0.2,
            isLegible: false,
            adviceMessage: advice.isNotEmpty ? advice : 'No legible text detected. Ensure good lighting.',
          );
        }

        final lines = trimmed
            .split('\n')
            .map((l) => l.trim().replaceAll(RegExp(r'^[*\-#•]+\s*'), ''))
            .where((l) => l.isNotEmpty)
            .toList();

        final fullText = lines.join('. ');

        return OcrTextResult(
          fullText: fullText.isNotEmpty ? fullText : trimmed,
          textLines: lines,
          confidence: 0.95,
          isLegible: true,
        );
      }

      return const OcrTextResult(
        fullText: 'AI service unconfigured.',
        textLines: ['AI service unconfigured.'],
        confidence: 0.0,
        isLegible: false,
        adviceMessage: 'Please configure Gemini API key in Settings.',
      );
    } catch (e) {
      debugPrint('[OcrService] Real-time OCR error: $e');
      return OcrTextResult(
        fullText: '',
        textLines: const [],
        confidence: 0.0,
        isLegible: false,
        adviceMessage: 'Text recognition encountered an issue: $e. Please verify connection and retry.',
      );
    }
  }
}
