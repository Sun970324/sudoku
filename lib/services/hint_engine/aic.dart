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
extension HintEngineAic on HintEngine {
  /// Longest chain explored, in nodes. Real eliminations show up far short of
  /// this; it only bounds a pathological search.
  static const _maxAicNodes = 12;

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

  // A node packs a cell (0-80) and a digit (1-9) into one int:
  //   node = cell * 9 + (digit - 1)
  // Group nodes live above that range: node = _groupBase + index into the
  // search's group list (built per board in [_searchAic]).
  static const _groupBase = 729;
  static int _node(int cell, int digit) => cell * 9 + (digit - 1);
  static int _nodeCell(int node) => node ~/ 9;
  static int _nodeDigit(int node) => node % 9 + 1;
  static int _boxOf(int cell) => (cell ~/ 9) ~/ 3 * 3 + (cell % 9) ~/ 3;

  static List<int> _nodeCellsOf(int node, List<_AicGroup> groups) =>
      node < _groupBase ? [_nodeCell(node)] : groups[node - _groupBase].cells;

  static int _nodeDigitOf(int node, List<_AicGroup> groups) =>
      node < _groupBase ? _nodeDigit(node) : groups[node - _groupBase].digit;

  static bool _cellsSee(int a, int b) =>
      a != b &&
      (a ~/ 9 == b ~/ 9 || // same row
          a % 9 == b % 9 || // same column
          ((a ~/ 9) ~/ 3 == (b ~/ 9) ~/ 3 &&
              (a % 9) ~/ 3 == (b % 9) ~/ 3)); // same box

  /// Weak = "at most one of [a], [b] is true". For singles: same cell with
  /// another digit (bivalue mode), or the same digit in a peer cell. A group
  /// weak-links to a same-digit single that sees all of its cells, and to a
  /// disjoint same-digit group sharing its box or line — either way two
  /// simultaneous trues would repeat the digit inside one unit.
  bool _weakLink(int a, int b, bool useBivalue, List<_AicGroup> groups) {
    if (a == b) return false;
    final aIsGroup = a >= _groupBase, bIsGroup = b >= _groupBase;
    if (!aIsGroup && !bIsGroup) {
      final ca = _nodeCell(a), da = _nodeDigit(a);
      final cb = _nodeCell(b), db = _nodeDigit(b);
      if (ca == cb) return useBivalue && da != db;
      if (da == db) return _cellsSee(ca, cb);
      return false;
    }
    if (aIsGroup && bIsGroup) {
      final ga = groups[a - _groupBase], gb = groups[b - _groupBase];
      return ga.digit == gb.digit &&
          !ga.cells.any(gb.cells.contains) &&
          (ga.box == gb.box || ga.line == gb.line);
    }
    final g = groups[(aIsGroup ? a : b) - _groupBase];
    final s = aIsGroup ? b : a;
    if (_nodeDigit(s) != g.digit) return false;
    final cell = _nodeCell(s);
    if (g.cells.contains(cell)) return false;
    return _boxOf(cell) == g.box ||
        (g.line < 9 ? cell ~/ 9 == g.line : cell % 9 == g.line - 9);
  }

  Hint? _searchAic(
    List<List<Set<int>>> candidates,
    AppLocalizations? l10n, {
    required bool useBivalue,
    bool grouped = false,
    required HintTechnique technique,
  }) {
    final resolvedL10n = _resolveL10n(l10n);

    // Strong-link adjacency. Bilocation: a digit with exactly two places in a
    // unit. Bivalue (general AIC): a cell with exactly two candidates.
    final strong = <int, Set<int>>{};
    void addStrong(int a, int b) {
      (strong[a] ??= <int>{}).add(b);
      (strong[b] ??= <int>{}).add(a);
    }

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

    // Grouped mode: register every box/line segment holding 2+ candidates of
    // a digit as a group node, then add the two grouped strong-link shapes —
    // a unit whose candidates split into exactly two segments, at least one
    // of them multi-cell (two singles is plain bilocation, added above).
    final groups = <_AicGroup>[];
    if (grouped) {
      final groupIds = <int, int>{};
      int groupKey(int d, int box, int line) => ((d - 1) * 9 + box) * 18 + line;
      for (var box = 0; box < 9; box++) {
        final r0 = box ~/ 3 * 3, c0 = box % 3 * 3;
        for (var d = 1; d <= 9; d++) {
          for (var i = 0; i < 3; i++) {
            final rowCells = <int>[
              for (var c = c0; c < c0 + 3; c++)
                if (candidates[r0 + i][c].contains(d)) (r0 + i) * 9 + c,
            ];
            if (rowCells.length >= 2) {
              groupIds[groupKey(d, box, r0 + i)] = groups.length;
              groups.add(_AicGroup(d, rowCells, box, r0 + i));
            }
            final colCells = <int>[
              for (var r = r0; r < r0 + 3; r++)
                if (candidates[r][c0 + i].contains(d)) r * 9 + (c0 + i),
            ];
            if (colCells.length >= 2) {
              groupIds[groupKey(d, box, 9 + c0 + i)] = groups.length;
              groups.add(_AicGroup(d, colCells, box, 9 + c0 + i));
            }
          }
        }
      }

      int chunkNode(List<int> cells, int d, int box, int line) =>
          cells.length == 1
              ? _node(cells[0], d)
              : _groupBase + groupIds[groupKey(d, box, line)]!;

      for (final unit in _allUnits()) {
        for (var d = 1; d <= 9; d++) {
          final places = <int>[
            for (final rc in unit.cells)
              if (candidates[rc[0]][rc[1]].contains(d)) rc[0] * 9 + rc[1],
          ];
          if (places.length < 3) continue;
          if (unit.type == _UnitType.box) {
            for (final byCol in [false, true]) {
              final chunks = <int, List<int>>{};
              for (final p in places) {
                (chunks[byCol ? p % 9 : p ~/ 9] ??= []).add(p);
              }
              if (chunks.length != 2) continue;
              final parts = chunks.entries.toList();
              addStrong(
                chunkNode(parts[0].value, d, unit.index,
                    byCol ? 9 + parts[0].key : parts[0].key),
                chunkNode(parts[1].value, d, unit.index,
                    byCol ? 9 + parts[1].key : parts[1].key),
              );
            }
          } else {
            final line =
                unit.type == _UnitType.row ? unit.index : 9 + unit.index;
            final chunks = <int, List<int>>{};
            for (final p in places) {
              (chunks[_boxOf(p)] ??= []).add(p);
            }
            if (chunks.length != 2) continue;
            final parts = chunks.entries.toList();
            addStrong(
              chunkNode(parts[0].value, d, parts[0].key, line),
              chunkNode(parts[1].value, d, parts[1].key, line),
            );
          }
        }
      }
    }
    if (strong.isEmpty) return null;

    // Iterative deepening on chain length, so the shortest (clearest) chain
    // wins. Endpoints are added strong-first, two nodes at a time, so every
    // examined path ends with a strong link.
    for (var maxNodes = 4; maxNodes <= _maxAicNodes; maxNodes += 2) {
      for (final start in strong.keys.toList()..sort()) {
        for (final second in strong[start]!.toList()..sort()) {
          final hint = _extendAic(
            candidates,
            strong,
            groups,
            [start, second],
            {start, second},
            useBivalue,
            maxNodes,
            technique,
            resolvedL10n,
          );
          if (hint != null) return hint;
        }
      }
    }
    return null;
  }

  /// [path] always ends with a strong link (even length). Tries the current
  /// path for eliminations, then extends by a weak+strong pair.
  Hint? _extendAic(
    List<List<Set<int>>> candidates,
    Map<int, Set<int>> strong,
    List<_AicGroup> groups,
    List<int> path,
    Set<int> visited,
    bool useBivalue,
    int maxNodes,
    HintTechnique technique,
    AppLocalizations l10n,
  ) {
    final hint = _aicHint(candidates, groups, path, useBivalue, technique, l10n);
    if (hint != null) return hint;
    if (path.length >= maxNodes) return null;

    final last = path.last;
    for (final via in _weakNeighbours(candidates, last, useBivalue, groups)) {
      if (visited.contains(via)) continue;
      final onward = strong[via];
      if (onward == null) continue;
      for (final next in onward) {
        if (visited.contains(next) || next == via) continue;
        visited.add(via);
        visited.add(next);
        final deeper = _extendAic(candidates, strong, groups,
            [...path, via, next], visited, useBivalue, maxNodes, technique, l10n);
        visited.remove(via);
        visited.remove(next);
        if (deeper != null) return deeper;
      }
    }
    return null;
  }

  /// Candidate nodes weak-linked to [from]: same digit in a peer cell, plus
  /// (general AIC) the other candidates of [from]'s own cell, plus any group
  /// node the weak-link predicate admits. From a group, singles come from the
  /// group's own box and line (the only cells that can see all of it).
  Iterable<int> _weakNeighbours(List<List<Set<int>>> candidates, int from,
      bool useBivalue, List<_AicGroup> groups) sync* {
    if (from < _groupBase) {
      final cell = _nodeCell(from);
      final d = _nodeDigit(from);
      final r = cell ~/ 9, c = cell % 9;
      for (final p in _peers(r, c)) {
        if (candidates[p[0]][p[1]].contains(d)) yield _node(p[0] * 9 + p[1], d);
      }
      if (useBivalue) {
        for (final d2 in candidates[r][c]) {
          if (d2 != d) yield _node(cell, d2);
        }
      }
    } else {
      final g = groups[from - _groupBase];
      final r0 = g.box ~/ 3 * 3, c0 = g.box % 3 * 3;
      final seen = <int>{...g.cells};
      for (var i = 0; i < 9; i++) {
        final inBox = (r0 + i ~/ 3) * 9 + (c0 + i % 3);
        final onLine = g.line < 9 ? g.line * 9 + i : i * 9 + (g.line - 9);
        for (final cell in [inBox, onLine]) {
          if (seen.add(cell) &&
              candidates[cell ~/ 9][cell % 9].contains(g.digit)) {
            yield _node(cell, g.digit);
          }
        }
      }
    }
    for (var gi = 0; gi < groups.length; gi++) {
      final other = _groupBase + gi;
      if (_weakLink(from, other, useBivalue, groups)) yield other;
    }
  }

  Hint? _aicHint(
    List<List<Set<int>>> candidates,
    List<_AicGroup> groups,
    List<int> path,
    bool useBivalue,
    HintTechnique technique,
    AppLocalizations l10n,
  ) {
    if (path.length < 4) return null;
    // Grouped finders only report chains that actually use a group node;
    // ungrouped chains are the plain finders' job (which run earlier).
    if ((technique == HintTechnique.groupedXChain ||
            technique == HintTechnique.groupedAic) &&
        !path.any((n) => n >= _groupBase)) {
      return null;
    }
    final a = path.first;
    final z = path.last;
    // Every (cell, digit) covered by a path node — group members included —
    // is off-limits as an elimination, keeping the drawn chain and the red
    // marks disjoint.
    final onPath = <int>{
      for (final n in path)
        for (final cell in _nodeCellsOf(n, groups))
          _node(cell, _nodeDigitOf(n, groups)),
    };

    final eliminations = <HintElimination>[];
    final seen = <int>{};
    for (var cell = 0; cell < 81; cell++) {
      final r = cell ~/ 9, c = cell % 9;
      for (final dC in candidates[r][c]) {
        final node = _node(cell, dC);
        if (onPath.contains(node)) continue;
        if (_weakLink(a, node, useBivalue, groups) &&
            _weakLink(z, node, useBivalue, groups) &&
            seen.add(node)) {
          eliminations.add(HintElimination(r, c, dC));
        }
      }
    }
    if (eliminations.isEmpty) return null;

    HintChainNode nodeOf(int n) => HintChainNode(
          [
            for (final cell in _nodeCellsOf(n, groups))
              HintCell(cell ~/ 9, cell % 9),
          ],
          _nodeDigitOf(n, groups),
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
      final cells = _nodeCellsOf(n, groups)
          .map((cell) => _cellDesc(cell ~/ 9, cell % 9, l10n))
          .join('·');
      return '$cells(${_nodeDigitOf(n, groups)})';
    }

    final chainDesc = path.map(nodeDesc).join(' - ');

    return Hint(
      technique: technique,
      type: HintType.eliminate,
      explanation: switch (technique) {
        HintTechnique.xChain =>
          l10n.explanationXChain(chainDesc, _nodeDigitOf(a, groups)),
        HintTechnique.groupedXChain =>
          l10n.explanationGroupedXChain(chainDesc, _nodeDigitOf(a, groups)),
        HintTechnique.groupedAic => l10n.explanationGroupedAic(chainDesc),
        _ => l10n.explanationAic(chainDesc),
      },
      primaryCells: {
        for (final n in path)
          for (final cell in _nodeCellsOf(n, groups))
            HintCell(cell ~/ 9, cell % 9),
      },
      secondaryCells:
          eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      primaryDigits: {for (final n in path) _nodeDigitOf(n, groups)},
      eliminations: eliminations,
      chainLinks: chainLinks,
    );
  }
}

/// A grouped-AIC node: [cells] (2-3 of them) are all the candidates of
/// [digit] on the intersection of [box] with one line — meaning "the digit
/// is somewhere in here". [line] encodes a row as `r` (0-8) and a column as
/// `9 + c` (9-17), so two groups share a line exactly when the values match.
class _AicGroup {
  const _AicGroup(this.digit, this.cells, this.box, this.line);

  final int digit;
  final List<int> cells;
  final int box;
  final int line;
}
