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

  const CurrencyDetectionResult({
    required this.denomination,
    required this.confidence,
    required this.isConfident,
    required this.spokenMessage,
    this.retryInstructions,
  });
}

abstract class CurrencyDetectionService {
  Future<CurrencyDetectionResult> identifyCurrency(XFile noteImage);
}

class DefaultCurrencyDetectionService implements CurrencyDetectionService {
  final GeminiVisionService? geminiService;
  static const double confidenceThreshold = 0.65;

  DefaultCurrencyDetectionService({this.geminiService});

  @override
  Future<CurrencyDetectionResult> identifyCurrency(XFile noteImage) async {
    try {
      final bytes = await noteImage.readAsBytes();
      if (bytes.isEmpty) {
        return const CurrencyDetectionResult(
          denomination: RupeeDenomination.uncertain,
          confidence: 0.0,
          isConfident: false,
          spokenMessage: 'Could not capture frame. Please lay note flat and try again.',
          retryInstructions: 'Ensure good lighting and hold phone directly above the note.',
        );
      }

      if (geminiService != null) {
        const prompt = 'You are an assistive currency identifier for a blind user in India. '
            'Examine this camera frame and identify the Indian Rupee (INR) banknote denomination '
            '(Mahatma Gandhi New Series: ₹10, ₹20, ₹50, ₹100, ₹200, ₹500).\n'
            'Check color, visible numbers, motifs, and size.\n'
            'Respond ONLY with a valid JSON object in this format:\n'
            '{\n'
            '  "denomination": 10 | 20 | 50 | 100 | 200 | 500 | 0,\n'
            '  "confidence": 0.0 to 1.0,\n'
            '  "spokenMessage": "Clear single sentence for text-to-speech announcement.",\n'
            '  "retryInstructions": "Guidance if the banknote is blurry, folded, or unclear"\n'
            '}';

        final response = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          mimeType: 'image/jpeg',
        );

        // Parse JSON from response
        return _parseJsonResponse(response);
      }

      return const CurrencyDetectionResult(
        denomination: RupeeDenomination.uncertain,
        confidence: 0.0,
        isConfident: false,
        spokenMessage: 'AI service unconfigured.',
        retryInstructions: 'Configure Gemini API Key in Settings.',
      );
    } catch (e) {
      debugPrint('[CurrencyDetectionService] Detection error: $e');
      return CurrencyDetectionResult(
        denomination: RupeeDenomination.uncertain,
        confidence: 0.0,
        isConfident: false,
        spokenMessage: 'Currency identification failed: $e',
        retryInstructions: 'Please hold still and try again.',
      );
    }
  }

  CurrencyDetectionResult _parseJsonResponse(String rawResponse) {
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
      final spokenMsg = map['spokenMessage']?.toString() ?? 'Note denomination evaluated.';
      final retry = map['retryInstructions']?.toString();

      final denom = _mapDenomination(denomValue);
      final isConfident = denom != RupeeDenomination.uncertain && conf >= confidenceThreshold;

      return CurrencyDetectionResult(
        denomination: denom,
        confidence: conf,
        isConfident: isConfident,
        spokenMessage: isConfident ? '₹${denom.numericValue} note detected.' : spokenMsg,
        retryInstructions: retry,
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
        spokenMessage: isFound ? '₹${denom.numericValue} note detected.' : rawResponse.trim(),
        retryInstructions: isFound ? null : 'Ensure note is well-lit and laid flat.',
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
