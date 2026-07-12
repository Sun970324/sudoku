import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/sudoku_grid.dart';

void main() {
  group('SudokuGrid.isValidPlacement', () {
    test('rejects a value already present in the same row', () {
      final grid = SudokuGrid.empty();
      grid.set(0, 0, 5);
      expect(grid.isValidPlacement(0, 3, 5), isFalse);
    });

    test('rejects a value already present in the same column', () {
      final grid = SudokuGrid.empty();
      grid.set(2, 4, 7);
      expect(grid.isValidPlacement(6, 4, 7), isFalse);
    });

    test('rejects a value already present in the same 3x3 box', () {
      final grid = SudokuGrid.empty();
      grid.set(0, 0, 9);
      expect(grid.isValidPlacement(2, 2, 9), isFalse);
    });

    test('allows a value with no conflicts', () {
      final grid = SudokuGrid.empty();
      grid.set(0, 0, 5);
      expect(grid.isValidPlacement(8, 8, 5), isTrue);
    });

    test('does not conflict with itself when re-checking the same cell', () {
      final grid = SudokuGrid.empty();
      grid.set(4, 4, 6);
      expect(grid.isValidPlacement(4, 4, 6), isTrue);
    });

    test('always allows placing an empty value (0)', () {
      final grid = SudokuGrid.empty();
      grid.set(0, 0, 5);
      expect(grid.isValidPlacement(0, 3, 0), isTrue);
    });
  });

  group('SudokuGrid.candidatesAt', () {
    test('an unconstrained empty cell allows every digit', () {
      final grid = SudokuGrid.empty();
      expect(grid.candidatesAt(4, 4), {1, 2, 3, 4, 5, 6, 7, 8, 9});
    });

    test('excludes digits already used in the row, column, and box', () {
      final grid = SudokuGrid.empty();
      grid.set(0, 1, 1); // same row
      grid.set(1, 0, 2); // same column
      grid.set(1, 1, 3); // same box
      grid.set(8, 8, 4); // unrelated cell, no effect
      expect(grid.candidatesAt(0, 0), {4, 5, 6, 7, 8, 9});
    });

    test('an already-filled cell has no candidates', () {
      final grid = SudokuGrid.empty();
      grid.set(2, 2, 7);
      expect(grid.candidatesAt(2, 2), isEmpty);
    });
  });

  test('clone produces an independent copy', () {
    final grid = SudokuGrid.empty();
    grid.set(1, 1, 3);
    final copy = grid.clone();
    copy.set(1, 1, 9);
    expect(grid.get(1, 1), 3);
    expect(copy.get(1, 1), 9);
  });

  test('toJson/fromJson round-trip preserves values', () {
    final grid = SudokuGrid.empty();
    grid.set(3, 3, 8);
    final restored = SudokuGrid.fromJson(grid.toJson());
    expect(restored.get(3, 3), 8);
  });
}
