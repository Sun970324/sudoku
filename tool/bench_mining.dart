// Throwaway: measure category-practice mining cost — for a few categories,
// mine one board and report how long it took. Grounds the "which categories
// need offline pre-mining" decision (cheap ones live-mine fine; Chains/ALS are
// the expensive tail).
//
//   flutter test tool/bench_mining.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/technique_board_miner.dart';

const _probe = [
  TechniqueCategory.singles,
  TechniqueCategory.subsets,
  TechniqueCategory.basicFish,
  TechniqueCategory.wings,
  TechniqueCategory.chainsAndLoops,
];

void main() {
  test('bench category mining', () {
    final rng = Random(1);
    // ignore: avoid_print
    print('category           result     ms');
    for (final category in _probe) {
      final sw = Stopwatch()..start();
      final board = mineCategoryBoard(category, maxSeeds: 400, random: rng);
      sw.stop();
      // ignore: avoid_print
      print('${category.name.padRight(18)} '
          '${(board == null ? "NULL" : "ok").padRight(10)} '
          '${sw.elapsedMilliseconds}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
