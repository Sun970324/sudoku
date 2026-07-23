// Throwaway: measure technique-mining cost — for a few practice items, probe a
// fixed number of solved boards (each dug to several depths, like
// mineTechniqueBoard) and report how often the item's technique shows up and
// how long it takes. Grounds the "generate hard-technique boards faster" work.
//
//   flutter test tool/bench_mining.dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/minimalizer.dart';
import 'package:sudoku/services/generation/technique_board_miner.dart';

const _probeItems = ['hiddenSingle', 'xWing', 'fish', 'uniqueRectangle', 'aic'];
const _boards = 40; // solved boards probed per item

void main() {
  test('bench mining hit-rate', () {
    final rng = Random(1);
    // ignore: avoid_print
    print('item              boards  hits  hit%   ms/board   solvesPerBoard');
    for (final id in _probeItems) {
      final item = practiceItems.firstWhere((it) => it.id == id);
      final tier = Difficulty.values[item.techniques
          .map((t) => techniqueDifficulty[t]!.index)
          .reduce(max)];
      final targets = digTargetsFor(tier);
      var hits = 0, solves = 0;
      final sw = Stopwatch()..start();
      for (var b = 0; b < _boards; b++) {
        final solution = BoardGenerator(random: rng).generateSolvedBoard();
        var found = false;
        for (final target in targets) {
          final dug = ClueRemover(random: rng).removeClues(solution, target);
          solves++;
          if (boardShowsItem(item.techniques, dug)) {
            found = true;
            break;
          }
        }
        if (!found) {
          final minimal = Minimalizer(random: rng)
              .minimalize(ClueRemover(random: rng).removeClues(solution, 24));
          solves++;
          if (boardShowsItem(item.techniques, minimal)) found = true;
        }
        if (found) hits++;
      }
      sw.stop();
      final pct = (100 * hits / _boards).toStringAsFixed(0);
      final msPer = (sw.elapsedMilliseconds / _boards).toStringAsFixed(0);
      final spb = (solves / _boards).toStringAsFixed(1);
      // ignore: avoid_print
      print('${id.padRight(17)} ${_boards.toString().padLeft(5)} '
          '${hits.toString().padLeft(5)} ${pct.padLeft(4)}% '
          '${msPer.padLeft(9)} ${spb.padLeft(15)}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
