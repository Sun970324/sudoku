import 'dart:math';

import '../../models/sudoku_grid.dart';

/// Produces fully-filled, valid 9x9 Sudoku boards via randomized
/// backtracking — the "BoardGenerator" module.
class BoardGenerator {
  BoardGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<List<int>> generateSolvedBoard() {
    final cells = List.generate(9, (_) => List.filled(9, 0));
    // The three diagonal boxes share no row/column, so they can be filled
    // independently at random before backtracking fills the rest — this
    // speeds up generation and adds variety versus a plain backtrack fill.
    for (var box = 0; box < 3; box++) {
      _fillBox(cells, box * 3, box * 3);
    }
    _fillRandomized(cells);
    return cells;
  }

  void _fillBox(List<List<int>> cells, int startRow, int startCol) {
    final values = List.generate(9, (i) => i + 1)..shuffle(_random);
    var index = 0;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        cells[startRow + r][startCol + c] = values[index++];
      }
    }
  }

  bool _fillRandomized(List<List<int>> cells) {
    int? row;
    int? col;
    outer:
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (cells[r][c] == 0) {
          row = r;
          col = c;
          break outer;
        }
      }
    }
    if (row == null) return true;

    final wrapper = SudokuGrid(cells);
    final values = List.generate(9, (i) => i + 1)..shuffle(_random);
    for (final value in values) {
      if (wrapper.isValidPlacement(row, col!, value)) {
        cells[row][col] = value;
        if (_fillRandomized(cells)) return true;
        cells[row][col] = 0;
      }
    }
    return false;
  }
}
