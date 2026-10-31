import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/network/gemini_service.dart';
import '../../../app/theme/app_colors.dart';
import 'dart:typed_data';

/// Fast image compressor delegating to optimized GeminiVisionService background isolate
class ImageCompressor {
  static Uint8List compress(Uint8List bytes, {int maxDimension = 640, int quality = 75}) {
    return GeminiVisionService.compressImageSync(bytes, maxDimension: maxDimension, quality: quality);
  }
}

enum DescriptionVerbosity {
  concise,
  detailed,
}

class ArDetectedObject {
  final String label;
  final String distance;
  final double x; // Relative horizontal position (0.0 to 1.0)
  final double y; // Relative vertical position (0.0 to 1.0)
  final double width;
  final double height;
  final Color color;

  const ArDetectedObject({
    required this.label,
    required this.distance,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
  });
}

class SceneDescriptionResult {
  final String descriptionText;
  final double confidence;
  final bool isLocalInference;
  final List<String> detectedElements;
  final List<ArDetectedObject> realWorldObjects;
  final bool isLightingAdequate;

  const SceneDescriptionResult({
    required this.descriptionText,
    required this.confidence,
    required this.isLocalInference,
    required this.detectedElements,
    this.realWorldObjects = const [],
    this.isLightingAdequate = true,
  });
}

abstract class SceneUnderstandingService {
  Future<SceneDescriptionResult> analyzeScene({
    required XFile imageFile,
    DescriptionVerbosity verbosity = DescriptionVerbosity.concise,
    String languageCode = 'en',
  });
}

class DefaultSceneUnderstandingService implements SceneUnderstandingService {
  final GeminiVisionService? geminiService;

  DefaultSceneUnderstandingService({this.geminiService});

  @override
  Future<SceneDescriptionResult> analyzeScene({
    required XFile imageFile,
    DescriptionVerbosity verbosity = DescriptionVerbosity.concise,
    String languageCode = 'en',
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      if (bytes.isEmpty) {
        return const SceneDescriptionResult(
          descriptionText: 'Unable to capture frame. Please hold steady and try again.',
          confidence: 0.1,
          isLocalInference: false,
          detectedElements: [],
          isLightingAdequate: false,
        );
      }

      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
        String langInstruction = 'Describe in clear, natural spoken English.';
        if (languageCode == 'mr') {
          langInstruction = 'Describe in clear, natural spoken Marathi (मराठी) for text-to-speech for a blind user in Maharashtra, India. Focus on walking path and obstacle locations.';
        } else if (languageCode == 'hi') {
          langInstruction = 'Describe in clear, natural spoken Hindi (हिन्दी) for text-to-speech for a blind user in India. Focus on walking path and obstacle locations.';
        }

        final prompt = 'You are a warm, empathetic spatial awareness companion for a visually impaired person. '
            'Look at this camera image and describe the physical scene as if you are speaking to a trusted friend who cannot see. '
            '$langInstruction '
            'Speak naturally and conversationally like a helpful guide beside them. '
            'Describe: '
            '1) Where they are (indoor room type, outdoor street, hallway, etc.), '
            '2) Is the path ahead clear to walk, or is something blocking the way? '
            '3) Any stairs (going up or down), doors, vehicles, traffic, obstacles, or people nearby and where they are relative to the user (left, right, ahead, how far), '
            '4) Lighting — is it bright, dim, or dark? Any dark areas to be careful of? '
            '5) Any signs, text, or important colored objects they should know about. '
            '6) Any safety concerns — steps, drops, traffic, uneven ground, or hazards. '
            'Keep it warm, natural, and easy to understand when spoken aloud. '
            'Then on a new line output:\n'
            'DETECTIONS:\n'
            '- [Object Name] | [Distance e.g. 1.5m] | [Position: Left/Center/Right] | [Color if visible]\n'
            '(List up to 6 most important real-world obstacles, vehicles, and items)';

        try {
          final response = await geminiService!.askGemini(
            prompt: prompt,
            imageBytes: bytes, // GeminiVisionService handles isolate-based fast compression directly
            mimeType: 'image/jpeg',
            maxTokens: 256,
          );

          final cleanedText = response.trim();

          // Separate description text and detections block
          String spokenDescription = cleanedText;
          final detectionsList = <ArDetectedObject>[];
          final elementsList = <String>[];

          if (cleanedText.contains('DETECTIONS:')) {
            final parts = cleanedText.split('DETECTIONS:');
            spokenDescription = parts[0].trim();
            final detectionsBlock = parts[1].trim();

            final lines = detectionsBlock.split('\n');
            int index = 0;
            for (final line in lines) {
              final trimmed = line.replaceAll(RegExp(r'^[-*•0-9.]\s*'), '').trim();
              if (trimmed.isEmpty) continue;

              final segments = trimmed.split('|').map((s) => s.trim()).toList();
              final label = segments.isNotEmpty ? segments[0] : 'Object';
              final dist = segments.length > 1 ? segments[1] : 'Ahead';
              final pos = segments.length > 2 ? segments[2].toLowerCase() : 'center';

              double x = 0.5;
              if (pos.contains('left')) x = 0.22;
              if (pos.contains('right')) x = 0.78;

              double y = 0.45 + (index * 0.1).clamp(0.0, 0.35);

              final palette = [
                AppColors.primaryCyan,
                const Color(0xFFF59E0B),
                const Color(0xFF10B981),
                const Color(0xFF8B5CF6),
                const Color(0xFFEC4899),
                const Color(0xFF3B82F6),
              ];

              detectionsList.add(
                ArDetectedObject(
                  label: label,
                  distance: dist,
                  x: x,
                  y: y,
                  width: 0.38,
                  height: 0.18,
                  color: palette[index % palette.length],
                ),
              );
              elementsList.add(label);
              index++;
            }
          } else {
            // Heuristic keyword extraction fallback
            final lower = spokenDescription.toLowerCase();
            for (final item in [
              'room',
              'door',
              'hallway',
              'chair',
              'table',
              'desk',
              'person',
              'path',
              'stairs',
              'window',
              'laptop',
              'screen',
              'wall',
            ]) {
              if (lower.contains(item)) {
                elementsList.add(item[0].toUpperCase() + item.substring(1));
              }
            }
          }

          return SceneDescriptionResult(
            descriptionText: spokenDescription,
            confidence: 0.95,
            isLocalInference: false,
            detectedElements: elementsList,
            realWorldObjects: detectionsList,
            isLightingAdequate: true,
          );
        } catch (e) {
          debugPrint('[SceneUnderstandingService] Gemini call failed: $e');
          final isMr = languageCode.startsWith('mr');
          final isHi = languageCode.startsWith('hi');
          final msg = isMr
              ? 'कॅमेरा फ्रेम कॅप्चर झाला, परंतु एआय विश्लेषण अयशस्वी झाले. कृपया तुमची इंटरनेट कनेक्शन आणि जेमिनी एपीआय की तपासा.'
              : (isHi
                  ? 'कैमरा फ्रेम कैप्चर हो गया, लेकिन एआई विश्लेषण विफल रहा। कृपया अपना इंटरनेट कनेक्शन और जेमिनी एपीआई की जांचें।'
                  : 'I captured the camera frame, but AI analysis failed. Please check your internet connection and verify your Gemini API key in Settings.');
          return SceneDescriptionResult(
            descriptionText: msg,
            confidence: 0.0,
            isLocalInference: false,
            detectedElements: const [],
            realWorldObjects: const [],
            isLightingAdequate: true,
          );
        }
      }

      final isMr = languageCode.startsWith('mr');
      final isHi = languageCode.startsWith('hi');
      final unconfigMsg = isMr
          ? 'लाइव कॅमेरा फ्रेम सक्रिय आहे. रिअल-टाइम एआय विश्लेषणासाठी कृपया तुमची जेमिनी एपीआय की सेटिंग्जमध्ये प्रविष्ट करा.'
          : (isHi
              ? 'लाइव कैमरा फ्रेम सक्रिय है। रीयल-टाइम एआई विश्लेषण के लिए कृपया अपनी जेमिनी एपीआई की सेटिंग्ज में दर्ज करें।'
              : 'Live camera frame captured. To analyze what is in front of the camera in real time, please add your Gemini API Key in Settings.');
      return SceneDescriptionResult(
        descriptionText: unconfigMsg,
        confidence: 0.0,
        isLocalInference: false,
        detectedElements: const [],
        realWorldObjects: const [],
        isLightingAdequate: true,
      );
    } catch (e) {
      debugPrint('[SceneUnderstandingService] Real-time scene analysis error: $e');
      return const SceneDescriptionResult(
        descriptionText: 'Unable to capture camera frame. Please ensure camera permissions are granted and try again.',
        confidence: 0.0,
        isLocalInference: false,
        detectedElements: [],
        realWorldObjects: [],
        isLightingAdequate: false,
      );
    }
  }
}
