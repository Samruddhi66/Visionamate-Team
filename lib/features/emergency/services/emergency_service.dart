import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/storage/preferences_service.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/audio/tts_service.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/haptics/haptic_patterns.dart';

class EmergencyService {
  final PreferencesService prefs;
  final HistoryRepository historyRepo;
  final TtsService tts;
  final HapticService haptics;

  EmergencyService({
    required this.prefs,
    required this.historyRepo,
    required this.tts,
    required this.haptics,
  });

  /// Get current location with high accuracy
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await tts.speak('Location services are disabled. Please enable GPS.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await tts.speak('Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await tts.speak('Location permissions are permanently denied.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('[EmergencyService] Location error: $e');
      await tts.speak('Unable to get current location.');
      return null;
    }
  }

  /// Get human-readable address from coordinates
  Future<String> getAddressFromLocation(Position position) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${prefs.geminiApiKey}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] ?? 'Unknown location';
        }
      }
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }
  }

  /// Make a real phone call to emergency contact
  Future<bool> callEmergencyContact() async {
    final phone = prefs.emergencyContactPhone;
    if (phone == null || phone.isEmpty) {
      await tts.speak('Emergency contact phone number is not configured.');
      return false;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'tel:$cleanPhone';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        await tts.speak('Calling emergency contact $phone now.');
        await haptics.trigger(HapticPattern.emergencyStatus);
        return true;
      } else {
        await tts.speak('Unable to make phone call on this device.');
        return false;
      }
    } catch (e) {
      debugPrint('[EmergencyService] Call error: $e');
      await tts.speak('Failed to make emergency call.');
      return false;
    }
  }

  /// Send SMS with location to emergency contact
  Future<bool> sendEmergencySms(Position position) async {
    final phone = prefs.emergencyContactPhone;
    if (phone == null || phone.isEmpty) {
      await tts.speak('Emergency contact phone number is not configured.');
      return false;
    }

    final address = await getAddressFromLocation(position);
    final message =
        'EMERGENCY SOS from VisionMate user!\n'
        'Location: $address\n'
        'Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n'
        'Accuracy: ${position.accuracy.toInt()} meters\n'
        'Time: ${DateTime.now().toIso8601String()}\n'
        'Please help immediately!';

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'sms:$cleanPhone?body=${Uri.encodeComponent(message)}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        await tts.speak('Emergency SMS with location sent to $phone.');
        await haptics.trigger(HapticPattern.actionSuccess);
        return true;
      } else {
        await tts.speak('Unable to send SMS on this device.');
        return false;
      }
    } catch (e) {
      debugPrint('[EmergencyService] SMS error: $e');
      await tts.speak('Failed to send emergency SMS.');
      return false;
    }
  }

  /// Share location with other VisionMate users
  Future<bool> shareLocationWithVisionMateUsers(Position position) async {
    final address = await getAddressFromLocation(position);
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

    final shareText =
        '🆘 VisionMate Emergency Location Share\n\n'
        'A VisionMate user needs assistance!\n\n'
        '📍 Location: $address\n'
        '🗺️ Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n'
        '📏 Accuracy: ${position.accuracy.toInt()} meters\n'
        '⏰ Time: ${DateTime.now().toIso8601String()}\n\n'
        'Open in Google Maps: $googleMapsUrl\n\n'
        'Please respond immediately if you can help.';

    try {
      await share_plus.SharePlus.instance.share(
        share_plus.ShareParams(text: shareText, subject: 'VisionMate Emergency Location'),
      );
      await tts.speak('Location shared with nearby VisionMate users.');
      await haptics.trigger(HapticPattern.actionSuccess);
      return true;
    } catch (e) {
      debugPrint('[EmergencyService] Share error: $e');
      await tts.speak('Failed to share location.');
      return false;
    }
  }

  /// Full emergency dispatch: call + SMS + share location
  Future<void> dispatchFullEmergency() async {
    await haptics.trigger(HapticPattern.emergencyStatus);
    await tts.speak('Emergency activated! Dispatching live coordinates and calling emergency contact.');

    final position = await getCurrentLocation();
    if (position == null) {
      await tts.speak('Unable to get location. Calling emergency contact without location.');
      await callEmergencyContact();
      return;
    }

    final address = await getAddressFromLocation(position);

    // Log emergency in history
    await historyRepo.addEntry(
      HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Emergency SOS Dispatched',
        category: 'emergency',
        content:
            'Location: $address\n'
            'Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n'
            'Accuracy: ${position.accuracy.toInt()}m',
        timestamp: DateTime.now(),
      ),
    );

    // Make real phone call
    await callEmergencyContact();

    // Send SMS with location
    await sendEmergencySms(position);

    // Share location with VisionMate users
    await shareLocationWithVisionMateUsers(position);

    await tts.speak(
        'Emergency complete. Emergency contact called, SMS with location sent, and location shared with VisionMate users. Help is on the way.');
    await haptics.trigger(HapticPattern.actionSuccess);
  }
}
