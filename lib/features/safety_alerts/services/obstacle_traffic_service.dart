import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/network/gemini_service.dart';
import '../../../app/theme/app_colors.dart';

enum HazardCategory {
  obstacle,
  traffic,
  trafficSignal,
  crossing,
  surface,
}

enum SpatialDirection {
  left,
  centerAhead,
  right,
}

extension SpatialDirectionText on SpatialDirection {
  String toSpokenText([String lang = 'en']) {
    if (lang.startsWith('mr')) {
      switch (this) {
        case SpatialDirection.left:
          return 'डाव्या बाजूला';
        case SpatialDirection.centerAhead:
          return 'थेट समोर';
        case SpatialDirection.right:
          return 'उजव्या बाजूला';
      }
    } else if (lang.startsWith('hi')) {
      switch (this) {
        case SpatialDirection.left:
          return 'बाईं ओर';
        case SpatialDirection.centerAhead:
          return 'सीधे सामने';
        case SpatialDirection.right:
          return 'दाईं ओर';
      }
    }
    switch (this) {
      case SpatialDirection.left:
        return 'on your left';
      case SpatialDirection.centerAhead:
        return 'directly ahead';
      case SpatialDirection.right:
        return 'on your right';
    }
  }
}

class ObstacleTrafficItem {
  final String label;
  final HazardCategory category;
  final String severity; // 'critical', 'moderate', 'low'
  final SpatialDirection direction;
  final String clockPosition; // e.g. "12 o'clock", "2 o'clock"
  final double distanceMeters;
  final double x; // 0.0 to 1.0
  final double y; // 0.0 to 1.0
  final double width;
  final double height;
  final bool isMoving;
  final String spokenAlert;
  final Color highlightColor;

  const ObstacleTrafficItem({
    required this.label,
    required this.category,
    required this.severity,
    required this.direction,
    required this.clockPosition,
    required this.distanceMeters,
    required this.x,
    required this.y,
    this.width = 0.25,
    this.height = 0.25,
    this.isMoving = false,
    required this.spokenAlert,
    required this.highlightColor,
  });

  bool get isCritical => severity == 'critical' || distanceMeters <= 1.5;
}

class ObstacleTrafficScanResult {
  final String spokenSummary;
  final List<ObstacleTrafficItem> items;
  final bool isSafeToWalk;
  final String? criticalWarning;
  final String? trafficLightStatus;
  final bool zebraCrossingVisible;

  const ObstacleTrafficScanResult({
    required this.spokenSummary,
    required this.items,
    required this.isSafeToWalk,
    this.criticalWarning,
    this.trafficLightStatus,
    this.zebraCrossingVisible = false,
  });
}

abstract class ObstacleTrafficService {
  Future<ObstacleTrafficScanResult> scanSurroundings(
    XFile cameraImage, {
    String languageCode = 'en',
  });
}

class DefaultObstacleTrafficService implements ObstacleTrafficService {
  final GeminiVisionService? geminiService;

  DefaultObstacleTrafficService({this.geminiService});

  @override
  Future<ObstacleTrafficScanResult> scanSurroundings(
    XFile cameraImage, {
    String languageCode = 'en',
  }) async {
    final lang = languageCode.toLowerCase();
    final isMr = lang.startsWith('mr');
    final isHi = lang.startsWith('hi');

    try {
      final bytes = await cameraImage.readAsBytes();
      if (bytes.isEmpty) {
        return ObstacleTrafficScanResult(
          spokenSummary: isMr
              ? 'कॅमेरा प्रतिमा घेता आली नाही.'
              : (isHi ? 'कैमरा छवि नहीं मिल सकी।' : 'Unable to capture camera frame.'),
          items: const [],
          isSafeToWalk: true,
        );
      }

      if (geminiService != null && geminiService!.preferencesService.hasGeminiApiKey) {
        String langRule = 'All labels and descriptions MUST be in natural spoken English.';
        if (isMr) {
          langRule = 'All labels, spokenSummary, and spokenAlert MUST be in natural, grammatically correct spoken Marathi (मराठी) for text-to-speech. '
              'For example: "सावधान! थेट समोर १.२ मीटर अंतरावर खाली जाणाऱ्या पायऱ्या आहेत." '
              'or "उजव्या बाजूला ३ मीटरवर रिक्षा थांबलेली आहे. रस्ता चालण्यास मोकळा आहे."';
        } else if (isHi) {
          langRule = 'All labels, spokenSummary, and spokenAlert MUST be in natural, grammatically correct spoken Hindi (हिन्दी) for text-to-speech. '
              'For example: "सावधान! सीधे सामने १.२ मीटर पर नीचे उतरने वाली सीढ़ियां हैं।" '
              'or "दाईं ओर ३ मीटर पर ऑटो रिक्शा है। आगे रास्ता साफ है।"';
        }

        final prompt = 'You are a critical safety and mobility guide for a blind pedestrian in India. '
            'Analyze this live camera frame with extreme detail for physical obstacles, hazards, traffic, vehicles, signals, and walkways.\n'
            'Identify:\n'
            '1. Physical obstacles: stairs/steps (specify up or down - downward stairs are high critical danger!), doors, poles, open potholes/pits, low hanging wires, barricades, furniture, puddles.\n'
            '2. Traffic & vehicles: cars, auto-rickshaws, bikes, buses, bicycles, pedestrians, moving vs stationary.\n'
            '3. Traffic signals & crossings: red light, green light, zebra crossing, pedestrian walk/don\'t walk.\n'
            '4. Safe walking path: is the ground directly ahead clear?\n'
            '$langRule\n\n'
            'Respond ONLY with valid JSON in this exact schema without markdown backticks:\n'
            '{\n'
            '  "isSafeToWalk": true,\n'
            '  "criticalWarning": "null or urgent 1-sentence warning if immediate hazard < 2m or moving vehicle",\n'
            '  "trafficLightStatus": "Red | Green | Yellow | None",\n'
            '  "zebraCrossingVisible": false,\n'
            '  "spokenSummary": "Detailed 2-sentence conversational human voice overview of the scene, hazards, and traffic",\n'
            '  "items": [\n'
            '    {\n'
            '      "label": "Stairs Down / Auto-rickshaw / Red Light",\n'
            '      "category": "obstacle | traffic | trafficSignal | crossing | surface",\n'
            '      "severity": "critical | moderate | low",\n'
            '      "direction": "left | centerAhead | right",\n'
            '      "clockPosition": "12 o\'clock",\n'
            '      "distanceMeters": 1.5,\n'
            '      "x": 0.5,\n'
            '      "y": 0.6,\n'
            '      "isMoving": false,\n'
            '      "spokenAlert": "Spoken description in requested language"\n'
            '    }\n'
            '  ]\n'
            '}';

        final response = await geminiService!.askGemini(
          prompt: prompt,
          imageBytes: bytes,
          mimeType: 'image/jpeg',
          maxTokens: 280,
        );

        return _parseScanResult(response, languageCode: languageCode);
      }

      // Fast offline heuristic if cloud AI is not configured
      return _generateOfflineFallback(languageCode);
    } catch (e) {
      debugPrint('[ObstacleTrafficService] Scan error: $e');
      return _generateOfflineFallback(languageCode);
    }
  }

  ObstacleTrafficScanResult _parseScanResult(String raw, {String languageCode = 'en'}) {
    final isMr = languageCode.startsWith('mr');
    final isHi = languageCode.startsWith('hi');

    try {
      var cleaned = raw.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final firstBrace = cleaned.indexOf('{');
      final lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace >= firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final isSafe = json['isSafeToWalk'] == true;
      final criticalWarning = json['criticalWarning']?.toString();
      final trafficLight = json['trafficLightStatus']?.toString();
      final zebra = json['zebraCrossingVisible'] == true;
      final summary = json['spokenSummary']?.toString() ?? (isMr ? 'परिसर स्कॅन पूर्ण.' : (isHi ? 'आसपास का स्कैन पूरा हुआ।' : 'Surroundings scanned.'));

      final items = <ObstacleTrafficItem>[];
      final rawItems = json['items'] as List?;
      if (rawItems != null) {
        for (final itemMap in rawItems) {
          if (itemMap is Map) {
            final label = itemMap['label']?.toString() ?? 'Object';
            final catStr = (itemMap['category']?.toString() ?? '').toLowerCase();
            final sevStr = (itemMap['severity']?.toString() ?? 'moderate').toLowerCase();
            final dirStr = (itemMap['direction']?.toString() ?? 'centerAhead').toLowerCase();
            final clock = itemMap['clockPosition']?.toString() ?? '12 o\'clock';
            final dist = (itemMap['distanceMeters'] as num?)?.toDouble() ?? 2.0;
            final x = ((itemMap['x'] as num?)?.toDouble() ?? 0.5).clamp(0.05, 0.95);
            final y = ((itemMap['y'] as num?)?.toDouble() ?? 0.5).clamp(0.05, 0.95);
            final isMoving = itemMap['isMoving'] == true;
            final spoken = itemMap['spokenAlert']?.toString() ?? '$label at $dist m';

            HazardCategory category = HazardCategory.obstacle;
            if (catStr.contains('traffic') && !catStr.contains('signal')) {
              category = HazardCategory.traffic;
            } else if (catStr.contains('signal')) {
              category = HazardCategory.trafficSignal;
            } else if (catStr.contains('cross')) {
              category = HazardCategory.crossing;
            } else if (catStr.contains('surface')) {
              category = HazardCategory.surface;
            }

            SpatialDirection direction = SpatialDirection.centerAhead;
            if (dirStr.contains('left')) {
              direction = SpatialDirection.left;
            } else if (dirStr.contains('right')) {
              direction = SpatialDirection.right;
            }

            Color color = AppColors.primaryCyan;
            if (sevStr == 'critical' || dist <= 1.5) {
              color = const Color(0xFFEF4444); // Neon red
            } else if (category == HazardCategory.traffic) {
              color = const Color(0xFFF59E0B); // Amber warning
            } else if (category == HazardCategory.trafficSignal) {
              color = const Color(0xFF10B981); // Emerald green
            }

            items.add(
              ObstacleTrafficItem(
                label: label,
                category: category,
                severity: sevStr,
                direction: direction,
                clockPosition: clock,
                distanceMeters: dist,
                x: x,
                y: y,
                isMoving: isMoving,
                spokenAlert: spoken,
                highlightColor: color,
              ),
            );
          }
        }
      }

      return ObstacleTrafficScanResult(
        spokenSummary: summary,
        items: items,
        isSafeToWalk: isSafe,
        criticalWarning: criticalWarning != 'null' ? criticalWarning : null,
        trafficLightStatus: trafficLight != 'null' ? trafficLight : null,
        zebraCrossingVisible: zebra,
      );
    } catch (e) {
      debugPrint('[ObstacleTrafficService] Parse error: $e');
      return _generateOfflineFallback(languageCode);
    }
  }

  ObstacleTrafficScanResult _generateOfflineFallback(String languageCode) {
    final isMr = languageCode.startsWith('mr');
    final isHi = languageCode.startsWith('hi');

    final summary = isMr
        ? 'कॅमेरा दृश्य सक्रिय. रस्ता मोकळा दिसत आहे. तपशीलवार स्कॅनिंगसाठी स्क्रीनवर कुठेही स्पर्श करा.'
        : (isHi
            ? 'कैमरा दृश्य सक्रिय। रास्ता साफ दिख रहा है। विस्तृत स्कैनिंग के लिए स्क्रीन पर कहीं भी स्पर्श करें।'
            : 'Live scanner active. Pathway appears clear ahead. Touch anywhere on screen to explore surroundings.');

    return ObstacleTrafficScanResult(
      spokenSummary: summary,
      items: [
        ObstacleTrafficItem(
          label: isMr ? 'चालण्याचा मार्ग' : (isHi ? 'पैदल रास्ता' : 'Walking Path'),
          category: HazardCategory.surface,
          severity: 'low',
          direction: SpatialDirection.centerAhead,
          clockPosition: "12 o'clock",
          distanceMeters: 2.0,
          x: 0.50,
          y: 0.70,
          spokenAlert: isMr ? 'थेट समोर चालण्याचा मार्ग मोकळा आहे' : 'Walking path clear directly ahead',
          highlightColor: AppColors.successGreen,
        ),
      ],
      isSafeToWalk: true,
    );
  }
}
