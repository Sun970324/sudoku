import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/generation/bitset/candidates.dart';
import 'package:sudoku/services/generation/bitset/conversions.dart';

/// A random 9x9 board with digits 0..9 (0 = empty). Not necessarily a legal
/// Sudoku — the conversions are pure data reshaping, so arbitrary contents
/// exercise them just as well.
List<List<int>> _randomBoard(Random rng) => List.generate(
      9,
      (_) => List.generate(9, (_) => rng.nextInt(10)),
    );

/// A random 9x9 grid of candidate sets (each cell an arbitrary subset of 1..9).
List<List<Set<int>>> _randomCandidates(Random rng) => List.generate(
      9,
      (_) => List.generate(9, (_) {
        final set = <int>{};
        for (var d = 1; d <= 9; d++) {
          if (rng.nextBool()) set.add(d);
        }
        return set;
      }),
    );

void main() {
  group('candidate mask helpers', () {
    test('add/has/remove/count/digits round-trip', () {
      var mask = 0;
      expect(candCount(mask), 0);
      for (final d in [1, 5, 9]) {
        mask = candAdd(mask, d);
      }
      expect(candCount(mask), 3);
      expect(candDigits(mask), [1, 5, 9]);
      expect(candHas(mask, 5), isTrue);
      expect(candHas(mask, 4), isFalse);

      mask = candRemove(mask, 5);
      expect(candDigits(mask), [1, 9]);

      expect(candDigits(candFull), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(candCount(candFull), 9);
    });
  });

  group('board <-> digit positions', () {
    test('round-trips exactly on many random boards', () {
      final rng = Random(20260724);
      for (var i = 0; i < 200; i++) {
        final board = _randomBoard(rng);
        final restored =
            digitPositionsToBoard(boardToDigitPositions(board));
        expect(restored, board, reason: 'iteration $i');
      }
    });

    test('positions list has entry per digit, entry 0 empty', () {
      final board = List.generate(9, (r) => List.generate(9, (c) => 0));
      board[0][0] = 7;
      board[8][8] = 7;
      board[4][4] = 3;
      final positions = boardToDigitPositions(board);
      expect(positions.length, 10);
      expect(positions[0].isEmpty, isTrue);
      expect(positions[7].toList(), [0, 80]);
      expect(positions[3].toList(), [40]);
    });
  });

  group('candidates <-> masks', () {
    test('round-trips exactly on many random candidate grids', () {
      final rng = Random(97531);
      for (var i = 0; i < 200; i++) {
        final candidates = _randomCandidates(rng);
        final restored = masksToCandidates(candidatesToMasks(candidates));
        expect(restored, candidates, reason: 'iteration $i');
      }
    });
  });
}
