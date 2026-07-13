part of '../hint_engine.dart';

extension HintEngineUniqueness on HintEngine {
  /// BUG+1 (Bi-Value Universal Grave): if every remaining empty cell has
  /// exactly 2 candidates, the puzzle would have 0 or 2 solutions (a "BUG"
  /// deadly pattern — impossible for a validly unique puzzle). BUG+1 is the
  /// one-cell-away case: exactly one empty cell (the "extra" cell) has 3
  /// candidates while every other empty cell already has exactly 2. For
  /// each of the extra cell's 3 candidates, this checks whether excluding
  /// it (leaving the other two) would complete a valid deadly pattern
  /// grid-wide — every unit's remaining candidates would each appear in
  /// exactly 2 cells, which [the theorem above] proves can't happen in a
  /// uniquely-solvable puzzle. Since excluding that candidate is therefore
  /// impossible, it must be the extra cell's actual value.
  ///
  /// Deliberately checked computationally (simulate the exclusion, verify
  /// the deadly-pattern property directly) rather than via a closed-form
  /// parity shortcut — this ties the implementation directly to the proven
  /// definition instead of a hand-derived formula that would be easy to get
  /// subtly wrong.
  Hint? findBugPlusOne(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolvedL10n = _resolveL10n(l10n);
    final grid = SudokuGrid(board);
    final cands = candidates ?? _freshCandidates(board);

    List<int>? extraCell;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (grid.get(r, c) != 0) continue;
        final count = cands[r][c].length;
        if (count == 2) continue;
        if (count == 3 && extraCell == null) {
          extraCell = [r, c];
          continue;
        }
        // A second 3-candidate cell, any cell with >3, or a cell with <2
        // (should already be resolved by an earlier technique) all mean
        // this isn't a clean BUG+1 shape.
        return null;
      }
    }
    if (extraCell == null) return null;

    final row = extraCell[0];
    final col = extraCell[1];
    final threeCandidates = cands[row][col];

    for (final digit in threeCandidates) {
      final hypothetical = threeCandidates.toSet()..remove(digit);
      if (_completesDeadlyPattern(board, cands, row, col, hypothetical)) {
        return Hint(
          technique: HintTechnique.bugPlusOne,
          type: HintType.reveal,
          explanation: resolvedL10n.explanationBugPlusOne(row + 1, col + 1, digit),
          primaryCells: {HintCell(row, col)},
          row: row,
          col: col,
          value: digit,
        );
      }
    }
    return null;
  }

  /// Whether replacing the extra cell's candidates with [reducedCandidates]
  /// (2 digits) makes every unit's candidates pair up exactly twice per
  /// digit — the deadly "Bi-Value Universal Grave" pattern.
  bool _completesDeadlyPattern(
    List<List<int>> board,
    List<List<Set<int>>> candidates,
    int extraRow,
    int extraCol,
    Set<int> reducedCandidates,
  ) {
    for (final unit in _allUnits()) {
      final counts = <int, int>{};
      for (final rc in unit.cells) {
        if (board[rc[0]][rc[1]] != 0) continue;
        final isExtraCell = rc[0] == extraRow && rc[1] == extraCol;
        final cellCandidates =
            isExtraCell ? reducedCandidates : candidates[rc[0]][rc[1]];
        for (final digit in cellCandidates) {
          counts[digit] = (counts[digit] ?? 0) + 1;
        }
      }
      if (counts.values.any((count) => count != 2)) return false;
    }
    return true;
  }
}
