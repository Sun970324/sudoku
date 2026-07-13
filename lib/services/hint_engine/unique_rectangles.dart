part of '../hint_engine.dart';

extension HintEngineUniqueRectangles on HintEngine {
  /// Finds every Unique Rectangle base: 4 cells at 2 rows x 2 columns
  /// spanning exactly 2 boxes (`(sameBoxRow) != (sameBoxCol)` — both same
  /// would put all 4 cells in 1 box, both different would spread them
  /// across 4 boxes), all still unsolved, whose candidates all share
  /// exactly 2 common digits (the "deadly pair" — always exactly 2 in any
  /// genuine match, since at least 2 of the 4 cells must be pure for any
  /// UR type to apply). Row-major, deterministic order.
  List<_URBase> _findURBases(List<List<Set<int>>> candidates) {
    final bases = <_URBase>[];
    for (var r1 = 0; r1 < 9; r1++) {
      for (var r2 = r1 + 1; r2 < 9; r2++) {
        final sameBoxRow = r1 ~/ 3 == r2 ~/ 3;
        for (var c1 = 0; c1 < 9; c1++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            final sameBoxCol = c1 ~/ 3 == c2 ~/ 3;
            if (sameBoxRow == sameBoxCol) continue;

            final cells = [
              [r1, c1],
              [r1, c2],
              [r2, c1],
              [r2, c2],
            ];
            if (cells.any((rc) => candidates[rc[0]][rc[1]].length < 2)) {
              continue;
            }

            var common = candidates[r1][c1];
            for (final rc in cells.skip(1)) {
              common = common.intersection(candidates[rc[0]][rc[1]]);
            }
            if (common.length != 2) continue;
            final pair = common.toList()..sort();

            final List<List<int>> group1;
            final List<List<int>> group2;
            if (sameBoxRow) {
              // Rows share a box-row band, columns don't -> each box
              // group shares a column.
              group1 = [
                [r1, c1],
                [r2, c1],
              ];
              group2 = [
                [r1, c2],
                [r2, c2],
              ];
            } else {
              // Columns share a box-column band, rows don't -> each box
              // group shares a row.
              group1 = [
                [r1, c1],
                [r1, c2],
              ];
              group2 = [
                [r2, c1],
                [r2, c2],
              ];
            }
            bases.add(_URBase(group1, group2, pair[0], pair[1]));
          }
        }
      }
    }
    return bases;
  }

  bool _urCellsPure(
    List<List<Set<int>>> candidates,
    List<List<int>> group,
  ) =>
      group.every((rc) => candidates[rc[0]][rc[1]].length == 2);

  /// Unique Rectangle Type 1: 3 of the 4 cells are pure {a, b}, the 4th
  /// has extra candidates too. If the 4th were also just {a, b}, the
  /// puzzle would have 2 solutions (swap a/b across the pure diagonal) —
  /// so a and b are eliminated from the 4th cell.
  Hint? findUniqueRectangleType1(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolvedL10n = _resolveL10n(l10n);
    final resolved = candidates ?? _freshCandidates(board);
    for (final base in _findURBases(resolved)) {
      final cells = [...base.group1, ...base.group2];
      final pureCells =
          cells.where((rc) => resolved[rc[0]][rc[1]].length == 2).toList();
      if (pureCells.length != 3) continue;
      final extra =
          cells.firstWhere((rc) => resolved[rc[0]][rc[1]].length != 2);
      final extraCandidates = resolved[extra[0]][extra[1]];

      final eliminations = [
        if (extraCandidates.contains(base.a))
          HintElimination(extra[0], extra[1], base.a),
        if (extraCandidates.contains(base.b))
          HintElimination(extra[0], extra[1], base.b),
      ];
      if (eliminations.isEmpty) continue;

      final cellsDesc = cells
          .map((rc) => _cellDesc(rc[0], rc[1], resolvedL10n))
          .join(', ');
      return Hint(
        technique: HintTechnique.uniqueRectangleType1,
        type: HintType.eliminate,
        explanation: resolvedL10n.explanationUniqueRectangleType1(
          cellsDesc,
          base.a,
          base.b,
        ),
        primaryCells: cells.map((rc) => HintCell(rc[0], rc[1])).toSet(),
        secondaryCells: {HintCell(extra[0], extra[1])},
        highlightedBoxes: {
          _boxIndexOf(base.group1[0]),
          _boxIndexOf(base.group2[0]),
        },
        eliminations: eliminations,
      );
    }
    return null;
  }

  /// Unique Rectangle Type 2: one box group (the floor) is pure {a, b};
  /// the other (the roof) both carry the SAME single extra digit c (i.e.
  /// each roof cell is exactly {a, b, c}). At least one roof cell must be
  /// c to avoid the deadly pattern, so c can be eliminated from any cell
  /// that peers both roof cells.
  Hint? findUniqueRectangleType2(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolvedL10n = _resolveL10n(l10n);
    final resolved = candidates ?? _freshCandidates(board);
    for (final base in _findURBases(resolved)) {
      final g1Pure = _urCellsPure(resolved, base.group1);
      final g2Pure = _urCellsPure(resolved, base.group2);
      if (g1Pure == g2Pure) continue;
      final roof = g1Pure ? base.group2 : base.group1;

      final extra0 =
          resolved[roof[0][0]][roof[0][1]].difference({base.a, base.b});
      final extra1 =
          resolved[roof[1][0]][roof[1][1]].difference({base.a, base.b});
      if (extra0.length != 1 || extra1.length != 1) continue;
      final c = extra0.first;
      if (extra1.first != c) continue;

      final urIndices = {
        ...base.group1,
        ...base.group2,
      }.map((rc) => rc[0] * 9 + rc[1]).toSet();

      final eliminations = <HintElimination>[];
      for (var r = 0; r < 9; r++) {
        for (var col = 0; col < 9; col++) {
          if (urIndices.contains(r * 9 + col)) continue;
          if (!resolved[r][col].contains(c)) continue;
          if (_seeEachOther([r, col], roof[0]) &&
              _seeEachOther([r, col], roof[1])) {
            eliminations.add(HintElimination(r, col, c));
          }
        }
      }
      if (eliminations.isEmpty) continue;

      return Hint(
        technique: HintTechnique.uniqueRectangleType2,
        type: HintType.eliminate,
        explanation: resolvedL10n.explanationUniqueRectangleType2(
          _cellDesc(roof[0][0], roof[0][1], resolvedL10n),
          _cellDesc(roof[1][0], roof[1][1], resolvedL10n),
          base.a,
          base.b,
          c,
        ),
        primaryCells: {
          ...base.group1,
          ...base.group2,
        }.map((rc) => HintCell(rc[0], rc[1])).toSet(),
        secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
        highlightedBoxes: {
          _boxIndexOf(base.group1[0]),
          _boxIndexOf(base.group2[0]),
        },
        eliminations: eliminations,
      );
    }
    return null;
  }

  /// Unique Rectangle Type 3: floor pure {a, b}; the roof cells' extra
  /// candidates (beyond a/b), combined, act as a single "virtual cell". If
  /// that virtual cell plus 1-2 real external cells sharing a unit with
  /// both roof cells forms an exact Naked Pair/Triple (their combined
  /// candidates span exactly as many digits as participating cells), the
  /// subset's digits can be eliminated from the rest of that unit — same
  /// union-size logic as [_findNakedSubset], just with the roof pair
  /// standing in for one slot instead of a real cell.
  Hint? findUniqueRectangleType3(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolvedL10n = _resolveL10n(l10n);
    final resolved = candidates ?? _freshCandidates(board);
    for (final base in _findURBases(resolved)) {
      final g1Pure = _urCellsPure(resolved, base.group1);
      final g2Pure = _urCellsPure(resolved, base.group2);
      if (g1Pure == g2Pure) continue;
      final roof = g1Pure ? base.group2 : base.group1;

      final virtualDigits = resolved[roof[0][0]][roof[0][1]]
          .union(resolved[roof[1][0]][roof[1][1]])
          .difference({base.a, base.b});
      // A single extra digit is Type 2's territory, not Type 3's.
      if (virtualDigits.length < 2 || virtualDigits.length > 3) continue;

      final roofIndices = roof.map((rc) => rc[0] * 9 + rc[1]).toSet();
      final boxCells = SudokuGrid.boxCellsOf(roof[0][0], roof[0][1]);
      final sameRow = roof[0][0] == roof[1][0];
      final lineCells = sameRow
          ? [
              for (var c = 0; c < 9; c++) [roof[0][0], c]
            ]
          : [
              for (var r = 0; r < 9; r++) [r, roof[0][1]]
            ];

      final externalCount = virtualDigits.length - 1;
      for (final unit in [boxCells, lineCells]) {
        final pool = unit.where((rc) {
          if (roofIndices.contains(rc[0] * 9 + rc[1])) return false;
          final len = resolved[rc[0]][rc[1]].length;
          return len >= 1 && len <= virtualDigits.length;
        }).toList();
        if (pool.length < externalCount) continue;

        for (final extGroup in _combinations(pool, externalCount)) {
          final union = <int>{...virtualDigits};
          for (final e in extGroup) {
            union.addAll(resolved[e[0]][e[1]]);
          }
          if (union.length != virtualDigits.length) continue;

          final excluded = {
            ...roofIndices,
            ...extGroup.map((rc) => rc[0] * 9 + rc[1]),
          };
          final eliminations = <HintElimination>[];
          for (final rc in unit) {
            if (excluded.contains(rc[0] * 9 + rc[1])) continue;
            for (final d in union) {
              if (resolved[rc[0]][rc[1]].contains(d)) {
                eliminations.add(HintElimination(rc[0], rc[1], d));
              }
            }
          }
          if (eliminations.isEmpty) continue;

          final digitsDesc = (union.toList()..sort()).join(', ');
          final urBoxes = {
            _boxIndexOf(base.group1[0]),
            _boxIndexOf(base.group2[0]),
          };
          // The 2 UR boxes are always highlighted; if this particular
          // match came from the roof's shared LINE (not its shared box,
          // already covered by urBoxes), highlight that line too.
          final onLine = identical(unit, lineCells);
          return Hint(
            technique: HintTechnique.uniqueRectangleType3,
            type: HintType.eliminate,
            explanation: resolvedL10n.explanationUniqueRectangleType3(
              _cellDesc(roof[0][0], roof[0][1], resolvedL10n),
              _cellDesc(roof[1][0], roof[1][1], resolvedL10n),
              digitsDesc,
            ),
            primaryCells: {
              ...roof,
              ...extGroup,
            }.map((rc) => HintCell(rc[0], rc[1])).toSet(),
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            highlightedRows: onLine && sameRow ? {roof[0][0]} : const {},
            highlightedCols: onLine && !sameRow ? {roof[0][1]} : const {},
            highlightedBoxes: urBoxes,
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }

  /// Unique Rectangle Type 4: floor pure {a, b}; the roof cells always
  /// share a line (row or column, on top of their shared box, per the UR
  /// geometry). If one deadly-pair digit is conjugate in that line (its
  /// only 2 candidate cells in the whole line are the 2 roof cells), the
  /// other digit can be eliminated from both roof cells — if it weren't,
  /// the floor/roof a<->b swap would still be realizable regardless of
  /// the conjugacy, so it must be removed to avoid a second solution.
  Hint? findUniqueRectangleType4(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolvedL10n = _resolveL10n(l10n);
    final resolved = candidates ?? _freshCandidates(board);
    for (final base in _findURBases(resolved)) {
      final g1Pure = _urCellsPure(resolved, base.group1);
      final g2Pure = _urCellsPure(resolved, base.group2);
      if (g1Pure == g2Pure) continue;
      final roof = g1Pure ? base.group2 : base.group1;

      final sameRow = roof[0][0] == roof[1][0];
      final lineCells = sameRow
          ? [
              for (var c = 0; c < 9; c++) [roof[0][0], c]
            ]
          : [
              for (var r = 0; r < 9; r++) [r, roof[0][1]]
            ];

      for (final lockedDigit in [base.a, base.b]) {
        final otherDigit = lockedDigit == base.a ? base.b : base.a;
        final cellsWithLocked = lineCells
            .where((rc) => resolved[rc[0]][rc[1]].contains(lockedDigit))
            .toList();
        if (cellsWithLocked.length != 2) continue;
        final isRoofConjugate = cellsWithLocked
                .any((rc) => rc[0] == roof[0][0] && rc[1] == roof[0][1]) &&
            cellsWithLocked
                .any((rc) => rc[0] == roof[1][0] && rc[1] == roof[1][1]);
        if (!isRoofConjugate) continue;

        final eliminations = [
          for (final rc in roof)
            if (resolved[rc[0]][rc[1]].contains(otherDigit))
              HintElimination(rc[0], rc[1], otherDigit),
        ];
        if (eliminations.isEmpty) continue;

        return Hint(
          technique: HintTechnique.uniqueRectangleType4,
          type: HintType.eliminate,
          explanation: resolvedL10n.explanationUniqueRectangleType4(
            _cellDesc(roof[0][0], roof[0][1], resolvedL10n),
            _cellDesc(roof[1][0], roof[1][1], resolvedL10n),
            lockedDigit,
            otherDigit,
          ),
          primaryCells: {
            ...base.group1,
            ...base.group2,
          }.map((rc) => HintCell(rc[0], rc[1])).toSet(),
          secondaryCells: roof.map((rc) => HintCell(rc[0], rc[1])).toSet(),
          highlightedRows: sameRow ? {roof[0][0]} : const {},
          highlightedCols: sameRow ? const {} : {roof[0][1]},
          highlightedBoxes: {
            _boxIndexOf(base.group1[0]),
            _boxIndexOf(base.group2[0]),
          },
          eliminations: eliminations,
        );
      }
    }
    return null;
  }
}
