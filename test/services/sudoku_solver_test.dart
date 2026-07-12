import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/sudoku_solver.dart';

// Classic example puzzle (widely used as a Sudoku solver fixture) with a
// single, known solution.
const _puzzle = [
  [5, 3, 0, 0, 7, 0, 0, 0, 0],
  [6, 0, 0, 1, 9, 5, 0, 0, 0],
  [0, 9, 8, 0, 0, 0, 0, 6, 0],
  [8, 0, 0, 0, 6, 0, 0, 0, 3],
  [4, 0, 0, 8, 0, 3, 0, 0, 1],
  [7, 0, 0, 0, 2, 0, 0, 0, 6],
  [0, 6, 0, 0, 0, 0, 2, 8, 0],
  [0, 0, 0, 4, 1, 9, 0, 0, 5],
  [0, 0, 0, 0, 8, 0, 0, 7, 9],
];

const _solution = [
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

void main() {
  final solver = SudokuSolver();

  test('solve returns the known unique solution for a standard puzzle', () {
    final result = solver.solve(_puzzle);
    expect(result, _solution);
  });

  test('countSolutions reports exactly 1 for a puzzle with a unique solution', () {
    expect(solver.countSolutions(_puzzle, limit: 2), 1);
  });

  test('countSolutions caps at the requested limit for an ambiguous grid', () {
    final empty = List.generate(9, (_) => List.filled(9, 0));
    expect(solver.countSolutions(empty, limit: 2), 2);
  });

  test('solve returns null for a contradictory, unsolvable grid', () {
    final contradictory = List.generate(9, (_) => List.filled(9, 0));
    contradictory[0] = [1, 2, 3, 4, 5, 6, 7, 8, 0];
    contradictory[1][8] = 9; // column 8 already has the only value row 0 needs
    expect(solver.solve(contradictory), isNull);
  });
}
