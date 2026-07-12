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
  /// If [isAcceptable] is given, a removal is also only kept when it
  /// returns true for the resulting board (in addition to the existing
  /// uniqueness check) — e.g. a difficulty-ceiling check during graded
  /// puzzle generation. Defaults to always-accept, matching prior behavior.
  List<List<int>> removeClues(
    List<List<int>> solvedBoard,
    int targetGivenCount, {
    bool Function(List<List<int>> puzzle)? isAcceptable,
  }) {
    final puzzle = solvedBoard.map((row) => List<int>.from(row)).toList();
    final positions = [
      for (var r = 0; r < 9; r++)
        for (var c = 0; c < 9; c++) [r, c],
    ]..shuffle(_random);

    var givenCount = 81;
    for (final pos in positions) {
      if (givenCount <= targetGivenCount) break;
      final row = pos[0];
      final col = pos[1];
      final backup = puzzle[row][col];
      puzzle[row][col] = 0;
      final solutionCount = _solver.countSolutions(puzzle, limit: 2);
      final accept =
          solutionCount == 1 && (isAcceptable == null || isAcceptable(puzzle));
      if (accept) {
        givenCount--;
      } else {
        puzzle[row][col] = backup;
      }
    }
    return puzzle;
  }
}
