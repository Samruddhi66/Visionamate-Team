import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/gemini_service.dart';

enum RupeeDenomination {
  ten,
  twenty,
  fifty,
  hundred,
  twoHundred,
  fiveHundred,
  uncertain,
}

extension RupeeDenominationDetails on RupeeDenomination {
  int get numericValue {
    switch (this) {
      case RupeeDenomination.ten:
        return 10;
      case RupeeDenomination.twenty:
        return 20;
      case RupeeDenomination.fifty:
        return 50;
      case RupeeDenomination.hundred:
        return 100;
      case RupeeDenomination.twoHundred:
        return 200;
      case RupeeDenomination.fiveHundred:
        return 500;
      case RupeeDenomination.uncertain:
        return 0;
    }
  }

  String toSpokenPhrase([String languageCode = 'en']) {
    final lang = languageCode.toLowerCase();
    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    if (isMr) {
      switch (this) {
        case RupeeDenomination.ten:
          return '१० रुपयांची नोट';
        case RupeeDenomination.twenty:
          return '२० रुपयांची नोट';
        case RupeeDenomination.fifty:
          return '५० रुपयांची नोट';
        case RupeeDenomination.hundred:
          return '१०० रुपयांची नोट';
        case RupeeDenomination.twoHundred:
          return '२०० रुपयांची नोट';
        case RupeeDenomination.fiveHundred:
          return '५०० रुपयांची नोट';
        case RupeeDenomination.uncertain:
          return 'अस्पष्ट नोट';
      }
    }

    if (isHi) {
      switch (this) {
        case RupeeDenomination.ten:
          return '१० रुपये का नोट';
        case RupeeDenomination.twenty:
          return '२० रुपये का नोट';
        case RupeeDenomination.fifty:
          return '५० रुपये का नोट';
        case RupeeDenomination.hundred:
          return '१०० रुपये का नोट';
        case RupeeDenomination.twoHundred:
          return '२०० रुपये का नोट';
        case RupeeDenomination.fiveHundred:
          return '५०० रुपये का नोट';
        case RupeeDenomination.uncertain:
          return 'अस्पष्ट नोट';
      }
    }

    return spokenLabel;
  }

  String get spokenLabel {
    switch (this) {
      case RupeeDenomination.ten:
        return '10 Rupees note';
      case RupeeDenomination.twenty:
        return '20 Rupees note';
      case RupeeDenomination.fifty:
        return '50 Rupees note';
      case RupeeDenomination.hundred:
        return '100 Rupees note';
      case RupeeDenomination.twoHundred:
        return '200 Rupees note';
      case RupeeDenomination.fiveHundred:
        return '500 Rupees note';
      case RupeeDenomination.uncertain:
        return 'Uncertain note';
    }
  }
}

class CurrencyDetectionResult {
  final RupeeDenomination denomination;
  final double confidence;
  final bool isConfident;
  final String spokenMessage;
  final String? retryInstructions;
  final String? noteSide; // Front / Back
  final String? noteColor; // Stone Grey, Lavender, etc.
  final String? physicalCondition; // Crisp, folded, etc.
  final String? touchGuidance; // Centered, tilted, etc.

  const CurrencyDetectionResult({
    required this.denomination,
    required this.confidence,
    required this.isConfident,
    required this.spokenMessage,
    this.retryInstructions,
    this.noteSide,
    this.noteColor,
    this.physicalCondition,
    this.touchGuidance,
  });
}

abstract class CurrencyDetectionService {
  Future<CurrencyDetectionResult> identifyCurrency(
    XFile noteImage, {
    String languageCode = 'en',
  });
}

class DefaultCurrencyDetectionService implements CurrencyDetectionService {
  final GeminiVisionService? geminiService;
  static const double confidenceThreshold = 0.65;

  DefaultCurrencyDetectionService({this.geminiService});

  @override
  Future<CurrencyDetectionResult> identifyCurrency(
    XFile noteImage, {
    String languageCode = 'en',
  }) async {
    final lang = languageCode.toLowerCase();
    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    try {
      final bytes = await noteImage.readAsBytes();
      if (bytes.isEmpty) {
        final emptyMsg = isMr
            ? 'कॅमेरा फ्रेम घेता आली नाही. कृपया नोट सपाट ठेवा आणि पुन्हा प्रयत्न करा.'
            : (isHi
                ? 'कैमरा फ्रेम नहीं मिल सकी। कृपया नोट को सीधा रखें और पुनः प्रयास करें।'
                : 'Could not capture frame. Please lay note flat and try again.');
        final emptyRetry = isMr
            ? 'चांगल्या प्रकाशाची खात्री करा आणि फोन थेट नोटवर धरा.'
            : (isHi
                ? 'अच्छी रोशनी सुनिश्चित करें और फोन को सीधे नोट के ऊपर रखें।'
                : 'Ensure good lighting and hold phone directly above the note.');
        return CurrencyDetectionResult(
          denomination: RupeeDenomination.uncertain,
          confidence: 0.0,
          isConfident: false,
          spokenMessage: emptyMsg,
          retryInstructions: emptyRetry,
        );
      }

      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
        final langInstruction = isMr
            ? 'The "spokenMessage" field MUST be in natural, grammatically correct, human-sounding spoken Marathi (मराठी) for text-to-speech. '
                'Give full details: denomination, note color, which side (front/back), and note condition. '
                'Example: "ही ५०० रुपयांची नवीन सिरीजची राखाडी नोट आहे. समोरची बाजू दिसत आहे. नोट स्वच्छ आणि सपाट आहे."'
            : (isHi
                ? 'The "spokenMessage" field MUST be in natural, grammatically correct, human-sounding spoken Hindi (हिंदी) for text-to-speech. '
                    'Give full details: denomination, note color, side (front/back), and note condition. '
                    'Example: "यह ५०० रुपये का नया स्टोन ग्रे नोट है। सामने का हिस्सा दिख रहा है। नोट साफ और सीधा है।"'
                : 'The "spokenMessage" field MUST be in natural spoken English with full details: denomination, color, side (front/back), and condition, e.g. "500 Rupee stone grey note detected. Front side with Gandhi portrait. Note is crisp and centered."');

        final prompt = 'You are an assistive currency identifier for a visually impaired user in India. '
            'Examine this camera frame and identify the Indian Rupee (INR) banknote denomination '
            '(Mahatma Gandhi New Series: ₹10, ₹20, ₹50, ₹100, ₹200, ₹500).\n'
            'Identify:\n'
            '1. Denomination: 10, 20, 50, 100, 200, 500, or 0 if uncertain.\n'
            '2. Side: "Front (Mahatma Gandhi portrait)" or "Back (Monument: Red Fort/Sanchi Stupa/Ellora/Hampi/Rani ki Vav/Konark)"\n'
            '3. Color: Stone Grey (₹500), Bright Yellow (₹200), Lavender (₹100), Cyan (₹50), Greenish Yellow (₹20), Chocolate Brown (₹10)\n'
            '4. Condition: crisp/flat, folded, creased, or partial view\n'
            '5. Touch guidance: "center", "left", "right", "too close", "too far"\n'
            '$langInstruction\n\n'
            'Respond ONLY with a valid JSON object in this format without markdown backticks:\n'
            '{\n'
            '  "denomination": 10 | 20 | 50 | 100 | 200 | 500 | 0,\n'
            '  "confidence": 0.0 to 1.0,\n'
            '  "noteSide": "front | back",\n'
            '  "noteColor": "Stone Grey | Bright Yellow | Lavender | Cyan | Greenish Yellow | Chocolate Brown",\n'
            '  "physicalCondition": "flat | folded | creased | partial",\n'
            '  "touchGuidance": "center | left | right | tilted",\n'
            '  "spokenMessage": "Voice announcement in requested language with full details",\n'
            '  "retryInstructions": "Guidance in requested language if banknote is blurry or folded"\n'
            '}';

        final response = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          maxTokens: 220,
          mimeType: 'image/jpeg',
        );

        // Parse JSON from response
        return _parseJsonResponse(response, languageCode: languageCode);
      }

      final unconfigMsg = isMr
          ? 'चलन ओळखण्यासाठी कृपया नोट कॅमेऱ्यासमोर सपाट ठेवा.'
          : (isHi ? 'मुद्रा पहचानने के लिए नोट को कैमरे के सामने सीधा रखें।' : 'Please place currency note flat in center of camera view.');
      return CurrencyDetectionResult(
        denomination: RupeeDenomination.uncertain,
        confidence: 0.0,
        isConfident: false,
        spokenMessage: unconfigMsg,
        retryInstructions: isMr
            ? 'अचूक ओळखीसाठी कृपया सेटिंग्जमध्ये जाऊन जेमिनी एपीआय की प्रविष्ट करा.'
            : (isHi
                ? 'सटीक पहचान के लिए कृपया सेटिंग्स में जेमिनी एपीआई की दर्ज करें।'
                : 'Configure Gemini API Key in Settings for cloud banknote detection.'),
      );
    } catch (e) {
      debugPrint('[CurrencyDetectionService] Detection error: $e');
      final errMsg = isMr
          ? 'चलन ओळखण्यात समस्या आली. कृपया प्रकाश चांगला ठेवा आणि नोट सपाट धरा.'
          : (isHi ? 'नोट पहचानने में समस्या आई। कृपया रोशनी अच्छी रखें और नोट सीधा रखें।' : 'Currency identification unclear. Please ensure good lighting and hold note flat.');
      return CurrencyDetectionResult(
        denomination: RupeeDenomination.uncertain,
        confidence: 0.0,
        isConfident: false,
        spokenMessage: errMsg,
        retryInstructions: isMr ? 'कृपया स्थिर रहा आणि पुन्हा प्रयत्न करा.' : (isHi ? 'कृपया स्थिर रहें और पुनः प्रयास करें।' : 'Please hold still and try again.'),
      );
    }
  }

  CurrencyDetectionResult _parseJsonResponse(String rawResponse, {String languageCode = 'en'}) {
    final isMr = languageCode.startsWith('mr');
    final isHi = languageCode.startsWith('hi');

    try {
      // Clean markdown code blocks if any
      var cleaned = rawResponse.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // Find first { and last }
      final startIndex = cleaned.indexOf('{');
      final endIndex = cleaned.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        cleaned = cleaned.substring(startIndex, endIndex + 1);
      }

      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      final denomValue = map['denomination'] is num ? (map['denomination'] as num).toInt() : 0;
      final conf = map['confidence'] is num ? (map['confidence'] as num).toDouble() : 0.85;
      final spokenMsg = map['spokenMessage']?.toString() ?? '';
      final retry = map['retryInstructions']?.toString();
      final side = map['noteSide']?.toString();
      final color = map['noteColor']?.toString();
      final condition = map['physicalCondition']?.toString();
      final touchGuide = map['touchGuidance']?.toString();

      final denom = _mapDenomination(denomValue);
      final isConfident = denom != RupeeDenomination.uncertain && conf >= confidenceThreshold;

      String finalSpoken;
      if (spokenMsg.isNotEmpty && spokenMsg != 'Note denomination evaluated.') {
        finalSpoken = spokenMsg;
      } else if (isConfident) {
        finalSpoken = denom.toSpokenPhrase(languageCode);
      } else {
        finalSpoken = isMr
            ? 'नोटा स्पष्ट दिसत नाही.'
            : (isHi ? 'नोट स्पष्ट नहीं दिख रहा है।' : 'Note denomination uncertain.');
      }

      return CurrencyDetectionResult(
        denomination: denom,
        confidence: conf,
        isConfident: isConfident,
        spokenMessage: finalSpoken,
        retryInstructions: retry,
        noteSide: side,
        noteColor: color,
        physicalCondition: condition,
        touchGuidance: touchGuide,
      );
    } catch (e) {
      debugPrint('[CurrencyDetectionService] JSON parse fallback: $e');
      // Text fallback if Gemini responded in natural language
      final lower = rawResponse.toLowerCase();
      RupeeDenomination denom = RupeeDenomination.uncertain;
      if (lower.contains('500') || lower.contains('five hundred')) {
        denom = RupeeDenomination.fiveHundred;
      } else if (lower.contains('200') || lower.contains('two hundred')) {
        denom = RupeeDenomination.twoHundred;
      } else if (lower.contains('100') || lower.contains('one hundred') || lower.contains('hundred')) {
        denom = RupeeDenomination.hundred;
      } else if (lower.contains('50') || lower.contains('fifty')) {
        denom = RupeeDenomination.fifty;
      } else if (lower.contains('20') || lower.contains('twenty')) {
        denom = RupeeDenomination.twenty;
      } else if (lower.contains('10') || lower.contains('ten')) {
        denom = RupeeDenomination.ten;
      }

      final isFound = denom != RupeeDenomination.uncertain;
      return CurrencyDetectionResult(
        denomination: denom,
        confidence: isFound ? 0.85 : 0.2,
        isConfident: isFound,
        spokenMessage: isFound ? denom.toSpokenPhrase(languageCode) : rawResponse.trim(),
        retryInstructions: isFound
            ? null
            : (isMr
                ? 'नोट सपाट आणि प्रकाशात ठेवा.'
                : (isHi ? 'नोट को समतल और प्रकाश में रखें।' : 'Ensure note is well-lit and laid flat.')),
      );
    }
  }

  RupeeDenomination _mapDenomination(int value) {
    switch (value) {
      case 10:
        return RupeeDenomination.ten;
      case 20:
        return RupeeDenomination.twenty;
      case 50:
        return RupeeDenomination.fifty;
      case 100:
        return RupeeDenomination.hundred;
      case 200:
        return RupeeDenomination.twoHundred;
      case 500:
        return RupeeDenomination.fiveHundred;
      default:
        return RupeeDenomination.uncertain;
    }
  }
}
