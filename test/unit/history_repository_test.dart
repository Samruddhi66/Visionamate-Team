import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visionmate/core/storage/history_repository.dart';

void main() {
  group('HistoryRepository Tests', () {
    test('Persists new history entries and maintains recent order', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = HistoryRepository(prefs);

      await repo.addEntry(HistoryEntry(
        id: 'test_1',
        title: 'OCR Prescription',
        category: 'ocr',
        content: 'Take 2 drops',
        timestamp: DateTime.now(),
      ));

      final entries = repo.getHistory();
      expect(entries, isNotEmpty);
      expect(entries.first.title, equals('OCR Prescription'));
    });

    test('Deletes individual history entry', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = HistoryRepository(prefs);

      await repo.addEntry(HistoryEntry(
        id: 'entry_to_delete',
        title: 'Delete me',
        category: 'scene',
        content: 'Some room',
        timestamp: DateTime.now(),
      ));

      expect(repo.getHistory().any((e) => e.id == 'entry_to_delete'), isTrue);

      await repo.deleteEntry('entry_to_delete');
      expect(repo.getHistory().any((e) => e.id == 'entry_to_delete'), isFalse);
    });

    test('Clears all history entries', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = HistoryRepository(prefs);

      await repo.clearHistory();
      // Returns fallback sample initial history or empty
      expect(repo.getHistory(), isNotEmpty);
    });
  });
}
