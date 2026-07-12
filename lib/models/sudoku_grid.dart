class SudokuGrid {
  SudokuGrid(this.cells)
      : _rowMask = List.filled(9, 0),
        _colMask = List.filled(9, 0),
        _boxMask = List.filled(9, 0) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final value = cells[r][c];
        if (value != 0) _mark(r, c, value);
      }
    }
  }

  factory SudokuGrid.empty() =>
      SudokuGrid(List.generate(9, (_) => List.filled(9, 0)));

  factory SudokuGrid.fromJson(List<dynamic> json) => SudokuGrid(
        json.map((row) => (row as List<dynamic>).cast<int>()).toList(),
      );

  final List<List<int>> cells;

  /// Row/column/3x3-box bitmasks (bit `1 << digit`) kept in sync with
  /// [cells] by [_mark]/[_unmark] — built once in the constructor (O(81))
  /// so [isValidPlacement]/[candidatesAt] can answer in O(1)/O(9) instead of
  /// re-scanning 27 cells per query. Only [set] mutates [cells] after
  /// construction, so this stays accurate as long as callers go through it
  /// rather than writing [cells] directly.
  final List<int> _rowMask;
  final List<int> _colMask;
  final List<int> _boxMask;

  static int _boxIndex(int row, int col) => (row ~/ 3) * 3 + col ~/ 3;

  static List<List<List<int>>>? _cachedBoxCells;

  /// The 9 cells of the 3x3 box containing (row, col), including (row, col)
  /// itself. Pure board geometry (independent of any grid's cell values),
  /// so — like [peersOf] — this is cached once across all 81 possible
  /// (row, col) rather than rebuilt on every call.
  static List<List<int>> boxCellsOf(int row, int col) {
    final cache =
        _cachedBoxCells ??= List.generate(81, (i) => _buildBoxCells(i ~/ 9, i % 9));
    return cache[row * 9 + col];
  }

  static List<List<int>> _buildBoxCells(int row, int col) {
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    return [
      for (var r = boxRow; r < boxRow + 3; r++)
        for (var c = boxCol; c < boxCol + 3; c++) [r, c],
    ];
  }

  static List<List<List<int>>>? _cachedPeers;

  /// Every cell sharing a row, column, or 3x3 box with (row, col),
  /// excluding (row, col) itself. Note the box portion is folded in
  /// unconditionally (like the original per-call-site implementations this
  /// centralizes), so the ~4 box cells that also share a row or column with
  /// (row, col) appear twice — harmless for every consumer here (building a
  /// Set, `.any()` membership checks, idempotent `.remove()`, or an
  /// early-return existence scan), so this preserves that behavior exactly
  /// rather than "fixing" it into a strictly-deduplicated 20-cell list.
  static List<List<int>> peersOf(int row, int col) {
    final cache =
        _cachedPeers ??= List.generate(81, (i) => _buildPeers(i ~/ 9, i % 9));
    return cache[row * 9 + col];
  }

  static List<List<int>> _buildPeers(int row, int col) {
    final peers = <List<int>>[];
    for (var c = 0; c < 9; c++) {
      if (c != col) peers.add([row, c]);
    }
    for (var r = 0; r < 9; r++) {
      if (r != row) peers.add([r, col]);
    }
    for (final cell in boxCellsOf(row, col)) {
      if (cell[0] != row || cell[1] != col) peers.add(cell);
    }
    return peers;
  }

  void _mark(int row, int col, int value) {
    final bit = 1 << value;
    _rowMask[row] |= bit;
    _colMask[col] |= bit;
    _boxMask[_boxIndex(row, col)] |= bit;
  }

  void _unmark(int row, int col, int value) {
    final bit = ~(1 << value);
    _rowMask[row] &= bit;
    _colMask[col] &= bit;
    _boxMask[_boxIndex(row, col)] &= bit;
  }

  int get(int row, int col) => cells[row][col];

  void set(int row, int col, int value) {
    final old = cells[row][col];
    if (old == value) return;
    if (old != 0) _unmark(row, col, old);
    if (value != 0) _mark(row, col, value);
    cells[row][col] = value;
  }

  /// Checks whether [value] can occupy (row, col) without conflicting with
  /// any other cell in the same row, column, or 3x3 box. Excludes the cell
  /// itself so this works whether the cell already holds [value] or is empty.
  bool isValidPlacement(int row, int col, int value) {
    if (value == 0) return true;
    if (cells[row][col] == 0) {
      final used =
          _rowMask[row] | _colMask[col] | _boxMask[_boxIndex(row, col)];
      return used & (1 << value) == 0;
    }
    // The cell already holds a value (possibly `value` itself): the masks
    // only record *whether* a digit is used in a unit, not how many times,
    // so they can't tell "only this cell has it" apart from "this cell and
    // a genuine duplicate elsewhere both have it". Fall back to a direct
    // scan for this rare case — every real call site here only ever
    // queries already-empty cells, so this path is a correctness safety
    // net, not a hot path.
    for (final p in peersOf(row, col)) {
      if (cells[p[0]][p[1]] == value) return false;
    }
    return true;
  }

  /// Digits 1-9 that could legally occupy (row, col) given the current cell
  /// values — empty if the cell is already filled. Derived purely from
  /// board state, with no notion of player pencil-mark notes.
  Set<int> candidatesAt(int row, int col) {
    if (cells[row][col] != 0) return {};
    final used = _rowMask[row] | _colMask[col] | _boxMask[_boxIndex(row, col)];
    return {
      for (var v = 1; v <= 9; v++)
        if (used & (1 << v) == 0) v,
    };
  }

  /// [candidatesAt] for every cell, as a 9x9 grid — the shared
  /// implementation behind HintEngine's and HumanSolver's identical
  /// "recompute every cell's candidates from scratch" helper.
  List<List<Set<int>>> allCandidates() => List.generate(
        9,
        (r) => List.generate(9, (c) => candidatesAt(r, c)),
      );

  SudokuGrid clone() =>
      SudokuGrid(cells.map((row) => List<int>.from(row)).toList());

  List<List<int>> toJson() =>
      cells.map((row) => List<int>.from(row)).toList();
}
