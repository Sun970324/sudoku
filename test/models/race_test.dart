import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/race.dart';

void main() {
  group('Race.fromJson', () {
    test('parses a pending_puzzle row with no puzzle yet', () {
      final race = Race.fromJson({
        'id': 'race-1',
        'player_a': 'user-a',
        'player_b': 'user-b',
        'puzzle_provider': 'user-a',
        'difficulty': 'medium',
        'status': 'pending_puzzle',
        'puzzle': null,
        'solution': null,
        'fixed_mask': null,
        'winner_id': null,
      });

      expect(race.status, RaceStatus.pendingPuzzle);
      expect(race.difficulty, Difficulty.medium);
      expect(race.puzzle, isNull);
      expect(race.winnerId, isNull);
    });

    test('parses a ready row into a full SudokuPuzzle', () {
      final givens = List.generate(9, (r) => List.generate(9, (c) => 0));
      givens[0][0] = 5;
      final solution = List.generate(9, (r) => List.generate(9, (c) => 1));

      final race = Race.fromJson({
        'id': 'race-1',
        'player_a': 'user-a',
        'player_b': 'user-b',
        'puzzle_provider': 'user-a',
        'difficulty': 'hard',
        'status': 'ready',
        'puzzle': givens,
        'solution': solution,
        'fixed_mask': List.generate(
            9, (r) => List.generate(9, (c) => r == 0 && c == 0)),
        'winner_id': null,
      });

      expect(race.status, RaceStatus.ready);
      expect(race.puzzle, isNotNull);
      expect(race.puzzle!.puzzle.get(0, 0), 5);
      expect(race.puzzle!.solution.get(3, 3), 1);
      expect(race.puzzle!.isFixed(0, 0), isTrue);
      expect(race.puzzle!.isFixed(1, 1), isFalse);
    });

    test('parses a finished row with a winner', () {
      final race = Race.fromJson({
        'id': 'race-1',
        'player_a': 'user-a',
        'player_b': 'user-b',
        'puzzle_provider': 'user-a',
        'difficulty': 'easy',
        'status': 'finished',
        'puzzle': null,
        'solution': null,
        'fixed_mask': null,
        'winner_id': 'user-b',
      });

      expect(race.status, RaceStatus.finished);
      expect(race.winnerId, 'user-b');
    });
  });

  group('Race helpers', () {
    const race = Race(
      id: 'race-1',
      playerA: 'user-a',
      playerB: 'user-b',
      puzzleProvider: 'user-a',
      difficulty: Difficulty.medium,
      status: RaceStatus.pendingPuzzle,
    );

    test('opponentOf returns the other player', () {
      expect(race.opponentOf('user-a'), 'user-b');
      expect(race.opponentOf('user-b'), 'user-a');
    });

    test('isPuzzleProvider is true only for the provider', () {
      expect(race.isPuzzleProvider('user-a'), isTrue);
      expect(race.isPuzzleProvider('user-b'), isFalse);
    });
  });
}
