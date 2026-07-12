class SudokuGrid {
  SudokuGrid(this.cells);

  factory SudokuGrid.empty() =>
      SudokuGrid(List.generate(9, (_) => List.filled(9, 0)));

  factory SudokuGrid.fromJson(List<dynamic> json) => SudokuGrid(
        json.map((row) => (row as List<dynamic>).cast<int>()).toList(),
      );

  final List<List<int>> cells;

  int get(int row, int col) => cells[row][col];

  void set(int row, int col, int value) => cells[row][col] = value;

  /// Checks whether [value] can occupy (row, col) without conflicting with
  /// any other cell in the same row, column, or 3x3 box. Excludes the cell
  /// itself so this works whether the cell already holds [value] or is empty.
  bool isValidPlacement(int row, int col, int value) {
    if (value == 0) return true;
    for (var c = 0; c < 9; c++) {
      if (c != col && cells[row][c] == value) return false;
    }
    for (var r = 0; r < 9; r++) {
      if (r != row && cells[r][col] == value) return false;
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (var r = boxRow; r < boxRow + 3; r++) {
      for (var c = boxCol; c < boxCol + 3; c++) {
        if ((r != row || c != col) && cells[r][c] == value) return false;
      }
    }
    return true;
  }

  /// Digits 1-9 that could legally occupy (row, col) given the current cell
  /// values — empty if the cell is already filled. Derived purely from
  /// board state, with no notion of player pencil-mark notes.
  Set<int> candidatesAt(int row, int col) {
    if (cells[row][col] != 0) return {};
    return {
      for (var v = 1; v <= 9; v++)
        if (isValidPlacement(row, col, v)) v,
    };
  }

  SudokuGrid clone() =>
      SudokuGrid(cells.map((row) => List<int>.from(row)).toList());

  List<List<int>> toJson() =>
      cells.map((row) => List<int>.from(row)).toList();
}
