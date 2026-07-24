// One-off calibration harness for the cumulative-score difficulty bands in
// lib/models/hint.dart (difficultyScoreBands / scoreBand). NOT part of the
// app and not run by a plain `flutter test`. Run manually:
//
//   flutter test tool/calibrate_difficulty.dart
//
// It digs many solved boards down to a spread of given counts, solves each
// with HumanSolver, and reports — grouped by the puzzle's *floor* tier
// (hardest technique used, before any score promotion) — the distribution of
// cumulative scores. Set difficultyScoreBands so each tier's median score
// lands in that tier's band, and only unusually score-heavy puzzles promote.
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/difficulty_evaluator.dart';
import 'package:sudoku/services/generation/human_solver.dart';

const _boards = 60;
const _digTargets = [42, 36, 32, 29, 26, 24];

void main() {
  test('calibrate difficulty score bands', () {
    final boardGen = BoardGenerator();
    final clueRemover = ClueRemover();
    final evaluator = DifficultyEvaluator();
    final humanSolver = HumanSolver();

    final scoresByFloor = <Difficulty, List<int>>{
      for (final d in Difficulty.values) d: <int>[],
    };
    var solvedCount = 0;
    var unsolvedCount = 0;

    for (var b = 0; b < _boards; b++) {
      final solved = boardGen.generateSolvedBoard();
      for (final target in _digTargets) {
        final dug = clueRemover.removeClues(solved, target);
        final res = evaluator.evaluate(humanSolver.solve(dug));
        if (!res.solved) {
          unsolvedCount++;
          continue;
        }
        solvedCount++;
        scoresByFloor[res.floorDifficulty]!.add(res.score);
      }
      // ignore: avoid_print
      if ((b + 1) % 10 == 0) print('...${b + 1}/$_boards boards');
    }

    // ignore: avoid_print
    print('\nfully-solvable samples: $solvedCount  '
        '(unsolvable, skipped: $unsolvedCount)\n');
    // ignore: avoid_print
    print('floor tier      n   min   p10   p25   med   p75   p90   max');
    for (final d in Difficulty.values) {
      final s = scoresByFloor[d]!..sort();
      if (s.isEmpty) {
        // ignore: avoid_print
        print('${d.name.padRight(12)}    0     —');
        continue;
      }
      int q(double f) => s[(f * (s.length - 1)).round()];
      // ignore: avoid_print
      print('${d.name.padRight(12)} ${s.length.toString().padLeft(4)} '
          '${q(0).toString().padLeft(5)} ${q(0.10).toString().padLeft(5)} '
          '${q(0.25).toString().padLeft(5)} ${q(0.50).toString().padLeft(5)} '
          '${q(0.75).toString().padLeft(5)} ${q(0.90).toString().padLeft(5)} '
          '${q(1).toString().padLeft(5)}');
    }
    // ignore: avoid_print
    print('\ncurrent bands: $difficultyScoreBands');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
