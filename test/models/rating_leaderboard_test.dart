import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/rating_leaderboard.dart';
import 'package:sudoku/models/tier.dart';

void main() {
  group('RatingLeaderboard.fromJson', () {
    // Shape mirrors the get_rating_leaderboard RPC payload verified against
    // the live DB (single jsonb: total + my_rank/my_rating + entries).
    test('parses a board the caller appears on', () {
      final board = RatingLeaderboard.fromJson({
        'total': 2,
        'my_rank': 1,
        'my_rating': 1231,
        'entries': [
          {
            'rank': 1,
            'profile_id': 'user-a',
            'username': 'huru',
            'rating': 1231,
            'tier': 'silver',
            'wins': 2,
            'losses': 0,
          },
          {
            'rank': 2,
            'profile_id': 'user-b',
            'username': 'master',
            'rating': 1169,
            'tier': 'silver',
            'wins': 0,
            'losses': 2,
          },
        ],
      });

      expect(board.total, 2);
      expect(board.myRank, 1);
      expect(board.myRating, 1231);
      expect(board.entries, hasLength(2));
      expect(board.entries.first.username, 'huru');
      expect(board.entries.first.tier, Tier.silver);
      expect(board.entries.last.rating, 1169);
      expect(board.entries.last.losses, 2);
    });

    test('parses null my_rank (never played) and empty entries', () {
      final board = RatingLeaderboard.fromJson({
        'total': 0,
        'my_rank': null,
        'my_rating': null,
        'entries': <dynamic>[],
      });

      expect(board.total, 0);
      expect(board.myRank, isNull);
      expect(board.myRating, isNull);
      expect(board.entries, isEmpty);
    });

    test('maps the legacy platinum tier name to diamond', () {
      final board = RatingLeaderboard.fromJson({
        'total': 1,
        'my_rank': null,
        'my_rating': null,
        'entries': [
          {
            'rank': 1,
            'profile_id': 'user-a',
            'username': 'legacy',
            'rating': 1600,
            'tier': 'platinum',
            'wins': 5,
            'losses': 3,
          },
        ],
      });

      expect(board.entries.first.tier, Tier.diamond);
    });
  });
}
