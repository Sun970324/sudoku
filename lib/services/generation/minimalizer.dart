import 'dart:math';

import '../sudoku_solver.dart';

/// Exhaustively strips any further redundant givens from a unique-solution
/// puzzle — the "Minimalizer" module. Unlike [ClueRemover] (which stops at
/// a target given-count), this repeats full removal passes until an entire
/// pass removes nothing, reaching a local fixed point where no single
/// remaining given can be removed without breaking uniqueness (this is
/// order-dependent — a different shuffle order can land on a different,
/// equally-valid minimal subset, not one canonical minimum).
///
/// When [isAcceptable] is supplied to [minimalize], the fixed point becomes
/// *conditionally* minimal: no remaining given is removable while
/// preserving both uniqueness and [isAcceptable] (e.g. a difficulty
/// ceiling during graded puzzle generation). A ceiling-bounded run can land
/// on a different minimal subset depending on shuffle order, and can even
/// undershoot a target difficulty tier entirely — both acceptable per
/// generator.md, since the spec only requires the final accepted puzzle to
/// exactly match the target (enforced by the caller's retry loop, not by
/// this class).
class Minimalizer {
  Minimalizer({Random? random, SudokuSolver? solver})
      : _random = random ?? Random(),
        _solver = solver ?? SudokuSolver();

  final Random _random;
  final SudokuSolver _solver;

  List<List<int>> minimalize(
    List<List<int>> puzzle, {
    bool Function(List<List<int>> puzzle)? isAcceptable,
  }) {
    var current = puzzle.map((row) => List<int>.from(row)).toList();
    while (true) {
      final removedThisPass = _removalPass(current, isAcceptable);
      if (!removedThisPass) return current;
    }
  }

  /// Tries removing every remaining given once, in random order, keeping
  /// each removal that preserves a unique solution and (if given) satisfies
  /// [isAcceptable]. Returns whether at least one clue was actually removed
  /// during this pass.
  bool _removalPass(
    List<List<int>> puzzle,
    bool Function(List<List<int>> puzzle)? isAcceptable,
  ) {
    final givens = [
      for (var r = 0; r < 9; r++)
        for (var c = 0; c < 9; c++)
          if (puzzle[r][c] != 0) [r, c],
    ]..shuffle(_random);

    var removedAny = false;
    for (final pos in givens) {
      final row = pos[0];
      final col = pos[1];
      final backup = puzzle[row][col];
      puzzle[row][col] = 0;
      final accept = _solver.countSolutions(puzzle, limit: 2) == 1 &&
          (isAcceptable == null || isAcceptable(puzzle));
      if (accept) {
        removedAny = true;
      } else {
        puzzle[row][col] = backup;
      }
    }
    return removedAny;
  }
}
