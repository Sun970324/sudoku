import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/bitset/bitset_solver.dart';
import 'package:sudoku/services/generation/difficulty_evaluator.dart';
import 'package:sudoku/services/generation/human_solver.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';
import 'package:sudoku/services/generation/technique_board_miner.dart';
import 'package:sudoku/services/sudoku_solver.dart';

bool _isCompleteAndValid(List<List<int>> cells) {
  bool groupIsValid(Iterable<int> values) {
    final sorted = values.toList()..sort();
    return sorted.join(',') == List.generate(9, (i) => i + 1).join(',');
  }

  for (var r = 0; r < 9; r++) {
    if (!groupIsValid(cells[r])) return false;
  }
  for (var c = 0; c < 9; c++) {
    if (!groupIsValid([for (var r = 0; r < 9; r++) cells[r][c]])) {
      return false;
    }
  }
  for (var boxRow = 0; boxRow < 3; boxRow++) {
    for (var boxCol = 0; boxCol < 3; boxCol++) {
      final box = [
        for (var r = boxRow * 3; r < boxRow * 3 + 3; r++)
          for (var c = boxCol * 3; c < boxCol * 3 + 3; c++) cells[r][c],
      ];
      if (!groupIsValid(box)) return false;
    }
  }
  return true;
}

void main() {
  final solver = SudokuSolver();
  // BitsetSolver is the difficulty authority (what generation scored with);
  // the hint-arsenal HumanSolver below guards the separate playability
  // invariant (the in-game hint engine must never dead-end on an accepted
  // puzzle — its technique set is a superset of the generation order).
  final bitsetSolver = BitsetSolver();
  final hintArsenalSolver = HumanSolver(techniqueOrder: minableOrder);
  final evaluator = DifficultyEvaluator();
  final generator = SudokuGenerator(random: Random(42));

  // beginner/easy (Bronze/Silver) are generated purely by given count (no
  // technique ceiling/exact-match check at all — see SudokuGenerator's class
  // doc), so they get a relaxed assertion set below instead of the full
  // technique-gated ones that apply to Gold and up (medium/hard/master/
  // expert).
  const givenCountBasedTiers = {
    Difficulty.beginner,
    Difficulty.easy,
  };

  for (final difficulty in Difficulty.values) {
    group('generate(${difficulty.name})', () {
      // Generated once per tier (at group-registration time, not per test)
      // — the HoDoKu-style loop retries whole boards until one is accepted,
      // so regenerating per test would multiply that cost across every
      // assertion below for no benefit.
      final puzzle = generator.generate(difficulty);
      final isGivenCountBased = givenCountBasedTiers.contains(difficulty);

      test('produces a fully valid solution grid', () {
        expect(_isCompleteAndValid(puzzle.solution.cells), isTrue);
      });

      test('produces a puzzle with exactly one solution', () {
        expect(solver.countSolutions(puzzle.puzzle.cells, limit: 2), 1);
      });

      test('fixedMask marks exactly the given (non-zero) cells', () {
        for (var r = 0; r < 9; r++) {
          for (var c = 0; c < 9; c++) {
            expect(puzzle.isFixed(r, c), puzzle.puzzle.get(r, c) != 0);
          }
        }
      });

      if (isGivenCountBased) {
        test('has a 180°-rotationally symmetric givens pattern (these tiers '
            'are dug in symmetric pairs)', () {
          for (var r = 0; r < 9; r++) {
            for (var c = 0; c < 9; c++) {
              expect(puzzle.puzzle.get(r, c) != 0,
                  puzzle.puzzle.get(8 - r, 8 - c) != 0,
                  reason: 'cell ($r, $c) and its rotational partner '
                      '(${8 - r}, ${8 - c}) must both be given or both empty');
            }
          }
        });

        test('given-cell count lands at or near the tier target — symmetric '
            'pair removal can stop a cell or two short of it', () {
          final givenCount = puzzle.puzzle.cells
              .expand((row) => row)
              .where((value) => value != 0)
              .length;
          expect(givenCount.toDouble(),
              closeTo(difficulty.givenCount.toDouble(), 2));
        });

        test('is solvable via human techniques alone (no guessing) at this '
            'generous a given count', () {
          final result = bitsetSolver.solve(puzzle.puzzle.cells);
          expect(result.solved, isTrue,
              reason: '$difficulty puzzles must fully solve via human '
                  'techniques alone (no guessing/backtracking)');
        });
      } else {
        test('given-cell count stays within the mathematical floor and the '
            'full board — not a target-difficulty band', () {
          // Per generator.md's "Hint Count 정책," given count is only a
          // generation-speed hint, never a difficulty signal. These tiers
          // dig blind (uniqueness-only, HoDoKu-style), so the count lands
          // wherever uniqueness pruning stops it. 17 is the proven
          // mathematical floor for any uniquely-solvable 9x9 Sudoku.
          final givenCount = puzzle.puzzle.cells
              .expand((row) => row)
              .where((value) => value != 0)
              .length;
          expect(givenCount, greaterThanOrEqualTo(17));
          expect(givenCount, lessThanOrEqualTo(81));
        });

        if (difficulty == Difficulty.expert) {
          test('expert is held to a sparser givens cap (require.md #5) — '
              'at most 23, via the acceptance condition in '
              '_generateByTechnique', () {
            final givenCount = puzzle.puzzle.cells
                .expand((row) => row)
                .where((value) => value != 0)
                .length;
            expect(givenCount, lessThanOrEqualTo(23));
          });
        }

        test('the returned puzzle is minimal — no remaining given can be '
            'removed without breaking uniqueness (the blind HoDoKu-style '
            'dig tries every cell once, gated by uniqueness alone)', () {
          for (var r = 0; r < 9; r++) {
            for (var c = 0; c < 9; c++) {
              if (puzzle.puzzle.get(r, c) == 0) continue;
              final withoutClue = puzzle.puzzle.cells
                  .map((row) => List<int>.from(row))
                  .toList();
              withoutClue[r][c] = 0;

              expect(solver.countSolutions(withoutClue, limit: 2),
                  greaterThan(1),
                  reason: 'removing cell ($r, $c) must break uniqueness');
            }
          }
        });

        test('the difficulty authority (BitsetSolver) re-scores the puzzle '
            'to exactly the target tier AND score band (HoDoKu acceptance '
            'incl. rejectTooLowScore)', () {
          final result = bitsetSolver.solve(puzzle.puzzle.cells);
          final evaluated = evaluator.evaluate(result.toSolveResult());
          expect(result.solved, isTrue,
              reason: '$difficulty puzzles must fully solve via human '
                  'techniques alone (no guessing/backtracking)');
          expect(evaluated.highestDifficulty, difficulty,
              reason: 'the hardest technique used must belong to exactly '
                  'the $difficulty tier — solve history: ${result.history}');
          expect(scoreBand(evaluated.score), difficulty,
              reason: 'the cumulative score alone must land in the '
                  '$difficulty band (rejectTooLowScore) — '
                  'score: ${evaluated.score}');
        });

        test('the in-game hint engine (full arsenal) can also finish the '
            'puzzle — an accepted board must never dead-end the player\'s '
            'hint button', () {
          expect(hintArsenalSolver.solve(puzzle.puzzle.cells).solved, isTrue);
        });
      }
    });
  }
}
