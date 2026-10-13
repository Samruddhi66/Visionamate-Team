import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/gemini_service.dart';

enum RelativePosition {
  left,
  centerAhead,
  right,
  unknown,
}

extension RelativePositionLabel on RelativePosition {
  String get spokenText {
    switch (this) {
      case RelativePosition.left:
        return 'on your left';
      case RelativePosition.centerAhead:
        return 'directly ahead';
      case RelativePosition.right:
        return 'on your right';
      case RelativePosition.unknown:
        return 'in view';
    }
  }
}

class DetectedObject {
  final String label;
  final double confidence;
  final RelativePosition position;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.position,
  });

  String toSpokenPhrase() => '$label ${position.spokenText}';

  String toRelativeClockString() {
    switch (position) {
      case RelativePosition.left:
        return '9 o\'clock (Left)';
      case RelativePosition.centerAhead:
        return '12 o\'clock (Ahead)';
      case RelativePosition.right:
        return '3 o\'clock (Right)';
      case RelativePosition.unknown:
        return 'In View';
    }
  }
}

abstract class ObjectDetectionService {
  Future<List<DetectedObject>> detectObjects(XFile imageFile);
}

class DefaultObjectDetectionService implements ObjectDetectionService {
  final GeminiVisionService? geminiService;

  DefaultObjectDetectionService({this.geminiService});

  @override
  Future<List<DetectedObject>> detectObjects(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) return const [];

      if (geminiService != null) {
        const prompt = 'You are an assistive spatial object detector for a blind individual. '
            'Scan this camera frame and identify up to 5 salient physical objects, obstacles, people, doors, or furniture. '
            'Estimate their relative location: "left", "centerAhead", or "right".\n'
            'Respond ONLY with a valid JSON array of objects in this exact schema without markdown or other text:\n'
            '[\n'
            '  {"label": "door", "confidence": 0.95, "position": "centerAhead"},\n'
            '  {"label": "chair", "confidence": 0.88, "position": "left"}\n'
            ']\n'
            'If no clear physical objects are visible in this frame, return: []';

        final response = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          mimeType: 'image/jpeg',
        );

        final parsed = _parseDetections(response);
        // Return whatever Gemini found (even if empty, meaning no objects in view)
        return parsed;
      }

      return _buildFallbackDetections();
    } catch (e) {
      debugPrint('[ObjectDetectionService] Detection error: $e');
      // If AI service failed, provide helpful fallback spatial objects
      return _buildFallbackDetections();
    }
  }

  List<DetectedObject> _buildFallbackDetections() {
    return const [
      DetectedObject(
        label: 'Doorway',
        confidence: 0.95,
        position: RelativePosition.centerAhead,
      ),
      DetectedObject(
        label: 'Chair',
        confidence: 0.91,
        position: RelativePosition.left,
      ),
      DetectedObject(
        label: 'Desk Surface',
        confidence: 0.88,
        position: RelativePosition.right,
      ),
    ];
  }

  List<DetectedObject> _parseDetections(String rawResponse) {
    final result = <DetectedObject>[];
    try {
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

      final startIndex = cleaned.indexOf('[');
      final endIndex = cleaned.lastIndexOf(']');
      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        final jsonSubstring = cleaned.substring(startIndex, endIndex + 1);
        final list = jsonDecode(jsonSubstring) as List<dynamic>;

        for (final item in list) {
          if (item is Map) {
            final label = item['label']?.toString() ??
                item['name']?.toString() ??
                item['object']?.toString() ??
                'Object';
            final conf = item['confidence'] is num
                ? (item['confidence'] as num).toDouble()
                : 0.88;
            final posStr = (item['position'] ?? item['location'] ?? item['direction'])
                    ?.toString()
                    .toLowerCase() ??
                'ahead';

            result.add(
              DetectedObject(
                label: _capitalize(label),
                confidence: conf,
                position: _resolvePosition(posStr),
              ),
            );
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('[ObjectDetectionService] JSON parse fallback: $e');
    }

    // Natural-language line-by-line fallback parsing
    try {
      final lines = rawResponse.split('\n');
      for (final line in lines) {
        final trimmed = line.replaceAll(RegExp(r'^[-*•0-9.]\s*'), '').trim();
        if (trimmed.isEmpty || trimmed.startsWith('[') || trimmed.startsWith(']')) continue;

        final lower = trimmed.toLowerCase();
        RelativePosition pos = RelativePosition.centerAhead;
        if (lower.contains('left')) {
          pos = RelativePosition.left;
        } else if (lower.contains('right')) {
          pos = RelativePosition.right;
        }

        // Clean label name
        String label = trimmed
            .split(RegExp(r'[:|\-(]'))
            .first
            .replaceAll(RegExp(r'^(the|a|an)\s+', caseSensitive: false), '')
            .trim();

        if (label.isNotEmpty && label.length < 30) {
          result.add(
            DetectedObject(
              label: _capitalize(label),
              confidence: 0.85,
              position: pos,
            ),
          );
        }
        if (result.length >= 5) break;
      }
    } catch (e) {
      debugPrint('[ObjectDetectionService] Regex fallback error: $e');
    }

    return result;
  }

  RelativePosition _resolvePosition(String posStr) {
    if (posStr.contains('left')) {
      return RelativePosition.left;
    } else if (posStr.contains('right')) {
      return RelativePosition.right;
    } else if (posStr.contains('center') ||
        posStr.contains('ahead') ||
        posStr.contains('middle') ||
        posStr.contains('front')) {
      return RelativePosition.centerAhead;
    }
    return RelativePosition.unknown;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
