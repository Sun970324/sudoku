part of '../hint_engine.dart';

extension HintEngineSubsets on HintEngine {
  Hint? findNakedPair(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findNakedSubset(resolved, 2, HintTechnique.nakedPair);
  }

  Hint? findNakedTriple(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findNakedSubset(resolved, 3, HintTechnique.nakedTriple);
  }

  Hint? findNakedQuad(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findNakedSubset(resolved, 4, HintTechnique.nakedQuad);
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
  ) {
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
        final cellsDesc =
            group.map((rc) => '${rc[0] + 1}행${rc[1] + 1}열').join(', ');

        final (hRows, hCols, hBoxes) = _highlightFor(unit);
        return Hint(
          technique: technique,
          type: HintType.eliminate,
          explanation: '${unit.description}에서 $cellsDesc의 후보를 모두 '
              '합치면 $digitsDesc($size개)뿐이에요. 따라서 같은 구역 안 '
              '다른 칸에서는 $digitsDesc을(를) 후보에서 지울 수 있습니다.',
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
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findHiddenSubset(resolved, 2, HintTechnique.hiddenPair);
  }

  Hint? findHiddenTriple(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findHiddenSubset(resolved, 3, HintTechnique.hiddenTriple);
  }

  Hint? findHiddenQuad(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findHiddenSubset(resolved, 4, HintTechnique.hiddenQuad);
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
  ) {
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
        final cellsDesc =
            cellUnion.map((rc) => '${rc[0] + 1}행${rc[1] + 1}열').join(', ');

        final (hRows, hCols, hBoxes) = _highlightFor(unit);
        return Hint(
          technique: technique,
          type: HintType.eliminate,
          explanation: '${unit.description}에서 숫자 $digitsDesc는 오직 '
              '$cellsDesc에만 들어갈 수 있어요. 이 칸들에서는 $digitsDesc 외의 '
              '다른 후보를 모두 지울 수 있습니다.',
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
