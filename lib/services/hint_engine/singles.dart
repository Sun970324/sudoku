part of '../hint_engine.dart';

extension HintEngineSingles on HintEngine {
  Hint? findFullHouse(List<List<int>> board, [AppLocalizations? l10n]) {
    final resolvedL10n = _resolveL10n(l10n);
    final grid = SudokuGrid(board);
    for (final unit in _allUnits()) {
      final emptyCells =
          unit.cells.where((rc) => grid.get(rc[0], rc[1]) == 0).toList();
      if (emptyCells.length != 1) continue;

      final target = emptyCells.first;
      final present = <int>{
        for (final rc in unit.cells) grid.get(rc[0], rc[1]),
      }..remove(0);
      final missing = {for (var v = 1; v <= 9; v++) v}..removeAll(present);
      if (missing.length != 1) continue;
      final value = missing.first;

      final secondary = unit.cells
          .where((rc) => rc[0] != target[0] || rc[1] != target[1])
          .map((rc) => HintCell(rc[0], rc[1]))
          .toSet();

      final (hRows, hCols, hBoxes) = _highlightFor(unit);
      return Hint(
        technique: HintTechnique.fullHouse,
        type: HintType.reveal,
        explanation: resolvedL10n.explanationFullHouse(
          _unitDescription(unit, resolvedL10n),
          value,
        ),
        primaryCells: {HintCell(target[0], target[1])},
        secondaryCells: secondary,
        highlightedRows: hRows,
        highlightedCols: hCols,
        highlightedBoxes: hBoxes,
        row: target[0],
        col: target[1],
        value: value,
      );
    }
    return null;
  }

  Hint? findNakedSingle(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolvedL10n = _resolveL10n(l10n);
    final grid = SudokuGrid(board);
    final cands = candidates ?? _freshCandidates(board);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (grid.get(r, c) != 0) continue;
        final cellCandidates = cands[r][c];
        if (cellCandidates.length != 1) continue;
        final value = cellCandidates.first;

        final secondary = _peers(r, c)
            .where((rc) => grid.get(rc[0], rc[1]) != 0)
            .map((rc) => HintCell(rc[0], rc[1]))
            .toSet();

        return Hint(
          technique: HintTechnique.nakedSingle,
          type: HintType.reveal,
          explanation: resolvedL10n.explanationNakedSingle(r + 1, c + 1, value),
          primaryCells: {HintCell(r, c)},
          secondaryCells: secondary,
          row: r,
          col: c,
          value: value,
        );
      }
    }
    return null;
  }

  Hint? findHiddenSingle(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolvedL10n = _resolveL10n(l10n);
    final resolved = candidates ?? _freshCandidates(board);

    for (final unit in _allUnits()) {
      for (var value = 1; value <= 9; value++) {
        final cellsWithValue = unit.cells
            .where((rc) => resolved[rc[0]][rc[1]].contains(value))
            .toList();
        if (cellsWithValue.length != 1) continue;
        final target = cellsWithValue.first;

        final secondary = unit.cells
            .where((rc) => rc[0] != target[0] || rc[1] != target[1])
            .map((rc) => HintCell(rc[0], rc[1]))
            .toSet();

        // For every other still-empty cell in the unit, value isn't a
        // candidate there because it's already placed somewhere in that
        // cell's own row, column, or box — highlight those specific units
        // (so the board visually shows "these areas are already covered by
        // value, that's why only one cell in the unit is left") and also
        // color the exact blocking cell itself, same as any other reason
        // cell. Checking the unit's own row/col/box here is harmless: it
        // always comes back false, since by definition this unit doesn't
        // contain value yet.
        final extraRows = <int>{};
        final extraCols = <int>{};
        final extraBoxes = <int>{};
        final extraSecondary = <HintCell>{};
        for (final rc in unit.cells) {
          if (rc[0] == target[0] && rc[1] == target[1]) continue;
          if (board[rc[0]][rc[1]] != 0) continue;
          final r = rc[0];
          final c = rc[1];
          for (var cc = 0; cc < 9; cc++) {
            if (board[r][cc] == value) {
              extraRows.add(r);
              extraSecondary.add(HintCell(r, cc));
            }
          }
          for (var rr = 0; rr < 9; rr++) {
            if (board[rr][c] == value) {
              extraCols.add(c);
              extraSecondary.add(HintCell(rr, c));
            }
          }
          for (final bcell in SudokuGrid.boxCellsOf(r, c)) {
            if (board[bcell[0]][bcell[1]] == value) {
              extraBoxes.add(_boxIndexOf(rc));
              extraSecondary.add(HintCell(bcell[0], bcell[1]));
            }
          }
        }

        final (hRows, hCols, hBoxes) = _highlightFor(unit);
        return Hint(
          technique: HintTechnique.hiddenSingle,
          type: HintType.reveal,
          explanation: resolvedL10n.explanationHiddenSingle(
            _unitDescription(unit, resolvedL10n),
            value,
            target[0] + 1,
            target[1] + 1,
          ),
          primaryCells: {HintCell(target[0], target[1])},
          secondaryCells: {...secondary, ...extraSecondary},
          highlightedRows: {...hRows, ...extraRows},
          highlightedCols: {...hCols, ...extraCols},
          highlightedBoxes: {...hBoxes, ...extraBoxes},
          row: target[0],
          col: target[1],
          value: value,
        );
      }
    }
    return null;
  }
}
