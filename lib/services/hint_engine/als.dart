part of '../hint_engine.dart';

/// Sue de Coq — a Distributed Disjoint Subset around a box/line crossing.
///
/// Take 2-3 empty cells C on the intersection of a box and a line whose
/// candidate union V has at least |C|+2 digits, an Almost Locked Set A on
/// the rest of the line (|A| cells, |A|+1 digits D) and an ALS B on the
/// rest of the box (digits E), with A,B cell-disjoint and D∩E empty. If
/// exactly |C|-2 digits of V escape D∪E, then the |C|+|A|+|B| cells hold
/// exactly that many distinct digits, each confined to one side:
///
///  - a D digit fits only in A∪C (all on the line, so at most once), and
///  - an E digit only in B∪C (all in the box),
///  - a leftover V digit only in C itself,
///
/// so every one of them lands exactly once inside the pattern — and can be
/// eliminated from the rest of its confining unit. This is the classic
/// disjoint form only (JS's AALS/overlap extensions are deliberately not
/// ported — their extra soundness conditions aren't re-derivable as
/// cleanly, and the classic form is what the walkthrough can explain).
extension HintEngineSueDeCoq on HintEngine {
  Hint? findSueDeCoq(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    final resolvedL10n = _resolveL10n(l10n);

    for (var box = 0; box < 9; box++) {
      final r0 = box ~/ 3 * 3, c0 = box % 3 * 3;
      final boxCells = <int>[
        for (var r = r0; r < r0 + 3; r++)
          for (var c = c0; c < c0 + 3; c++)
            if (resolved[r][c].isNotEmpty) r * 9 + c,
      ];
      for (var lineNo = 0; lineNo < 6; lineNo++) {
        final isRow = lineNo < 3;
        final lineIdx = isRow ? r0 + lineNo : c0 + (lineNo - 3);
        final lineCells = <int>[
          for (var j = 0; j < 9; j++)
            if (resolved[isRow ? lineIdx : j][isRow ? j : lineIdx].isNotEmpty)
              isRow ? lineIdx * 9 + j : j * 9 + lineIdx,
        ];
        final inter =
            lineCells.where((cell) => _boxOfCell(cell) == box).toList();
        if (inter.length < 2) continue;

        for (var k = 2; k <= inter.length; k++) {
          for (final c in _combinations(inter, k)) {
            final v = <int>{
              for (final cell in c) ...resolved[cell ~/ 9][cell % 9],
            };
            if (v.length < k + 2) continue;
            final linePool =
                lineCells.where((cell) => !c.contains(cell)).toList();
            final boxPool =
                boxCells.where((cell) => !c.contains(cell)).toList();

            for (final a in _alsSubsets(resolved, linePool)) {
              for (final b in _alsSubsets(resolved, boxPool)) {
                if (a.cells.any(b.cells.contains)) continue;
                if (a.digits.any(b.digits.contains)) continue;
                final rem = v
                    .where((d) =>
                        !a.digits.contains(d) && !b.digits.contains(d))
                    .toSet();
                if (rem.length != k - 2) continue;

                final eliminations = <HintElimination>[];
                final seen = <int>{};
                void collect(List<int> pool, List<int> keep, Set<int> gone) {
                  for (final cell in pool) {
                    if (keep.contains(cell)) continue;
                    for (final d in resolved[cell ~/ 9][cell % 9]) {
                      if (gone.contains(d) && seen.add(cell * 10 + d)) {
                        eliminations
                            .add(HintElimination(cell ~/ 9, cell % 9, d));
                      }
                    }
                  }
                }

                collect(linePool, a.cells, {...a.digits, ...rem});
                collect(boxPool, b.cells, {...b.digits, ...rem});
                if (eliminations.isEmpty) continue;

                final interDesc = c
                    .map((cell) => _cellDesc(cell ~/ 9, cell % 9, resolvedL10n))
                    .join('·');
                final allDigits = ({...v, ...a.digits, ...b.digits}.toList()
                      ..sort())
                    .join('·');
                final lineDesc = isRow
                    ? _rowDesc(lineIdx, resolvedL10n)
                    : _colDesc(lineIdx, resolvedL10n);

                return Hint(
                  technique: HintTechnique.sueDeCoq,
                  type: HintType.eliminate,
                  explanation: resolvedL10n.explanationSueDeCoq(
                      interDesc, allDigits),
                  mainInfo:
                      '$lineDesc · ${_boxDescription(box ~/ 3, box % 3, resolvedL10n)}',
                  primaryCells: {
                    for (final cell in c) HintCell(cell ~/ 9, cell % 9),
                  },
                  colorGroupA: {
                    for (final cell in a.cells) HintCell(cell ~/ 9, cell % 9),
                  },
                  colorGroupB: {
                    for (final cell in b.cells) HintCell(cell ~/ 9, cell % 9),
                  },
                  secondaryCells: eliminations
                      .map((e) => HintCell(e.row, e.col))
                      .toSet(),
                  primaryDigits: {...v, ...a.digits, ...b.digits},
                  highlightedRows: isRow ? {lineIdx} : const {},
                  highlightedCols: isRow ? const {} : {lineIdx},
                  highlightedBoxes: {box},
                  eliminations: eliminations,
                  digitGroups: [v, a.digits, b.digits],
                );
              }
            }
          }
        }
      }
    }
    return null;
  }

  static int _boxOfCell(int cell) =>
      (cell ~/ 9) ~/ 3 * 3 + (cell % 9) ~/ 3;

  /// Every Almost Locked Set inside [pool]: 1-4 cells holding exactly one
  /// more distinct candidate than cells. Size 1 is a bivalue cell.
  List<_Als> _alsSubsets(List<List<Set<int>>> candidates, List<int> pool) {
    final result = <_Als>[];
    for (var size = 1; size <= HintEngineAic._maxAlsCells; size++) {
      if (size > pool.length) break;
      for (final combo in _combinations(pool, size)) {
        final union = <int>{
          for (final cell in combo) ...candidates[cell ~/ 9][cell % 9],
        };
        if (union.length == size + 1) result.add(_Als(combo, union));
      }
    }
    return result;
  }
}

class _Als {
  const _Als(this.cells, this.digits);

  final List<int> cells;
  final Set<int> digits;
}
