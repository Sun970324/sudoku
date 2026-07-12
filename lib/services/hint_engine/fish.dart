part of '../hint_engine.dart';

extension HintEngineFish on HintEngine {
  Hint? findXWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXWingRows(resolved) ?? _findXWingCols(resolved);
  }

  Hint? _findXWingRows(List<List<Set<int>>> candidates) {
    for (var d = 1; d <= 9; d++) {
      final rowCols = <int, List<int>>{};
      for (var r = 0; r < 9; r++) {
        final cols = [
          for (var c = 0; c < 9; c++)
            if (candidates[r][c].contains(d)) c,
        ];
        if (cols.length == 2) rowCols[r] = cols;
      }
      final rows = rowCols.keys.toList()..sort();
      for (var i = 0; i < rows.length; i++) {
        for (var j = i + 1; j < rows.length; j++) {
          final r1 = rows[i];
          final r2 = rows[j];
          final cols1 = rowCols[r1]!;
          final cols2 = rowCols[r2]!;
          if (cols1[0] != cols2[0] || cols1[1] != cols2[1]) continue;
          final c1 = cols1[0];
          final c2 = cols1[1];

          final eliminations = <HintElimination>[];
          for (var r = 0; r < 9; r++) {
            if (r == r1 || r == r2) continue;
            for (final c in [c1, c2]) {
              if (candidates[r][c].contains(d)) {
                eliminations.add(HintElimination(r, c, d));
              }
            }
          }
          if (eliminations.isEmpty) continue;

          return Hint(
            technique: HintTechnique.xWing,
            type: HintType.eliminate,
            explanation: '숫자 $d는 ${r1 + 1}행과 ${r2 + 1}행에서 각각 '
                '${c1 + 1}열, ${c2 + 1}열 두 곳에만 들어갈 수 있어요. 네 칸이 '
                '사각형을 이루므로, 두 열의 다른 칸에서는 $d를 후보에서 지울 수 있습니다.',
            primaryCells: {
              HintCell(r1, c1),
              HintCell(r1, c2),
              HintCell(r2, c1),
              HintCell(r2, c2),
            },
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            highlightedRows: {r1, r2},
            highlightedCols: {c1, c2},
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }

  Hint? _findXWingCols(List<List<Set<int>>> candidates) {
    for (var d = 1; d <= 9; d++) {
      final colRows = <int, List<int>>{};
      for (var c = 0; c < 9; c++) {
        final rows = [
          for (var r = 0; r < 9; r++)
            if (candidates[r][c].contains(d)) r,
        ];
        if (rows.length == 2) colRows[c] = rows;
      }
      final cols = colRows.keys.toList()..sort();
      for (var i = 0; i < cols.length; i++) {
        for (var j = i + 1; j < cols.length; j++) {
          final c1 = cols[i];
          final c2 = cols[j];
          final rows1 = colRows[c1]!;
          final rows2 = colRows[c2]!;
          if (rows1[0] != rows2[0] || rows1[1] != rows2[1]) continue;
          final r1 = rows1[0];
          final r2 = rows1[1];

          final eliminations = <HintElimination>[];
          for (var c = 0; c < 9; c++) {
            if (c == c1 || c == c2) continue;
            for (final r in [r1, r2]) {
              if (candidates[r][c].contains(d)) {
                eliminations.add(HintElimination(r, c, d));
              }
            }
          }
          if (eliminations.isEmpty) continue;

          return Hint(
            technique: HintTechnique.xWing,
            type: HintType.eliminate,
            explanation: '숫자 $d는 ${c1 + 1}열과 ${c2 + 1}열에서 각각 '
                '${r1 + 1}행, ${r2 + 1}행 두 곳에만 들어갈 수 있어요. 네 칸이 '
                '사각형을 이루므로, 두 행의 다른 칸에서는 $d를 후보에서 지울 수 있습니다.',
            primaryCells: {
              HintCell(r1, c1),
              HintCell(r2, c1),
              HintCell(r1, c2),
              HintCell(r2, c2),
            },
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            highlightedRows: {r1, r2},
            highlightedCols: {c1, c2},
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }

  /// Swordfish: the 3-line generalization of X-Wing. For a digit confined,
  /// across 3 rows, to a combined span of exactly 3 columns (each row
  /// individually has between 2 and 3 candidate cells for it), the digit
  /// must occupy exactly those 3 (row, column) intersections — so it can
  /// be eliminated from the rest of those 3 columns, outside the 3 base
  /// rows. Deliberately separate code from [findXWing] rather than a
  /// shared refactor (surgical change), but internally size-parameterized
  /// like [_findNakedSubset]/[_findHiddenSubset] so a future Jellyfish
  /// (size 4) request is a small addition rather than a new algorithm.
  Hint? findSwordfish(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findFish(resolved, 3, HintTechnique.swordfish);
  }

  /// Jellyfish: the 4-line generalization of X-Wing/Swordfish, via the
  /// same size-parameterized [_findFish] helper.
  Hint? findJellyfish(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findFish(resolved, 4, HintTechnique.jellyfish);
  }

  Hint? _findFish(
    List<List<Set<int>>> candidates,
    int size,
    HintTechnique technique,
  ) =>
      _findFishRows(candidates, size, technique) ??
      _findFishCols(candidates, size, technique);

  Hint? _findFishRows(
    List<List<Set<int>>> candidates,
    int size,
    HintTechnique technique,
  ) {
    for (var d = 1; d <= 9; d++) {
      final rowCols = <int, Set<int>>{};
      for (var r = 0; r < 9; r++) {
        final cols = {
          for (var c = 0; c < 9; c++)
            if (candidates[r][c].contains(d)) c,
        };
        if (cols.length >= 2 && cols.length <= size) rowCols[r] = cols;
      }
      final rows = rowCols.keys.toList()..sort();
      if (rows.length < size) continue;

      for (final combo in _combinations(rows, size)) {
        final union = <int>{};
        for (final r in combo) {
          union.addAll(rowCols[r]!);
        }
        if (union.length != size) continue;

        final eliminations = <HintElimination>[];
        for (var r = 0; r < 9; r++) {
          if (combo.contains(r)) continue;
          for (final c in union) {
            if (candidates[r][c].contains(d)) {
              eliminations.add(HintElimination(r, c, d));
            }
          }
        }
        if (eliminations.isEmpty) continue;

        final primaryCells = <HintCell>{
          for (final r in combo)
            for (final c in rowCols[r]!) HintCell(r, c),
        };
        final rowsDesc = combo.map((r) => '${r + 1}행').join(', ');
        final colsDesc =
            (union.toList()..sort()).map((c) => '${c + 1}열').join(', ');

        return Hint(
          technique: technique,
          type: HintType.eliminate,
          explanation: '숫자 $d는 $rowsDesc에서 합쳐서 $colsDesc 세 곳에만 들어갈 '
              '수 있어요. 그래서 이 세 열의 다른 칸(이 행들 밖)에서는 $d를 '
              '후보에서 지울 수 있습니다.',
          primaryCells: primaryCells,
          secondaryCells:
              eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
          highlightedRows: combo.toSet(),
          highlightedCols: union,
          eliminations: eliminations,
        );
      }
    }
    return null;
  }

  Hint? _findFishCols(
    List<List<Set<int>>> candidates,
    int size,
    HintTechnique technique,
  ) {
    for (var d = 1; d <= 9; d++) {
      final colRows = <int, Set<int>>{};
      for (var c = 0; c < 9; c++) {
        final rows = {
          for (var r = 0; r < 9; r++)
            if (candidates[r][c].contains(d)) r,
        };
        if (rows.length >= 2 && rows.length <= size) colRows[c] = rows;
      }
      final cols = colRows.keys.toList()..sort();
      if (cols.length < size) continue;

      for (final combo in _combinations(cols, size)) {
        final union = <int>{};
        for (final c in combo) {
          union.addAll(colRows[c]!);
        }
        if (union.length != size) continue;

        final eliminations = <HintElimination>[];
        for (var c = 0; c < 9; c++) {
          if (combo.contains(c)) continue;
          for (final r in union) {
            if (candidates[r][c].contains(d)) {
              eliminations.add(HintElimination(r, c, d));
            }
          }
        }
        if (eliminations.isEmpty) continue;

        final primaryCells = <HintCell>{
          for (final c in combo)
            for (final r in colRows[c]!) HintCell(r, c),
        };
        final colsDesc = combo.map((c) => '${c + 1}열').join(', ');
        final rowsDesc =
            (union.toList()..sort()).map((r) => '${r + 1}행').join(', ');

        return Hint(
          technique: technique,
          type: HintType.eliminate,
          explanation: '숫자 $d는 $colsDesc에서 합쳐서 $rowsDesc 세 곳에만 들어갈 '
              '수 있어요. 그래서 이 세 행의 다른 칸(이 열들 밖)에서는 $d를 '
              '후보에서 지울 수 있습니다.',
          primaryCells: primaryCells,
          secondaryCells:
              eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
          highlightedCols: combo.toSet(),
          highlightedRows: union,
          eliminations: eliminations,
        );
      }
    }
    return null;
  }

  /// Finned X-Wing / Sashimi X-Wing: an "almost X-Wing" — one row (the
  /// clean row) has exactly 2 candidate cells for a digit (the cover
  /// columns); the other row (the fin row) has those same cover column(s)
  /// PLUS extra candidate cells (fins) elsewhere. Finned: the fin row still
  /// has BOTH cover columns as candidates. Sashimi: the fin row is missing
  /// one cover column entirely (structurally replaced by the fins).
  /// Either way: if every fin is false, this is a genuine X-Wing and
  /// eliminates normally in the cover columns outside the 2 base rows; if
  /// some fin is true, its peers lose the digit. A target cell only
  /// survives both branches — and can be eliminated — if it's a normal
  /// X-Wing target AND a peer of every single fin cell (not just "in the
  /// same box" — that's merely the common case where all fins happen to
  /// share one box; checking each fin individually is the fully general,
  /// always-correct version of the rule).
  Hint? findFinnedXWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findFinnedOrSashimiRows(resolved, wantSashimi: false) ??
        _findFinnedOrSashimiCols(resolved, wantSashimi: false);
  }

  Hint? findSashimiXWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findFinnedOrSashimiRows(resolved, wantSashimi: true) ??
        _findFinnedOrSashimiCols(resolved, wantSashimi: true);
  }

  Hint? _findFinnedOrSashimiRows(
    List<List<Set<int>>> candidates, {
    required bool wantSashimi,
  }) {
    for (var d = 1; d <= 9; d++) {
      final rowCols = <int, Set<int>>{};
      for (var r = 0; r < 9; r++) {
        final cols = {
          for (var c = 0; c < 9; c++)
            if (candidates[r][c].contains(d)) c,
        };
        if (cols.isNotEmpty) rowCols[r] = cols;
      }
      final rowKeys = rowCols.keys.toList()..sort();

      for (final rc in rowKeys) {
        if (rowCols[rc]!.length != 2) continue;
        final coverCols = rowCols[rc]!;

        for (final rf in rowKeys) {
          if (rf == rc) continue;
          final rfCols = rowCols[rf]!;
          final fins = rfCols.difference(coverCols);
          final overlap = rfCols.intersection(coverCols);
          if (fins.isEmpty || overlap.isEmpty) continue;
          if ((overlap.length == 1) != wantSashimi) continue;
          final technique = wantSashimi
              ? HintTechnique.sashimiXWing
              : HintTechnique.finnedXWing;

          // Guaranteed non-empty by the `fins.isEmpty` check above — every
          // cover-column candidate would otherwise vacuously pass `.every`
          // below and be eliminated as if this were a plain X-Wing.
          final finCells = fins.map((c) => [rf, c]).toList();

          final eliminations = <HintElimination>[];
          for (var r = 0; r < 9; r++) {
            if (r == rc || r == rf) continue;
            for (final c in coverCols) {
              if (!candidates[r][c].contains(d)) continue;
              if (finCells.every((f) => _seeEachOther([r, c], f))) {
                eliminations.add(HintElimination(r, c, d));
              }
            }
          }
          if (eliminations.isEmpty) continue;

          final primaryCells = <HintCell>{
            for (final c in rowCols[rc]!) HintCell(rc, c),
            for (final c in rfCols) HintCell(rf, c),
          };
          final finsDesc = fins.map((c) => '${rf + 1}행${c + 1}열').join(', ');

          return Hint(
            technique: technique,
            type: HintType.eliminate,
            explanation: '${rc + 1}행은 숫자 $d의 후보가 두 곳뿐인 정석 X-윙 '
                '모양이에요. ${rf + 1}행에는 그 외에 $finsDesc(핀)에도 '
                '후보가 있어서 온전한 X-윙은 아니지만, 핀을 모두 보는 칸에서는 '
                '$d를 후보에서 지울 수 있습니다.',
            primaryCells: primaryCells,
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            highlightedRows: {rc, rf},
            highlightedCols: coverCols,
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }

  Hint? _findFinnedOrSashimiCols(
    List<List<Set<int>>> candidates, {
    required bool wantSashimi,
  }) {
    for (var d = 1; d <= 9; d++) {
      final colRows = <int, Set<int>>{};
      for (var c = 0; c < 9; c++) {
        final rows = {
          for (var r = 0; r < 9; r++)
            if (candidates[r][c].contains(d)) r,
        };
        if (rows.isNotEmpty) colRows[c] = rows;
      }
      final colKeys = colRows.keys.toList()..sort();

      for (final cc in colKeys) {
        if (colRows[cc]!.length != 2) continue;
        final coverRows = colRows[cc]!;

        for (final cf in colKeys) {
          if (cf == cc) continue;
          final cfRows = colRows[cf]!;
          final fins = cfRows.difference(coverRows);
          final overlap = cfRows.intersection(coverRows);
          if (fins.isEmpty || overlap.isEmpty) continue;
          if ((overlap.length == 1) != wantSashimi) continue;
          final technique = wantSashimi
              ? HintTechnique.sashimiXWing
              : HintTechnique.finnedXWing;

          final finCells = fins.map((r) => [r, cf]).toList();

          final eliminations = <HintElimination>[];
          for (var c = 0; c < 9; c++) {
            if (c == cc || c == cf) continue;
            for (final r in coverRows) {
              if (!candidates[r][c].contains(d)) continue;
              if (finCells.every((f) => _seeEachOther([r, c], f))) {
                eliminations.add(HintElimination(r, c, d));
              }
            }
          }
          if (eliminations.isEmpty) continue;

          final primaryCells = <HintCell>{
            for (final r in colRows[cc]!) HintCell(r, cc),
            for (final r in cfRows) HintCell(r, cf),
          };
          final finsDesc = fins.map((r) => '${r + 1}행${cf + 1}열').join(', ');

          return Hint(
            technique: technique,
            type: HintType.eliminate,
            explanation: '${cc + 1}열은 숫자 $d의 후보가 두 곳뿐인 정석 X-윙 '
                '모양이에요. ${cf + 1}열에는 그 외에 $finsDesc(핀)에도 '
                '후보가 있어서 온전한 X-윙은 아니지만, 핀을 모두 보는 칸에서는 '
                '$d를 후보에서 지울 수 있습니다.',
            primaryCells: primaryCells,
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            highlightedCols: {cc, cf},
            highlightedRows: coverRows,
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }
}
