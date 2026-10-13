import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class UserLocation {
  final double latitude;
  final double longitude;
  final double accuracy; // meters
  final double? heading;  // degrees
  final double? speed;    // m/s

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.heading,
    this.speed,
  });

  bool get isAccuracyReliable => accuracy <= 20.0; // Within 20 meters is reliable for pedestrian navigation
}

abstract class LocationService {
  Future<bool> checkPermission();
  Future<UserLocation?> getCurrentLocation();
  Stream<UserLocation> getLocationStream();
}

class DeviceLocationService implements LocationService {
  @override
  Future<bool> checkPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] GPS is turned off on device.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[LocationService] Permission check error: $e');
      return false;
    }
  }

  @override
  Future<UserLocation?> getCurrentLocation() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        heading: position.heading,
        speed: position.speed,
      );
    } catch (e) {
      debugPrint('[LocationService] getCurrentLocation error: $e');
      return null;
    }
  }

  @override
  Stream<UserLocation> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Update every 3 meters for pedestrian navigation
      ),
    ).map((pos) => UserLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          heading: pos.heading,
          speed: pos.speed,
        ));
  }
}

/// Mock Location Service for unit tests
class MockLocationService implements LocationService {
  UserLocation? mockLocation;

  MockLocationService({
    this.mockLocation = const UserLocation(
      latitude: 18.5204, // Pune coordinates
      longitude: 73.8567,
      accuracy: 5.0,
      heading: 90.0,
      speed: 1.2,
    ),
  });

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<UserLocation?> getCurrentLocation() async => mockLocation;

  @override
  Stream<UserLocation> getLocationStream() {
    if (mockLocation == null) return const Stream.empty();
    return Stream.value(mockLocation!);
  }
}
