part of '../hint_engine.dart';

/// Alternating Inference Chain core — X-Chain (single digit) and the general
/// AIC. Both search the same graph of candidate "nodes" (one per cell+digit)
/// joined by two kinds of link:
///
///  - **strong** (`A =S= B`, "at least one of A, B is true"): a *bilocation*
///    link (a digit with exactly two places in a unit) or, for the general
///    AIC, a *bivalue* link (a cell with exactly two candidates).
///  - **weak** (`A ~W~ B`, "at most one of A, B is true"): two same-digit
///    candidates that see each other, or (general AIC only) two candidates in
///    the same cell.
///
/// An AIC alternates strong/weak/strong…/strong starting and ending with a
/// strong link. Following it, `¬A ⇒ Z` for its two end nodes A and Z, i.e.
/// **A ∨ Z** — at least one end is true. So any candidate that weak-links to
/// BOTH ends can be eliminated (were it true, both ends would be false).
///
/// X-Chain is exactly this restricted to one digit (bilocation + same-digit
/// weak links only), which makes both endpoints the same digit — recovering
/// the familiar "a cell seeing both ends loses the digit" rule. Deliberately
/// hint-only (absent from [humanSolverTechniqueOrder]) and ordered LAST, so
/// it only ever surfaces chains the earlier, more specific techniques
/// (Turbot family, XY-Chain, …) don't already report.
///
/// The **grouped** variants extend the node set: 2-3 same-digit candidates
/// lying on one box/line intersection (a mini-row or mini-column) act as a
/// single node meaning "the digit is somewhere in this group". That admits
/// two extra strong-link shapes — a line whose candidates split into exactly
/// two box segments, and a box whose candidates split into exactly two
/// mini-lines — and a group weak-links to anything that sees *all* of its
/// cells. Grouped finders only report chains that use at least one group
/// node, since plain chains are already [findXChain]/[findAic]'s job.
///
/// The **ALS** variants add one more strong-link source: an Almost Locked
/// Set — N cells of one unit sharing exactly N+1 candidates. Removing any
/// one of its candidates locks the rest in, so for every candidate pair
/// (x, z) of an ALS, "no x in the ALS" forces "z in the ALS": a strong link
/// between the ALS's x-cells and its z-cells (each side a set node like a
/// group, but the two sides carry *different* digits). ALS-XZ is exactly a
/// 4-node chain over two such links joined by the restricted-common weak
/// link, and WXYZ-Wing is its (bivalue cell + 3-cell ALS) special case.
extension HintEngineAic on HintEngine {
  /// Longest chain explored, in nodes. Real eliminations show up far short of
  /// this; it only bounds a pathological search.
  static const _maxAicNodes = 12;

  /// Largest ALS enumerated, in cells. 2-4 covers the overwhelming share of
  /// real ALS-XZ/WXYZ patterns; bigger sets explode the subset count for
  /// vanishing returns.
  static const _maxAlsCells = 4;

  Hint? findXChain(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _searchAic(resolved, l10n,
        useBivalue: false, technique: HintTechnique.xChain);
  }

  Hint? findAic(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _searchAic(resolved, l10n,
        useBivalue: true, technique: HintTechnique.aic);
  }

  Hint? findGroupedXChain(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _searchAic(resolved, l10n,
        useBivalue: false,
        grouped: true,
        technique: HintTechnique.groupedXChain);
  }

  Hint? findGroupedAic(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _searchAic(resolved, l10n,
        useBivalue: true, grouped: true, technique: HintTechnique.groupedAic);
  }

  /// A bivalue cell strong-linked to a 3-cell ALS through one restricted
  /// common digit — 4 cells sharing 4 candidates, the classic WXYZ-Wing.
  Hint? findWXYZWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _searchAic(resolved, l10n,
        useBivalue: true,
        als: true,
        maxChainNodes: 4,
        technique: HintTechnique.wxyzWing);
  }

  /// Two ALSs joined by a restricted common digit (the XZ rule): any other
  /// shared digit can be eliminated from cells seeing all of its places in
  /// both sets.
  Hint? findAlsXZ(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _searchAic(resolved, l10n,
        useBivalue: true,
        als: true,
        maxChainNodes: 4,
        technique: HintTechnique.alsXZ);
  }

  /// The full chain search with every link source enabled — grouped segment
  /// nodes and ALS nodes both. Only reports chains that use at least one
  /// genuine ALS link, since everything else is an earlier finder's job.
  Hint? findAlsAic(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _searchAic(resolved, l10n,
        useBivalue: true,
        grouped: true,
        als: true,
        technique: HintTechnique.alsAic);
  }

  // A node packs a cell (0-80) and a digit (1-9) into one int:
  //   node = cell * 9 + (digit - 1)
  // Set nodes (grouped segments and ALS digit-sides) live above that range:
  // node = _setBase + index into the search's set list.
  static const _setBase = 729;
  static int _node(int cell, int digit) => cell * 9 + (digit - 1);
  static int _nodeCell(int node) => node ~/ 9;
  static int _nodeDigit(int node) => node % 9 + 1;
  static int _boxOf(int cell) => (cell ~/ 9) ~/ 3 * 3 + (cell % 9) ~/ 3;

  static bool _cellsSee(int a, int b) =>
      a != b &&
      (a ~/ 9 == b ~/ 9 || // same row
          a % 9 == b % 9 || // same column
          ((a ~/ 9) ~/ 3 == (b ~/ 9) ~/ 3 &&
              (a % 9) ~/ 3 == (b % 9) ~/ 3)); // same box

  static bool _seesAll(int cell, List<int> cells) =>
      cells.every((t) => _cellsSee(cell, t));

  /// Weak = "at most one of [a], [b] is true". For singles: same cell with
  /// another digit (bivalue mode), or the same digit in a peer cell. A set
  /// node weak-links to a same-digit single that sees all of its cells, and
  /// to a disjoint same-digit set every cell of which it fully sees — either
  /// way two simultaneous trues would repeat the digit inside one unit.
  bool _weakLink(int a, int b, _AicSearch ctx) {
    if (a == b) return false;
    final aIsSet = a >= _setBase, bIsSet = b >= _setBase;
    if (!aIsSet && !bIsSet) {
      final ca = _nodeCell(a), da = _nodeDigit(a);
      final cb = _nodeCell(b), db = _nodeDigit(b);
      if (ca == cb) return ctx.useBivalue && da != db;
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

  Hint? _searchAic(
    List<List<Set<int>>> candidates,
    AppLocalizations? l10n, {
    required bool useBivalue,
    bool grouped = false,
    bool als = false,
    int maxChainNodes = _maxAicNodes,
    required HintTechnique technique,
  }) {
    final ctx = _AicSearch(
      candidates: candidates,
      useBivalue: useBivalue,
      technique: technique,
      l10n: _resolveL10n(l10n),
    );

    // Registers (or dedupes) a digit-restricted cell set; single cells stay
    // plain nodes so identical links land on identical node ids.
    int nodeFor(int digit, List<int> cells) {
      if (cells.length == 1) return _node(cells[0], digit);
      final sorted = [...cells]..sort();
      final key = '$digit:${sorted.join(",")}';
      final existing = ctx.setIds[key];
      if (existing != null) return _setBase + existing;
      ctx.setIds[key] = ctx.sets.length;
      ctx.setsByDigit[digit - 1].add(_setBase + ctx.sets.length);
      ctx.sets.add(_AicSetNode(digit, sorted));
      return _setBase + ctx.sets.length - 1;
    }

    void addStrong(int a, int b) {
      (ctx.strong[a] ??= <int>{}).add(b);
      (ctx.strong[b] ??= <int>{}).add(a);
    }

    // Strong-link sources. Bilocation: a digit with exactly two places in a
    // unit. Bivalue (general AIC): a cell with exactly two candidates.
    for (final unit in _allUnits()) {
      for (var d = 1; d <= 9; d++) {
        final places = <int>[
          for (final rc in unit.cells)
            if (candidates[rc[0]][rc[1]].contains(d)) rc[0] * 9 + rc[1],
        ];
        if (places.length == 2) {
          addStrong(_node(places[0], d), _node(places[1], d));
        }
      }
    }
    if (useBivalue) {
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          final cand = candidates[r][c];
          if (cand.length == 2) {
            final ds = cand.toList()..sort();
            addStrong(_node(r * 9 + c, ds[0]), _node(r * 9 + c, ds[1]));
          }
        }
      }
    }

    // Grouped mode: a unit whose candidates split into exactly two segments
    // (by box on a line, by mini-line in a box), at least one of them
    // multi-cell (two singles is plain bilocation, added above).
    if (grouped) {
      for (final unit in _allUnits()) {
        for (var d = 1; d <= 9; d++) {
          final places = <int>[
            for (final rc in unit.cells)
              if (candidates[rc[0]][rc[1]].contains(d)) rc[0] * 9 + rc[1],
          ];
          if (places.length < 3) continue;
          final splits = unit.type == _UnitType.box
              ? [(int p) => p ~/ 9, (int p) => p % 9]
              : [_boxOf];
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

    // ALS mode: every N-cell subset of a unit holding exactly N+1 candidates
    // contributes a strong link between each pair of its candidates' cell
    // sets. Size 1 (a bivalue cell) is already the bivalue link above.
    if (als) {
      for (final unit in _allUnits()) {
        final cells = <int>[
          for (final rc in unit.cells)
            if (candidates[rc[0]][rc[1]].length >= 2) rc[0] * 9 + rc[1],
        ];
        for (var size = 2; size <= _maxAlsCells; size++) {
          if (size > cells.length) break;
          for (final combo in _combinations(cells, size)) {
            final union = <int>{};
            for (final cell in combo) {
              union.addAll(candidates[cell ~/ 9][cell % 9]);
            }
            if (union.length != size + 1) continue;
            final digits = union.toList()..sort();
            final nodes = <int, int>{
              for (final d in digits)
                d: nodeFor(d, [
                  for (final cell in combo)
                    if (candidates[cell ~/ 9][cell % 9].contains(d)) cell,
                ]),
            };
            for (var i = 0; i < digits.length; i++) {
              for (var j = i + 1; j < digits.length; j++) {
                final a = nodes[digits[i]]!, b = nodes[digits[j]]!;
                addStrong(a, b);
                final key = _AicSearch.pairKey(a, b);
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
    if (ctx.strong.isEmpty) return null;

    // Iterative deepening on chain length, so the shortest (clearest) chain
    // wins. Endpoints are added strong-first, two nodes at a time, so every
    // examined path ends with a strong link.
    for (var maxNodes = 4; maxNodes <= maxChainNodes; maxNodes += 2) {
      for (final start in ctx.strong.keys.toList()..sort()) {
        for (final second in ctx.strong[start]!.toList()..sort()) {
          final hint =
              _extendAic(ctx, [start, second], {start, second}, maxNodes);
          if (hint != null) return hint;
        }
      }
    }
    return null;
  }

  /// [path] always ends with a strong link (even length). Tries the current
  /// path for eliminations, then extends by a weak+strong pair.
  Hint? _extendAic(
    _AicSearch ctx,
    List<int> path,
    Set<int> visited,
    int maxNodes,
  ) {
    final hint = _aicHint(ctx, path);
    if (hint != null) return hint;
    if (path.length >= maxNodes) return null;

    final last = path.last;
    for (final via in _weakNeighbours(ctx, last)) {
      if (visited.contains(via)) continue;
      final onward = ctx.strong[via];
      if (onward == null) continue;
      for (final next in onward) {
        if (visited.contains(next) || next == via) continue;
        visited.add(via);
        visited.add(next);
        final deeper = _extendAic(ctx, [...path, via, next], visited, maxNodes);
        visited.remove(via);
        visited.remove(next);
        if (deeper != null) return deeper;
      }
    }
    return null;
  }

  /// Candidate nodes weak-linked to [from]: same digit in a peer cell, plus
  /// (general AIC) the other candidates of [from]'s own cell, plus any set
  /// node the weak-link predicate admits. From a set node, singles are the
  /// same-digit candidates among the cells seeing the whole set.
  Iterable<int> _weakNeighbours(_AicSearch ctx, int from) sync* {
    final candidates = ctx.candidates;
    int digit;
    if (from < _setBase) {
      final cell = _nodeCell(from);
      digit = _nodeDigit(from);
      final r = cell ~/ 9, c = cell % 9;
      for (final p in _peers(r, c)) {
        if (candidates[p[0]][p[1]].contains(digit)) {
          yield _node(p[0] * 9 + p[1], digit);
        }
      }
      if (ctx.useBivalue) {
        for (final d2 in candidates[r][c]) {
          if (d2 != digit) yield _node(cell, d2);
        }
      }
    } else {
      final s = ctx.sets[from - _setBase];
      digit = s.digit;
      final first = s.cells[0];
      final rest = s.cells.sublist(1);
      for (final p in _peers(first ~/ 9, first % 9)) {
        final cell = p[0] * 9 + p[1];
        if (!s.cells.contains(cell) &&
            _seesAll(cell, rest) &&
            candidates[p[0]][p[1]].contains(digit)) {
          yield _node(cell, digit);
        }
      }
    }
    for (final other in ctx.setsByDigit[digit - 1]) {
      if (other != from && _weakLink(from, other, ctx)) yield other;
    }
  }

  /// Whether the strong link joining path[i] and path[i+1] is an intra-cell
  /// bivalue link.
  static bool _isBivalueLink(List<int> path, int i) =>
      path[i] < _setBase &&
      path[i + 1] < _setBase &&
      _nodeCell(path[i]) == _nodeCell(path[i + 1]);

  Hint? _aicHint(_AicSearch ctx, List<int> path) {
    if (path.length < 4) return null;
    // Per-technique shape gate — each finder only reports what the finders
    // ordered before it cannot, so labels stay honest.
    switch (ctx.technique) {
      case HintTechnique.groupedXChain:
      case HintTechnique.groupedAic:
        if (!path.any((n) => n >= _setBase)) return null;
      case HintTechnique.wxyzWing:
        // Exactly one bivalue cell and one 3-cell ALS as the strong links.
        final headAls = ctx.alsSizeOfLink(path, 0);
        final tailAls = ctx.alsSizeOfLink(path, 2);
        if (path.length != 4 ||
            !((_isBivalueLink(path, 0) && tailAls == 3) ||
                (_isBivalueLink(path, 2) && headAls == 3))) {
          return null;
        }
      case HintTechnique.alsXZ:
        if (path.length != 4 ||
            ((ctx.alsSizeOfLink(path, 0) ?? 0) < 2 &&
                (ctx.alsSizeOfLink(path, 2) ?? 0) < 2)) {
          return null;
        }
      case HintTechnique.alsAic:
        var hasAls = false;
        for (var i = 0; i + 1 < path.length && !hasAls; i += 2) {
          hasAls = (ctx.alsSizeOfLink(path, i) ?? 0) >= 2;
        }
        if (!hasAls) return null;
      default:
        break;
    }
    final a = path.first;
    final z = path.last;
    // Every (cell, digit) covered by a path node — set members included —
    // is off-limits as an elimination, keeping the drawn chain and the red
    // marks disjoint.
    final onPath = <int>{
      for (final n in path)
        for (final cell in _nodeCellsOf(n, ctx.sets))
          _node(cell, _nodeDigitOf(n, ctx.sets)),
    };

    final eliminations = <HintElimination>[];
    final seen = <int>{};
    for (var cell = 0; cell < 81; cell++) {
      final r = cell ~/ 9, c = cell % 9;
      for (final dC in ctx.candidates[r][c]) {
        final node = _node(cell, dC);
        if (onPath.contains(node)) continue;
        if (_weakLink(a, node, ctx) &&
            _weakLink(z, node, ctx) &&
            seen.add(node)) {
          eliminations.add(HintElimination(r, c, dC));
        }
      }
    }
    if (eliminations.isEmpty) return null;

    HintChainNode nodeOf(int n) => HintChainNode(
          [
            for (final cell in _nodeCellsOf(n, ctx.sets))
              HintCell(cell ~/ 9, cell % 9),
          ],
          _nodeDigitOf(n, ctx.sets),
        );

    final chainLinks = <HintChainLink>[
      for (var i = 0; i + 1 < path.length; i++)
        HintChainLink(
          from: nodeOf(path[i]),
          to: nodeOf(path[i + 1]),
          // Links alternate strong/weak starting with strong.
          strong: i.isEven,
        ),
    ];

    String nodeDesc(int n) {
      final cells = _nodeCellsOf(n, ctx.sets)
          .map((cell) => _cellDesc(cell ~/ 9, cell % 9, ctx.l10n))
          .join('·');
      return '$cells(${_nodeDigitOf(n, ctx.sets)})';
    }

    final chainDesc = path.map(nodeDesc).join(' - ');
    final l10n = ctx.l10n;

    return Hint(
      technique: ctx.technique,
      type: HintType.eliminate,
      explanation: switch (ctx.technique) {
        HintTechnique.xChain =>
          l10n.explanationXChain(chainDesc, _nodeDigitOf(a, ctx.sets)),
        HintTechnique.groupedXChain =>
          l10n.explanationGroupedXChain(chainDesc, _nodeDigitOf(a, ctx.sets)),
        HintTechnique.groupedAic => l10n.explanationGroupedAic(chainDesc),
        HintTechnique.wxyzWing => l10n.explanationWXYZWing(chainDesc),
        HintTechnique.alsXZ => l10n.explanationAlsXZ(chainDesc),
        HintTechnique.alsAic => l10n.explanationAlsAic(chainDesc),
        _ => l10n.explanationAic(chainDesc),
      },
      primaryCells: {
        for (final n in path)
          for (final cell in _nodeCellsOf(n, ctx.sets))
            HintCell(cell ~/ 9, cell % 9),
        // An ALS's full extent — every cell of the almost-locked set, not
        // just the two digit-sides the chain touches — so the board shows
        // why the linked sets are almost locked.
        for (var i = 0; i + 1 < path.length; i += 2)
          for (final cell in ctx.alsLinkCells[
                  _AicSearch.pairKey(path[i], path[i + 1])] ??
              const <int>[])
            HintCell(cell ~/ 9, cell % 9),
      },
      secondaryCells:
          eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      primaryDigits: {for (final n in path) _nodeDigitOf(n, ctx.sets)},
      eliminations: eliminations,
      chainLinks: chainLinks,
    );
  }

  static List<int> _nodeCellsOf(int node, List<_AicSetNode> sets) =>
      node < _setBase ? [_nodeCell(node)] : sets[node - _setBase].cells;

  static int _nodeDigitOf(int node, List<_AicSetNode> sets) =>
      node < _setBase ? _nodeDigit(node) : sets[node - _setBase].digit;
}

/// One chain-search's mutable state: the strong-link adjacency, the set-node
/// registry (grouped segments and ALS digit-sides share one id space so
/// identical (digit, cells) pairs are one node), and which strong links came
/// from an ALS (by pair key, holding the smallest generating ALS's cell
/// count — the shape gates read it to tell ALS links from plain ones).
class _AicSearch {
  _AicSearch({
    required this.candidates,
    required this.useBivalue,
    required this.technique,
    required this.l10n,
  });

  final List<List<Set<int>>> candidates;
  final bool useBivalue;
  final HintTechnique technique;
  final AppLocalizations l10n;

  final strong = <int, Set<int>>{};
  final sets = <_AicSetNode>[];
  final setIds = <String, int>{};
  final setsByDigit = List.generate(9, (_) => <int>[]);
  final alsLinkSize = <int, int>{};
  final alsLinkCells = <int, List<int>>{};

  static int pairKey(int a, int b) =>
      a < b ? a * 100000 + b : b * 100000 + a;

  /// The generating ALS's size for the strong link at [i] (even indices),
  /// or null if that link is bilocation/bivalue/segment only.
  int? alsSizeOfLink(List<int> path, int i) =>
      alsLinkSize[pairKey(path[i], path[i + 1])];
}

/// A digit-restricted cell set acting as one chain node — "digit is in one
/// of these cells". Grouped variants build them from box/line segments; ALS
/// variants from an Almost Locked Set's per-digit cells.
class _AicSetNode {
  const _AicSetNode(this.digit, this.cells);

  final int digit;
  final List<int> cells;
}
