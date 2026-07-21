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

  // A node packs a cell (0-80) and a digit (1-9) into one int:
  //   node = cell * 9 + (digit - 1)
  static int _node(int cell, int digit) => cell * 9 + (digit - 1);
  static int _nodeCell(int node) => node ~/ 9;
  static int _nodeDigit(int node) => node % 9 + 1;

  static bool _cellsSee(int a, int b) =>
      a != b &&
      (a ~/ 9 == b ~/ 9 || // same row
          a % 9 == b % 9 || // same column
          ((a ~/ 9) ~/ 3 == (b ~/ 9) ~/ 3 &&
              (a % 9) ~/ 3 == (b % 9) ~/ 3)); // same box

  bool _weakLink(int a, int b, bool useBivalue) {
    if (a == b) return false;
    final ca = _nodeCell(a), da = _nodeDigit(a);
    final cb = _nodeCell(b), db = _nodeDigit(b);
    if (ca == cb) return useBivalue && da != db;
    if (da == db) return _cellsSee(ca, cb);
    return false;
  }

  Hint? _searchAic(
    List<List<Set<int>>> candidates,
    AppLocalizations? l10n, {
    required bool useBivalue,
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
    List<int> path,
    Set<int> visited,
    bool useBivalue,
    int maxNodes,
    HintTechnique technique,
    AppLocalizations l10n,
  ) {
    final hint = _aicHint(candidates, path, useBivalue, technique, l10n);
    if (hint != null) return hint;
    if (path.length >= maxNodes) return null;

    final last = path.last;
    for (final via in _weakNeighbours(candidates, last, useBivalue)) {
      if (visited.contains(via)) continue;
      final onward = strong[via];
      if (onward == null) continue;
      for (final next in onward) {
        if (visited.contains(next) || next == via) continue;
        visited.add(via);
        visited.add(next);
        final deeper = _extendAic(candidates, strong, [...path, via, next],
            visited, useBivalue, maxNodes, technique, l10n);
        visited.remove(via);
        visited.remove(next);
        if (deeper != null) return deeper;
      }
    }
    return null;
  }

  /// Candidate nodes weak-linked to [from]: same digit in a peer cell, plus
  /// (general AIC) the other candidates of [from]'s own cell.
  Iterable<int> _weakNeighbours(
      List<List<Set<int>>> candidates, int from, bool useBivalue) sync* {
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
  }

  Hint? _aicHint(
    List<List<Set<int>>> candidates,
    List<int> path,
    bool useBivalue,
    HintTechnique technique,
    AppLocalizations l10n,
  ) {
    if (path.length < 4) return null;
    final a = path.first;
    final z = path.last;
    final onPath = path.toSet();

    final eliminations = <HintElimination>[];
    final seen = <int>{};
    for (var cell = 0; cell < 81; cell++) {
      final r = cell ~/ 9, c = cell % 9;
      for (final dC in candidates[r][c]) {
        final node = _node(cell, dC);
        if (onPath.contains(node)) continue;
        if (_weakLink(a, node, useBivalue) &&
            _weakLink(z, node, useBivalue) &&
            seen.add(node)) {
          eliminations.add(HintElimination(r, c, dC));
        }
      }
    }
    if (eliminations.isEmpty) return null;

    final chainLinks = <HintChainLink>[
      for (var i = 0; i + 1 < path.length; i++)
        HintChainLink(
          from: HintChainNode.single(
              HintCell(_nodeCell(path[i]) ~/ 9, _nodeCell(path[i]) % 9),
              _nodeDigit(path[i])),
          to: HintChainNode.single(
              HintCell(_nodeCell(path[i + 1]) ~/ 9, _nodeCell(path[i + 1]) % 9),
              _nodeDigit(path[i + 1])),
          // Links alternate strong/weak starting with strong.
          strong: i.isEven,
        ),
    ];

    final chainDesc = path
        .map((n) =>
            '${_cellDesc(_nodeCell(n) ~/ 9, _nodeCell(n) % 9, l10n)}(${_nodeDigit(n)})')
        .join(' - ');

    return Hint(
      technique: technique,
      type: HintType.eliminate,
      explanation: technique == HintTechnique.xChain
          ? l10n.explanationXChain(chainDesc, _nodeDigit(a))
          : l10n.explanationAic(chainDesc),
      primaryCells: {
        for (final n in path)
          HintCell(_nodeCell(n) ~/ 9, _nodeCell(n) % 9),
      },
      secondaryCells:
          eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      primaryDigits: {for (final n in path) _nodeDigit(n)},
      eliminations: eliminations,
      chainLinks: chainLinks,
    );
  }
}
