import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/minimalizer.dart';
import 'package:sudoku/services/sudoku_solver.dart';

// Classic example solved grid (also used in sudoku_solver_test.dart).
const _solved = [
  [5, 3, 4, 6, 7, 8, 9, 1, 2],
  [6, 7, 2, 1, 9, 5, 3, 4, 8],
  [1, 9, 8, 3, 4, 2, 5, 6, 7],
  [8, 5, 9, 7, 6, 1, 4, 2, 3],
  [4, 2, 6, 8, 5, 3, 7, 9, 1],
  [7, 1, 3, 9, 2, 4, 8, 5, 6],
  [9, 6, 1, 5, 3, 7, 2, 8, 4],
  [2, 8, 7, 4, 1, 9, 6, 3, 5],
  [3, 4, 5, 2, 8, 6, 1, 7, 9],
];

int _givenCount(List<List<int>> board) =>
    board.expand((row) => row).where((v) => v != 0).length;

/// A guaranteed unique-solution puzzle with plenty of givens (60 — far more
/// than any 9x9 puzzle needs), built the same way ClueRemover is already
/// tested to work — safer than hand-blanking cells from a solved grid,
/// which can silently produce an ambiguous starting puzzle.
List<List<int>> _generousPuzzle(int seed) =>
    ClueRemover(random: Random(seed)).removeClues(_solved, 60);

void main() {
  final solver = SudokuSolver();

  test('strips at least one redundant given from a generously-filled '
      'unique-solution puzzle', () {
    final puzzle = _generousPuzzle(1);
    final before = _givenCount(puzzle);

    final result = Minimalizer(random: Random(1)).minimalize(puzzle);

    expect(_givenCount(result), lessThan(before));
    expect(solver.countSolutions(result, limit: 2), 1);
  });

  test('the result always keeps a unique solution', () {
    final puzzle = _generousPuzzle(2);

    final result = Minimalizer(random: Random(2)).minimalize(puzzle);

    expect(solver.countSolutions(result, limit: 2), 1);
  });

  test('is idempotent — running it again on its own output changes '
      'nothing further', () {
    final puzzle = _generousPuzzle(3);

    final once = Minimalizer(random: Random(3)).minimalize(puzzle);
    final twice = Minimalizer(random: Random(4)).minimalize(once);

    expect(twice, equals(once));
  });

  test('does not mutate the input board', () {
    final puzzle = _generousPuzzle(5);
    final original = puzzle.map((row) => List<int>.from(row)).toList();

    Minimalizer(random: Random(5)).minimalize(puzzle);

    expect(puzzle, equals(original));
  });

}
