import 'bitset81.dart';

/// Precomputed board geometry, shared by every bitset-based technique. All
/// tables are pure functions of the 9x9 layout (independent of any puzzle),
/// so they are built once as lazy static finals and never mutated.
///
/// Cells are addressed by a flat index `cell = row * 9 + col` (0..80).
class BitsetGeometry {
  BitsetGeometry._();

  static int rowOf(int cell) => cell ~/ 9;

  static int colOf(int cell) => cell % 9;

  static int boxOf(int cell) => (rowOf(cell) ~/ 3) * 3 + colOf(cell) ~/ 3;

  static int cellIndex(int row, int col) => row * 9 + col;

  /// The 27 units as bitsets: indices 0..8 are the 9 rows, 9..17 the 9
  /// columns, 18..26 the 9 boxes. Each holds exactly 9 cells.
  static final List<BitSet81> units = _buildUnits();

  static List<BitSet81> _buildUnits() {
    final result = List.generate(27, (_) => BitSet81());
    for (var i = 0; i < 9; i++) {
      final row = result[i];
      final col = result[9 + i];
      for (var j = 0; j < 9; j++) {
        row.add(cellIndex(i, j));
        col.add(cellIndex(j, i));
      }
    }
    for (var box = 0; box < 9; box++) {
      final set = result[18 + box];
      final baseRow = (box ~/ 3) * 3;
      final baseCol = (box % 3) * 3;
      for (var r = baseRow; r < baseRow + 3; r++) {
        for (var c = baseCol; c < baseCol + 3; c++) {
          set.add(cellIndex(r, c));
        }
      }
    }
    return result;
  }

  /// For each cell, its 20 "buddies" (peers): every other cell sharing its
  /// row, column, or box, minus the cell itself. Mirrors HoDoKu's precomputed
  /// buddy sets — the workhorse of candidate elimination.
  static final List<BitSet81> buddies = _buildBuddies();

  static List<BitSet81> _buildBuddies() {
    return List.generate(81, (cell) {
      final set = BitSet81();
      final row = rowOf(cell);
      final col = colOf(cell);
      final box = boxOf(cell);
      set
        ..union(units[row])
        ..union(units[9 + col])
        ..union(units[18 + box])
        ..remove(cell);
      return set;
    });
  }
}
