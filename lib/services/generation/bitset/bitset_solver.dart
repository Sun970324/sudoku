import '../../../models/hint.dart';
import 'candidates.dart';
import 'geometry.dart';

/// The 27 units as flat cell-index lists (rows 0..8, cols 9..17, boxes 18..26),
/// derived once from [BitsetGeometry].
final List<List<int>> _unitCells =
    [for (var u = 0; u < 27; u++) BitsetGeometry.units[u].toList()];

/// Phase 1 of the bitset solver: the cheap "generation core" techniques —
/// Full House, Naked/Hidden Single, Intersections (Pointing/Claiming) and
/// Naked/Hidden Subsets (pair/triple/quad). It works entirely on
/// candidate-bitmasks with incremental updates (placing a digit strikes it
/// from that cell's [BitsetGeometry.buddies] in O(1) each), and produces only
/// placements/eliminations + a [HintTechnique] log — no localized [Hint]
/// objects. This is the fast solver used by generation/mining; the existing
/// [HintEngine]/[HumanSolver] stays the player-facing hint path untouched.
///
/// NOTE: Locked Pair/Triple are not detected as their own step — a Naked
/// Subset run over every unit already produces the identical eliminations
/// (the pair/triple's line unit is one of those scanned), so solving is
/// unaffected; only the history label differs (it reads nakedPair/nakedTriple).
class BitsetSolveResult {
  const BitsetSolveResult({
    required this.solved,
    required this.board,
    required this.history,
  });

  /// Whether every cell was filled using only the enabled techniques.
  final bool solved;

  /// The final 9x9 board (0 = still empty when unsolved).
  final List<List<int>> board;

  /// Every technique application, in order.
  final List<HintTechnique> history;
}

class BitsetSolver {
  /// Techniques this solver knows, in ascending-difficulty priority order.
  static const order = <HintTechnique>[
    HintTechnique.fullHouse,
    HintTechnique.nakedSingle,
    HintTechnique.hiddenSingle,
    HintTechnique.intersectionPointing,
    HintTechnique.intersectionClaiming,
    HintTechnique.nakedPair,
    HintTechnique.hiddenPair,
    HintTechnique.nakedTriple,
    HintTechnique.hiddenTriple,
    HintTechnique.nakedQuad,
    HintTechnique.hiddenQuad,
  ];

  late List<int> _cell; // 81 placed values (0 = empty)
  late List<int> _mask; // 81 candidate bitmasks (0 for placed cells)
  late List<HintTechnique> _history;

  /// Solves [input] (9x9, 0 = empty) with the enabled subset of [order]. When
  /// [enabled] is null every technique is used. Returns the final board plus
  /// the technique log; `solved` is true only if every cell was filled.
  BitsetSolveResult solve(List<List<int>> input, {Set<HintTechnique>? enabled}) {
    _cell = List<int>.filled(81, 0);
    _mask = List<int>.filled(81, 0);
    _history = <HintTechnique>[];

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        _cell[r * 9 + c] = input[r][c];
      }
    }
    for (var i = 0; i < 81; i++) {
      if (_cell[i] != 0) continue;
      var m = candFull;
      BitsetGeometry.buddies[i].forEach((b) {
        if (_cell[b] != 0) m = candRemove(m, _cell[b]);
      });
      _mask[i] = m;
    }

    bool on(HintTechnique t) => enabled == null || enabled.contains(t);

    while (!_contradiction()) {
      var progressed = false;
      for (final t in order) {
        if (!on(t)) continue;
        if (_apply(t)) {
          progressed = true;
          break; // restart from the cheapest technique
        }
      }
      if (!progressed) break;
    }

    return BitsetSolveResult(
      solved: _cell.every((v) => v != 0),
      board: [for (var r = 0; r < 9; r++) _cell.sublist(r * 9, r * 9 + 9)],
      history: _history,
    );
  }

  /// Any empty cell with no candidates left means the board is inconsistent —
  /// stop rather than spin.
  bool _contradiction() {
    for (var i = 0; i < 81; i++) {
      if (_cell[i] == 0 && _mask[i] == 0) return true;
    }
    return false;
  }

  bool _apply(HintTechnique t) => switch (t) {
        HintTechnique.fullHouse => _fullHouse(),
        HintTechnique.nakedSingle => _nakedSingle(),
        HintTechnique.hiddenSingle => _hiddenSingle(),
        HintTechnique.intersectionPointing => _pointing(),
        HintTechnique.intersectionClaiming => _claiming(),
        HintTechnique.nakedPair => _nakedSubset(2, HintTechnique.nakedPair),
        HintTechnique.nakedTriple => _nakedSubset(3, HintTechnique.nakedTriple),
        HintTechnique.nakedQuad => _nakedSubset(4, HintTechnique.nakedQuad),
        HintTechnique.hiddenPair => _hiddenSubset(2, HintTechnique.hiddenPair),
        HintTechnique.hiddenTriple =>
          _hiddenSubset(3, HintTechnique.hiddenTriple),
        HintTechnique.hiddenQuad => _hiddenSubset(4, HintTechnique.hiddenQuad),
        _ => false,
      };

  void _place(int cell, int digit) {
    _cell[cell] = digit;
    _mask[cell] = 0;
    BitsetGeometry.buddies[cell].forEach((b) {
      if (_cell[b] == 0) _mask[b] = candRemove(_mask[b], digit);
    });
  }

  bool _fullHouse() {
    for (final unit in _unitCells) {
      int? empty;
      var count = 0;
      for (final i in unit) {
        if (_cell[i] == 0) {
          empty = i;
          count++;
        }
      }
      if (count == 1) {
        _place(empty!, candDigits(_mask[empty]).first);
        _history.add(HintTechnique.fullHouse);
        return true;
      }
    }
    return false;
  }

  bool _nakedSingle() {
    for (var i = 0; i < 81; i++) {
      if (_cell[i] == 0 && candCount(_mask[i]) == 1) {
        _place(i, candDigits(_mask[i]).first);
        _history.add(HintTechnique.nakedSingle);
        return true;
      }
    }
    return false;
  }

  bool _hiddenSingle() {
    for (final unit in _unitCells) {
      for (var d = 1; d <= 9; d++) {
        int? only;
        var count = 0;
        for (final i in unit) {
          if (_cell[i] == 0 && candHas(_mask[i], d)) {
            only = i;
            count++;
          }
        }
        if (count == 1) {
          _place(only!, d);
          _history.add(HintTechnique.hiddenSingle);
          return true;
        }
      }
    }
    return false;
  }

  bool _pointing() {
    for (var box = 18; box < 27; box++) {
      for (var d = 1; d <= 9; d++) {
        final cells = [
          for (final i in _unitCells[box])
            if (_cell[i] == 0 && candHas(_mask[i], d)) i,
        ];
        if (cells.length < 2) continue;
        final row = cells.first ~/ 9;
        final col = cells.first % 9;
        final sameRow = cells.every((i) => i ~/ 9 == row);
        final sameCol = cells.every((i) => i % 9 == col);
        if (!sameRow && !sameCol) continue;
        // Eliminate d from the confining line, outside this box.
        final line = sameRow ? row : 9 + col; // unit index of the line
        if (_eliminateFromUnitOutsideBox(line, box, d)) {
          _history.add(HintTechnique.intersectionPointing);
          return true;
        }
      }
    }
    return false;
  }

  bool _claiming() {
    for (var line = 0; line < 18; line++) {
      for (var d = 1; d <= 9; d++) {
        final cells = [
          for (final i in _unitCells[line])
            if (_cell[i] == 0 && candHas(_mask[i], d)) i,
        ];
        if (cells.length < 2) continue;
        final box = BitsetGeometry.boxOf(cells.first);
        if (!cells.every((i) => BitsetGeometry.boxOf(i) == box)) continue;
        // Eliminate d from the box, outside this line.
        var changed = false;
        for (final i in _unitCells[18 + box]) {
          if (_unitCells[line].contains(i)) continue;
          if (_cell[i] == 0 && candHas(_mask[i], d)) {
            _mask[i] = candRemove(_mask[i], d);
            changed = true;
          }
        }
        if (changed) {
          _history.add(HintTechnique.intersectionClaiming);
          return true;
        }
      }
    }
    return false;
  }

  /// Removes candidate [d] from cells of unit [line] that lie outside [box].
  bool _eliminateFromUnitOutsideBox(int line, int box, int d) {
    var changed = false;
    for (final i in _unitCells[line]) {
      if (BitsetGeometry.boxOf(i) == box - 18) continue;
      if (_cell[i] == 0 && candHas(_mask[i], d)) {
        _mask[i] = candRemove(_mask[i], d);
        changed = true;
      }
    }
    return changed;
  }

  bool _nakedSubset(int k, HintTechnique tag) {
    for (final unit in _unitCells) {
      final empties = [for (final i in unit) if (_cell[i] == 0) i];
      if (empties.length <= k) continue; // need cells left to eliminate from
      for (final combo in _combinations(empties, k)) {
        var union = 0;
        for (final i in combo) {
          union |= _mask[i];
        }
        if (candCount(union) != k) continue;
        var changed = false;
        for (final i in empties) {
          if (combo.contains(i)) continue;
          final trimmed = _mask[i] & ~union;
          if (trimmed != _mask[i]) {
            _mask[i] = trimmed;
            changed = true;
          }
        }
        if (changed) {
          _history.add(tag);
          return true;
        }
      }
    }
    return false;
  }

  bool _hiddenSubset(int k, HintTechnique tag) {
    for (final unit in _unitCells) {
      // Digits still open in this unit, and the cells each can go in.
      final digitCells = <int, List<int>>{};
      for (var d = 1; d <= 9; d++) {
        final cells = [
          for (final i in unit)
            if (_cell[i] == 0 && candHas(_mask[i], d)) i,
        ];
        if (cells.isNotEmpty) digitCells[d] = cells;
      }
      final digits = digitCells.keys.toList();
      if (digits.length <= k) continue;
      for (final combo in _combinations(digits, k)) {
        final cellSet = <int>{};
        for (final d in combo) {
          cellSet.addAll(digitCells[d]!);
        }
        if (cellSet.length != k) continue;
        // These k cells hold only these k digits — strip the rest.
        var comboMask = 0;
        for (final d in combo) {
          comboMask = candAdd(comboMask, d);
        }
        var changed = false;
        for (final i in cellSet) {
          final trimmed = _mask[i] & comboMask;
          if (trimmed != _mask[i]) {
            _mask[i] = trimmed;
            changed = true;
          }
        }
        if (changed) {
          _history.add(tag);
          return true;
        }
      }
    }
    return false;
  }
}

/// All size-[k] index combinations of [items], lexicographic order.
Iterable<List<int>> _combinations(List<int> items, int k) sync* {
  final n = items.length;
  if (k > n) return;
  final idx = List<int>.generate(k, (i) => i);
  while (true) {
    yield [for (final i in idx) items[i]];
    var p = k - 1;
    while (p >= 0 && idx[p] == p + n - k) {
      p--;
    }
    if (p < 0) return;
    idx[p]++;
    for (var q = p + 1; q < k; q++) {
      idx[q] = idx[q - 1] + 1;
    }
  }
}
