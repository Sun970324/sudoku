import '../../../models/hint.dart';
import 'candidates.dart';
import 'geometry.dart';

/// Bitset port of the hint engine's Alternating Inference Chain core
/// (`aic.dart` `_searchAic`), used by [BitsetSolver] for the four chain
/// techniques that stay hint-only in the generation order: general AIC,
/// grouped X-Chain / grouped AIC, and ALS-AIC. It is a faithful, mechanical
/// port — same node encoding, strong/weak links, iterative-deepening search
/// and per-technique shape gates — reading candidates from a mask grid
/// (`List<int>` of 81) instead of a `Set` grid. (X-Chain, XY-Chain, ALS-XZ and
/// WXYZ-Wing have their own direct bitset detectors in [BitsetSolver] and are
/// NOT routed here.)
///
/// [findEliminations] returns the candidates to strike as packed nodes
/// (`cell * 9 + digit - 1`), or an empty list if the technique doesn't apply.
class BitsetAic {
  static const _setBase = 729;
  static const _maxAicNodes = 12;
  static const _maxAlsCells = 4;

  /// Cap on chain-extension steps per search. The iterative-deepening DFS can
  /// explode on dense minimal boards (measured ~18s on a pathological expert
  /// board), so past this many extensions the search gives up and reports
  /// nothing — the solve then simply can't use this technique on that board
  /// and moves on / rejects it. Normal searches finish in a tiny fraction of
  /// this, so real eliminations are never lost; only the runaway tail is cut.
  static const _maxExtensions = 30000;

  static int _node(int cell, int digit) => cell * 9 + (digit - 1);
  static int _nodeCell(int node) => node ~/ 9;
  static int _nodeDigit(int node) => node % 9 + 1;
  static int _boxOf(int cell) => (cell ~/ 9) ~/ 3 * 3 + (cell % 9) ~/ 3;

  static bool _cellsSee(int a, int b) =>
      a != b &&
      (a ~/ 9 == b ~/ 9 ||
          a % 9 == b % 9 ||
          ((a ~/ 9) ~/ 3 == (b ~/ 9) ~/ 3 && (a % 9) ~/ 3 == (b % 9) ~/ 3));

  static bool _seesAll(int cell, List<int> cells) =>
      cells.every((t) => _cellsSee(cell, t));

  /// The candidates to eliminate for [technique] on the mask grid [mask], as
  /// packed nodes; empty when nothing applies.
  static List<int> findEliminations(List<int> mask, HintTechnique technique) {
    final useBivalue = technique != HintTechnique.groupedXChain;
    final grouped = technique == HintTechnique.groupedXChain ||
        technique == HintTechnique.groupedAic ||
        technique == HintTechnique.alsAic;
    final als = technique == HintTechnique.alsAic;

    final ctx = _Ctx(mask, technique);

    int nodeFor(int digit, List<int> cells) {
      if (cells.length == 1) return _node(cells[0], digit);
      final sorted = [...cells]..sort();
      final key = '$digit:${sorted.join(",")}';
      final existing = ctx.setIds[key];
      if (existing != null) return _setBase + existing;
      ctx.setIds[key] = ctx.sets.length;
      ctx.setsByDigit[digit - 1].add(_setBase + ctx.sets.length);
      ctx.sets.add(_SetNode(digit, sorted));
      return _setBase + ctx.sets.length - 1;
    }

    void addStrong(int a, int b) {
      (ctx.strong[a] ??= <int>{}).add(b);
      (ctx.strong[b] ??= <int>{}).add(a);
    }

    // Strong links. Bilocation: a digit with exactly two places in a unit.
    for (var u = 0; u < 27; u++) {
      final cells = _unitCells[u];
      for (var d = 1; d <= 9; d++) {
        final places = [
          for (final cell in cells)
            if (candHas(mask[cell], d)) cell,
        ];
        if (places.length == 2) {
          addStrong(_node(places[0], d), _node(places[1], d));
        }
      }
    }
    // Bivalue: a cell with exactly two candidates.
    if (useBivalue) {
      for (var cell = 0; cell < 81; cell++) {
        if (candCount(mask[cell]) == 2) {
          final ds = candDigits(mask[cell]);
          addStrong(_node(cell, ds[0]), _node(cell, ds[1]));
        }
      }
    }
    // Grouped: a unit whose candidates split into exactly two segments.
    if (grouped) {
      for (var u = 0; u < 27; u++) {
        final cells = _unitCells[u];
        final isBox = u >= 18;
        for (var d = 1; d <= 9; d++) {
          final places = [
            for (final cell in cells)
              if (candHas(mask[cell], d)) cell,
          ];
          if (places.length < 3) continue;
          final splits = isBox
              ? <int Function(int)>[(p) => p ~/ 9, (p) => p % 9]
              : <int Function(int)>[_boxOf];
          for (final keyOf in splits) {
            final chunks = <int, List<int>>{};
            for (final p in places) {
              (chunks[keyOf(p)] ??= []).add(p);
            }
            if (chunks.length != 2) continue;
            final parts = chunks.values.toList();
            addStrong(nodeFor(d, parts[0]), nodeFor(d, parts[1]));
          }
        }
      }
    }
    // ALS: every N-cell subset of a unit holding exactly N+1 candidates.
    if (als) {
      for (var u = 0; u < 27; u++) {
        final cells = [
          for (final cell in _unitCells[u])
            if (candCount(mask[cell]) >= 2) cell,
        ];
        for (var size = 2; size <= _maxAlsCells && size <= cells.length; size++) {
          for (final combo in _combinations(cells, size)) {
            var union = 0;
            for (final cell in combo) {
              union |= mask[cell];
            }
            if (candCount(union) != size + 1) continue;
            final digits = candDigits(union);
            final nodes = <int, int>{
              for (final d in digits)
                d: nodeFor(d, [
                  for (final cell in combo)
                    if (candHas(mask[cell], d)) cell,
                ]),
            };
            for (var i = 0; i < digits.length; i++) {
              for (var j = i + 1; j < digits.length; j++) {
                final a = nodes[digits[i]]!, b = nodes[digits[j]]!;
                addStrong(a, b);
                final key = _pairKey(a, b);
                final prev = ctx.alsLinkSize[key];
                if (prev == null || size < prev) {
                  ctx.alsLinkSize[key] = size;
                  ctx.alsLinkCells[key] = combo;
                }
              }
            }
          }
        }
      }
    }
    if (ctx.strong.isEmpty) return const [];

    for (var limit = 4; limit <= _maxAicNodes; limit += 2) {
      for (final start in ctx.strong.keys.toList()..sort()) {
        if (ctx.budget <= 0) return const []; // runaway search — give up
        for (final second in ctx.strong[start]!.toList()..sort()) {
          final elim =
              _extend(ctx, [start, second], {start, second}, limit, useBivalue);
          if (elim != null) return elim;
        }
      }
    }
    return const [];
  }

  static List<int>? _extend(
    _Ctx ctx,
    List<int> path,
    Set<int> visited,
    int maxNodes,
    bool useBivalue,
  ) {
    if (ctx.budget <= 0) return null;
    ctx.budget--;
    final elim = _eliminationsFor(ctx, path, useBivalue);
    if (elim != null) return elim;
    if (path.length >= maxNodes) return null;

    final last = path.last;
    for (final via in _weakNeighbours(ctx, last, useBivalue)) {
      if (visited.contains(via)) continue;
      final onward = ctx.strong[via];
      if (onward == null) continue;
      for (final next in onward) {
        if (visited.contains(next) || next == via) continue;
        visited.add(via);
        visited.add(next);
        final deeper =
            _extend(ctx, [...path, via, next], visited, maxNodes, useBivalue);
        visited.remove(via);
        visited.remove(next);
        if (deeper != null) return deeper;
      }
    }
    return null;
  }

  static Iterable<int> _weakNeighbours(
      _Ctx ctx, int from, bool useBivalue) sync* {
    if (from < _setBase) {
      final cell = _nodeCell(from);
      final digit = _nodeDigit(from);
      for (final p in BitsetGeometry.buddies[cell].toList()) {
        if (candHas(ctx.mask[p], digit)) yield _node(p, digit);
      }
      if (useBivalue) {
        for (final d2 in candDigits(ctx.mask[cell])) {
          if (d2 != digit) yield _node(cell, d2);
        }
      }
    } else {
      final s = ctx.sets[from - _setBase];
      final digit = s.digit;
      final first = s.cells[0];
      final rest = s.cells.sublist(1);
      for (final p in BitsetGeometry.buddies[first].toList()) {
        if (!s.cells.contains(p) &&
            _seesAll(p, rest) &&
            candHas(ctx.mask[p], digit)) {
          yield _node(p, digit);
        }
      }
    }
    final digit = from < _setBase ? _nodeDigit(from) : ctx.sets[from - _setBase].digit;
    for (final other in ctx.setsByDigit[digit - 1]) {
      if (other != from && _weakLink(from, other, ctx, useBivalue)) yield other;
    }
  }

  static bool _weakLink(int a, int b, _Ctx ctx, bool useBivalue) {
    if (a == b) return false;
    final aIsSet = a >= _setBase, bIsSet = b >= _setBase;
    if (!aIsSet && !bIsSet) {
      final ca = _nodeCell(a), da = _nodeDigit(a);
      final cb = _nodeCell(b), db = _nodeDigit(b);
      if (ca == cb) return useBivalue && da != db;
      if (da == db) return _cellsSee(ca, cb);
      return false;
    }
    if (aIsSet && bIsSet) {
      final sa = ctx.sets[a - _setBase], sb = ctx.sets[b - _setBase];
      return sa.digit == sb.digit &&
          !sa.cells.any(sb.cells.contains) &&
          sa.cells.every((c) => _seesAll(c, sb.cells));
    }
    final s = ctx.sets[(aIsSet ? a : b) - _setBase];
    final single = aIsSet ? b : a;
    if (_nodeDigit(single) != s.digit) return false;
    final cell = _nodeCell(single);
    return !s.cells.contains(cell) && _seesAll(cell, s.cells);
  }

  static List<int>? _eliminationsFor(
      _Ctx ctx, List<int> path, bool useBivalue) {
    if (path.length < 4) return null;
    switch (ctx.technique) {
      case HintTechnique.groupedXChain:
      case HintTechnique.groupedAic:
        if (!path.any((n) => n >= _setBase)) return null;
      case HintTechnique.alsAic:
        var hasAls = false;
        for (var i = 0; i + 1 < path.length && !hasAls; i += 2) {
          hasAls = (ctx.alsLinkSize[_pairKey(path[i], path[i + 1])] ?? 0) >= 2;
        }
        if (!hasAls) return null;
      default:
        break;
    }
    final a = path.first;
    final z = path.last;
    final onPath = <int>{
      for (final n in path)
        for (final cell in _cellsOf(n, ctx.sets))
          _node(cell, _digitOf(n, ctx.sets)),
    };

    final strikes = <int>[];
    final seen = <int>{};
    for (var cell = 0; cell < 81; cell++) {
      for (final dC in candDigits(ctx.mask[cell])) {
        final node = _node(cell, dC);
        if (onPath.contains(node)) continue;
        if (_weakLink(a, node, ctx, useBivalue) &&
            _weakLink(z, node, ctx, useBivalue) &&
            seen.add(node)) {
          strikes.add(node);
        }
      }
    }
    return strikes.isEmpty ? null : strikes;
  }

  static List<int> _cellsOf(int node, List<_SetNode> sets) =>
      node < _setBase ? [_nodeCell(node)] : sets[node - _setBase].cells;

  static int _digitOf(int node, List<_SetNode> sets) =>
      node < _setBase ? _nodeDigit(node) : sets[node - _setBase].digit;

  static int _pairKey(int a, int b) =>
      a < b ? a * 100000 + b : b * 100000 + a;
}

/// The 27 units as flat cell-index lists (rows 0-8, cols 9-17, boxes 18-26).
final List<List<int>> _unitCells =
    [for (var u = 0; u < 27; u++) BitsetGeometry.units[u].toList()];

class _Ctx {
  _Ctx(this.mask, this.technique);

  final List<int> mask;
  final HintTechnique technique;
  final strong = <int, Set<int>>{};
  final sets = <_SetNode>[];
  final setIds = <String, int>{};
  final setsByDigit = List.generate(9, (_) => <int>[]);
  final alsLinkSize = <int, int>{};
  final alsLinkCells = <int, List<int>>{};

  /// Remaining chain-extension steps before the search bails (see
  /// [BitsetAic._maxExtensions]).
  int budget = BitsetAic._maxExtensions;
}

class _SetNode {
  const _SetNode(this.digit, this.cells);

  final int digit;
  final List<int> cells;
}

/// All size-[k] combinations of [items], lexicographic order.
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
