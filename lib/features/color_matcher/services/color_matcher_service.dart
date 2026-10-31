import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/gemini_service.dart';

class ColorMatchResult {
  final String itemType;
  final String primaryColor;
  final String secondaryColor;
  final String pattern;
  final String matchingAdvice;
  final String spokenSummary;

  const ColorMatchResult({
    required this.itemType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.pattern,
    required this.matchingAdvice,
    required this.spokenSummary,
  });
}

class ColorMatcherService {
  final GeminiVisionService? geminiService;

  ColorMatcherService({this.geminiService});

  Future<ColorMatchResult> analyzeClothing(
    XFile cameraImage, {
    String languageCode = 'mr',
  }) async {
    final lang = languageCode.toLowerCase();
    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    try {
      final bytes = await cameraImage.readAsBytes();
      if (bytes.isEmpty) {
        return _fallbackError(
          isMr ? 'कपड्याचा फोटो घेता आला नाही.' : 'Unable to capture clothing image.',
          languageCode,
        );
      }

      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
        final prompt = '''
You are VisionMate Fashion & Color Assistant for a blind person.
Analyze the clothing or fabric item in this image.
Respond strictly in valid JSON format only (no markdown, no quotes):
{
  "itemType": "e.g. Shirt, T-Shirt, Trousers, Saree, Kurta, Jacket, Dress, Shoes in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "primaryColor": "Main color with shade e.g. Dark Navy Blue, Maroon, Beige in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "secondaryColor": "Secondary or accent color, or 'None' in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "pattern": "e.g. Plain solid, Checked, Vertical Stripes, Floral printed in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "matchingAdvice": "Practical color-matching advice on what pants/shirts/shoes to wear with this in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "spokenSummary": "Conversational, natural advice for a blind user in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}. Tell the color clearly first, then pattern, then outfit matching tip."
}
''';

        final raw = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          maxTokens: 500,
        );

        return _parseColorJson(raw, languageCode);
      }
    } catch (e) {
      debugPrint('[ColorMatcherService] Error: $e');
    }

    return _fallbackError(
      isMr
          ? 'रंग ओळखण्यासाठी इंटरनेट कनेक्शन आणि जेमिनी की आवश्यक आहे.'
          : 'Internet connection and Gemini API key required to identify clothing color.',
      languageCode,
    );
  }

  ColorMatchResult _parseColorJson(String raw, String languageCode) {
    final isMr = languageCode.startsWith('mr');

    try {
      var cleaned = raw.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
      cleaned = cleaned.trim();

      final firstBrace = cleaned.indexOf('{');
      final lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace >= firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final type = json['itemType']?.toString() ?? (isMr ? 'कपडा' : 'Clothing');
      final prim = json['primaryColor']?.toString() ?? '';
      final sec = json['secondaryColor']?.toString() ?? '';
      final pat = json['pattern']?.toString() ?? '';
      final advice = json['matchingAdvice']?.toString() ?? '';
      final summary = json['spokenSummary']?.toString() ?? '$type. $prim.';

      return ColorMatchResult(
        itemType: type,
        primaryColor: prim,
        secondaryColor: sec,
        pattern: pat,
        matchingAdvice: advice,
        spokenSummary: summary,
      );
    } catch (_) {
      return _fallbackError(
        isMr ? 'रंग ओळखता आला नाही.' : 'Unable to parse color details.',
        languageCode,
      );
    }
  }

  ColorMatchResult _fallbackError(String message, String languageCode) {
    return ColorMatchResult(
      itemType: '',
      primaryColor: '',
      secondaryColor: '',
      pattern: '',
      matchingAdvice: '',
      spokenSummary: message,
    );
  }
}
