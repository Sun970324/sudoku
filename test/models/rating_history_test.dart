import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/rating_history.dart';

void main() {
  group('RatingHistoryPoint.fromJson', () {
    // Shape mirrors the get_my_rating_history RPC payload verified against
    // the live DB: [{finished_at, rating, delta}] oldest-first.
    test('parses fields and derives ratingBefore from rating - delta', () {
      final point = RatingHistoryPoint.fromJson({
        'finished_at': '2026-07-14T09:06:17.371169+00:00',
        'rating': 1216,
        'delta': 16,
      });

      expect(point.rating, 1216);
      expect(point.delta, 16);
      expect(point.ratingBefore, 1200);
      expect(point.finishedAt,
          DateTime.parse('2026-07-14T09:06:17.371169+00:00'));
    });

    test('ratingBefore handles a rating loss (negative delta)', () {
      final point = RatingHistoryPoint.fromJson({
        'finished_at': '2026-07-14T11:16:40+00:00',
        'rating': 1184,
        'delta': -16,
      });

      expect(point.ratingBefore, 1200);
    });
  });
}
