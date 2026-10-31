import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../../../core/network/gemini_service.dart';

class BarcodeProductResult {
  final String barcodeValue;
  final String barcodeFormat;
  final String productName;
  final String category;
  final String spokenSummary;

  const BarcodeProductResult({
    required this.barcodeValue,
    required this.barcodeFormat,
    required this.productName,
    required this.category,
    required this.spokenSummary,
  });
}

class BarcodeScannerService {
  final GeminiVisionService? geminiService;
  final BarcodeScanner _mlKitScanner = BarcodeScanner();

  BarcodeScannerService({this.geminiService});

  // Offline quick lookup dictionary for common Indian packaged goods barcodes
  static const Map<String, Map<String, String>> _offlineProductDb = {
    '8901030': {'name': 'Parle-G बिस्किट (Parle-G Glucose Biscuits)', 'cat': 'खाद्यपदार्थ (Food)'},
    '8901058': {'name': 'मॅगी २ मिनिट नूडल्स (Maggi 2-Minute Noodles)', 'cat': 'खाद्यपदार्थ (Food)'},
    '8901063': {'name': 'अमूल ताजे दूध किंवा बटर (Amul Milk / Butter)', 'cat': 'दुग्धजन्य (Dairy)'},
    '8901725': {'name': 'टाटा मीठ (Tata Salt Vaccum Evaporated)', 'cat': 'किराणा (Grocery)'},
    '8901023': {'name': 'कोलगेट टूथपेस्ट (Colgate Strong Teeth)', 'cat': 'स्वच्छता (Personal Care)'},
    '8901088': {'name': 'डेटॉल अँटीसेप्टिक लिक्विड किंवा साबण (Dettol)', 'cat': 'स्वच्छता (Personal Care)'},
    '8901491': {'name': 'लाइफबॉय किंवा लक्स साबण (Lifebuoy/Lux)', 'cat': 'स्वच्छता (Personal Care)'},
    '8901314': {'name': 'फॉर्च्युन सूर्यफूल तेल (Fortune Edible Oil)', 'cat': 'किराणा (Grocery)'},
    '8901262': {'name': 'हल्दीराम शेव किंवा नमकीन (Haldiram Bhujia/Namkeen)', 'cat': 'खाद्यपदार्थ (Food)'},
  };

  /// Scans barcode on-device using Google ML Kit first (100% offline, <30ms)
  Future<BarcodeProductResult> scanBarcodeFromImage(
    XFile cameraImage, {
    String languageCode = 'mr',
  }) async {
    final lang = languageCode.toLowerCase();
    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    try {
      final inputImage = InputImage.fromFilePath(cameraImage.path);
      final barcodes = await _mlKitScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        final rawValue = barcode.rawValue ?? barcode.displayValue ?? '';
        final formatName = barcode.format.name;

        // Try offline lookup first
        String? knownProduct;
        String? knownCat;

        for (final prefix in _offlineProductDb.keys) {
          if (rawValue.startsWith(prefix)) {
            knownProduct = _offlineProductDb[prefix]!['name'];
            knownCat = _offlineProductDb[prefix]!['cat'];
            break;
          }
        }

        if (knownProduct != null) {
          final summary = isMr
              ? 'वस्तू ओळखली: $knownProduct. श्रेणी: $knownCat.'
              : (isHi
                  ? 'वस्तु पहचानी गई: $knownProduct। श्रेणी: $knownCat।'
                  : 'Product identified: $knownProduct. Category: $knownCat.');

          return BarcodeProductResult(
            barcodeValue: rawValue,
            barcodeFormat: formatName,
            productName: knownProduct,
            category: knownCat ?? '',
            spokenSummary: summary,
          );
        }

        // If online and Gemini available, query for rich product packaging identification
        if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
          final bytes = await cameraImage.readAsBytes();
          final prompt = '''
A barcode was detected with code: "$rawValue" ($formatName).
Identify the exact product name, brand, weight, and price from this package.
Respond strictly in JSON only:
{
  "productName": "Name and brand of product in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}",
  "category": "Food, Beverage, Toiletries, Medicine, etc.",
  "spokenSummary": "Concise spoken summary for a blind person identifying the product clearly in ${isMr ? 'Marathi' : (isHi ? 'Hindi' : 'English')}."
}
''';
          try {
            final rawAi = await geminiService!.askGemini(
              prompt: prompt,
              imageBytes: bytes,
              maxTokens: 400,
            );
            return _parseGeminiProductJson(rawAi, rawValue, formatName, languageCode);
          } catch (_) {}
        }

        // Fallback with barcode value announcement
        final summary = isMr
            ? 'बारकोड स्कॅन झाला: $rawValue. स्वरूप: $formatName.'
            : (isHi
                ? 'बारकोड स्कैन हुआ: $rawValue। प्रारूप: $formatName।'
                : 'Barcode scanned: $rawValue. Format: $formatName.');

        return BarcodeProductResult(
          barcodeValue: rawValue,
          barcodeFormat: formatName,
          productName: 'बारकोड $rawValue',
          category: 'पॅकबंद वस्तू',
          spokenSummary: summary,
        );
      }
    } catch (e) {
      debugPrint('[BarcodeScannerService] ML Kit error: $e');
    }

    return BarcodeProductResult(
      barcodeValue: '',
      barcodeFormat: '',
      productName: '',
      category: '',
      spokenSummary: isMr
          ? 'बारकोड सापडला नाही. कृपया कॅमेरा पॅकेटच्या बारकोडवर स्थिर धरा.'
          : 'No barcode detected. Please hold camera steady over product barcode.',
    );
  }

  BarcodeProductResult _parseGeminiProductJson(
    String raw,
    String barcodeValue,
    String barcodeFormat,
    String languageCode,
  ) {
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
      final name = json['productName']?.toString() ?? 'वस्तू';
      final cat = json['category']?.toString() ?? '';
      final summary = json['spokenSummary']?.toString() ?? name;

      return BarcodeProductResult(
        barcodeValue: barcodeValue,
        barcodeFormat: barcodeFormat,
        productName: name,
        category: cat,
        spokenSummary: summary,
      );
    } catch (_) {
      return BarcodeProductResult(
        barcodeValue: barcodeValue,
        barcodeFormat: barcodeFormat,
        productName: 'बारकोड $barcodeValue',
        category: '',
        spokenSummary: 'बारकोड $barcodeValue',
      );
    }
  }

  void dispose() {
    _mlKitScanner.close();
  }
}
