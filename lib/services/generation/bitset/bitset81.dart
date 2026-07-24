/// A fixed-capacity set of the 81 Sudoku cell indices (0..80), backed by two
/// `int` words — `_low` holds bits 0..63, `_high` holds bits 64..80 (only its
/// low 17 bits are ever used). This mirrors HoDoKu's `SudokuSet`, letting
/// union/intersection/subset/difference run as O(1) bitwise ops instead of
/// per-cell loops.
///
/// IMPORTANT: VM/native only. This relies on Dart `int` being a full 64-bit
/// two's-complement value (so word 0 can legitimately use bit 63). On Dart
/// *web*, `int` is a 53-bit double and bitwise ops are 32-bit, which would
/// silently corrupt the high bits. The solver never runs on web, so this is a
/// non-issue here — but do not reuse this type in web code.
class BitSet81 {
  BitSet81() : this._(0, 0);

  BitSet81._(this._low, this._high);

  /// A set containing every cell 0..80 (low word full, high word's bits
  /// 0..16 set).
  factory BitSet81.all() => BitSet81._(-1, 0x1FFFF);

  int _low;
  int _high;

  static int _popcount(int x) {
    // 64-bit SWAR popcount. Uses unsigned shifts (`>>>`) so a set bit 63
    // (negative `x`) is counted correctly.
    x = x - ((x >>> 1) & 0x5555555555555555);
    x = (x & 0x3333333333333333) + ((x >>> 2) & 0x3333333333333333);
    x = (x + (x >>> 4)) & 0x0F0F0F0F0F0F0F0F;
    return ((x * 0x0101010101010101) >>> 56) & 0x7F;
  }

  /// Index of the single set bit in a power-of-two `bit` (its trailing-zero
  /// count). `bit - 1` turns every lower bit on, so its popcount is the index.
  static int _bitIndex(int bit) => _popcount(bit - 1);

  void add(int i) {
    if (i < 64) {
      _low |= 1 << i;
    } else {
      _high |= 1 << (i - 64);
    }
  }

  void remove(int i) {
    if (i < 64) {
      _low &= ~(1 << i);
    } else {
      _high &= ~(1 << (i - 64));
    }
  }

  bool contains(int i) {
    if (i < 64) return _low & (1 << i) != 0;
    return _high & (1 << (i - 64)) != 0;
  }

  bool get isEmpty => _low == 0 && _high == 0;

  bool get isNotEmpty => !isEmpty;

  void clear() {
    _low = 0;
    _high = 0;
  }

  /// Number of cells in the set (popcount of both words).
  int get count => _popcount(_low) + _popcount(_high);

  // --- In-place set algebra ---

  void union(BitSet81 other) {
    _low |= other._low;
    _high |= other._high;
  }

  void intersect(BitSet81 other) {
    _low &= other._low;
    _high &= other._high;
  }

  /// In-place set difference (`this AND NOT other`).
  void subtract(BitSet81 other) {
    _low &= ~other._low;
    _high &= ~other._high;
  }

  // --- Non-mutating set algebra ---

  BitSet81 operator |(BitSet81 other) =>
      BitSet81._(_low | other._low, _high | other._high);

  BitSet81 operator &(BitSet81 other) =>
      BitSet81._(_low & other._low, _high & other._high);

  /// `this AND NOT other`, without mutating either operand.
  BitSet81 difference(BitSet81 other) =>
      BitSet81._(_low & ~other._low, _high & ~other._high);

  /// Whether the two sets share at least one cell.
  bool intersects(BitSet81 other) =>
      _low & other._low != 0 || _high & other._high != 0;

  /// Whether [other] is a subset of this set (every cell of [other] is here).
  bool containsAll(BitSet81 other) =>
      _low & other._low == other._low && _high & other._high == other._high;

  /// The cell indices, in ascending order.
  List<int> toList() {
    final out = <int>[];
    forEach(out.add);
    return out;
  }

  /// Applies [action] to every cell index in ascending order. Scans only the
  /// set bits (isolating the lowest with `w & -w`) rather than all 81 slots.
  void forEach(void Function(int index) action) {
    var w = _low;
    while (w != 0) {
      final bit = w & -w;
      action(_bitIndex(bit));
      w ^= bit;
    }
    w = _high;
    while (w != 0) {
      final bit = w & -w;
      action(64 + _bitIndex(bit));
      w ^= bit;
    }
  }

  BitSet81 copy() => BitSet81._(_low, _high);

  @override
  bool operator ==(Object other) =>
      other is BitSet81 && other._low == _low && other._high == _high;

  @override
  int get hashCode => Object.hash(_low, _high);

  @override
  String toString() => 'BitSet81${toList()}';
}
