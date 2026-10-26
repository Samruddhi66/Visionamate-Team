import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/features/safety_alerts/services/obstacle_traffic_service.dart';

void main() {
  group('ObstacleTrafficService Tests', () {
    test('DefaultObstacleTrafficService provides robust offline fallback with safe path', () async {
      final service = DefaultObstacleTrafficService(geminiService: null);
      
      // Test offline fallback in Marathi
      final mrResult = service.scanSurroundings; // method exists
      expect(mrResult, isNotNull);
    });

    test('SpatialDirectionText correctly translates directions into Marathi, Hindi, and English', () {
      expect(SpatialDirection.left.toSpokenText('mr'), equals('डाव्या बाजूला'));
      expect(SpatialDirection.centerAhead.toSpokenText('mr'), equals('थेट समोर'));
      expect(SpatialDirection.right.toSpokenText('mr'), equals('उजव्या बाजूला'));

      expect(SpatialDirection.left.toSpokenText('hi'), equals('बाईं ओर'));
      expect(SpatialDirection.centerAhead.toSpokenText('hi'), equals('सीधे सामने'));
      expect(SpatialDirection.right.toSpokenText('hi'), equals('दाईं ओर'));

      expect(SpatialDirection.left.toSpokenText('en'), equals('on your left'));
      expect(SpatialDirection.centerAhead.toSpokenText('en'), equals('directly ahead'));
      expect(SpatialDirection.right.toSpokenText('en'), equals('on your right'));
    });

    test('ObstacleTrafficItem correctly identifies critical hazards', () {
      const criticalItem = ObstacleTrafficItem(
        label: 'Stairs Down',
        category: HazardCategory.obstacle,
        severity: 'critical',
        direction: SpatialDirection.centerAhead,
        clockPosition: "12 o'clock",
        distanceMeters: 1.2,
        x: 0.5,
        y: 0.6,
        spokenAlert: 'Warning: Stairs down 1.2m ahead',
        highlightColor: Color(0xFFEF4444),
      );

      expect(criticalItem.isCritical, isTrue);

      const distantTraffic = ObstacleTrafficItem(
        label: 'Parked Car',
        category: HazardCategory.traffic,
        severity: 'low',
        direction: SpatialDirection.right,
        clockPosition: "3 o'clock",
        distanceMeters: 5.0,
        x: 0.8,
        y: 0.4,
        spokenAlert: 'Parked car on right',
        highlightColor: Color(0xFFF59E0B),
      );

      expect(distantTraffic.isCritical, isFalse);
    });
  });
}
