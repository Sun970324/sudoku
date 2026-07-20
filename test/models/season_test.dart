import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/season.dart';
import 'package:sudoku/models/tier.dart';

void main() {
  group('Season.fromJson', () {
    // Shape mirrors a row from the public `seasons` table.
    test('parses id, timestamps, and status', () {
      final season = Season.fromJson({
        'id': 1,
        'started_at': '2026-07-20T12:00:00+00:00',
        'ends_at': '2026-08-01T00:00:00+09:00',
        'status': 'active',
      });

      expect(season.id, 1);
      expect(season.status, 'active');
      expect(season.startedAt, DateTime.parse('2026-07-20T12:00:00+00:00'));
      expect(season.endsAt, DateTime.parse('2026-08-01T00:00:00+09:00'));
    });
  });

  group('Season.daysRemaining', () {
    Season seasonEndingIn(Duration untilEnd) => Season(
          id: 1,
          startedAt: DateTime.now(),
          endsAt: DateTime.now().add(untilEnd),
          status: 'active',
        );

    test('rounds up whole days until the end', () {
      expect(seasonEndingIn(const Duration(days: 5)).daysRemaining, 5);
    });

    test('rounds a partial final day up to 1', () {
      expect(seasonEndingIn(const Duration(hours: 2)).daysRemaining, 1);
    });

    test('is 0 once the season has ended', () {
      expect(seasonEndingIn(const Duration(hours: -1)).daysRemaining, 0);
    });
  });

  group('SeasonStanding.fromJson', () {
    // Shape mirrors a row from the `season_standings` table, written by the
    // end_season_if_due rollover.
    test('parses a season_standings row', () {
      final standing = SeasonStanding.fromJson({
        'season_id': 1,
        'profile_id': '5b0e806e-0000-0000-0000-000000000000',
        'final_rating': 1550,
        'final_tier': 'diamond',
        'final_rank': 3,
        'wins': 5,
        'losses': 1,
      });

      expect(standing.seasonId, 1);
      expect(standing.finalRating, 1550);
      expect(standing.finalTier, Tier.diamond);
      expect(standing.finalRank, 3);
      expect(standing.wins, 5);
      expect(standing.losses, 1);
    });
  });
}
