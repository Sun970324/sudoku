class SudokuSolver {
  /// Returns a solved copy of [grid], or null if no solution exists.
  List<List<int>>? solve(List<List<int>> grid) {
    final working = grid.map((row) => List<int>.from(row)).toList();
    final masks = _Masks.fromGrid(working);
    if (_solve(working, masks)) return working;
    return null;
  }

  bool _solve(List<List<int>> grid, _Masks masks) {
    final cell = _pickCell(grid, masks);
    if (cell == null) return true;
    final row = cell.row;
    final col = cell.col;
    for (var value = 1; value <= 9; value++) {
      if (masks.allows(row, col, value)) {
        grid[row][col] = value;
        masks.place(row, col, value);
        if (_solve(grid, masks)) return true;
        masks.remove(row, col, value);
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
    final masks = _Masks.fromGrid(working);
    return _count(working, masks, limit);
  }

  int _count(List<List<int>> grid, _Masks masks, int limit) {
    final cell = _pickCell(grid, masks);
    if (cell == null) return 1;
    final row = cell.row;
    final col = cell.col;
    var found = 0;
    for (var value = 1; value <= 9; value++) {
      if (masks.allows(row, col, value)) {
        grid[row][col] = value;
        masks.place(row, col, value);
        found += _count(grid, masks, limit - found);
        masks.remove(row, col, value);
        grid[row][col] = 0;
        if (found >= limit) break;
      }
    }
    return found;
  }

  /// Most-constrained-cell (MRV) selection: the empty cell with the fewest
  /// remaining candidates, so branchier decisions are deferred and dead
  /// ends (a cell with zero candidates) are hit — and backtracked from —
  /// as early as possible. Doesn't change *how many* solutions exist
  /// (order-independent), only how fast the search finds/rules them out.
  _Cell? _pickCell(List<List<int>> grid, _Masks masks) {
    _Cell? best;
    var bestCount = 10;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (grid[r][c] != 0) continue;
        final count = masks.candidateCount(r, c);
        if (count == 0) return _Cell(r, c);
        if (count < bestCount) {
          bestCount = count;
          best = _Cell(r, c);
          if (count == 1) return best;
        }
      }
    }
    return best;
  }
}

class _Cell {
  const _Cell(this.row, this.col);
  final int row;
  final int col;
}

/// Row/column/3x3-box "digit used" bitmasks, threaded through the
/// recursive search and updated incrementally (O(1) per placement/undo)
/// instead of rebuilding a fresh view of the board at every recursion
/// frame.
class _Masks {
  _Masks(this._row, this._col, this._box);

  factory _Masks.fromGrid(List<List<int>> grid) {
    final row = List.filled(9, 0);
    final col = List.filled(9, 0);
    final box = List.filled(9, 0);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final value = grid[r][c];
        if (value != 0) {
          final bit = 1 << value;
          row[r] |= bit;
          col[c] |= bit;
          box[_boxIndex(r, c)] |= bit;
        }
      }
    }
    return _Masks(row, col, box);
  }

  final List<int> _row;
  final List<int> _col;
  final List<int> _box;

  static int _boxIndex(int row, int col) => (row ~/ 3) * 3 + col ~/ 3;

  bool allows(int row, int col, int value) =>
      (_row[row] | _col[col] | _box[_boxIndex(row, col)]) & (1 << value) == 0;

  int candidateCount(int row, int col) {
    final used = _row[row] | _col[col] | _box[_boxIndex(row, col)];
    var count = 0;
    for (var v = 1; v <= 9; v++) {
      if (used & (1 << v) == 0) count++;
    }
    return count;
  }

  void place(int row, int col, int value) {
    final bit = 1 << value;
    _row[row] |= bit;
    _col[col] |= bit;
    _box[_boxIndex(row, col)] |= bit;
  }

  void remove(int row, int col, int value) {
    final bit = ~(1 << value);
    _row[row] &= bit;
    _col[col] &= bit;
    _box[_boxIndex(row, col)] &= bit;
  }
}
