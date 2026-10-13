import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String id;
  final String title;
  final String category; // 'ocr', 'scene', 'currency', 'navigation', 'emergency'
  final String content;
  final DateTime timestamp;

  const HistoryEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class HistoryRepository {
  static const String _keyHistory = 'vm_history_entries';
  final SharedPreferences _prefs;

  HistoryRepository(this._prefs);

  List<HistoryEntry> getHistory() {
    final raw = _prefs.getStringList(_keyHistory);
    if (raw == null || raw.isEmpty) {
      return [
        HistoryEntry(
          id: '1',
          title: 'Read Text: Medical Prescription',
          category: 'ocr',
          content: 'Take 1 tablet after meals twice daily with water.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        HistoryEntry(
          id: '2',
          title: 'Navigation: Pune Central Metro Station',
          category: 'navigation',
          content: 'Arrived at Gate 2 after 350 meters.',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
    }

    try {
      return raw.map((item) => HistoryEntry.fromJson(jsonDecode(item) as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addEntry(HistoryEntry entry) async {
    final current = getHistory();
    current.insert(0, entry);
    // Keep max 50 entries to respect storage and privacy
    final trimmed = current.take(50).map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_keyHistory, trimmed);
  }

  Future<void> deleteEntry(String id) async {
    final current = getHistory().where((e) => e.id != id).map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_keyHistory, current);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_keyHistory);
  }
}
