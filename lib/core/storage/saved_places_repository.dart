import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedPlace {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

class SavedPlacesRepository {
  static const String _keySavedPlaces = 'vm_saved_places';
  final SharedPreferences _prefs;

  SavedPlacesRepository(this._prefs);

  List<SavedPlace> getSavedPlaces() {
    final raw = _prefs.getStringList(_keySavedPlaces);
    if (raw == null || raw.isEmpty) {
      return const [
        SavedPlace(
          id: 'home',
          name: 'Home',
          address: 'Flat 402, Shivajinagar, Pune',
          latitude: 18.5314,
          longitude: 73.8446,
        ),
        SavedPlace(
          id: 'college',
          name: 'COEP Tech University',
          address: 'Wellesley Rd, Shivajinagar, Pune',
          latitude: 18.5293,
          longitude: 73.8565,
        ),
        SavedPlace(
          id: 'pharmacy',
          name: 'Central City Pharmacy',
          address: 'FC Road, Deccan Gymkhana, Pune',
          latitude: 18.5186,
          longitude: 73.8415,
        ),
      ];
    }

    try {
      return raw.map((item) => SavedPlace.fromJson(jsonDecode(item) as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addPlace(SavedPlace place) async {
    final current = getSavedPlaces().toList();
    current.add(place);
    final encoded = current.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keySavedPlaces, encoded);
  }

  Future<void> removePlace(String id) async {
    final current = getSavedPlaces().where((p) => p.id != id).map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keySavedPlaces, current);
  }
}
