import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../models/difficulty.dart';
import '../../../models/hint.dart';
import '../human_solver.dart' show SolveResult;
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
    required this.techniqueCounts,
  });

  /// Whether every cell was filled using only the enabled techniques.
  final bool solved;

  /// The final 9x9 board (0 = still empty when unsolved).
  final List<List<int>> board;

  /// Every technique application, in order.
  final List<HintTechnique> history;

  /// How many times each technique in [history] was used.
  final Map<HintTechnique, int> techniqueCounts;

  /// This result in the shape [DifficultyEvaluator] scores — same fields, so
  /// every difficulty-labelling site in the app can use the bitset solver as
  /// the single authority (HoDoKu's one-solver principle) without touching
  /// the evaluator.
  SolveResult toSolveResult() => SolveResult(
        solved: solved,
        board: board,
        history: history,
        techniqueCounts: techniqueCounts,
      );
}

class BitsetSolver {
  /// Techniques this solver knows, in ascending-difficulty priority order.
  static const order = <HintTechnique>[
    HintTechnique.fullHouse,
    HintTechnique.nakedSingle,
    HintTechnique.hiddenSingle,
    HintTechnique.intersectionPointing,
    HintTechnique.intersectionClaiming,
    HintTechnique.lockedPair,
    HintTechnique.nakedPair,
    HintTechnique.hiddenPair,
    HintTechnique.lockedTriple,
    HintTechnique.nakedTriple,
    HintTechnique.hiddenTriple,
    HintTechnique.xWing,
    HintTechnique.skyscraper,
    HintTechnique.twoStringKite,
    HintTechnique.turbotFish,
    HintTechnique.xyWing,
    HintTechnique.remotePair,
    HintTechnique.simpleColoring,
    HintTechnique.multiColoring,
    HintTechnique.xyzWing,
    HintTechnique.wWing,
    HintTechnique.nakedQuad,
    HintTechnique.hiddenQuad,
    HintTechnique.swordfish,
    HintTechnique.jellyfish,
    HintTechnique.finnedXWing,
    HintTechnique.sashimiXWing,
    HintTechnique.bugPlusOne,
    HintTechnique.uniqueRectangleType1,
    HintTechnique.uniqueRectangleType2,
    HintTechnique.uniqueRectangleType3,
    HintTechnique.uniqueRectangleType4,
    HintTechnique.xChain,
    HintTechnique.wxyzWing,
    HintTechnique.alsXZ,
    HintTechnique.xyChain,
  ];

  late List<int> _cell; // 81 placed values (0 = empty)
  late List<int> _mask; // 81 candidate bitmasks (0 for placed cells)
  late List<HintTechnique> _history;

  /// Solves [input] (9x9, 0 = empty) with the enabled subset of [order]. When
  /// [enabled] is null every technique is used. Returns the final board plus
  /// the technique log; `solved` is true only if every cell was filled.
  ///
  /// With [maxDifficulty] set the solve aborts the moment it proves too hard
  /// for that tier — HoDoKu's generation-time optimisation, integrated into
  /// the solver exactly like SudokuSolver.getHint ("Wenn das Puzzle zu schwer
  /// ist, gleich abbrechen"): each applied step accumulates score/level, and
  /// an over-tier step or a cumulative score past the tier's band ends the
  /// solve with `solved == false` (indistinguishable from stuck — generation
  /// rejects both).
  BitsetSolveResult solve(
    List<List<int>> input, {
    Set<HintTechnique>? enabled,
    Difficulty? maxDifficulty,
  }) {
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
    final scoreCeiling =
        maxDifficulty == null ? null : difficultyScoreBands[maxDifficulty];
    var score = 0;
    var seenSteps = 0;
    var aborted = false;

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
      if (maxDifficulty != null) {
        // Score the steps this iteration appended (techniques may log more
        // than one entry only in theory; the loop breaks on first success).
        while (seenSteps < _history.length) {
          final t = _history[seenSteps++];
          if (techniqueDifficulty[t]!.index > maxDifficulty.index) {
            aborted = true; // over-tier step — too hard
          }
          score += techniqueBaseScore[t]!;
          if (scoreCeiling != null && score >= scoreCeiling) {
            aborted = true; // past the tier's cumulative band — too hard
          }
        }
        if (aborted) break;
      }
    }

    final counts = <HintTechnique, int>{};
    for (final t in _history) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return BitsetSolveResult(
      solved: !aborted && _cell.every((v) => v != 0),
      board: [for (var r = 0; r < 9; r++) _cell.sublist(r * 9, r * 9 + 9)],
      history: _history,
      techniqueCounts: counts,
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
        HintTechnique.lockedPair => _nakedSubset(2, lockedOnly: true),
        HintTechnique.lockedTriple => _nakedSubset(3, lockedOnly: true),
        HintTechnique.nakedPair => _nakedSubset(2),
        HintTechnique.nakedTriple => _nakedSubset(3),
        HintTechnique.nakedQuad => _nakedSubset(4),
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
        HintTechnique.remotePair => _remotePair(),
        HintTechnique.finnedXWing => _finnedXWing(wantSashimi: false),
        HintTechnique.sashimiXWing => _finnedXWing(wantSashimi: true),
        HintTechnique.finnedSwordfish =>
          _finnedFishN(3, HintTechnique.finnedSwordfish),
        HintTechnique.finnedJellyfish =>
          _finnedFishN(4, HintTechnique.finnedJellyfish),
        HintTechnique.sueDeCoq => _sueDeCoq(),
        HintTechnique.tripleFirework => _tripleFirework(),
        HintTechnique.bugPlusOne => _bugPlusOne(),
        HintTechnique.uniqueRectangleType1 => _uniqueRectangle(1),
        HintTechnique.uniqueRectangleType2 => _uniqueRectangle(2),
        HintTechnique.uniqueRectangleType3 => _uniqueRectangle(3),
        HintTechnique.uniqueRectangleType4 => _uniqueRectangle(4),
        HintTechnique.xChain => _xChain(),
        HintTechnique.wxyzWing => _alsXZ(wxyzOnly: true),
        HintTechnique.alsXZ => _alsXZ(wxyzOnly: false),
        HintTechnique.xyChain => _xyChain(),
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

  /// Naked subset of size [k], HoDoKu-style (SimpleSolver.findNakedXle): the
  /// eliminations run over EVERY unit the subset cells share (a box-and-line
  /// confined pair strips both units in ONE step), and the step is labelled
  /// Locked Pair/Triple exactly under HoDoKu's condition — size < 4, cells
  /// confined to a box AND a line, eliminations found in more than one shared
  /// unit. With [lockedOnly] only locked-labelled finds fire (the separate
  /// lockedPair/lockedTriple order slots); without it the locked shapes have
  /// already been consumed, so plain naked labels stay clean.
  bool _nakedSubset(int k, {bool lockedOnly = false}) {
    for (final unit in _unitCells) {
      final empties = [for (final i in unit) if (_cell[i] == 0) i];
      if (empties.length <= k) continue; // need cells left to eliminate from
      for (final combo in _combinations(empties, k)) {
        var union = 0;
        for (final i in combo) {
          union |= _mask[i];
        }
        if (candCount(union) != k) continue;

        // Every unit shared by ALL subset cells (its own unit plus, for a
        // box-line confined subset, the crossing one).
        final sameRow = combo.every((i) => i ~/ 9 == combo.first ~/ 9);
        final sameCol = combo.every((i) => i % 9 == combo.first % 9);
        final sameBox = combo.every(
            (i) => BitsetGeometry.boxOf(i) == BitsetGeometry.boxOf(combo.first));
        final sharedUnits = [
          if (sameRow) combo.first ~/ 9,
          if (sameCol) 9 + combo.first % 9,
          if (sameBox) 18 + BitsetGeometry.boxOf(combo.first),
        ];
        final lockedShape = k < 4 && sameBox && (sameRow || sameCol);
        if (lockedOnly && !lockedShape) continue;

        var changedUnits = 0;
        for (final u in sharedUnits) {
          var changedHere = false;
          for (final i in _unitCells[u]) {
            if (combo.contains(i) || _cell[i] != 0) continue;
            final trimmed = _mask[i] & ~union;
            if (trimmed != _mask[i]) {
              _mask[i] = trimmed;
              changedHere = true;
            }
          }
          if (changedHere) changedUnits++;
        }
        if (changedUnits == 0) continue;

        final isLocked = lockedShape && changedUnits > 1;
        if (lockedOnly && !isLocked) {
          // Locked shape but single-unit eliminations: HoDoKu treats that as
          // a plain naked subset — but we've already applied the strikes, so
          // record it under its naked label rather than pretending nothing
          // happened.
          _history.add(k == 2 ? HintTechnique.nakedPair : HintTechnique.nakedTriple);
          return true;
        }
        _history.add(isLocked
            ? (k == 2 ? HintTechnique.lockedPair : HintTechnique.lockedTriple)
            : switch (k) {
                2 => HintTechnique.nakedPair,
                3 => HintTechnique.nakedTriple,
                _ => HintTechnique.nakedQuad,
              });
        return true;
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

  /// X-Chain: a single-digit alternating chain that starts and ends with a
  /// strong link (conjugate pair), so one of the two ends must be the digit
  /// — cells seeing both ends lose it. Iterative deepening 4..12 nodes like
  /// the hint engine's `_searchAic(useBivalue: false)`, preferring short
  /// chains.
  bool _xChain() {
    for (var d = 1; d <= 9; d++) {
      final positions = BitSet81();
      for (var i = 0; i < 81; i++) {
        if (_cell[i] == 0 && candHas(_mask[i], d)) positions.add(i);
      }
      // Strong neighbours: conjugate-pair partners per unit.
      final strong = <int, List<int>>{};
      for (var u = 0; u < 27; u++) {
        final inUnit = BitsetGeometry.units[u] & positions;
        if (inUnit.count != 2) continue;
        final pair = inUnit.toList();
        strong.putIfAbsent(pair[0], () => []).add(pair[1]);
        strong.putIfAbsent(pair[1], () => []).add(pair[0]);
      }
      if (strong.length < 4) continue;

      final path = <int>[];
      // Extends [path] (whose last link was strong) by weak+strong pairs.
      bool extend(int maxNodes) {
        final last = path.last;
        // Even node count & both end-links strong -> try eliminations.
        if (path.length >= 4 && path.length.isEven) {
          final elim = BitsetGeometry.buddies[path.first] &
              BitsetGeometry.buddies[last] &
              positions;
          for (final p in path) {
            elim.remove(p);
          }
          if (elim.isNotEmpty) {
            elim.forEach((cell) {
              _mask[cell] = candRemove(_mask[cell], d);
            });
            return true;
          }
        }
        if (path.length + 2 > maxNodes) return false;
        // Weak step to any seen candidate, then a strong step from there.
        final weak = BitsetGeometry.buddies[last] & positions;
        var found = false;
        weak.forEach((via) {
          if (found || path.contains(via)) return;
          final nexts = strong[via];
          if (nexts == null) return;
          for (final next in nexts) {
            if (found || path.contains(next) || next == via) continue;
            path
              ..add(via)
              ..add(next);
            if (extend(maxNodes)) {
              found = true;
              return;
            }
            path
              ..removeLast()
              ..removeLast();
          }
        });
        return found;
      }

      for (var maxNodes = 4; maxNodes <= 12; maxNodes += 2) {
        for (final start in strong.keys.toList()..sort()) {
          for (final second in strong[start]!) {
            path
              ..clear()
              ..add(start)
              ..add(second);
            if (extend(maxNodes)) {
              _history.add(HintTechnique.xChain);
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// XY-Chain: a chain of bivalue cells, each passing its "other" digit to
  /// the next peer cell that holds it; when the passed digit comes back to
  /// the start's reserved z (chain of 4+ cells), one end must be z — cells
  /// seeing both ends lose z. Mirrors the engine's finder (min 4 cells so
  /// naked-pair/XY-Wing shapes stay with their own techniques; depth 25).
  bool _xyChain() {
    final bivalue = <int>[];
    for (var i = 0; i < 81; i++) {
      if (_cell[i] == 0 && candCount(_mask[i]) == 2) bivalue.add(i);
    }
    if (bivalue.length < 4) return false;

    final path = <int>[];
    bool extend(int current, int needed, int z) {
      if (path.length >= 25) return false;
      final nexts = BitsetGeometry.buddies[current];
      for (final next in bivalue) {
        if (path.contains(next)) continue;
        if (!nexts.contains(next)) continue;
        if (!candHas(_mask[next], needed)) continue;
        final other = candDigits(candRemove(_mask[next], needed)).first;
        path.add(next);
        if (other == z && path.length >= 4) {
          final elim = BitsetGeometry.buddies[path.first] &
              BitsetGeometry.buddies[next];
          for (final p in path) {
            elim.remove(p);
          }
          var changed = false;
          elim.forEach((cell) {
            if (_cell[cell] == 0 && candHas(_mask[cell], z)) {
              _mask[cell] = candRemove(_mask[cell], z);
              changed = true;
            }
          });
          if (changed) return true;
        }
        if (extend(next, other, z)) return true;
        path.removeLast();
      }
      return false;
    }

    for (final start in bivalue) {
      final digits = candDigits(_mask[start]);
      for (final z in digits) {
        final a = digits.firstWhere((d) => d != z);
        path
          ..clear()
          ..add(start);
        if (extend(start, a, z)) {
          _history.add(HintTechnique.xyChain);
          return true;
        }
      }
    }
    return false;
  }

  /// ALS-XZ (single restricted common): two cell-disjoint Almost Locked
  /// Sets A and B with a restricted common digit x (every x-cell of A sees
  /// every x-cell of B, so x can't be in both) and another common digit z —
  /// at least one of A/B keeps z, so cells seeing every z-cell of both lose
  /// z. With [wxyzOnly], only the classic WXYZ-Wing shape is reported (one
  /// ALS is a single bivalue cell and the pattern spans 4 cells).
  bool _alsXZ({required bool wxyzOnly}) {
    // Every ALS of 1..4 cells per unit: k cells holding k+1 digits.
    final alsList = <(BitSet81, int)>[]; // (cells, digit-union mask)
    final seen = <String>{};
    for (var u = 0; u < 27; u++) {
      final empties = [
        for (final i in _unitCells[u])
          if (_cell[i] == 0 && candCount(_mask[i]) >= 2) i,
      ];
      for (var k = 1; k <= 4 && k <= empties.length; k++) {
        for (final combo in _combinations(empties, k)) {
          var union = 0;
          for (final i in combo) {
            union |= _mask[i];
          }
          if (candCount(union) != k + 1) continue;
          final cells = BitSet81();
          for (final i in combo) {
            cells.add(i);
          }
          if (seen.add('${cells.hashCode}:$union')) {
            alsList.add((cells, union));
          }
        }
      }
    }

    for (var i = 0; i < alsList.length; i++) {
      for (var j = i + 1; j < alsList.length; j++) {
        final (aCells, aMask) = alsList[i];
        final (bCells, bMask) = alsList[j];
        if (aCells.intersects(bCells)) continue;
        if (wxyzOnly &&
            !(aCells.count + bCells.count == 4 &&
                (aCells.count == 1 || bCells.count == 1))) {
          continue;
        }
        final commons = aMask & bMask;
        if (candCount(commons) < 2) continue;

        for (final x in candDigits(commons)) {
          // Restricted common: every x-cell of A sees every x-cell of B.
          var xa = BitSet81(), xb = BitSet81();
          aCells.forEach((c) {
            if (candHas(_mask[c], x)) xa.add(c);
          });
          bCells.forEach((c) {
            if (candHas(_mask[c], x)) xb.add(c);
          });
          if (xa.isEmpty || xb.isEmpty) continue;
          var restricted = true;
          xa.forEach((ca) {
            if (restricted && !BitsetGeometry.buddies[ca].containsAll(xb)) {
              restricted = false;
            }
          });
          if (!restricted) continue;

          for (final z in candDigits(commons)) {
            if (z == x) continue;
            // Cells seeing EVERY z-cell of A and B lose z.
            var sight = BitSet81.all();
            var zCells = BitSet81();
            for (final cellsOf in [aCells, bCells]) {
              cellsOf.forEach((c) {
                if (candHas(_mask[c], z)) {
                  sight.intersect(BitsetGeometry.buddies[c]);
                  zCells.add(c);
                }
              });
            }
            sight.subtract(aCells);
            sight.subtract(bCells);
            var changed = false;
            sight.forEach((cell) {
              if (_cell[cell] == 0 && candHas(_mask[cell], z)) {
                _mask[cell] = candRemove(_mask[cell], z);
                changed = true;
              }
            });
            if (changed) {
              _history.add(
                  wxyzOnly ? HintTechnique.wxyzWing : HintTechnique.alsXZ);
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Remote Pair: a simple path of same-pair bivalue cells, each step a
  /// peer link. Odd link-count paths of 4+ cells force opposite values on
  /// the two ends, so cells seeing both ends lose BOTH digits. DFS like the
  /// hint engine's (depth-capped; pools are tiny).
  bool _remotePair() {
    final byPair = <int, List<int>>{};
    for (var i = 0; i < 81; i++) {
      if (_cell[i] == 0 && candCount(_mask[i]) == 2) {
        byPair.putIfAbsent(_mask[i], () => []).add(i);
      }
    }
    for (final entry in byPair.entries) {
      final pool = entry.value;
      if (pool.length < 4) continue;
      final pairMask = entry.key;
      final path = <int>[];
      bool extend(int last) {
        if (path.length >= 4 && (path.length - 1).isOdd) {
          final elim =
              BitsetGeometry.buddies[path.first] & BitsetGeometry.buddies[last];
          for (final p in path) {
            elim.remove(p);
          }
          var changed = false;
          elim.forEach((cell) {
            if (_cell[cell] == 0 && _mask[cell] & pairMask != 0) {
              final trimmed = _mask[cell] & ~pairMask;
              if (trimmed != _mask[cell]) {
                _mask[cell] = trimmed;
                changed = true;
              }
            }
          });
          if (changed) return true;
        }
        if (path.length >= 20) return false;
        for (final next in pool) {
          if (path.contains(next)) continue;
          if (!BitsetGeometry.buddies[last].contains(next)) continue;
          path.add(next);
          if (extend(next)) return true;
          path.removeLast();
        }
        return false;
      }

      for (final start in pool) {
        path
          ..clear()
          ..add(start);
        if (extend(start)) {
          _history.add(HintTechnique.remotePair);
          return true;
        }
      }
    }
    return false;
  }

  /// Finned/Sashimi X-Wing (rows-as-base then cols-as-base, like the hint
  /// engine): a clean base line with exactly 2 cover positions + a fin line
  /// with overlap and extra fins. Finned keeps both cover positions in the
  /// fin line (overlap 2), Sashimi only one (overlap 1). Eliminations: plain
  /// X-Wing targets that additionally see EVERY fin cell.
  bool _finnedXWing({required bool wantSashimi}) {
    for (var d = 1; d <= 9; d++) {
      for (final rowsAsBase in const [true, false]) {
        final lineMask = List<int>.filled(9, 0);
        for (var i = 0; i < 9; i++) {
          for (var j = 0; j < 9; j++) {
            final cell = rowsAsBase ? i * 9 + j : j * 9 + i;
            if (_cell[cell] == 0 && candHas(_mask[cell], d)) {
              lineMask[i] |= 1 << j;
            }
          }
        }
        for (var clean = 0; clean < 9; clean++) {
          if (candCount(lineMask[clean]) != 2) continue;
          final cover = lineMask[clean];
          for (var fin = 0; fin < 9; fin++) {
            if (fin == clean || lineMask[fin] == 0) continue;
            final fins = lineMask[fin] & ~cover;
            final overlap = lineMask[fin] & cover;
            if (fins == 0 || overlap == 0) continue;
            if ((candCount(overlap) == 1) != wantSashimi) continue;

            // Fin cells as board indices; targets must see all of them.
            var finBuddies = BitSet81.all();
            for (var j = 0; j < 9; j++) {
              if (fins & (1 << j) == 0) continue;
              final cell = rowsAsBase ? fin * 9 + j : j * 9 + fin;
              finBuddies.intersect(BitsetGeometry.buddies[cell]);
            }
            var changed = false;
            for (var j = 0; j < 9; j++) {
              if (cover & (1 << j) == 0) continue;
              for (var i = 0; i < 9; i++) {
                if (i == clean || i == fin) continue;
                final cell = rowsAsBase ? i * 9 + j : j * 9 + i;
                if (_cell[cell] == 0 &&
                    candHas(_mask[cell], d) &&
                    finBuddies.contains(cell)) {
                  _mask[cell] = candRemove(_mask[cell], d);
                  changed = true;
                }
              }
            }
            if (changed) {
              _history.add(wantSashimi
                  ? HintTechnique.sashimiXWing
                  : HintTechnique.finnedXWing);
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Finned Swordfish (size 3) / Finned Jellyfish (size 4): [size] base lines
  /// whose combined positions span size+1..size+2 cover positions; picking
  /// [size] of them as the cover leaves the rest as fins. A cover cell outside
  /// the base lines that sees EVERY fin loses the digit. Generalizes
  /// [_finnedXWing] (which owns size 2, incl. the sashimi split).
  bool _finnedFishN(int size, HintTechnique tag) {
    for (var d = 1; d <= 9; d++) {
      for (final rowsAsBase in const [true, false]) {
        final lineMask = List<int>.filled(9, 0);
        for (var i = 0; i < 9; i++) {
          for (var j = 0; j < 9; j++) {
            final cell = rowsAsBase ? i * 9 + j : j * 9 + i;
            if (_cell[cell] == 0 && candHas(_mask[cell], d)) {
              lineMask[i] |= 1 << j;
            }
          }
        }
        final baseLines = [
          for (var i = 0; i < 9; i++)
            if (candCount(lineMask[i]) >= 2 && candCount(lineMask[i]) <= size + 2)
              i,
        ];
        if (baseLines.length < size) continue;

        for (final base in _combinations(baseLines, size)) {
          var spanned = 0;
          for (final i in base) {
            spanned |= lineMask[i];
          }
          if (candCount(spanned) <= size || candCount(spanned) > size + 2) {
            continue;
          }
          final spannedCols = [
            for (var j = 0; j < 9; j++)
              if (spanned & (1 << j) != 0) j,
          ];
          for (final coverCols in _combinations(spannedCols, size)) {
            var cover = 0;
            for (final j in coverCols) {
              cover |= 1 << j;
            }
            // Fins = base positions outside the cover; every base line must
            // still reach the cover.
            var finBuddies = BitSet81.all();
            var hasFin = false;
            var allReach = true;
            for (final i in base) {
              if (lineMask[i] & cover == 0) allReach = false;
              final finBits = lineMask[i] & ~cover;
              for (var j = 0; j < 9; j++) {
                if (finBits & (1 << j) == 0) continue;
                hasFin = true;
                final cell = rowsAsBase ? i * 9 + j : j * 9 + i;
                finBuddies.intersect(BitsetGeometry.buddies[cell]);
              }
            }
            if (!hasFin || !allReach) continue;

            var changed = false;
            for (final j in coverCols) {
              for (var i = 0; i < 9; i++) {
                if (base.contains(i)) continue;
                final cell = rowsAsBase ? i * 9 + j : j * 9 + i;
                if (_cell[cell] == 0 &&
                    candHas(_mask[cell], d) &&
                    finBuddies.contains(cell)) {
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
    }
    return false;
  }

  /// Every Almost Locked Set in [pool] (1..4 cells holding exactly one more
  /// digit than cells) as (cells, digit-union mask).
  List<(List<int>, int)> _alsSubsetsIn(List<int> pool) {
    final out = <(List<int>, int)>[];
    for (var size = 1; size <= 4 && size <= pool.length; size++) {
      for (final combo in _combinations(pool, size)) {
        var union = 0;
        for (final i in combo) {
          union |= _mask[i];
        }
        if (candCount(union) == size + 1) out.add((combo, union));
      }
    }
    return out;
  }

  /// Sue de Coq (classic disjoint form, ported from the hint engine's
  /// findSueDeCoq): 2-3 cells C on a box/line intersection with candidate
  /// union V (|V| >= |C|+2), an ALS A on the rest of the line and an ALS B on
  /// the rest of the box — cell-disjoint, digit-disjoint — with exactly |C|-2
  /// digits of V outside A∪B. Then A's digits (+the leftover) fall off the
  /// rest of the line and B's (+leftover) off the rest of the box.
  bool _sueDeCoq() {
    for (var box = 0; box < 9; box++) {
      final br = box ~/ 3 * 3, bc = box % 3 * 3;
      final boxCells = [
        for (final i in _unitCells[18 + box])
          if (_cell[i] == 0) i,
      ];
      for (final lineIsRow in const [true, false]) {
        for (var t = 0; t < 3; t++) {
          final lineIdx = lineIsRow ? br + t : bc + t;
          final lineCells = [
            for (final i in _unitCells[lineIsRow ? lineIdx : 9 + lineIdx])
              if (_cell[i] == 0) i,
          ];
          final inter = [
            for (final i in lineCells)
              if (BitsetGeometry.boxOf(i) == box) i,
          ];
          if (inter.length < 2) continue;

          for (var k = 2; k <= inter.length; k++) {
            for (final c in _combinations(inter, k)) {
              var v = 0;
              for (final i in c) {
                v |= _mask[i];
              }
              if (candCount(v) < k + 2) continue;
              final linePool = [
                for (final i in lineCells)
                  if (!c.contains(i)) i,
              ];
              final boxPool = [
                for (final i in boxCells)
                  if (!c.contains(i)) i,
              ];
              for (final (aCells, aMask) in _alsSubsetsIn(linePool)) {
                for (final (bCells, bMask) in _alsSubsetsIn(boxPool)) {
                  if (aCells.any(bCells.contains)) continue;
                  if (aMask & bMask != 0) continue;
                  final rem = v & ~aMask & ~bMask;
                  if (candCount(rem) != k - 2) continue;

                  final goneLine = aMask | rem;
                  final goneBox = bMask | rem;
                  var changed = false;
                  for (final i in linePool) {
                    if (aCells.contains(i)) continue;
                    final trimmed = _mask[i] & ~goneLine;
                    if (trimmed != _mask[i]) {
                      _mask[i] = trimmed;
                      changed = true;
                    }
                  }
                  for (final i in boxPool) {
                    if (bCells.contains(i)) continue;
                    final trimmed = _mask[i] & ~goneBox;
                    if (trimmed != _mask[i]) {
                      _mask[i] = trimmed;
                      changed = true;
                    }
                  }
                  if (changed) {
                    _history.add(HintTechnique.sueDeCoq);
                    return true;
                  }
                }
              }
            }
          }
        }
      }
    }
    return false;
  }

  /// Triple Firework (ported from the hint engine): a cross cell (r,c), three
  /// digits each confined on row r to the box plus at most one shared row
  /// wing, and on column c to the box plus one shared column wing. The three
  /// cells {cross, rowWing, colWing} then hold exactly those three digits —
  /// so they lose every other candidate, and the box's other cells lose all
  /// three digits.
  bool _tripleFirework() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (_cell[r * 9 + c] != 0) continue;
        final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
        final eligible = <int>[];
        final rowOut = <int, int>{}, colOut = <int, int>{}; // digit -> cell
        final rowOutN = <int, int>{}, colOutN = <int, int>{};
        for (var d = 1; d <= 9; d++) {
          var inRow = false, inCol = false, rN = 0, cN = 0, rCell = -1, cCell = -1;
          for (var j = 0; j < 9; j++) {
            if (_cell[r * 9 + j] == 0 && candHas(_mask[r * 9 + j], d)) {
              inRow = true;
              if (j ~/ 3 != c ~/ 3) {
                rN++;
                rCell = r * 9 + j;
              }
            }
            if (_cell[j * 9 + c] == 0 && candHas(_mask[j * 9 + c], d)) {
              inCol = true;
              if (j ~/ 3 != r ~/ 3) {
                cN++;
                cCell = j * 9 + c;
              }
            }
          }
          if (inRow && inCol && rN <= 1 && cN <= 1) {
            eligible.add(d);
            rowOutN[d] = rN;
            colOutN[d] = cN;
            if (rN == 1) rowOut[d] = rCell;
            if (cN == 1) colOut[d] = cCell;
          }
        }
        if (eligible.length < 3) continue;

        for (final triple in _combinations(eligible, 3)) {
          final rowWings = {for (final d in triple) if (rowOutN[d] == 1) rowOut[d]!};
          final colWings = {for (final d in triple) if (colOutN[d] == 1) colOut[d]!};
          if (rowWings.length != 1 || colWings.length != 1) continue;
          final rowWing = rowWings.first, colWing = colWings.first;
          var digits = 0;
          for (final d in triple) {
            digits |= 1 << d;
          }
          final crossCell = r * 9 + c;
          if (_mask[crossCell] & digits == 0 ||
              _mask[rowWing] & digits == 0 ||
              _mask[colWing] & digits == 0) {
            continue;
          }
          var changed = false;
          for (final cell in [crossCell, rowWing, colWing]) {
            final trimmed = _mask[cell] & digits;
            if (_cell[cell] == 0 && trimmed != _mask[cell]) {
              _mask[cell] = trimmed;
              changed = true;
            }
          }
          for (var rr = br; rr < br + 3; rr++) {
            if (rr == r) continue;
            for (var cc = bc; cc < bc + 3; cc++) {
              if (cc == c) continue;
              final cell = rr * 9 + cc;
              final trimmed = _mask[cell] & ~digits;
              if (_cell[cell] == 0 && trimmed != _mask[cell]) {
                _mask[cell] = trimmed;
                changed = true;
              }
            }
          }
          if (changed) {
            _history.add(HintTechnique.tripleFirework);
            return true;
          }
        }
      }
    }
    return false;
  }

  /// BUG+1: every empty cell bivalue except exactly one trivalue cell; for
  /// each of its 3 candidates, if EXCLUDING it would leave every unit's
  /// remaining candidates appearing exactly twice (the deadly BUG shape),
  /// that candidate must be the cell's value — place it.
  bool _bugPlusOne() {
    var extra = -1;
    for (var i = 0; i < 81; i++) {
      if (_cell[i] != 0) continue;
      final n = candCount(_mask[i]);
      if (n == 2) continue;
      if (n == 3 && extra == -1) {
        extra = i;
        continue;
      }
      return false; // second 3-cell, or any other count — not a BUG+1 shape
    }
    if (extra == -1) return false;

    for (final digit in candDigits(_mask[extra])) {
      final reduced = candRemove(_mask[extra], digit);
      var deadly = true;
      for (var u = 0; u < 27 && deadly; u++) {
        final counts = List<int>.filled(10, 0);
        for (final i in _unitCells[u]) {
          if (_cell[i] != 0) continue;
          final m = i == extra ? reduced : _mask[i];
          for (final d in candDigits(m)) {
            counts[d]++;
          }
        }
        for (var d = 1; d <= 9; d++) {
          if (counts[d] != 0 && counts[d] != 2) {
            deadly = false;
            break;
          }
        }
      }
      if (deadly) {
        _place(extra, digit);
        _history.add(HintTechnique.bugPlusOne);
        return true;
      }
    }
    return false;
  }

  /// Unique Rectangle types 1-4, sharing the hint engine's base scan: 4 empty
  /// cells at 2 rows x 2 cols spanning exactly 2 boxes whose masks share
  /// exactly 2 common digits (the deadly pair).
  bool _uniqueRectangle(int type) {
    for (var r1 = 0; r1 < 9; r1++) {
      for (var r2 = r1 + 1; r2 < 9; r2++) {
        final sameBoxRow = r1 ~/ 3 == r2 ~/ 3;
        for (var c1 = 0; c1 < 9; c1++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            if (sameBoxRow == (c1 ~/ 3 == c2 ~/ 3)) continue;
            final cells = [r1 * 9 + c1, r1 * 9 + c2, r2 * 9 + c1, r2 * 9 + c2];
            if (cells.any((i) => _cell[i] != 0 || candCount(_mask[i]) < 2)) {
              continue;
            }
            var common = _mask[cells[0]];
            for (final i in cells.skip(1)) {
              common &= _mask[i];
            }
            if (candCount(common) != 2) continue;
            // Box groups: share a column when the rows share a box-row band,
            // a row otherwise (same as the engine's _URBase geometry).
            final g1 = sameBoxRow
                ? [r1 * 9 + c1, r2 * 9 + c1]
                : [r1 * 9 + c1, r1 * 9 + c2];
            final g2 = sameBoxRow
                ? [r1 * 9 + c2, r2 * 9 + c2]
                : [r2 * 9 + c1, r2 * 9 + c2];
            if (_urType(type, common, cells, g1, g2)) return true;
          }
        }
      }
    }
    return false;
  }

  bool _urType(
      int type, int pairMask, List<int> cells, List<int> g1, List<int> g2) {
    bool pure(List<int> g) => g.every((i) => _mask[i] == pairMask);

    switch (type) {
      case 1:
        final pureCells = cells.where((i) => _mask[i] == pairMask).length;
        if (pureCells != 3) return false;
        final extra = cells.firstWhere((i) => _mask[i] != pairMask);
        final trimmed = _mask[extra] & ~pairMask;
        if (trimmed == _mask[extra]) return false;
        _mask[extra] = trimmed;
        _history.add(HintTechnique.uniqueRectangleType1);
        return true;

      case 2:
        if (pure(g1) == pure(g2)) return false;
        final roof = pure(g1) ? g2 : g1;
        final e0 = _mask[roof[0]] & ~pairMask;
        final e1 = _mask[roof[1]] & ~pairMask;
        if (candCount(e0) != 1 || e0 != e1) return false;
        final c = candDigits(e0).first;
        final elim =
            BitsetGeometry.buddies[roof[0]] & BitsetGeometry.buddies[roof[1]];
        for (final i in cells) {
          elim.remove(i);
        }
        var changed = false;
        elim.forEach((i) {
          if (_cell[i] == 0 && candHas(_mask[i], c)) {
            _mask[i] = candRemove(_mask[i], c);
            changed = true;
          }
        });
        if (!changed) return false;
        _history.add(HintTechnique.uniqueRectangleType2);
        return true;

      case 3:
        if (pure(g1) == pure(g2)) return false;
        final roof3 = pure(g1) ? g2 : g1;
        final virtual = (_mask[roof3[0]] | _mask[roof3[1]]) & ~pairMask;
        final vCount = candCount(virtual);
        if (vCount < 2 || vCount > 3) return false;
        final sameRow = roof3[0] ~/ 9 == roof3[1] ~/ 9;
        final line = sameRow ? roof3[0] ~/ 9 : 9 + roof3[0] % 9;
        final box = 18 + BitsetGeometry.boxOf(roof3[0]);
        for (final u in [box, line]) {
          final pool = [
            for (final i in _unitCells[u])
              if (!roof3.contains(i) &&
                  _cell[i] == 0 &&
                  candCount(_mask[i]) >= 1 &&
                  candCount(_mask[i]) <= vCount)
                i,
          ];
          final externalCount = vCount - 1;
          if (pool.length < externalCount) continue;
          for (final ext in _combinations(pool, externalCount)) {
            var union = virtual;
            for (final i in ext) {
              union |= _mask[i];
            }
            if (candCount(union) != vCount) continue;
            var changed = false;
            for (final i in _unitCells[u]) {
              if (roof3.contains(i) || ext.contains(i) || _cell[i] != 0) {
                continue;
              }
              final trimmed = _mask[i] & ~union;
              if (trimmed != _mask[i]) {
                _mask[i] = trimmed;
                changed = true;
              }
            }
            if (changed) {
              _history.add(HintTechnique.uniqueRectangleType3);
              return true;
            }
          }
        }
        return false;

      case 4:
        if (pure(g1) == pure(g2)) return false;
        final roof4 = pure(g1) ? g2 : g1;
        final sameRow4 = roof4[0] ~/ 9 == roof4[1] ~/ 9;
        final line4 = sameRow4 ? roof4[0] ~/ 9 : 9 + roof4[0] % 9;
        for (final locked in candDigits(pairMask)) {
          final withLocked = [
            for (final i in _unitCells[line4])
              if (_cell[i] == 0 && candHas(_mask[i], locked)) i,
          ];
          if (withLocked.length != 2 ||
              !withLocked.contains(roof4[0]) ||
              !withLocked.contains(roof4[1])) {
            continue;
          }
          final other = candDigits(pairMask).firstWhere((d) => d != locked);
          var changed = false;
          for (final i in roof4) {
            if (candHas(_mask[i], other)) {
              _mask[i] = candRemove(_mask[i], other);
              changed = true;
            }
          }
          if (changed) {
            _history.add(HintTechnique.uniqueRectangleType4);
            return true;
          }
        }
        return false;
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
