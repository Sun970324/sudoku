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

  /// Multi-Coloring: two or more separate conjugate-pair color clusters exist
  /// for one digit. Ported from HoDoKu's ColoringSolver (findMultiColorSteps):
  ///
  ///  - **Wrap** (HoDoKu Multi-Colors 2): if one colour of cluster A can see
  ///    BOTH colours of cluster B, that colour can never be the digit
  ///    (whichever colour of B is true eliminates it), so the whole colour is
  ///    removed.
  ///  - **Trap** (HoDoKu Multi-Colors 1): if colour a of cluster A sees colour
  ///    c of cluster B, then a and c can't both be true — so the opposite
  ///    colours b and d can't both be false; any cell seeing both b and d
  ///    therefore loses the digit.
  Hint? findMultiColoring(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findMultiColoring(resolved, l10n);
  }

  Hint? _findMultiColoring(
    List<List<Set<int>>> candidates,
    AppLocalizations? l10n,
  ) {
    final resolvedL10n = _resolveL10n(l10n);
    for (var d = 1; d <= 9; d++) {
      final components = _colorComponentsForDigit(candidates, d);
      if (components.length < 2) continue;
      // Ordered pairs: a->b is not b->a for the wrap rule (a colour of A vs
      // both colours of B), so every combination is checked (as HoDoKu does).
      for (var i = 0; i < components.length; i++) {
        for (var j = 0; j < components.length; j++) {
          if (i == j) continue;
          final hint = _multiColorPair(
              candidates, components[i], components[j], d, resolvedL10n);
          if (hint != null) return hint;
        }
      }
    }
    return null;
  }

  Hint? _multiColorPair(
    List<List<Set<int>>> candidates,
    (Map<int, int>, List<(int, int)>) clusterA,
    (Map<int, int>, List<(int, int)>) clusterB,
    int digit,
    AppLocalizations l10n,
  ) {
    List<List<int>> cellsOf(Map<int, int> coloring, int color) => [
          for (final e in coloring.entries)
            if (e.value == color) [e.key ~/ 9, e.key % 9],
        ];
    final a = cellsOf(clusterA.$1, 0);
    final b = cellsOf(clusterA.$1, 1);
    final c = cellsOf(clusterB.$1, 0);
    final e = cellsOf(clusterB.$1, 1);

    bool sees(List<List<int>> x, List<List<int>> y) {
      for (final p in x) {
        for (final q in y) {
          if (_seeEachOther(p, q)) return true;
        }
      }
      return false;
    }

    // Wrap: a colour of A sees both colours of B -> that colour is impossible.
    for (final color in [a, b]) {
      if (sees(color, c) && sees(color, e)) {
        final elim = [
          for (final p in color)
            if (candidates[p[0]][p[1]].contains(digit))
              HintElimination(p[0], p[1], digit),
        ];
        if (elim.isNotEmpty) {
          return _multiColorHint(
              clusterA, clusterB, digit, elim, l10n, trap: false);
        }
      }
    }

    // Trap: colour x of A sees colour y of B -> cells seeing both opposite
    // colours (oppX in A, oppY in B) lose the digit.
    final excluded = {...clusterA.$1.keys, ...clusterB.$1.keys};
    for (final (x, y, oppX, oppY) in [
      (a, c, b, e),
      (a, e, b, c),
      (b, c, a, e),
      (b, e, a, c),
    ]) {
      if (!sees(x, y)) continue;
      final elim = <HintElimination>[];
      for (var r = 0; r < 9; r++) {
        for (var col = 0; col < 9; col++) {
          if (excluded.contains(r * 9 + col)) continue;
          if (!candidates[r][col].contains(digit)) continue;
          if (oppX.any((p) => _seeEachOther([r, col], p)) &&
              oppY.any((p) => _seeEachOther([r, col], p))) {
            elim.add(HintElimination(r, col, digit));
          }
        }
      }
      if (elim.isNotEmpty) {
        return _multiColorHint(
            clusterA, clusterB, digit, elim, l10n, trap: true);
      }
    }
    return null;
  }

  Hint _multiColorHint(
    (Map<int, int>, List<(int, int)>) clusterA,
    (Map<int, int>, List<(int, int)>) clusterB,
    int digit,
    List<HintElimination> eliminations,
    AppLocalizations l10n, {
    required bool trap,
  }) {
    HintCell cellAt(int idx) => HintCell(idx ~/ 9, idx % 9);
    final groupA = clusterA.$1.keys.map(cellAt).toSet();
    final groupB = clusterB.$1.keys.map(cellAt).toSet();
    return Hint(
      technique: HintTechnique.multiColoring,
      type: HintType.eliminate,
      explanation: l10n.explanationMultiColoring(digit),
      primaryCells: {...groupA, ...groupB},
      secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      colorGroupA: groupA,
      colorGroupB: groupB,
      eliminations: eliminations,
      chainLinks: [
        ..._conjugateEdgeLinks(clusterA.$2, digit),
        ..._conjugateEdgeLinks(clusterB.$2, digit),
      ],
      // Trap eliminations land on outside onlookers seeing two colours (like
      // simple-coloring rule 2, so the step builder draws convergence
      // connectors); wrap eliminations land on a colour's own cells (rule 1).
      elimSources: trap
          ? [
              for (final idx in {...clusterA.$1.keys, ...clusterB.$1.keys})
                HintChainNode.single(cellAt(idx), digit),
            ]
          : const [],
    );
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
