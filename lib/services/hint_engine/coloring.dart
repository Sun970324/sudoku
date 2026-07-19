part of '../hint_engine.dart';

/// Defensive bound on remote-pair chain length, mirroring
/// [_maxXYChainDepth]'s role for XY-Chain — a densely interlinked pool of
/// same-pair cells could otherwise blow up the depth-first walk. Real
/// eliminations are found far below this.
const _maxRemotePairDepth = 20;

extension HintEngineColoring on HintEngine {
  /// Remote Pair: a chain of cells that ALL hold the same two candidates
  /// {a, b}, each linked to the next by being peers. Since every cell is
  /// bivalue, picking a value for one forces the whole chain to alternate,
  /// so cells an odd number of links apart always hold opposite values —
  /// meaning one of them is a and the other b. Any cell seeing both ends of
  /// such an odd-length chain therefore loses BOTH a and b.
  ///
  /// The chain must be at least 4 cells: a 2-cell "chain" of peers is a
  /// Naked Pair, and while [findXYChain] would reach the same eliminations
  /// (a remote pair IS an XY-chain whose cells happen to share one pair),
  /// this is far easier to spot — same rationale as the Turbot family
  /// sitting ahead of Simple Coloring.
  Hint? findRemotePair(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findRemotePair(resolved, l10n);
  }

  Hint? _findRemotePair(
    List<List<Set<int>>> candidates,
    AppLocalizations? l10n,
  ) {
    final resolvedL10n = _resolveL10n(l10n);
    // Group every bivalue cell by its candidate pair; only cells sharing the
    // exact same pair can chain together.
    final byPair = <String, List<List<int>>>{};
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (candidates[r][c].length != 2) continue;
        final key = (candidates[r][c].toList()..sort()).join(',');
        byPair.putIfAbsent(key, () => []).add([r, c]);
      }
    }

    for (final entry in byPair.entries) {
      final cells = entry.value;
      if (cells.length < 4) continue;
      final digits = entry.key.split(',').map(int.parse).toList();
      final a = digits[0];
      final b = digits[1];

      for (final start in cells) {
        final hint = _extendRemotePair(
          candidates,
          cells,
          [start],
          a,
          b,
          resolvedL10n,
        );
        if (hint != null) return hint;
      }
    }
    return null;
  }

  /// Walks the remote-pair graph depth-first. Every step alternates parity,
  /// so once [path] holds 4+ cells and its two ends are an odd number of
  /// links apart, they are guaranteed to hold opposite values.
  Hint? _extendRemotePair(
    List<List<Set<int>>> candidates,
    List<List<int>> pool,
    List<List<int>> path,
    int a,
    int b,
    AppLocalizations l10n,
  ) {
    if (path.length >= 4 && (path.length - 1).isOdd) {
      final hint = _buildRemotePairHint(candidates, path, a, b, l10n);
      if (hint != null) return hint;
    }
    if (path.length >= _maxRemotePairDepth) return null;

    final visited = path.map((p) => p[0] * 9 + p[1]).toSet();
    for (final next in pool) {
      if (visited.contains(next[0] * 9 + next[1])) continue;
      if (!_seeEachOther(path.last, next)) continue;
      final hint = _extendRemotePair(
        candidates,
        pool,
        [...path, next],
        a,
        b,
        l10n,
      );
      if (hint != null) return hint;
    }
    return null;
  }

  Hint? _buildRemotePairHint(
    List<List<Set<int>>> candidates,
    List<List<int>> path,
    int a,
    int b,
    AppLocalizations l10n,
  ) {
    final start = path.first;
    final end = path.last;
    final onPath = path.map((p) => p[0] * 9 + p[1]).toSet();

    final eliminations = <HintElimination>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (onPath.contains(r * 9 + c)) continue;
        if (!_seeEachOther([r, c], start) || !_seeEachOther([r, c], end)) {
          continue;
        }
        // Both digits go: whichever way the chain falls, one end is a and
        // the other is b, and this cell sees them both.
        for (final d in [a, b]) {
          if (candidates[r][c].contains(d)) {
            eliminations.add(HintElimination(r, c, d));
          }
        }
      }
    }
    if (eliminations.isEmpty) return null;

    // Same link grammar as an XY-Chain (a remote pair IS one whose cells all
    // share the same pair): each cell's own a=b is a strong link, the shared
    // digit reaching the next cell a weak one. The path has an odd number of
    // links, so the carry lands both ends on [a] — the overlay's convergence
    // connectors then run from the two end cells to each eliminated
    // candidate (of either digit) they both see.
    HintCell cellAt(int i) => HintCell(path[i][0], path[i][1]);
    final chainLinks = <HintChainLink>[
      HintChainLink(
        from: HintChainNode.single(cellAt(0), a),
        to: HintChainNode.single(cellAt(0), b),
        strong: true,
      ),
    ];
    var carry = b;
    for (var i = 0; i + 1 < path.length; i++) {
      chainLinks.add(HintChainLink(
        from: HintChainNode.single(cellAt(i), carry),
        to: HintChainNode.single(cellAt(i + 1), carry),
        strong: false,
      ));
      final other = carry == a ? b : a;
      chainLinks.add(HintChainLink(
        from: HintChainNode.single(cellAt(i + 1), carry),
        to: HintChainNode.single(cellAt(i + 1), other),
        strong: true,
      ));
      carry = other;
    }

    return Hint(
      technique: HintTechnique.remotePair,
      type: HintType.eliminate,
      explanation: l10n.explanationRemotePair(
        path.map((p) => _cellDesc(p[0], p[1], l10n)).join(' - '),
        a,
        b,
      ),
      primaryCells: path.map((p) => HintCell(p[0], p[1])).toSet(),
      secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      colorGroupA: {
        for (var i = 0; i < path.length; i += 2) HintCell(path[i][0], path[i][1]),
      },
      colorGroupB: {
        for (var i = 1; i < path.length; i += 2) HintCell(path[i][0], path[i][1]),
      },
      primaryDigits: {a, b},
      eliminations: eliminations,
      chainLinks: chainLinks,
    );
  }

  Hint? findSimpleColoring(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findSimpleColoring(resolved, l10n);
  }

  Hint? _findSimpleColoring(
    List<List<Set<int>>> candidates,
    AppLocalizations? l10n,
  ) {
    final resolvedL10n = _resolveL10n(l10n);
    for (var d = 1; d <= 9; d++) {
      final components = _colorComponentsForDigit(candidates, d);
      for (final (coloring, edges) in components) {
        final hint =
            _simpleColoringRule1(candidates, coloring, edges, d, resolvedL10n);
        if (hint != null) return hint;
      }
      for (final (coloring, edges) in components) {
        final hint =
            _simpleColoringRule2(candidates, coloring, edges, d, resolvedL10n);
        if (hint != null) return hint;
      }
    }
    return null;
  }

  /// The component's conjugate edges as the strong links they are — one
  /// per pair, all on [digit] — so the overlay draws the chain the coloring
  /// argument actually walks.
  List<HintChainLink> _conjugateEdgeLinks(List<(int, int)> edges, int digit) =>
      [
        for (final e in edges)
          HintChainLink(
            from: HintChainNode.single(HintCell(e.$1 ~/ 9, e.$1 % 9), digit),
            to: HintChainNode.single(HintCell(e.$2 ~/ 9, e.$2 % 9), digit),
            strong: true,
          ),
      ];

  /// All conjugate-pair-linked components (>= 2 cells) for [digit], each as
  /// a cell-index (`row * 9 + col`) -> color (0/1) map plus the conjugate
  /// edges joining its cells (canonical `(min, max)` index pairs, deduped —
  /// two cells alone in both a row AND their box are still one edge), so a
  /// hint can draw the chain's actual links rather than just colored cells.
  /// Discovered in deterministic row-major order of each component's first
  /// cell.
  List<(Map<int, int>, List<(int, int)>)> _colorComponentsForDigit(
    List<List<Set<int>>> candidates,
    int digit,
  ) {
    final adjacency = <int, Set<int>>{};
    final edges = <(int, int)>{};
    for (final unit in _allUnits()) {
      final cellsWithDigit = unit.cells
          .where((rc) => candidates[rc[0]][rc[1]].contains(digit))
          .toList();
      if (cellsWithDigit.length != 2) continue;
      final a = cellsWithDigit[0][0] * 9 + cellsWithDigit[0][1];
      final b = cellsWithDigit[1][0] * 9 + cellsWithDigit[1][1];
      adjacency.putIfAbsent(a, () => {}).add(b);
      adjacency.putIfAbsent(b, () => {}).add(a);
      edges.add(a < b ? (a, b) : (b, a));
    }

    final visited = <int>{};
    final components = <(Map<int, int>, List<(int, int)>)>[];
    final startCells = adjacency.keys.toList()..sort();
    for (final start in startCells) {
      if (!visited.add(start)) continue;
      final coloring = <int, int>{start: 0};
      final queue = [start];
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        for (final neighbor in adjacency[current]!) {
          if (!visited.add(neighbor)) continue;
          coloring[neighbor] = 1 - coloring[current]!;
          queue.add(neighbor);
        }
      }
      if (coloring.length >= 2) {
        components.add((
          coloring,
          [
            for (final e in edges)
              if (coloring.containsKey(e.$1)) e,
          ],
        ));
      }
    }
    return components;
  }

  Hint? _simpleColoringRule1(
    List<List<Set<int>>> candidates,
    Map<int, int> coloring,
    List<(int, int)> edges,
    int digit,
    AppLocalizations l10n,
  ) {
    for (final color in [0, 1]) {
      final cellsOfColor = coloring.entries
          .where((e) => e.value == color)
          .map((e) => [e.key ~/ 9, e.key % 9])
          .toList();
      for (var i = 0; i < cellsOfColor.length; i++) {
        for (var j = i + 1; j < cellsOfColor.length; j++) {
          if (!_seeEachOther(cellsOfColor[i], cellsOfColor[j])) continue;

          final eliminations = [
            for (final rc in cellsOfColor)
              if (candidates[rc[0]][rc[1]].contains(digit))
                HintElimination(rc[0], rc[1], digit),
          ];
          if (eliminations.isEmpty) continue;

          final contradictionCells =
              cellsOfColor.map((rc) => HintCell(rc[0], rc[1])).toSet();
          final otherColorCells = coloring.entries
              .where((e) => e.value != color)
              .map((e) => HintCell(e.key ~/ 9, e.key % 9))
              .toSet();
          final aDesc = _cellDesc(cellsOfColor[i][0], cellsOfColor[i][1], l10n);
          final bDesc = _cellDesc(cellsOfColor[j][0], cellsOfColor[j][1], l10n);

          return Hint(
            technique: HintTechnique.simpleColoring,
            type: HintType.eliminate,
            explanation:
                l10n.explanationSimpleColoringRule1(digit, aDesc, bDesc),
            primaryCells: contradictionCells,
            secondaryCells: otherColorCells,
            colorGroupA: contradictionCells,
            colorGroupB: otherColorCells,
            eliminations: eliminations,
            // The chain the coloring walked, plus a weak link between the
            // two same-colored cells that see each other — the "can't both
            // be true" clash that wipes out their whole color.
            chainLinks: [
              ..._conjugateEdgeLinks(edges, digit),
              HintChainLink(
                from: HintChainNode.single(
                    HintCell(cellsOfColor[i][0], cellsOfColor[i][1]), digit),
                to: HintChainNode.single(
                    HintCell(cellsOfColor[j][0], cellsOfColor[j][1]), digit),
                strong: false,
              ),
            ],
            // No convergence connectors: the eliminations land ON the
            // contradictory color's own cells, not on outside onlookers.
            elimSources: const [],
          );
        }
      }
    }
    return null;
  }

  Hint? _simpleColoringRule2(
    List<List<Set<int>>> candidates,
    Map<int, int> coloring,
    List<(int, int)> edges,
    int digit,
    AppLocalizations l10n,
  ) {
    final componentCells = coloring.keys.toSet();
    final eliminations = <HintElimination>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final idx = r * 9 + c;
        if (componentCells.contains(idx)) continue;
        if (!candidates[r][c].contains(digit)) continue;

        var seesColor0 = false;
        var seesColor1 = false;
        for (final entry in coloring.entries) {
          if (!_seeEachOther([r, c], [entry.key ~/ 9, entry.key % 9])) {
            continue;
          }
          if (entry.value == 0) {
            seesColor0 = true;
          } else {
            seesColor1 = true;
          }
          if (seesColor0 && seesColor1) break;
        }
        if (seesColor0 && seesColor1) {
          eliminations.add(HintElimination(r, c, digit));
        }
      }
    }
    if (eliminations.isEmpty) return null;

    final cellsDesc = coloring.keys
        .map((idx) => _cellDesc(idx ~/ 9, idx % 9, l10n))
        .join(', ');
    final colorGroupA = coloring.entries
        .where((e) => e.value == 0)
        .map((e) => HintCell(e.key ~/ 9, e.key % 9))
        .toSet();
    final colorGroupB = coloring.entries
        .where((e) => e.value == 1)
        .map((e) => HintCell(e.key ~/ 9, e.key % 9))
        .toSet();

    return Hint(
      technique: HintTechnique.simpleColoring,
      type: HintType.eliminate,
      explanation: l10n.explanationSimpleColoringRule2(digit, cellsDesc),
      primaryCells:
          coloring.keys.map((idx) => HintCell(idx ~/ 9, idx % 9)).toSet(),
      secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      colorGroupA: colorGroupA,
      colorGroupB: colorGroupB,
      eliminations: eliminations,
      chainLinks: _conjugateEdgeLinks(edges, digit),
      // Every chain cell is a potential convergence source; the overlay
      // narrows these to the nearest one per color, drawing each trapped
      // cell's "sees both colors" as exactly two connectors.
      elimSources: [
        for (final idx in coloring.keys)
          HintChainNode.single(HintCell(idx ~/ 9, idx % 9), digit),
      ],
    );
  }
}
