part of '../hint_engine.dart';

extension HintEngineColoring on HintEngine {
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
      for (final coloring in components) {
        final hint = _simpleColoringRule1(candidates, coloring, d, resolvedL10n);
        if (hint != null) return hint;
      }
      for (final coloring in components) {
        final hint = _simpleColoringRule2(candidates, coloring, d, resolvedL10n);
        if (hint != null) return hint;
      }
    }
    return null;
  }

  /// All conjugate-pair-linked components (>= 2 cells) for [digit], each as
  /// a cell-index (`row * 9 + col`) -> color (0/1) map, discovered in
  /// deterministic row-major order of each component's first cell.
  List<Map<int, int>> _colorComponentsForDigit(
    List<List<Set<int>>> candidates,
    int digit,
  ) {
    final adjacency = <int, Set<int>>{};
    for (final unit in _allUnits()) {
      final cellsWithDigit = unit.cells
          .where((rc) => candidates[rc[0]][rc[1]].contains(digit))
          .toList();
      if (cellsWithDigit.length != 2) continue;
      final a = cellsWithDigit[0][0] * 9 + cellsWithDigit[0][1];
      final b = cellsWithDigit[1][0] * 9 + cellsWithDigit[1][1];
      adjacency.putIfAbsent(a, () => {}).add(b);
      adjacency.putIfAbsent(b, () => {}).add(a);
    }

    final visited = <int>{};
    final components = <Map<int, int>>[];
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
      if (coloring.length >= 2) components.add(coloring);
    }
    return components;
  }

  Hint? _simpleColoringRule1(
    List<List<Set<int>>> candidates,
    Map<int, int> coloring,
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
          );
        }
      }
    }
    return null;
  }

  Hint? _simpleColoringRule2(
    List<List<Set<int>>> candidates,
    Map<int, int> coloring,
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
    );
  }
}
