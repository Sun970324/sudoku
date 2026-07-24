/// Per-cell candidate representation: a small `int` bitmask where bit `d`
/// (for digit `d` in 1..9) is set iff `d` is a candidate for that cell. Bit 0
/// is unused, so an empty mask (0) means "no candidates" and [candFull] (bits
/// 1..9) means "all nine".
///
/// A whole grid is a flat `List<int>` of length 81, indexed by
/// `cell = row * 9 + col` — the same indexing the geometry tables use.
///
/// VM/native only, for the same reason as [BitSet81]: these are 64-bit
/// bitwise ops that would truncate on Dart web (the solver never runs there).
library;

/// Mask with every digit 1..9 present (`0b11_1111_1110` = 0x3FE).
const int candFull = 0x3FE;

/// Whether digit [d] (1..9) is a candidate in [mask].
bool candHas(int mask, int d) => mask & (1 << d) != 0;

/// [mask] with digit [d] added.
int candAdd(int mask, int d) => mask | (1 << d);

/// [mask] with digit [d] removed.
int candRemove(int mask, int d) => mask & ~(1 << d);

/// Number of candidate digits in [mask].
int candCount(int mask) {
  var count = 0;
  for (var m = mask; m != 0; m &= m - 1) {
    count++;
  }
  return count;
}

/// The candidate digits of [mask], in ascending order (1..9).
List<int> candDigits(int mask) {
  final out = <int>[];
  for (var d = 1; d <= 9; d++) {
    if (mask & (1 << d) != 0) out.add(d);
  }
  return out;
}

/// A fresh, empty 81-cell candidate grid.
List<int> emptyCandidateGrid() => List<int>.filled(81, 0);
