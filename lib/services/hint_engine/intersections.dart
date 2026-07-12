part of '../hint_engine.dart';

extension HintEngineIntersections on HintEngine {
  Hint? findIntersectionPointing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findPointing(resolved);
  }

  /// Intersection removal (claiming): a digit confined to one box within a
  /// line lets it be eliminated from the rest of that box outside the line.
  Hint? findIntersectionClaiming(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findClaiming(resolved);
  }

  Hint? _findPointing(List<List<Set<int>>> candidates) {
    for (var boxRow = 0; boxRow < 3; boxRow++) {
      for (var boxCol = 0; boxCol < 3; boxCol++) {
        final boxCells = SudokuGrid.boxCellsOf(boxRow * 3, boxCol * 3);
        for (var d = 1; d <= 9; d++) {
          final cellsWithD = boxCells
              .where((rc) => candidates[rc[0]][rc[1]].contains(d))
              .toList();
          if (cellsWithD.length < 2 || cellsWithD.length > 3) continue;

          final rows = cellsWithD.map((rc) => rc[0]).toSet();
          final cols = cellsWithD.map((rc) => rc[1]).toSet();

          List<HintElimination> eliminations;
          String lineDesc;
          Set<int> lineRows = const {};
          Set<int> lineCols = const {};
          if (rows.length == 1) {
            final r = rows.first;
            lineDesc = '${r + 1}행';
            lineRows = {r};
            eliminations = [
              for (var c = 0; c < 9; c++)
                if (c ~/ 3 != boxCol && candidates[r][c].contains(d))
                  HintElimination(r, c, d),
            ];
          } else if (cols.length == 1) {
            final c = cols.first;
            lineDesc = '${c + 1}열';
            lineCols = {c};
            eliminations = [
              for (var r = 0; r < 9; r++)
                if (r ~/ 3 != boxRow && candidates[r][c].contains(d))
                  HintElimination(r, c, d),
            ];
          } else {
            continue;
          }
          if (eliminations.isEmpty) continue;

          return Hint(
            technique: HintTechnique.intersectionPointing,
            type: HintType.eliminate,
            explanation: '${_boxDescription(boxRow, boxCol)} 안에서 숫자 $d는 '
                '$lineDesc 위에만 있어요. 그래서 $lineDesc의 나머지 칸(박스 밖)에서는 '
                '$d를 후보에서 지울 수 있습니다.',
            primaryCells:
                cellsWithD.map((rc) => HintCell(rc[0], rc[1])).toSet(),
            secondaryCells:
                eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
            highlightedRows: lineRows,
            highlightedCols: lineCols,
            highlightedBoxes: {boxRow * 3 + boxCol},
            eliminations: eliminations,
          );
        }
      }
    }
    return null;
  }

  Hint? _findClaiming(List<List<Set<int>>> candidates) {
    for (var r = 0; r < 9; r++) {
      for (var d = 1; d <= 9; d++) {
        final cellsWithD = [
          for (var c = 0; c < 9; c++)
            if (candidates[r][c].contains(d)) [r, c],
        ];
        if (cellsWithD.length < 2 || cellsWithD.length > 3) continue;
        final boxCols = cellsWithD.map((rc) => rc[1] ~/ 3).toSet();
        if (boxCols.length != 1) continue;

        final boxRow = r ~/ 3;
        final boxCol = boxCols.first;
        final eliminations = [
          for (final bcell in SudokuGrid.boxCellsOf(boxRow * 3, boxCol * 3))
            if (bcell[0] != r && candidates[bcell[0]][bcell[1]].contains(d))
              HintElimination(bcell[0], bcell[1], d),
        ];
        if (eliminations.isEmpty) continue;

        return Hint(
          technique: HintTechnique.intersectionClaiming,
          type: HintType.eliminate,
          explanation: '${r + 1}행에서 숫자 $d는 ${_boxDescription(boxRow, boxCol)} '
              '안에만 있어요. 그래서 같은 박스의 나머지 칸(이 행 밖)에서는 '
              '$d를 후보에서 지울 수 있습니다.',
          primaryCells: cellsWithD.map((rc) => HintCell(rc[0], rc[1])).toSet(),
          secondaryCells:
              eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
          highlightedRows: {r},
          highlightedBoxes: {boxRow * 3 + boxCol},
          eliminations: eliminations,
        );
      }
    }
    for (var c = 0; c < 9; c++) {
      for (var d = 1; d <= 9; d++) {
        final cellsWithD = [
          for (var r = 0; r < 9; r++)
            if (candidates[r][c].contains(d)) [r, c],
        ];
        if (cellsWithD.length < 2 || cellsWithD.length > 3) continue;
        final boxRows = cellsWithD.map((rc) => rc[0] ~/ 3).toSet();
        if (boxRows.length != 1) continue;

        final boxCol = c ~/ 3;
        final boxRow = boxRows.first;
        final eliminations = [
          for (final bcell in SudokuGrid.boxCellsOf(boxRow * 3, boxCol * 3))
            if (bcell[1] != c && candidates[bcell[0]][bcell[1]].contains(d))
              HintElimination(bcell[0], bcell[1], d),
        ];
        if (eliminations.isEmpty) continue;

        return Hint(
          technique: HintTechnique.intersectionClaiming,
          type: HintType.eliminate,
          explanation: '${c + 1}열에서 숫자 $d는 ${_boxDescription(boxRow, boxCol)} '
              '안에만 있어요. 그래서 같은 박스의 나머지 칸(이 열 밖)에서는 '
              '$d를 후보에서 지울 수 있습니다.',
          primaryCells: cellsWithD.map((rc) => HintCell(rc[0], rc[1])).toSet(),
          secondaryCells:
              eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
          highlightedCols: {c},
          highlightedBoxes: {boxRow * 3 + boxCol},
          eliminations: eliminations,
        );
      }
    }
    return null;
  }
}
