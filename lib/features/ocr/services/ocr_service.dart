import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  Future<OcrTextResult> recognizeText(
    XFile imageFile, {
    String languageCode = 'en',
  });
}

class DefaultOcrService implements OcrService {
  final GeminiVisionService? geminiService;
  final TextRecognizer _mlKitRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  DefaultOcrService({this.geminiService});

  @override
  Future<OcrTextResult> recognizeText(
    XFile imageFile, {
    String languageCode = 'en',
  }) async {
    final isMr = languageCode.startsWith('mr');
    final isHi = languageCode.startsWith('hi');

    try {
      final bytes = await imageFile.readAsBytes();

      if (bytes.isEmpty) {
        final emptyMsg = isMr
            ? 'कोणताही फोटो डेटा कॅप्चर झाला नाही. कृपया फोन स्थिर ठेवा आणि पुन्हा प्रयत्न करा.'
            : (isHi
                ? 'कोई इमेज डेटा कैप्चर नहीं हुआ। कृपया फोन स्थिर रखें और पुनः प्रयास करें।'
                : 'No image data captured. Please hold phone steady and try again.');
        return OcrTextResult(
          fullText: '',
          textLines: [],
          confidence: 0.0,
          isLegible: false,
          adviceMessage: emptyMsg,
        );
      }

      // 1. FAST ON-DEVICE OFFLINE RECOGNITION VIA GOOGLE ML KIT (<50ms)
      String mlKitText = '';
      List<String> mlKitLines = [];
      try {
        final inputImage = InputImage.fromFilePath(imageFile.path);
        final recognized = await _mlKitRecognizer.processImage(inputImage);
        mlKitText = recognized.text.trim();
        mlKitLines = recognized.blocks
            .expand((b) => b.lines)
            .map((l) => l.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('[OcrService] ML Kit on-device processing notice: $e');
      }

      // 2. If Gemini is available and configured, enhance with rich context & translation
      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
        try {
          final langGuidance = isMr
              ? 'If NO legible text is found, return "NO_TEXT_FOUND: " followed by user guidance in natural Marathi (मराठी) for TTS.'
              : (isHi
                  ? 'If NO legible text is found, return "NO_TEXT_FOUND: " followed by user guidance in natural Hindi (हिंदी) for TTS.'
                  : 'If NO visible or legible text is found, start with "NO_TEXT_FOUND: " followed by user guidance in English.');

          final prompt = 'You are an accurate OCR text reader for a visually impaired user. '
              'Examine this camera image and transcribe all visible text, street signs, document content, '
              'ingredient labels, notices, or instructions accurately (supporting Marathi, Hindi, English, and regional Indian text).\n'
              '- Format each distinct sentence or sign on its own line.\n'
              '- Preserve punctuation, capitalization, and numbers.\n'
              '- $langGuidance\n'
              '- Do NOT output conversational chit-chat, disclaimers, or code blocks; just output the transcribed text.';

          final response = await geminiService!.askGemini(
            prompt: prompt,
            imageBytes: bytes,
            maxTokens: 250,
            mimeType: 'image/jpeg',
          );

          final trimmed = response.trim();

          if (!trimmed.startsWith('NO_TEXT_FOUND:')) {
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
        } catch (e) {
          debugPrint('[OcrService] Cloud Gemini OCR failed, relying on on-device ML Kit: $e');
        }
      }

      // 3. 100% OFFLINE FALLBACK VIA ON-DEVICE ML KIT
      if (mlKitText.isNotEmpty) {
        return OcrTextResult(
          fullText: mlKitText,
          textLines: mlKitLines.isNotEmpty ? mlKitLines : [mlKitText],
          confidence: 0.90,
          isLegible: true,
        );
      }

      final defaultNoText = isMr
          ? 'कोणताही स्पष्ट मजकूर आढळला नाही. कागदावर चांगला प्रकाश असल्याची खात्री करा.'
          : (isHi
              ? 'कोई स्पष्ट टेक्स्ट नहीं मिला। दस्तावेज़ पर अच्छी रोशनी सुनिश्चित करें।'
              : 'No legible text detected. Ensure good lighting on the document.');
      return OcrTextResult(
        fullText: '',
        textLines: const [],
        confidence: 0.2,
        isLegible: false,
        adviceMessage: defaultNoText,
      );
    } catch (e) {
      debugPrint('[OcrService] OCR error: $e');
      final errAdvice = isMr
          ? 'मजकूर ओळखण्यात अडचण आली. कृपया कागद कॅमेऱ्यासमोर स्थिर ठेवा आणि पुन्हा प्रयत्न करा.'
          : 'Text recognition could not read the frame. Please hold text steady under good lighting.';
      return OcrTextResult(
        fullText: '',
        textLines: const [],
        confidence: 0.0,
        isLegible: false,
        adviceMessage: errAdvice,
      );
    }
  }

  void dispose() {
    _mlKitRecognizer.close();
  }
}
