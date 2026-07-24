/// A fixed-capacity set of the 81 Sudoku cell indices (0..80), backed by three
/// `int` words of 27 bits each — `_w0` holds cells 0..26, `_w1` holds 27..53,
/// `_w2` holds 54..80. This mirrors HoDoKu's `SudokuSet`, letting
/// union/intersection/subset/difference run as O(1) bitwise ops instead of
/// per-cell loops.
///
/// The 27-bit word width is deliberate: every value stays ≤ `0x7FFFFFF`, so all
/// bitwise ops fit inside 32 bits and behave identically on the Dart VM (64-bit
/// `int`) and on Dart *web* (32-bit bitwise on 53-bit doubles). No word ever
/// uses a sign bit or a bit above 31, so nothing is silently truncated.
class BitSet81 {
  BitSet81() : this._(0, 0, 0);

  BitSet81._(this._w0, this._w1, this._w2);

  /// All 27 low bits of a word set (cells within one word: `0x7FFFFFF`).
  static const int _wordFull = 0x7FFFFFF;

  /// A set containing every cell 0..80 (all three words full).
  factory BitSet81.all() => BitSet81._(_wordFull, _wordFull, _wordFull);

  int _w0;
  int _w1;
  int _w2;

  /// Popcount of a ≤27-bit word by clearing the lowest set bit each step
  /// (`x & (x - 1)`). All intermediates stay ≤27 bits, so this is web-safe.
  static int _popcount(int x) {
    var count = 0;
    while (x != 0) {
      x &= x - 1;
      count++;
    }
    return count;
  }

  /// Index of the single set bit in a power-of-two `bit` (its trailing-zero
  /// count). `bit - 1` turns every lower bit on, so its popcount is the index.
  static int _bitIndex(int bit) => _popcount(bit - 1);

  void add(int i) {
    if (i < 27) {
      _w0 |= 1 << i;
    } else if (i < 54) {
      _w1 |= 1 << (i - 27);
    } else {
      _w2 |= 1 << (i - 54);
    }
  }

  void remove(int i) {
    if (i < 27) {
      _w0 &= ~(1 << i);
    } else if (i < 54) {
      _w1 &= ~(1 << (i - 27));
    } else {
      _w2 &= ~(1 << (i - 54));
    }
  }

  bool contains(int i) {
    if (i < 27) return _w0 & (1 << i) != 0;
    if (i < 54) return _w1 & (1 << (i - 27)) != 0;
    return _w2 & (1 << (i - 54)) != 0;
  }

  bool get isEmpty => _w0 == 0 && _w1 == 0 && _w2 == 0;

  bool get isNotEmpty => !isEmpty;

  void clear() {
    _w0 = 0;
    _w1 = 0;
    _w2 = 0;
  }

  /// Number of cells in the set (popcount of all three words).
  int get count => _popcount(_w0) + _popcount(_w1) + _popcount(_w2);

  // --- In-place set algebra ---

  void union(BitSet81 other) {
    _w0 |= other._w0;
    _w1 |= other._w1;
    _w2 |= other._w2;
  }

  void intersect(BitSet81 other) {
    _w0 &= other._w0;
    _w1 &= other._w1;
    _w2 &= other._w2;
  }

  /// In-place set difference (`this AND NOT other`).
  void subtract(BitSet81 other) {
    _w0 &= ~other._w0;
    _w1 &= ~other._w1;
    _w2 &= ~other._w2;
  }

  // --- Non-mutating set algebra ---

  BitSet81 operator |(BitSet81 other) =>
      BitSet81._(_w0 | other._w0, _w1 | other._w1, _w2 | other._w2);

  BitSet81 operator &(BitSet81 other) =>
      BitSet81._(_w0 & other._w0, _w1 & other._w1, _w2 & other._w2);

  /// `this AND NOT other`, without mutating either operand.
  BitSet81 difference(BitSet81 other) => BitSet81._(
        _w0 & ~other._w0,
        _w1 & ~other._w1,
        _w2 & ~other._w2,
      );

  /// Whether the two sets share at least one cell.
  bool intersects(BitSet81 other) =>
      _w0 & other._w0 != 0 || _w1 & other._w1 != 0 || _w2 & other._w2 != 0;

  /// Whether [other] is a subset of this set (every cell of [other] is here).
  bool containsAll(BitSet81 other) =>
      _w0 & other._w0 == other._w0 &&
      _w1 & other._w1 == other._w1 &&
      _w2 & other._w2 == other._w2;

  /// The cell indices, in ascending order.
  List<int> toList() {
    final out = <int>[];
    forEach(out.add);
    return out;
  }

  /// Applies [action] to every cell index in ascending order. Scans only the
  /// set bits (isolating the lowest with `w & -w`) rather than all 81 slots.
  void forEach(void Function(int index) action) {
    var w = _w0;
    while (w != 0) {
      final bit = w & -w;
      action(_bitIndex(bit));
      w ^= bit;
    }
    w = _w1;
    while (w != 0) {
      final bit = w & -w;
      action(27 + _bitIndex(bit));
      w ^= bit;
    }
    w = _w2;
    while (w != 0) {
      final bit = w & -w;
      action(54 + _bitIndex(bit));
      w ^= bit;
    }
  }

  BitSet81 copy() => BitSet81._(_w0, _w1, _w2);

  @override
  bool operator ==(Object other) =>
      other is BitSet81 &&
      other._w0 == _w0 &&
      other._w1 == _w1 &&
      other._w2 == _w2;

  @override
  int get hashCode => Object.hash(_w0, _w1, _w2);

  @override
  String toString() => 'BitSet81${toList()}';
}
