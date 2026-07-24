part of '../hint_engine.dart';

/// Triple Firework — three digits whose row and column candidates both
/// "spray" out of one box by a single wing cell each.
///
/// Fix a cross cell X = (R, C) in box B, and three digits whose candidates
/// in row R all lie inside B except for at most one shared cell (the row
/// wing, on R outside B), and likewise in column C with a column wing.
/// Each digit must still be placeable in both lines (it has a candidate
/// there at all). Then each digit's row placement is in B∩R or the row
/// wing, and its column placement in B∩C or the column wing — but B can
/// hold it only once, so every digit must occupy X (covering both) or a
/// wing. Three digits into three cells, one each: {X, row wing, column
/// wing} hold exactly the three digits. So those cells lose every other
/// candidate, and — since a digit placed elsewhere in B would force BOTH
/// its wings, claiming two of the three cells — the box's non-cross cells
/// lose all three digits too.
extension HintEngineFireworks on HintEngine {
  Hint? findTripleFirework(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    final resolvedL10n = _resolveL10n(l10n);

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (resolved[r][c].isEmpty) continue;
        final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;

        // Per digit: where it sits on the row/column outside the box, and
        // whether it is present on the line at all. Eligible digits leak by
        // at most one cell per line.
        final eligible = <int>[];
        final rowOut = <int, Set<int>>{}, colOut = <int, Set<int>>{};
        for (var d = 1; d <= 9; d++) {
          var inRow = false, inCol = false;
          final rOut = <int>{}, cOut = <int>{};
          for (var j = 0; j < 9; j++) {
            if (resolved[r][j].contains(d)) {
              inRow = true;
              if (j ~/ 3 != c ~/ 3) rOut.add(r * 9 + j);
            }
            if (resolved[j][c].contains(d)) {
              inCol = true;
              if (j ~/ 3 != r ~/ 3) cOut.add(j * 9 + c);
            }
          }
          if (inRow && inCol && rOut.length <= 1 && cOut.length <= 1) {
            eligible.add(d);
            rowOut[d] = rOut;
            colOut[d] = cOut;
          }
        }
        if (eligible.length < 3) continue;

        for (final triple in _combinations(eligible, 3)) {
          final rowWings = <int>{for (final d in triple) ...rowOut[d]!};
          final colWings = <int>{for (final d in triple) ...colOut[d]!};
          // One shared wing per line — an empty union would be a plain
          // intersection pattern, not a firework.
          if (rowWings.length != 1 || colWings.length != 1) continue;
          final rowWing = rowWings.first, colWing = colWings.first;
          final digits = triple.toSet();
          // Every one of the three cells must be able to take its digit.
          if (!resolved[r][c].any(digits.contains) ||
              !resolved[rowWing ~/ 9][rowWing % 9].any(digits.contains) ||
              !resolved[colWing ~/ 9][colWing % 9].any(digits.contains)) {
            continue;
          }

          final eliminations = <HintElimination>[];
          for (final cell in [r * 9 + c, rowWing, colWing]) {
            for (final d in resolved[cell ~/ 9][cell % 9]) {
              if (!digits.contains(d)) {
                eliminations.add(HintElimination(cell ~/ 9, cell % 9, d));
              }
            }
          }
          for (var rr = br; rr < br + 3; rr++) {
            if (rr == r) continue;
            for (var cc = bc; cc < bc + 3; cc++) {
              if (cc == c) continue;
              for (final d in resolved[rr][cc]) {
                if (digits.contains(d)) {
                  eliminations.add(HintElimination(rr, cc, d));
                }
              }
            }
          }
          if (eliminations.isEmpty) continue;

          final digitsDesc = (triple.toList()..sort()).join('·');
          final tripleCells = [r * 9 + c, rowWing, colWing];
          final cellsDesc = tripleCells
              .map((cell) => _cellDesc(cell ~/ 9, cell % 9, resolvedL10n))
              .join('·');
          // The full spray: every candidate cell of the three digits on the
          // two lines (all inside the box or a wing, by construction).
          Set<HintCell> sprayOf(bool row) => {
                for (var j = 0; j < 9; j++)
                  if (resolved[row ? r : j][row ? j : c]
                      .any(digits.contains))
                    row ? HintCell(r, j) : HintCell(j, c),
              };

          return Hint(
            technique: HintTechnique.tripleFirework,
            type: HintType.eliminate,
            explanation: resolvedL10n.explanationTripleFirework(
                digitsDesc, cellsDesc),
            mainInfo:
                '${_rowDesc(r, resolvedL10n)} · ${_colDesc(c, resolvedL10n)}',
            primaryCells: {
              for (final cell in tripleCells)
                HintCell(cell ~/ 9, cell % 9),
            },
            colorGroupA: sprayOf(true),
            colorGroupB: sprayOf(false),
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            primaryDigits: digits,
            highlightedRows: {r},
            highlightedCols: {c},
            highlightedBoxes: {r ~/ 3 * 3 + c ~/ 3},
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }
}
