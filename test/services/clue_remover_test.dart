import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
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

void main() {
  final solver = SudokuSolver();

  test('removes clues down toward the target given-count', () {
    final puzzle =
        ClueRemover(random: Random(1)).removeClues(_solved, 30);
    expect(_givenCount(puzzle), lessThanOrEqualTo(35));
  });

  test('never removes more than the original 81 minus the target', () {
    final puzzle = ClueRemover(random: Random(2)).removeClues(_solved, 40);
    expect(_givenCount(puzzle), greaterThanOrEqualTo(40));
  });

  test('the result always keeps a unique solution', () {
    final puzzle = ClueRemover(random: Random(3)).removeClues(_solved, 27);
    expect(solver.countSolutions(puzzle, limit: 2), 1);
  });

  test('a target at or above 81 removes nothing', () {
    final puzzle = ClueRemover(random: Random(4)).removeClues(_solved, 81);
    expect(puzzle, equals(_solved));
  });

  test('does not mutate the input board', () {
    final original = _solved.map((row) => List<int>.from(row)).toList();
    ClueRemover(random: Random(5)).removeClues(_solved, 30);
    expect(_solved, equals(original));
  });

  test('isAcceptable rejecting everything leaves the board unchanged even '
      'though every removal would preserve uniqueness', () {
    final puzzle = ClueRemover(random: Random(6)).removeClues(
      _solved,
      30,
      isAcceptable: (_) => false,
    );
    expect(puzzle, equals(_solved));
  });

  test('isAcceptable only narrows removals, never widens beyond the '
      'uniqueness check', () {
    final puzzle = ClueRemover(random: Random(7)).removeClues(
      _solved,
      30,
      isAcceptable: (_) => true,
    );
    expect(solver.countSolutions(puzzle, limit: 2), 1);
    expect(_givenCount(puzzle), lessThanOrEqualTo(35));
  });
}
