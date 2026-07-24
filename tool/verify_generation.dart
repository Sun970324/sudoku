// One-off end-to-end generation health check for the score-derived
// difficulty tiers. NOT part of the app / not run by plain `flutter test`.
//
//   flutter test tool/verify_generation.dart
//
// Generates several puzzles per tier through the real SudokuGenerator and
// reports the evaluated combined tier, score and given count of each —
// confirming every tier still generates (no StateError) and lands where
// expected after a tier-mapping change.
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/services/generation/bitset/bitset_solver.dart';
import 'package:sudoku/services/generation/difficulty_evaluator.dart';
import 'package:sudoku/services/generation/human_solver.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';

const _perTier = 12;

/// A puzzle's givens are 180°-rotationally symmetric when a cell is given iff
/// its point-reflection through the centre is too.
bool _isSymmetric(List<List<int>> cells) {
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      if ((cells[r][c] != 0) != (cells[8 - r][8 - c] != 0)) return false;
    }
  }
  return true;
}

void main() {
  test('generation health per tier', () {
    final generator = SudokuGenerator();
    final evaluator = DifficultyEvaluator();
    // BitsetSolver is the difficulty authority (the same solver generation
    // scored with) — its re-evaluation must match the label exactly.
    // HumanSolver agreement is reported as an informational column only:
    // the two solvers take different step paths, so borderline boards can
    // land a band apart without anything being wrong.
    final bitsetSolver = BitsetSolver();
    final humanSolver = HumanSolver();

    for (final tier in Difficulty.values) {
      final scores = <int>[];
      final givensList = <int>[];
      var mismatches = 0;
      var humanAgrees = 0;
      var symmetricCount = 0;
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < _perTier; i++) {
        final puzzle = generator.generate(tier);
        final cells = puzzle.puzzle.toJson();
        givensList.add(
            cells.fold<int>(0, (s, r) => s + r.where((v) => v != 0).length));
        if (_isSymmetric(cells)) symmetricCount++;
        final res =
            evaluator.evaluate(bitsetSolver.solve(cells).toSolveResult());
        scores.add(res.score);
        if (res.highestDifficulty != tier) mismatches++;
        if (evaluator
                .evaluate(humanSolver.solve(cells))
                .highestDifficulty ==
            tier) {
          humanAgrees++;
        }
      }
      stopwatch.stop();
      scores.sort();
      givensList.sort();
      final ms = (stopwatch.elapsedMilliseconds / _perTier).round();
      // ignore: avoid_print
      print('${tier.name.padRight(9)}  '
          'score[min ${scores.first}, med ${scores[scores.length ~/ 2]}, '
          'max ${scores.last}]  '
          'givens[${givensList.first}-${givensList.last}]  '
          'authority!=target: $mismatches/$_perTier  '
          'humanAgree: $humanAgrees/$_perTier  '
          'symmetric: $symmetricCount/$_perTier  ~${ms}ms/puzzle');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
