import 'dart:math';

import '../sudoku_solver.dart';

/// Strips clues from a fully-solved board down toward a target given-count,
/// keeping only removals that leave the puzzle with a unique solution — the
/// "ClueRemover" module.
class ClueRemover {
  ClueRemover({Random? random, SudokuSolver? solver})
      : _random = random ?? Random(),
        _solver = solver ?? SudokuSolver();

  final Random _random;
  final SudokuSolver _solver;

  /// Returns a copy of [solvedBoard] with cells cleared to 0, removed in
  /// random order, stopping once [targetGivenCount] is reached or no more
  /// cells can be removed without breaking uniqueness (whichever comes
  /// first) — the result may have more than [targetGivenCount] givens if
  /// uniqueness can't be preserved all the way down.
  ///
  /// When [symmetric] is true, cells are cleared in 180°-rotational pairs
  /// (a cell and its point-reflection through the centre), so the givens
  /// keep a point-symmetric pattern; the pair is kept only if clearing
  /// *both* still leaves a unique puzzle. Defaults to false
  /// (independent single-cell removal).
  List<List<int>> removeClues(
    List<List<int>> solvedBoard,
    int targetGivenCount, {
    bool symmetric = false,
  }) {
    final puzzle = solvedBoard.map((row) => List<int>.from(row)).toList();
    final units = _removalUnits(symmetric)..shuffle(_random);

    var givenCount = 81;
    for (final unit in units) {
      if (givenCount <= targetGivenCount) break;
      final backups = [for (final pos in unit) puzzle[pos[0]][pos[1]]];
      for (final pos in unit) {
        puzzle[pos[0]][pos[1]] = 0;
      }
      final accept = _solver.countSolutions(puzzle, limit: 2) == 1;
      if (accept) {
        givenCount -= unit.length;
      } else {
        for (var i = 0; i < unit.length; i++) {
          puzzle[unit[i][0]][unit[i][1]] = backups[i];
        }
      }
    }
    return puzzle;
  }

  /// Groups all 81 cells into the units removed together. Asymmetric: 81
  /// single-cell units (each removed independently). Symmetric: the 40
  /// 180°-rotational pairs (linear index `i` paired with `80 - i`) plus the
  /// self-paired centre cell — so a unit is cleared or kept as a whole,
  /// preserving point symmetry.
  List<List<List<int>>> _removalUnits(bool symmetric) {
    if (!symmetric) {
      return [
        for (var r = 0; r < 9; r++)
          for (var c = 0; c < 9; c++)
            [
              [r, c]
            ],
      ];
    }
    final units = <List<List<int>>>[];
    for (var i = 0; i <= 40; i++) {
      final partner = 80 - i;
      units.add(partner == i
          ? [
              [i ~/ 9, i % 9]
            ]
          : [
              [i ~/ 9, i % 9],
              [partner ~/ 9, partner % 9]
            ]);
    }
    return units;
  }
}
