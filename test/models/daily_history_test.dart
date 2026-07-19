import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/daily.dart';

void main() {
  group('DailyHistoryEntry.fromJson', () {
    test('parses a get_my_daily_history row', () {
      final entry = DailyHistoryEntry.fromJson({
        'puzzle_date': '2026-07-14',
        'elapsed_seconds': 512,
        'mistakes': 1,
      });

      expect(entry.date, DateTime(2026, 7, 14));
      expect(entry.elapsedSeconds, 512);
      expect(entry.mistakes, 1);
    });
  });
}
