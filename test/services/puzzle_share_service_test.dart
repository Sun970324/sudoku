import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/puzzle_share_service.dart';

// Same fixture as sudoku_solver_test.dart — a classic example puzzle with a
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
  final service = PuzzleShareService();

  SudokuPuzzle buildPuzzle() => SudokuPuzzle(
        puzzle: SudokuGrid(_puzzle.map((row) => [...row]).toList()),
        solution: SudokuGrid(_solution.map((row) => [...row]).toList()),
        fixedMask: List.generate(
          9,
          (r) => List.generate(9, (c) => _puzzle[r][c] != 0),
        ),
        difficulty: Difficulty.medium,
      );

  test('decodeText reverses encodeText back to the same givens and solution',
      () {
    final code = service.encodeText(buildPuzzle());
    final decoded = service.decodeText(code);

    expect(decoded.puzzle.toJson(), _puzzle);
    expect(decoded.solution.toJson(), _solution);
  });

  test('decodeText rejects a garbage code', () {
    expect(
      () => service.decodeText('not-a-real-code'),
      throwsA(isA<PuzzleShareException>()),
    );
  });

  test('decodeText rejects a code with a tampered checksum', () {
    final code = service.encodeText(buildPuzzle());
    final lastChar = code[code.length - 1];
    // Flip the checksum character to something guaranteed different.
    final tamperedChar = lastChar == '0' ? '1' : '0';
    final tampered = code.substring(0, code.length - 1) + tamperedChar;

    expect(
      () => service.decodeText(tampered),
      throwsA(isA<PuzzleShareException>()),
    );
  });
}
