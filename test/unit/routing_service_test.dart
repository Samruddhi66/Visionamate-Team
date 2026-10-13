import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/features/navigation/services/location_service.dart';
import 'package:visionmate/features/navigation/services/routing_service.dart';

void main() {
  group('Pedestrian RoutingService Tests', () {
    test('Calculates walking route with turn directions and arrival step', () async {
      final routingService = OsrmRoutingService();
      const origin = UserLocation(
        latitude: 18.5204,
        longitude: 73.8567,
        accuracy: 4.5,
      );

      final route = await routingService.calculateRoute(
        origin: origin,
        destinationQuery: 'Central Metro Station',
      );

      expect(route, isNotNull);
      expect(route!.destinationName, equals('Central Metro Station'));
      expect(route.steps, isNotEmpty);
      expect(route.steps.last.turnDirection, equals(TurnDirection.destinationArrival));
      expect(route.steps.any((s) => s.turnDirection == TurnDirection.left), isTrue);
      expect(route.totalDistanceMeters, greaterThan(0));
    });
  });
}
