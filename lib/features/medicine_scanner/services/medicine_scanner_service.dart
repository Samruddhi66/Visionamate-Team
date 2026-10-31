import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/gemini_service.dart';

class MedicineAnalysisResult {
  final String medicineName;
  final String dosage;
  final String expiryDate;
  final bool isExpired;
  final String indication;
  final String warning;
  final String spokenSummary;

  const MedicineAnalysisResult({
    required this.medicineName,
    required this.dosage,
    required this.expiryDate,
    required this.isExpired,
    required this.indication,
    required this.warning,
    required this.spokenSummary,
  });
}

class MedicineScannerService {
  final GeminiVisionService? geminiService;

  MedicineScannerService({this.geminiService});

  Future<MedicineAnalysisResult> scanMedicine(
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
          isMr ? 'औषधाची प्रतिमा घेता आली नाही.' : (isHi ? 'दवा की फोटो नहीं ली जा सकी।' : 'Failed to capture medicine image.'),
          languageCode,
        );
      }

      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
        final prompt = '''
You are VisionMate Medical AI for blind and visually impaired users.
Analyze this medicine packaging, tablet blister strip, prescription label, or syrup bottle.
Respond strictly with valid JSON only (no markdown, no quotes):
{
  "medicineName": "Full brand name and active salt composition",
  "dosage": "Strength e.g. 500mg, and usage frequency",
  "expiryDate": "Expiry month/year e.g. 11/2026",
  "isExpired": true or false,
  "indication": "Primary use e.g. fever, pain, infection in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "warning": "Critical safety precaution or doctor advice in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "spokenSummary": "Clear, direct spoken advice for a blind user in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}. If expired, begin with an urgent warning alert."
}
''';

        final raw = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          maxTokens: 500,
        );

        return _parseMedicineJson(raw, languageCode);
      }
    } catch (e) {
      debugPrint('[MedicineScannerService] Scan error: $e');
    }

    return _fallbackError(
      isMr
          ? 'औषध तपासण्यासाठी इंटरनेट कनेक्शन आणि जेमिनी की आवश्यक आहे.'
          : (isHi
              ? 'दवा जांचने के लिए इंटरनेट और जेमिनी कुंजी आवश्यक है।'
              : 'Internet connection and Gemini API key required to scan medicine.'),
      languageCode,
    );
  }

  MedicineAnalysisResult _parseMedicineJson(String raw, String languageCode) {
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
      final name = json['medicineName']?.toString() ?? (isMr ? 'औषध' : 'Medicine');
      final dose = json['dosage']?.toString() ?? '';
      final exp = json['expiryDate']?.toString() ?? (isMr ? 'तारीख स्पष्ट नाही' : 'Date not visible');
      final expired = json['isExpired'] == true;
      final ind = json['indication']?.toString() ?? '';
      final warn = json['warning']?.toString() ?? '';
      final summary = json['spokenSummary']?.toString() ?? '$name. $exp.';

      return MedicineAnalysisResult(
        medicineName: name,
        dosage: dose,
        expiryDate: exp,
        isExpired: expired,
        indication: ind,
        warning: warn,
        spokenSummary: summary,
      );
    } catch (_) {
      return _fallbackError(
        isMr ? 'औषधाची माहिती वाचता आली नाही.' : 'Unable to parse medicine details.',
        languageCode,
      );
    }
  }

  MedicineAnalysisResult _fallbackError(String message, String languageCode) {
    return MedicineAnalysisResult(
      medicineName: 'अज्ञात',
      dosage: '',
      expiryDate: '',
      isExpired: false,
      indication: '',
      warning: '',
      spokenSummary: message,
    );
  }
}
