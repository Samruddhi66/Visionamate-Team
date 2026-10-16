import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/network/gemini_service.dart';
import '../../../app/theme/app_colors.dart';

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

        final prompt = 'You are an assistive spatial awareness guide for a blind person. '
            'Look at this camera image and describe the physical scene in 2 direct, actionable sentences. '
            '$langInstruction '
            'Highlight: 1) the walking path directly ahead, 2) any obstacles, doors, steps, people, or furniture and their positions (left, ahead, right). '
            'Then on a new line output:\n'
            'DETECTIONS:\n'
            '- [Object Name] | [Distance e.g. 1.5m] | [Position: Left/Center/Right]\n'
            '(List up to 3 most important real-world items)';

        try {
          final response = await geminiService!.askGemini(
            prompt: prompt,
            imageBytes: bytes,
            mimeType: 'image/jpeg',
            maxTokens: 180,
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
              final distance = segments.length > 1 ? segments[1] : '1.5 m';
              final posStr = segments.length > 2 ? segments[2].toLowerCase() : '';

              elementsList.add(label);

              double x = 0.15;
              double y = 0.25;
              Color color = AppColors.primaryCyan;

              if (posStr.contains('right') || index == 1) {
                x = 0.60;
                y = 0.20;
                color = AppColors.successGreen;
              } else if (posStr.contains('center') || posStr.contains('ahead') || index == 2) {
                x = 0.35;
                y = 0.50;
                color = AppColors.warningAmber;
              }

              detectionsList.add(
                ArDetectedObject(
                  label: label,
                  distance: distance,
                  x: x,
                  y: y,
                  width: 140,
                  height: 100,
                  color: color,
                ),
              );
              index++;
              if (index >= 3) break;
            }
          }

          if (elementsList.isEmpty) {
            final lower = cleanedText.toLowerCase();
            for (final item in [
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
              ? 'कॅमेरा फ्रेम कॅप्चर झाली, परंतु एआय विश्लेषण अयशस्वी झाले. कृपया इंटरनेट आणि जेमिनी की तपासा.'
              : (isHi
                  ? 'कैमरा फ्रेम कैप्चर हुआ, लेकिन एआई विश्लेषण विफल रहा। कृपया इंटरनेट और जेमिनी की जांचें।'
                  : 'Live frame captured, but AI analysis failed. Please verify your Gemini API key in Settings.');
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
          ? 'थेट कॅमेरा फ्रेम सक्रिय आहे. रिअल-टाइम एआय विश्लेषणासाठी कृपया तुमची जेमिनी एपीआय की प्रविष्ट करा.'
          : (isHi
              ? 'लाइव कैमरा फ्रेम सक्रिय है। रीयल-टाइम एआई विश्लेषण के लिए कृपया अपनी जेमिनी एपीआई की दर्ज करें।'
              : 'Live camera frame captured. To analyze what is in front of the camera in real time, please add your Gemini API Key.');
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
        descriptionText: 'Unable to capture camera frame. Please ensure camera permissions are granted.',
        confidence: 0.0,
        isLocalInference: false,
        detectedElements: [],
        realWorldObjects: [],
        isLightingAdequate: false,
      );
    }
  }
}
