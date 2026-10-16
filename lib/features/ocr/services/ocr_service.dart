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
  Future<OcrTextResult> recognizeText(
    XFile imageFile, {
    String languageCode = 'en',
  });
}

class DefaultOcrService implements OcrService {
  final GeminiVisionService? geminiService;

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

      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
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
          maxTokens: 180,
          mimeType: 'image/jpeg',
        );

        final trimmed = response.trim();

        if (trimmed.startsWith('NO_TEXT_FOUND:')) {
          final advice = trimmed.replaceFirst('NO_TEXT_FOUND:', '').trim();
          final defaultNoText = isMr
              ? 'कोणताही स्पष्ट मजकूर आढळला नाही. चांगला प्रकाश असल्याची खात्री करा.'
              : (isHi
                  ? 'कोई स्पष्ट टेक्स्ट नहीं मिला। अच्छी रोशनी सुनिश्चित करें।'
                  : 'No legible text detected. Ensure good lighting.');
          return OcrTextResult(
            fullText: '',
            textLines: const [],
            confidence: 0.2,
            isLegible: false,
            adviceMessage: advice.isNotEmpty ? advice : defaultNoText,
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

      final unconfigAdvice = isMr
          ? 'मजकूर वाचण्यासाठी कॅमेऱ्यासमोर कागद किंवा चिन्ह स्थिर ठेवा.'
          : (isHi
              ? 'टेक्स्ट पढ़ने के लिए कैमरे के सामने दस्तावेज़ सीधा रखें।'
              : 'Hold document or sign steady in front of camera.');
      return OcrTextResult(
        fullText: unconfigAdvice,
        textLines: [unconfigAdvice],
        confidence: 0.0,
        isLegible: false,
        adviceMessage: isMr
            ? 'क्लाउड एआय वाचनासाठी कृपया सेटिंग्जमध्ये जाऊन जेमिनी की टाका.'
            : (isHi ? 'क्लाउड एआई वाचन के लिए कृपया सेटिंग्स में जेमिनी की दर्ज करें।' : 'Configure Gemini API key in Settings for cloud text transcription.'),
      );
    } catch (e) {
      debugPrint('[OcrService] Real-time OCR error: $e');
      final isMr = languageCode.startsWith('mr');
      final isHi = languageCode.startsWith('hi');
      final errAdvice = isMr
          ? 'मजकूर ओळखण्यात अडचण आली. कृपया कॅमेऱ्यासमोर मजकूर स्थिर ठेवा आणि पुन्हा प्रयत्न करा.'
          : (isHi
              ? 'टेक्स्ट पहचानने में समस्या आई। कृपया टेक्स्ट को स्थिर रखें और पुनः प्रयास करें।'
              : 'Text recognition could not read the frame. Please hold text steady under good lighting.');
      return OcrTextResult(
        fullText: '',
        textLines: const [],
        confidence: 0.0,
        isLegible: false,
        adviceMessage: errAdvice,
      );
    }
  }
}
