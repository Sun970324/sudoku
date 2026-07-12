import '../models/sudoku_grid.dart';

class SudokuSolver {
  /// Returns a solved copy of [grid], or null if no solution exists.
  List<List<int>>? solve(List<List<int>> grid) {
    final working = grid.map((row) => List<int>.from(row)).toList();
    if (_solve(working)) return working;
    return null;
  }

  bool _solve(List<List<int>> grid) {
    final empty = _findEmpty(grid);
    if (empty == null) return true;
    final row = empty[0];
    final col = empty[1];
    final wrapper = SudokuGrid(grid);
    for (var value = 1; value <= 9; value++) {
      if (wrapper.isValidPlacement(row, col, value)) {
        grid[row][col] = value;
        if (_solve(grid)) return true;
        grid[row][col] = 0;
      }
    }
    return false;
  }

  /// Counts solutions for [grid], stopping early once [limit] is reached.
  /// Used during puzzle generation to confirm a unique solution without
  /// exhaustively enumerating every possibility.
  int countSolutions(List<List<int>> grid, {int limit = 2}) {
    final working = grid.map((row) => List<int>.from(row)).toList();
    return _count(working, limit);
  }

  int _count(List<List<int>> grid, int limit) {
    final empty = _findEmpty(grid);
    if (empty == null) return 1;
    final row = empty[0];
    final col = empty[1];
    final wrapper = SudokuGrid(grid);
    var found = 0;
    for (var value = 1; value <= 9; value++) {
      if (wrapper.isValidPlacement(row, col, value)) {
        grid[row][col] = value;
        found += _count(grid, limit - found);
        grid[row][col] = 0;
        if (found >= limit) break;
      }
    }
    return found;
  }

  List<int>? _findEmpty(List<List<int>> grid) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (grid[r][c] == 0) return [r, c];
      }
    }
    return null;
  }
}
