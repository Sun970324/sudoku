part of '../hint_engine.dart';

extension HintEngineSubsets on HintEngine {
  Hint? findNakedPair(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findNakedSubset(resolved, 2, HintTechnique.nakedPair, l10n);
  }

  Hint? findNakedTriple(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findNakedSubset(resolved, 3, HintTechnique.nakedTriple, l10n);
  }

  Hint? findNakedQuad(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findNakedSubset(resolved, 4, HintTechnique.nakedQuad, l10n);
  }

  Hint? findLockedPair(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findLockedSubset(resolved, 2, HintTechnique.lockedPair, l10n);
  }

  Hint? findLockedTriple(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findLockedSubset(resolved, 3, HintTechnique.lockedTriple, l10n);
  }

  /// Locked N-subset: a naked subset whose cells all sit in the *intersection*
  /// of a box and a line, which makes it a naked subset of BOTH units at once
  /// — so its digits clear out of the rest of the line AND the rest of the
  /// box in a single step.
  ///
  /// This finds nothing [_findNakedSubset] couldn't: the same pattern is a
  /// naked subset of the line and, separately, of the box, so two successive
  /// Naked Pair steps reach the same position. What it adds is the step a
  /// player would actually recognize — one named pattern doing both halves —
  /// which is why it's deliberately ordered *after* Intersection (so a
  /// simpler Pointing/Claiming still wins where it applies, keeping easy
  /// puzzles easy) but *before* Naked Pair, whose tier it shares.
  Hint? _findLockedSubset(
    List<List<Set<int>>> candidates,
    int size,
    HintTechnique technique,
    AppLocalizations? l10n,
  ) {
    final resolvedL10n = _resolveL10n(l10n);
    for (final box in _allUnits().where((u) => u.type == _UnitType.box)) {
      for (final line in _linesThrough(box)) {
        final intersection = [
          for (final rc in box.cells)
            if (line.cells.any((l) => l[0] == rc[0] && l[1] == rc[1])) rc,
        ];
        final pool = intersection.where((rc) {
          final len = candidates[rc[0]][rc[1]].length;
          return len >= 2 && len <= size;
        }).toList();
        if (pool.length < size) continue;

        for (final group in _combinations(pool, size)) {
          final union = <int>{};
          for (final rc in group) {
            union.addAll(candidates[rc[0]][rc[1]]);
          }
          if (union.length != size) continue;

          // The point of the technique: sweep the line AND the box, not
          // whichever single unit happened to be scanned first.
          final targets = <List<int>>[
            ...line.cells,
            for (final rc in box.cells)
              if (!line.cells.any((l) => l[0] == rc[0] && l[1] == rc[1])) rc,
          ];
          final eliminations = <HintElimination>[];
          for (final rc in targets) {
            if (group.any((g) => g[0] == rc[0] && g[1] == rc[1])) continue;
            for (final d in union) {
              if (candidates[rc[0]][rc[1]].contains(d)) {
                eliminations.add(HintElimination(rc[0], rc[1], d));
              }
            }
          }
          if (eliminations.isEmpty) continue;

          final (lRows, lCols, _) = _highlightFor(line);
          final (_, _, bBoxes) = _highlightFor(box);
          return Hint(
            technique: technique,
            type: HintType.eliminate,
            explanation: resolvedL10n.explanationLockedSubset(
              _unitDescription(line, resolvedL10n),
              _unitDescription(box, resolvedL10n),
              group
                  .map((rc) => _cellDesc(rc[0], rc[1], resolvedL10n))
                  .join(', '),
              (union.toList()..sort()).join(', '),
              size,
            ),
            primaryCells: group.map((rc) => HintCell(rc[0], rc[1])).toSet(),
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            highlightedRows: lRows,
            highlightedCols: lCols,
            highlightedBoxes: bBoxes,
            primaryDigits: union,
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }

  /// The 3 rows and 3 columns that pass through [box].
  Iterable<_Unit> _linesThrough(_Unit box) sync* {
    final boxRow = (box.index ~/ 3) * 3;
    final boxCol = (box.index % 3) * 3;
    for (final unit in _allUnits()) {
      if (unit.type == _UnitType.row &&
          unit.index >= boxRow &&
          unit.index < boxRow + 3) {
        yield unit;
      }
      if (unit.type == _UnitType.col &&
          unit.index >= boxCol &&
          unit.index < boxCol + 3) {
        yield unit;
      }
    }
  }

  /// Naked N-subset: [size] cells in a unit whose candidates, combined,
  /// span exactly [size] digits (the cells don't need identical candidate
  /// sets — e.g. {1,2}/{2,3}/{1,3} is a valid naked triple on {1,2,3}) mean
  /// those digits must occupy exactly those cells, so they can be
  /// eliminated from every other cell in the unit.
  Hint? _findNakedSubset(
    List<List<Set<int>>> candidates,
    int size,
    HintTechnique technique,
    AppLocalizations? l10n,
  ) {
    final resolvedL10n = _resolveL10n(l10n);
    for (final unit in _allUnits()) {
      final pool = unit.cells.where((rc) {
        final len = candidates[rc[0]][rc[1]].length;
        return len >= 2 && len <= size;
      }).toList();
      if (pool.length < size) continue;

      for (final group in _combinations(pool, size)) {
        final union = <int>{};
        for (final rc in group) {
          union.addAll(candidates[rc[0]][rc[1]]);
        }
        if (union.length != size) continue;

        final eliminations = <HintElimination>[];
        for (final rc in unit.cells) {
          if (group.any((g) => g[0] == rc[0] && g[1] == rc[1])) continue;
          final cellCandidates = candidates[rc[0]][rc[1]];
          for (final d in union) {
            if (cellCandidates.contains(d)) {
              eliminations.add(HintElimination(rc[0], rc[1], d));
            }
          }
        }
        if (eliminations.isEmpty) continue;

        final digits = union.toList()..sort();
        final digitsDesc = digits.join(', ');
        final cellsDesc = group
            .map((rc) => _cellDesc(rc[0], rc[1], resolvedL10n))
            .join(', ');

        final (hRows, hCols, hBoxes) = _highlightFor(unit);
        return Hint(
          technique: technique,
          type: HintType.eliminate,
          explanation: resolvedL10n.explanationNakedSubset(
            _unitDescription(unit, resolvedL10n),
            cellsDesc,
            digitsDesc,
            size,
          ),
          primaryCells: group.map((rc) => HintCell(rc[0], rc[1])).toSet(),
          secondaryCells:
              eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
          highlightedRows: hRows,
          highlightedCols: hCols,
          highlightedBoxes: hBoxes,
          primaryDigits: union,
          eliminations: eliminations,
        );
      }
    }
    return null;
  }

  Hint? findHiddenPair(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findHiddenSubset(resolved, 2, HintTechnique.hiddenPair, l10n);
  }

  Hint? findHiddenTriple(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findHiddenSubset(resolved, 3, HintTechnique.hiddenTriple, l10n);
  }

  Hint? findHiddenQuad(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findHiddenSubset(resolved, 4, HintTechnique.hiddenQuad, l10n);
  }

  /// Hidden N-subset: [size] digits in a unit that, between them, only
  /// appear as candidates in exactly [size] cells mean those digits must
  /// occupy exactly those cells, so every other candidate can be
  /// eliminated from those cells (even though, unlike the naked case,
  /// the cells themselves may carry plenty of other candidates too).
  Hint? _findHiddenSubset(
    List<List<Set<int>>> candidates,
    int size,
    HintTechnique technique,
    AppLocalizations? l10n,
  ) {
    final resolvedL10n = _resolveL10n(l10n);
    for (final unit in _allUnits()) {
      final digitCells = <int, List<List<int>>>{};
      for (var d = 1; d <= 9; d++) {
        final cells = unit.cells
            .where((rc) => candidates[rc[0]][rc[1]].contains(d))
            .toList();
        if (cells.length >= 2 && cells.length <= size) {
          digitCells[d] = cells;
        }
      }
      final digitPool = digitCells.keys.toList()..sort();
      if (digitPool.length < size) continue;

      for (final digitGroup in _combinations(digitPool, size)) {
        final cellUnion = <List<int>>[];
        final seenCells = <int>{};
        for (final d in digitGroup) {
          for (final rc in digitCells[d]!) {
            if (seenCells.add(rc[0] * 9 + rc[1])) cellUnion.add(rc);
          }
        }
        if (cellUnion.length != size) continue;

        final eliminations = <HintElimination>[];
        for (final rc in cellUnion) {
          final cellCandidates = candidates[rc[0]][rc[1]];
          for (final d in cellCandidates) {
            if (!digitGroup.contains(d)) {
              eliminations.add(HintElimination(rc[0], rc[1], d));
            }
          }
        }
        if (eliminations.isEmpty) continue;

        final digitsDesc = digitGroup.join(', ');
        final cellsDesc = cellUnion
            .map((rc) => _cellDesc(rc[0], rc[1], resolvedL10n))
            .join(', ');

        final (hRows, hCols, hBoxes) = _highlightFor(unit);
        return Hint(
          technique: technique,
          type: HintType.eliminate,
          explanation: resolvedL10n.explanationHiddenSubset(
            _unitDescription(unit, resolvedL10n),
            digitsDesc,
            cellsDesc,
          ),
          primaryCells: cellUnion.map((rc) => HintCell(rc[0], rc[1])).toSet(),
          highlightedRows: hRows,
          highlightedCols: hCols,
          highlightedBoxes: hBoxes,
          primaryDigits: digitGroup.toSet(),
          eliminations: eliminations,
        );
      }
    }
    return null;
  }
}
