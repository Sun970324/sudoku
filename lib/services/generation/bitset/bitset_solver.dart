import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../models/hint.dart';
import 'bitset81.dart';
import 'candidates.dart';
import 'conversions.dart';
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
    HintTechnique.xWing,
    HintTechnique.skyscraper,
    HintTechnique.twoStringKite,
    HintTechnique.turbotFish,
    HintTechnique.xyWing,
    HintTechnique.simpleColoring,
    HintTechnique.multiColoring,
    HintTechnique.xyzWing,
    HintTechnique.wWing,
    HintTechnique.nakedQuad,
    HintTechnique.hiddenQuad,
    HintTechnique.swordfish,
    HintTechnique.jellyfish,
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

  /// Test-only: loads [board] + [candidates] verbatim (no recomputation) and
  /// runs technique [t] exactly once. Returns the resulting candidate grid,
  /// or null if the technique found nothing — so the ports can be checked
  /// against the hint engine's `candidatesFrom` fixture positions directly.
  @visibleForTesting
  List<List<Set<int>>>? debugApplyOnce(
    HintTechnique t,
    List<List<int>> board,
    List<List<Set<int>>> candidates,
  ) {
    _cell = List<int>.filled(81, 0);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        _cell[r * 9 + c] = board[r][c];
      }
    }
    _mask = candidatesToMasks(candidates);
    _history = <HintTechnique>[];
    if (!_apply(t)) return null;
    return masksToCandidates(_mask);
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
        HintTechnique.xWing => _fish(2, HintTechnique.xWing),
        HintTechnique.swordfish => _fish(3, HintTechnique.swordfish),
        HintTechnique.jellyfish => _fish(4, HintTechnique.jellyfish),
        HintTechnique.skyscraper ||
        HintTechnique.twoStringKite ||
        HintTechnique.turbotFish =>
          _singleDigitChain(t),
        HintTechnique.xyWing => _xyWing(withPivotZ: false),
        HintTechnique.xyzWing => _xyWing(withPivotZ: true),
        HintTechnique.wWing => _wWing(),
        HintTechnique.simpleColoring => _simpleColoring(),
        HintTechnique.multiColoring => _multiColoring(),
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

  /// Basic fish of size [k] (2=X-Wing, 3=Swordfish, 4=Jellyfish), rows-as-base
  /// then columns-as-base. Per digit each base line becomes a 9-bit mask of
  /// its candidate positions along the cover axis; a fish is [k] base lines
  /// (each with 2..[k] positions) whose position masks union to exactly [k]
  /// cover lines — then the digit falls off the cover lines outside the base.
  bool _fish(int k, HintTechnique tag) {
    for (var d = 1; d <= 9; d++) {
      for (final rowsAsBase in const [true, false]) {
        // lineMask[i] = 9-bit mask of cover positions of digit d in base line i.
        final lineMask = List<int>.filled(9, 0);
        for (var i = 0; i < 9; i++) {
          for (var j = 0; j < 9; j++) {
            final cell = rowsAsBase ? i * 9 + j : j * 9 + i;
            if (_cell[cell] == 0 && candHas(_mask[cell], d)) {
              lineMask[i] |= 1 << j;
            }
          }
        }
        final baseCandidates = [
          for (var i = 0; i < 9; i++)
            if (lineMask[i] != 0 &&
                candCount(lineMask[i]) >= 2 &&
                candCount(lineMask[i]) <= k)
              i,
        ];
        if (baseCandidates.length < k) continue;
        for (final combo in _combinations(baseCandidates, k)) {
          var cover = 0;
          for (final i in combo) {
            cover |= lineMask[i];
          }
          if (candCount(cover) != k) continue;
          // Eliminate d from the cover lines outside the base lines.
          var changed = false;
          for (var j = 0; j < 9; j++) {
            if (cover & (1 << j) == 0) continue;
            for (var i = 0; i < 9; i++) {
              if (combo.contains(i)) continue;
              final cell = rowsAsBase ? i * 9 + j : j * 9 + i;
              if (_cell[cell] == 0 && candHas(_mask[cell], d)) {
                _mask[cell] = candRemove(_mask[cell], d);
                changed = true;
              }
            }
          }
          if (changed) {
            _history.add(tag);
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Skyscraper / 2-String Kite / Turbot Fish — the strong-weak-strong
  /// single-digit pattern (`f1 =strong= p1 ~weak~ p2 =strong= f2`), ported
  /// from the hint engine's `_findSingleDigitChain` with the same
  /// classification (incl. the X-Wing degeneracy rejection), so the history
  /// labels match. Eliminations are one bit-intersection:
  /// `buddies[f1] & buddies[f2] & positions(d)` minus the pattern cells.
  bool _singleDigitChain(HintTechnique want) {
    for (var d = 1; d <= 9; d++) {
      // Conjugate pairs: units with exactly two open cells holding d.
      // (unit index u: 0-8 row, 9-17 col, 18-26 box — mirrors _unitCells.)
      final linkCells = <List<int>>[]; // [a, b, unitIndex]
      final positions = BitSet81();
      for (var i = 0; i < 81; i++) {
        if (_cell[i] == 0 && candHas(_mask[i], d)) positions.add(i);
      }
      for (var u = 0; u < 27; u++) {
        final inUnit = BitsetGeometry.units[u] & positions;
        if (inUnit.count != 2) continue;
        final pair = inUnit.toList();
        linkCells.add([pair[0], pair[1], u]);
      }

      for (var i = 0; i < linkCells.length; i++) {
        for (var j = i + 1; j < linkCells.length; j++) {
          final s1 = linkCells[i];
          final s2 = linkCells[j];
          for (var e1 = 0; e1 < 2; e1++) {
            final p1 = s1[e1], f1 = s1[1 - e1];
            for (var e2 = 0; e2 < 2; e2++) {
              final p2 = s2[e2], f2 = s2[1 - e2];
              if ({p1, f1, p2, f2}.length != 4) continue;
              if (!BitsetGeometry.buddies[p1].contains(p2)) continue;

              final cls = _classifyChain(s1[2], s2[2], p1, p2, f1, f2);
              if (cls != want) continue;

              final elim = BitsetGeometry.buddies[f1] &
                  BitsetGeometry.buddies[f2] &
                  positions;
              elim
                ..remove(p1)
                ..remove(f1)
                ..remove(p2)
                ..remove(f2);
              if (elim.isEmpty) continue;
              elim.forEach((cell) {
                _mask[cell] = candRemove(_mask[cell], d);
              });
              _history.add(want);
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// XY-Wing ([withPivotZ] false) and XYZ-Wing (true) share one shape: a
  /// pivot seeing two bivalue wings {x,z} and {y,z}; z falls out of every
  /// cell seeing both wings (and, for XYZ, the pivot too — its own z makes
  /// the pivot a third z-holder, so eliminations must see all three).
  bool _xyWing({required bool withPivotZ}) {
    final pivotSize = withPivotZ ? 3 : 2;
    for (var pivot = 0; pivot < 81; pivot++) {
      if (_cell[pivot] != 0 || candCount(_mask[pivot]) != pivotSize) continue;
      final pm = _mask[pivot];
      // Bivalue buddies whose pair is a subset of (pivot ∪ wing) shapes.
      final wings = <int>[];
      BitsetGeometry.buddies[pivot].forEach((b) {
        if (_cell[b] == 0 && candCount(_mask[b]) == 2) wings.add(b);
      });
      for (var i = 0; i < wings.length; i++) {
        for (var j = i + 1; j < wings.length; j++) {
          final m1 = _mask[wings[i]], m2 = _mask[wings[j]];
          final z = m1 & m2; // shared digit of the two wings
          if (candCount(z) != 1) continue;
          if (withPivotZ) {
            // XYZ: pivot = {x,y,z}, wings = {x,z},{y,z}: pivot ∪ wings == pivot.
            if ((m1 | m2) != pm) continue;
            if (pm & z == 0) continue;
          } else {
            // XY: pivot = {x,y} disjoint from z; wings cover pivot exactly.
            if (pm & z != 0) continue;
            if ((m1 | m2) & ~z != pm) continue;
          }
          final d = candDigits(z).first;
          var elim = BitsetGeometry.buddies[wings[i]] &
              BitsetGeometry.buddies[wings[j]];
          if (withPivotZ) elim.intersect(BitsetGeometry.buddies[pivot]);
          elim.remove(pivot);
          var changed = false;
          elim.forEach((cell) {
            if (_cell[cell] == 0 && candHas(_mask[cell], d)) {
              _mask[cell] = candRemove(_mask[cell], d);
              changed = true;
            }
          });
          if (changed) {
            _history.add(
                withPivotZ ? HintTechnique.xyzWing : HintTechnique.xyWing);
            return true;
          }
        }
      }
    }
    return false;
  }

  /// W-Wing: two bivalue cells with the same pair {a,b}, not seeing each
  /// other, bridged by a conjugate pair (strong link) on b whose ends see one
  /// wing each — one wing must then be a, so cells seeing both wings lose a.
  bool _wWing() {
    // Bivalue cells grouped by their exact pair mask.
    final byPair = <int, List<int>>{};
    for (var i = 0; i < 81; i++) {
      if (_cell[i] == 0 && candCount(_mask[i]) == 2) {
        byPair.putIfAbsent(_mask[i], () => []).add(i);
      }
    }
    for (final entry in byPair.entries) {
      final cells = entry.value;
      if (cells.length < 2) continue;
      final digits = candDigits(entry.key);
      for (var i = 0; i < cells.length; i++) {
        for (var j = i + 1; j < cells.length; j++) {
          final w1 = cells[i], w2 = cells[j];
          if (BitsetGeometry.buddies[w1].contains(w2)) continue;
          for (final b in digits) {
            final a = b == digits[0] ? digits[1] : digits[0];
            // A strong link on b whose ends see w1 and w2 respectively.
            final positions = BitSet81();
            for (var c = 0; c < 81; c++) {
              if (_cell[c] == 0 && candHas(_mask[c], b)) positions.add(c);
            }
            for (var u = 0; u < 27; u++) {
              final inUnit = BitsetGeometry.units[u] & positions;
              if (inUnit.count != 2) continue;
              final ends = inUnit.toList();
              // The link cells must be outside the wings themselves.
              if (ends.contains(w1) || ends.contains(w2)) continue;
              final sees1 = BitsetGeometry.buddies[ends[0]].contains(w1) &&
                  BitsetGeometry.buddies[ends[1]].contains(w2);
              final sees2 = BitsetGeometry.buddies[ends[0]].contains(w2) &&
                  BitsetGeometry.buddies[ends[1]].contains(w1);
              if (!sees1 && !sees2) continue;
              final elim =
                  BitsetGeometry.buddies[w1] & BitsetGeometry.buddies[w2];
              var changed = false;
              elim.forEach((cell) {
                if (_cell[cell] == 0 && candHas(_mask[cell], a)) {
                  _mask[cell] = candRemove(_mask[cell], a);
                  changed = true;
                }
              });
              if (changed) {
                _history.add(HintTechnique.wWing);
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }

  /// Simple Coloring: 2-color each conjugate-pair component of a digit.
  /// Rule 1 (wrap): two same-colored cells see each other -> that whole
  /// color is impossible. Rule 2 (trap): an outside cell seeing both colors
  /// loses the digit.
  bool _simpleColoring() {
    for (var d = 1; d <= 9; d++) {
      final positions = BitSet81();
      for (var i = 0; i < 81; i++) {
        if (_cell[i] == 0 && candHas(_mask[i], d)) positions.add(i);
      }
      for (final component in _colorComponents(d, positions)) {
        final (colorA, colorB) = component;
        // Rule 1: a color containing two cells that see each other is false.
        for (final color in [colorA, colorB]) {
          var clash = false;
          color.forEach((c1) {
            if (!clash &&
                (BitsetGeometry.buddies[c1] & color).isNotEmpty) {
              clash = true;
            }
          });
          if (clash) {
            var changed = false;
            color.forEach((cell) {
              if (candHas(_mask[cell], d)) {
                _mask[cell] = candRemove(_mask[cell], d);
                changed = true;
              }
            });
            if (changed) {
              _history.add(HintTechnique.simpleColoring);
              return true;
            }
          }
        }
        // Rule 2: outside cells seeing both colors.
        final seesA = BitSet81();
        colorA.forEach((c) => seesA.union(BitsetGeometry.buddies[c]));
        final seesB = BitSet81();
        colorB.forEach((c) => seesB.union(BitsetGeometry.buddies[c]));
        final trapped = (seesA & seesB & positions)
          ..subtract(colorA)
          ..subtract(colorB);
        if (trapped.isNotEmpty) {
          trapped.forEach((cell) {
            _mask[cell] = candRemove(_mask[cell], d);
          });
          _history.add(HintTechnique.simpleColoring);
          return true;
        }
      }
    }
    return false;
  }

  /// Multi-Coloring (HoDoKu wrap/trap between two clusters, mirroring the
  /// hint engine's findMultiColoring): for a digit with 2+ separate color
  /// clusters — wrap: a colour of cluster A seeing BOTH colours of cluster B
  /// can never be the digit; trap: if colour a (of A) sees colour c (of B),
  /// cells seeing both opposite colours b and d lose the digit.
  bool _multiColoring() {
    for (var d = 1; d <= 9; d++) {
      final positions = BitSet81();
      for (var i = 0; i < 81; i++) {
        if (_cell[i] == 0 && candHas(_mask[i], d)) positions.add(i);
      }
      final components = _colorComponents(d, positions);
      if (components.length < 2) continue;

      BitSet81 seen(BitSet81 color) {
        final s = BitSet81();
        color.forEach((c) => s.union(BitsetGeometry.buddies[c]));
        return s;
      }

      for (var i = 0; i < components.length; i++) {
        for (var j = 0; j < components.length; j++) {
          if (i == j) continue;
          final (a, b) = components[i];
          final (c, e) = components[j];
          // Wrap: a colour of A sees both colours of B -> that colour off.
          for (final color in [a, b]) {
            final s = seen(color);
            if (s.intersects(c) && s.intersects(e)) {
              var changed = false;
              color.forEach((cell) {
                if (candHas(_mask[cell], d)) {
                  _mask[cell] = candRemove(_mask[cell], d);
                  changed = true;
                }
              });
              if (changed) {
                _history.add(HintTechnique.multiColoring);
                return true;
              }
            }
          }
          // Trap: colour x of A sees colour y of B -> cells seeing both
          // opposites lose d.
          for (final (x, y, oppX, oppY) in [
            (a, c, b, e),
            (a, e, b, c),
            (b, c, a, e),
            (b, e, a, c),
          ]) {
            if (!seen(x).intersects(y)) continue;
            final trapped = (seen(oppX) & seen(oppY) & positions)
              ..subtract(a)
              ..subtract(b)
              ..subtract(c)
              ..subtract(e);
            if (trapped.isNotEmpty) {
              trapped.forEach((cell) {
                _mask[cell] = candRemove(_mask[cell], d);
              });
              _history.add(HintTechnique.multiColoring);
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Conjugate-pair components of digit [d] over [positions], each 2-colored
  /// by BFS. Only components with >= 2 cells are returned.
  List<(BitSet81, BitSet81)> _colorComponents(int d, BitSet81 positions) {
    // Adjacency: conjugate pairs (units with exactly 2 cells of d).
    final adjacency = <int, List<int>>{};
    for (var u = 0; u < 27; u++) {
      final inUnit = BitsetGeometry.units[u] & positions;
      if (inUnit.count != 2) continue;
      final pair = inUnit.toList();
      adjacency.putIfAbsent(pair[0], () => []).add(pair[1]);
      adjacency.putIfAbsent(pair[1], () => []).add(pair[0]);
    }
    final visited = <int>{};
    final components = <(BitSet81, BitSet81)>[];
    final starts = adjacency.keys.toList()..sort();
    for (final start in starts) {
      if (!visited.add(start)) continue;
      final colorA = BitSet81()..add(start);
      final colorB = BitSet81();
      final queue = [(start, 0)];
      while (queue.isNotEmpty) {
        final (cell, color) = queue.removeAt(0);
        for (final next in adjacency[cell]!) {
          if (!visited.add(next)) continue;
          (color == 0 ? colorB : colorA).add(next);
          queue.add((next, 1 - color));
        }
      }
      if (colorA.count + colorB.count >= 2) {
        components.add((colorA, colorB));
      }
    }
    return components;
  }

  /// Same classification as the hint engine's `_classifySingleDigitChain`:
  /// null = the X-Wing degeneracy (skipped — the fish detector owns it).
  HintTechnique? _classifyChain(
      int u1, int u2, int p1, int p2, int f1, int f2) {
    final lineLink = p1 ~/ 9 == p2 ~/ 9 || p1 % 9 == p2 % 9;
    final bothRows = u1 < 9 && u2 < 9;
    final bothCols = u1 >= 9 && u1 < 18 && u2 >= 9 && u2 < 18;
    final rowAndCol = (u1 < 9 && u2 >= 9 && u2 < 18) ||
        (u2 < 9 && u1 >= 9 && u1 < 18);

    if ((bothRows || bothCols) && lineLink) {
      if (bothRows && f1 % 9 == f2 % 9) return null;
      if (bothCols && f1 ~/ 9 == f2 ~/ 9) return null;
      return HintTechnique.skyscraper;
    }
    if (rowAndCol && !lineLink) return HintTechnique.twoStringKite;
    return HintTechnique.turbotFish;
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
