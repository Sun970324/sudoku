import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/daily.dart';
import 'package:sudoku/models/difficulty.dart';

void main() {
  group('DailyPuzzle.fromJson', () {
    test('remaps snake_case fixed_mask and parses the date', () {
      final givens = List.generate(9, (r) => List.generate(9, (c) => 0));
      givens[0][0] = 5;
      final solution = List.generate(9, (r) => List.generate(9, (c) => 1));
      final fixedMask = List.generate(
          9, (r) => List.generate(9, (c) => r == 0 && c == 0));

      final daily = DailyPuzzle.fromJson({
        'puzzle_date': '2026-07-15',
        'puzzle': givens,
        'solution': solution,
        'fixed_mask': fixedMask,
        'difficulty': 'medium',
        'created_by': 'user-a',
        'created_at': '2026-07-15T00:01:00+00:00',
      });

      expect(daily.puzzleDate, DateTime.parse('2026-07-15'));
      expect(daily.puzzle.difficulty, Difficulty.medium);
      expect(daily.puzzle.puzzle.get(0, 0), 5);
      expect(daily.puzzle.solution.get(4, 4), 1);
      expect(daily.puzzle.isFixed(0, 0), isTrue);
      expect(daily.puzzle.isFixed(1, 1), isFalse);
    });
  });

  group('DailyLeaderboard.fromJson', () {
    test('parses a board the caller appears on', () {
      final board = DailyLeaderboard.fromJson({
        'total': 42,
        'my_rank': 7,
        'my_elapsed_seconds': 312,
        'entries': [
          {
            'rank': 1,
            'profile_id': 'user-a',
            'username': 'Player1',
            'elapsed_seconds': 100,
          },
          {
            'rank': 2,
            'profile_id': 'user-b',
            'username': 'Player2',
            'elapsed_seconds': 150,
          },
        ],
      });

      expect(board.total, 42);
      expect(board.myRank, 7);
      expect(board.myElapsedSeconds, 312);
      expect(board.completedToday, isTrue);
      expect(board.entries, hasLength(2));
      expect(board.entries.first.username, 'Player1');
      expect(board.entries.last.elapsedSeconds, 150);
    });

    test('parses null my_rank (not completed) and empty entries', () {
      final board = DailyLeaderboard.fromJson({
        'total': 0,
        'my_rank': null,
        'my_elapsed_seconds': null,
        'entries': <dynamic>[],
      });

      expect(board.total, 0);
      expect(board.myRank, isNull);
      expect(board.myElapsedSeconds, isNull);
      expect(board.completedToday, isFalse);
      expect(board.entries, isEmpty);
    });
  });
}
