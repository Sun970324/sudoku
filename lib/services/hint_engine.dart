import '../models/hint.dart';
import '../models/sudoku_grid.dart';

enum _UnitType { row, col, box }

class _Unit {
  const _Unit(this.cells, this.description, this.type, this.index);

  final List<List<int>> cells;
  final String description;

  /// Whether this unit is a row, column, or box.
  final _UnitType type;

  /// Row/column index (0-8), or box index (0-8, `boxRow * 3 + boxCol`).
  final int index;
}

/// A candidate Unique Rectangle base: 4 cells at 2 rows x 2 columns
/// spanning exactly 2 boxes, grouped by which box they belong to.
/// [group1]/[group2] always share a line with each other (both cells of
/// a group share a column when the rectangle's 2 rows share a box-row
/// band, or share a row when its 2 columns share a box-column band) —
/// this falls straight out of the geometry, never mixed. [a]/[b] are the
/// "deadly pair" digits common to all 4 cells.
class _URBase {
  const _URBase(this.group1, this.group2, this.a, this.b);

  final List<List<int>> group1;
  final List<List<int>> group2;
  final int a;
  final int b;
}

List<_Unit> _allUnits() {
  final units = <_Unit>[];
  for (var r = 0; r < 9; r++) {
    units.add(_Unit(
      [
        for (var c = 0; c < 9; c++) [r, c]
      ],
      '${r + 1}행',
      _UnitType.row,
      r,
    ));
  }
  for (var c = 0; c < 9; c++) {
    units.add(_Unit(
      [
        for (var r = 0; r < 9; r++) [r, c]
      ],
      '${c + 1}열',
      _UnitType.col,
      c,
    ));
  }
  for (var boxRow = 0; boxRow < 3; boxRow++) {
    for (var boxCol = 0; boxCol < 3; boxCol++) {
      final cells = <List<int>>[
        for (var r = boxRow * 3; r < boxRow * 3 + 3; r++)
          for (var c = boxCol * 3; c < boxCol * 3 + 3; c++) [r, c],
      ];
      units.add(_Unit(
        cells,
        _boxDescription(boxRow, boxCol),
        _UnitType.box,
        boxRow * 3 + boxCol,
      ));
    }
  }
  return units;
}

String _boxDescription(int boxRow, int boxCol) {
  final boxIndex = boxRow * 3 + boxCol + 1;
  return '박스 $boxIndex (${boxRow * 3 + 1}~${boxRow * 3 + 3}행, '
      '${boxCol * 3 + 1}~${boxCol * 3 + 3}열)';
}

/// The box index (0-8, `boxRow * 3 + boxCol`) containing [cell].
int _boxIndexOf(List<int> cell) => (cell[0] ~/ 3) * 3 + cell[1] ~/ 3;

/// The `(highlightedRows, highlightedCols, highlightedBoxes)` triple for a
/// [Hint] whose reasoning is confined to [unit].
(Set<int>, Set<int>, Set<int>) _highlightFor(_Unit unit) => switch (unit.type) {
      _UnitType.row => ({unit.index}, const <int>{}, const <int>{}),
      _UnitType.col => (const <int>{}, {unit.index}, const <int>{}),
      _UnitType.box => (const <int>{}, const <int>{}, {unit.index}),
    };

/// Whether cells [a] and [b] (each a `[row, col]` pair) share a row,
/// column, or box — i.e. are Sudoku peers of each other.
bool _seeEachOther(List<int> a, List<int> b) =>
    (a[0] != b[0] || a[1] != b[1]) &&
    _peers(a[0], a[1]).any((p) => p[0] == b[0] && p[1] == b[1]);

List<List<int>> _peers(int row, int col) {
  final peers = <List<int>>[];
  for (var c = 0; c < 9; c++) {
    if (c != col) peers.add([row, c]);
  }
  for (var r = 0; r < 9; r++) {
    if (r != row) peers.add([r, col]);
  }
  final boxRow = (row ~/ 3) * 3;
  final boxCol = (col ~/ 3) * 3;
  for (var r = boxRow; r < boxRow + 3; r++) {
    for (var c = boxCol; c < boxCol + 3; c++) {
      if (r != row || c != col) peers.add([r, c]);
    }
  }
  return peers;
}

/// All size-[k] combinations of [items], in lexicographic order (so callers
/// that scan digits 1-9 or cells in a fixed unit order keep finding the
/// same "first match" they would with a hand-written nested loop).
Iterable<List<T>> _combinations<T>(List<T> items, int k) sync* {
  if (k == 0) {
    yield const [];
    return;
  }
  for (var i = 0; i <= items.length - k; i++) {
    for (final rest in _combinations(items.sublist(i + 1), k - 1)) {
      yield [items[i], ...rest];
    }
  }
}

/// Finds the next logical deduction a human solver could make on [board],
/// trying techniques in increasing difficulty order (see [hintTechniqueOrder])
/// and returning the first one that applies. Reveal-type techniques (Full
/// House, Naked Single, Hidden Single) always compute candidates fresh from
/// the board's confirmed digits, regardless of [findHint]'s `candidates`
/// argument — their correctness must not depend on whatever the player has
/// or hasn't noted. Eliminate-type techniques (Naked/Hidden Pair/Triple/Quad,
/// Intersection Pointing/Claiming, X-Wing, Simple Coloring, XY-Wing) use
/// the supplied `candidates` grid when given — typically the player's own
/// current notes (see
/// [GameController.requestHint]), so a hint reflects what they've actually
/// narrowed down and, once applied, isn't rediscovered identically forever
/// (since applying an eliminate-type hint only edits notes, never the
/// board). When omitted, these also fall back to a fresh board computation.
class HintEngine {
  List<List<Set<int>>> _freshCandidates(List<List<int>> board) {
    final grid = SudokuGrid(board);
    return List.generate(
      9,
      (r) => List.generate(9, (c) => grid.candidatesAt(r, c)),
    );
  }

  /// [candidates], if supplied, is shared across every eliminate-type
  /// technique tried in this call so the whole chain stays internally
  /// consistent; reveal-type techniques ignore it (see class doc).
  Hint? findHint(List<List<int>> board, [List<List<Set<int>>>? candidates]) {
    final resolved = candidates ?? _freshCandidates(board);
    for (final technique in hintTechniqueOrder) {
      final hint = switch (technique) {
        HintTechnique.fullHouse => findFullHouse(board),
        HintTechnique.nakedSingle => findNakedSingle(board),
        HintTechnique.hiddenSingle => findHiddenSingle(board),
        HintTechnique.nakedPair => findNakedPair(board, resolved),
        HintTechnique.nakedTriple => findNakedTriple(board, resolved),
        HintTechnique.nakedQuad => findNakedQuad(board, resolved),
        HintTechnique.hiddenPair => findHiddenPair(board, resolved),
        HintTechnique.hiddenTriple => findHiddenTriple(board, resolved),
        HintTechnique.hiddenQuad => findHiddenQuad(board, resolved),
        HintTechnique.intersectionPointing =>
          findIntersectionPointing(board, resolved),
        HintTechnique.intersectionClaiming =>
          findIntersectionClaiming(board, resolved),
        HintTechnique.xWing => findXWing(board, resolved),
        HintTechnique.simpleColoring => findSimpleColoring(board, resolved),
        HintTechnique.xyWing => findXYWing(board, resolved),
        HintTechnique.swordfish => findSwordfish(board, resolved),
        HintTechnique.finnedXWing => findFinnedXWing(board, resolved),
        HintTechnique.sashimiXWing => findSashimiXWing(board, resolved),
        HintTechnique.xyChain => findXYChain(board, resolved),
        HintTechnique.jellyfish => findJellyfish(board, resolved),
        HintTechnique.uniqueRectangleType1 =>
          findUniqueRectangleType1(board, resolved),
        HintTechnique.uniqueRectangleType2 =>
          findUniqueRectangleType2(board, resolved),
        HintTechnique.uniqueRectangleType3 =>
          findUniqueRectangleType3(board, resolved),
        HintTechnique.uniqueRectangleType4 =>
          findUniqueRectangleType4(board, resolved),
      };
      if (hint != null) return hint;
    }
    return null;
  }

  Hint? findFullHouse(List<List<int>> board) {
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
        explanation: '${unit.description}에 빈 칸이 이 칸 하나만 남았어요. '
            '1~9 중 아직 없는 숫자는 $value뿐이라 자동으로 정해집니다.',
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
  ]) {
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
          explanation: '${r + 1}행 ${c + 1}열은 후보 숫자가 $value 하나뿐이에요. '
              '같은 행·열·박스에 나머지 숫자가 모두 있어서 $value만 남았습니다.',
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
  ]) {
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
          final boxRow = (r ~/ 3) * 3;
          final boxCol = (c ~/ 3) * 3;
          for (var br = boxRow; br < boxRow + 3; br++) {
            for (var bc = boxCol; bc < boxCol + 3; bc++) {
              if (board[br][bc] == value) {
                extraBoxes.add(_boxIndexOf(rc));
                extraSecondary.add(HintCell(br, bc));
              }
            }
          }
        }

        final (hRows, hCols, hBoxes) = _highlightFor(unit);
        return Hint(
          technique: HintTechnique.hiddenSingle,
          type: HintType.reveal,
          explanation: '${unit.description}에서 숫자 $value가 들어갈 수 있는 '
              '빈 칸은 ${target[0] + 1}행 ${target[1] + 1}열 하나뿐이에요.',
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

  /// Intersection removal (pointing): a digit confined to one line within a
  /// box lets it be eliminated from the rest of that line outside the box.
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
        final boxCells = <List<int>>[
          for (var r = boxRow * 3; r < boxRow * 3 + 3; r++)
            for (var c = boxCol * 3; c < boxCol * 3 + 3; c++) [r, c],
        ];
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
          for (var rr = boxRow * 3; rr < boxRow * 3 + 3; rr++)
            for (var cc = boxCol * 3; cc < boxCol * 3 + 3; cc++)
              if (rr != r && candidates[rr][cc].contains(d))
                HintElimination(rr, cc, d),
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
          for (var rr = boxRow * 3; rr < boxRow * 3 + 3; rr++)
            for (var cc = boxCol * 3; cc < boxCol * 3 + 3; cc++)
              if (cc != c && candidates[rr][cc].contains(d))
                HintElimination(rr, cc, d),
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

  /// X-Wing: a digit confined to the same two columns across two rows (or
  /// symmetrically, the same two rows across two columns) forms a rectangle
  /// — the digit can be eliminated from the rest of those two columns (or
  /// rows), outside the rectangle's four corners.
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

  /// Simple Coloring (a.k.a. Single's Chain): for one digit at a time,
  /// cells linked by conjugate pairs (the ONLY two candidate cells for that
  /// digit in some shared row/column/box) form a chain that must alternate
  /// true/false along every link. 2-coloring a chain's cells by that
  /// alternation exposes two elimination rules:
  ///  - Rule 1 ("twice in a unit"): if two same-colored cells also see each
  ///    other (peers), that color is self-contradictory, so every cell of
  ///    that color loses the digit.
  ///  - Rule 2 ("trap"): a cell outside the chain that sees at least one
  ///    cell of each color must be false regardless of which color turns
  ///    out true, so it loses the digit too.
  /// Tries digit 1-9 in order; within a digit, every component's Rule 1 is
  /// tried before any component's Rule 2 (a whole-color wipeout is the more
  /// direct deduction), keeping "first match wins" fully deterministic.
  Hint? findSimpleColoring(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findSimpleColoring(resolved);
  }

  Hint? _findSimpleColoring(List<List<Set<int>>> candidates) {
    for (var d = 1; d <= 9; d++) {
      final components = _colorComponentsForDigit(candidates, d);
      for (final coloring in components) {
        final hint = _simpleColoringRule1(candidates, coloring, d);
        if (hint != null) return hint;
      }
      for (final coloring in components) {
        final hint = _simpleColoringRule2(candidates, coloring, d);
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
          final aDesc = '${cellsOfColor[i][0] + 1}행${cellsOfColor[i][1] + 1}열';
          final bDesc = '${cellsOfColor[j][0] + 1}행${cellsOfColor[j][1] + 1}열';

          return Hint(
            technique: HintTechnique.simpleColoring,
            type: HintType.eliminate,
            explanation: '숫자 $digit의 후보를 사슬로 연결해보면 같은 그룹으로 묶인 '
                '$aDesc와 $bDesc가 서로 같은 행·열·박스에 있어요. 둘 다 $digit가 '
                '될 수는 없으므로 이 그룹 전체가 $digit일 수 없습니다. 그래서 이 '
                '그룹의 칸들에서는 $digit를 후보에서 지울 수 있습니다.',
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
        .map((idx) => '${idx ~/ 9 + 1}행${idx % 9 + 1}열')
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
      explanation: '숫자 $digit의 후보 사슬($cellsDesc)은 두 그룹으로 나뉘어 서로 '
          '반대 상태를 가져요. 이 두 그룹을 모두 보고 있는 칸은 어느 그룹이 참이든 '
          '$digit가 될 수 없으므로, 그 칸에서 $digit를 후보에서 지울 수 있습니다.',
      primaryCells:
          coloring.keys.map((idx) => HintCell(idx ~/ 9, idx % 9)).toSet(),
      secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      colorGroupA: colorGroupA,
      colorGroupB: colorGroupB,
      eliminations: eliminations,
    );
  }

  /// XY-Wing: a pivot cell with exactly 2 candidates {X, Y}, plus two wing
  /// cells (each a peer of the pivot, each with exactly 2 candidates)
  /// {X, Z} and {Y, Z} for some third digit Z. Whichever of X/Y the pivot
  /// turns out to be, one of the two wings is forced to Z, so any cell that
  /// is a peer of BOTH wings can't be Z either.
  Hint? findXYWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXYWing(resolved);
  }

  Hint? _findXYWing(List<List<Set<int>>> candidates) {
    for (var pr = 0; pr < 9; pr++) {
      for (var pc = 0; pc < 9; pc++) {
        final pivotCandidates = candidates[pr][pc];
        if (pivotCandidates.length != 2) continue;
        final pivotList = pivotCandidates.toList()..sort();
        final x = pivotList[0];
        final y = pivotList[1];

        final peers = _peers(pr, pc)
            .where((rc) => candidates[rc[0]][rc[1]].length == 2)
            .toList();

        for (var i = 0; i < peers.length; i++) {
          final w1 = peers[i];
          final w1Cands = candidates[w1[0]][w1[1]];
          final sharedW1 = w1Cands.intersection({x, y});
          if (sharedW1.length != 1) continue;
          final sharedDigitW1 = sharedW1.first;
          final z = w1Cands.difference({sharedDigitW1}).first;
          final otherPivotDigit = sharedDigitW1 == x ? y : x;

          for (var j = 0; j < peers.length; j++) {
            if (j == i) continue;
            final w2 = peers[j];
            final w2Cands = candidates[w2[0]][w2[1]];
            if (!(w2Cands.length == 2 &&
                w2Cands.contains(otherPivotDigit) &&
                w2Cands.contains(z))) {
              continue;
            }

            final eliminations = <HintElimination>[];
            for (var r = 0; r < 9; r++) {
              for (var c = 0; c < 9; c++) {
                if ((r == pr && c == pc) ||
                    (r == w1[0] && c == w1[1]) ||
                    (r == w2[0] && c == w2[1])) {
                  continue;
                }
                if (!candidates[r][c].contains(z)) continue;
                if (_seeEachOther([r, c], w1) && _seeEachOther([r, c], w2)) {
                  eliminations.add(HintElimination(r, c, z));
                }
              }
            }
            if (eliminations.isEmpty) continue;

            final pivotDesc = '${pr + 1}행${pc + 1}열';
            final w1Desc = '${w1[0] + 1}행${w1[1] + 1}열';
            final w2Desc = '${w2[0] + 1}행${w2[1] + 1}열';

            return Hint(
              technique: HintTechnique.xyWing,
              type: HintType.eliminate,
              explanation: '피벗 칸 $pivotDesc의 후보는 $x, $y 두 개예요. 날개 칸 '
                  '$w1Desc는 $sharedDigitW1 아니면 $z, $w2Desc는 '
                  '$otherPivotDigit 아니면 $z예요. 피벗이 $sharedDigitW1이면 '
                  '$w1Desc가, 피벗이 $otherPivotDigit이면 $w2Desc가 $z가 '
                  '되므로, 어느 쪽이든 두 날개를 모두 보는 칸에서는 $z를 '
                  '후보에서 지울 수 있습니다.',
              primaryCells: {
                HintCell(pr, pc),
                HintCell(w1[0], w1[1]),
                HintCell(w2[0], w2[1]),
              },
              secondaryCells:
                  eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
              primaryDigits: {x, y},
              eliminations: eliminations,
            );
          }
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

  /// Maximum XY-Chain path length (in cells) explored — a purely defensive
  /// backstop against a pathological, densely-interlinked bivalue subgraph
  /// blowing up search time. Any real elimination is found far short of
  /// this; it never affects legitimate results.
  static const _maxXYChainDepth = 25;

  /// XY-Chain: the multi-cell generalization of XY-Wing. A chain of
  /// bivalue cells, each linked to the next by a shared candidate digit
  /// (and by being peers), alternates which of its two candidates is
  /// "forced" at each step: if [current] is NOT [neededDigit], it must be
  /// its other candidate, which becomes the digit the next cell needs to
  /// continue the chain. If that forced alternation ever reaches a cell
  /// whose forced value is the original chain's target digit Z, then
  /// either the start cell is Z, or the end cell is Z — so any cell that
  /// peers BOTH ends and still has Z as a candidate can have it
  /// eliminated. Minimum chain length is 4 cells: length 2 is just a
  /// Naked Pair in disguise (two peer cells with identical candidate
  /// pairs), and length 3 is exactly an XY-Wing (the middle cell plays
  /// the pivot role) — both already handled by earlier, higher-priority
  /// techniques, so requiring length >= 4 keeps this a genuinely new
  /// capability rather than a slower rediscovery of existing hints.
  Hint? findXYChain(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXYChain(resolved);
  }

  Hint? _findXYChain(List<List<Set<int>>> candidates) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (candidates[r][c].length != 2) continue;
        final startCands = candidates[r][c].toList()..sort();
        for (var zIndex = 0; zIndex < 2; zIndex++) {
          final z = startCands[zIndex];
          final a = startCands[1 - zIndex];
          final hint = _extendXYChain(
              candidates,
              [r, c],
              a,
              z,
              [
                [r, c],
              ]);
          if (hint != null) return hint;
        }
      }
    }
    return null;
  }

  Hint? _extendXYChain(
    List<List<Set<int>>> candidates,
    List<int> current,
    int neededDigit,
    int targetZ,
    List<List<int>> path,
  ) {
    if (path.length >= _maxXYChainDepth) return null;

    final pathIndices = path.map((p) => p[0] * 9 + p[1]).toSet();
    final nextCells = <List<int>>{
      for (final p in _peers(current[0], current[1]))
        if (candidates[p[0]][p[1]].length == 2 &&
            candidates[p[0]][p[1]].contains(neededDigit) &&
            !pathIndices.contains(p[0] * 9 + p[1]))
          p,
    }.toList();

    for (final next in nextCells) {
      final nextCands = candidates[next[0]][next[1]];
      final otherDigit = nextCands.firstWhere((d) => d != neededDigit);
      final newPath = [...path, next];

      if (otherDigit == targetZ && newPath.length >= 4) {
        final hint = _buildXYChainHint(candidates, newPath, targetZ);
        if (hint != null) return hint;
      }

      final deeper =
          _extendXYChain(candidates, next, otherDigit, targetZ, newPath);
      if (deeper != null) return deeper;
    }
    return null;
  }

  Hint? _buildXYChainHint(
    List<List<Set<int>>> candidates,
    List<List<int>> path,
    int z,
  ) {
    final start = path.first;
    final end = path.last;
    final chainIndices = path.map((p) => p[0] * 9 + p[1]).toSet();

    final eliminations = <HintElimination>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (chainIndices.contains(r * 9 + c)) continue;
        if (!candidates[r][c].contains(z)) continue;
        if (_seeEachOther([r, c], start) && _seeEachOther([r, c], end)) {
          eliminations.add(HintElimination(r, c, z));
        }
      }
    }
    if (eliminations.isEmpty) return null;

    final chainDesc = path.map((p) => '${p[0] + 1}행${p[1] + 1}열').join(' - ');
    final colorGroupA = <HintCell>{
      for (var i = 0; i < path.length; i += 2) HintCell(path[i][0], path[i][1]),
    };
    final colorGroupB = <HintCell>{
      for (var i = 1; i < path.length; i += 2) HintCell(path[i][0], path[i][1]),
    };
    // Every digit that actually appears along the chain, not just the
    // target z — each link cell's OWN pair of candidates is what carries
    // the chain, so both matter, not only the digit eliminated at the end.
    final chainDigits = <int>{};
    for (final p in path) {
      chainDigits.addAll(candidates[p[0]][p[1]]);
    }

    return Hint(
      technique: HintTechnique.xyChain,
      type: HintType.eliminate,
      explanation: '$chainDesc 순서로 이어지는 칸들은 후보가 둘씩뿐이라, 사슬 '
          '한쪽 끝이 $z가 아니면 반대쪽 끝이 $z가 될 수밖에 없어요. 그래서 '
          '사슬 양쪽 끝을 모두 보는 칸에서는 $z를 후보에서 지울 수 있습니다.',
      primaryCells: path.map((p) => HintCell(p[0], p[1])).toSet(),
      secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      colorGroupA: colorGroupA,
      colorGroupB: colorGroupB,
      primaryDigits: chainDigits,
      eliminations: eliminations,
    );
  }

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
  ]) {
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

      return Hint(
        technique: HintTechnique.uniqueRectangleType1,
        type: HintType.eliminate,
        explanation: '${cells.map((rc) => '${rc[0] + 1}행${rc[1] + 1}열').join(
                  ', ',
                )}은 유일사각형(2행 2열, 박스 2개)을 이루는데, 그중 세 칸이 후보 '
            '${base.a}, ${base.b}뿐이에요. 나머지 한 칸도 이 둘뿐이라면 퍼즐 '
            '해가 두 개가 되어버리므로, 그 칸에서는 ${base.a}, ${base.b}를 '
            '후보에서 지울 수 있습니다.',
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
  ]) {
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
        explanation: '${roof[0][0] + 1}행${roof[0][1] + 1}열과 '
            '${roof[1][0] + 1}행${roof[1][1] + 1}열은 후보가 '
            '${base.a}, ${base.b}, $c 세 개씩이에요. 둘 다 '
            '${base.a}, ${base.b}뿐이라면 퍼즐 해가 두 개가 되므로, 둘 중 '
            '하나는 반드시 $c여야 해요. 그래서 두 칸을 모두 보는 다른 칸에서는 '
            '$c를 후보에서 지울 수 있습니다.',
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
  ]) {
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
      final boxRow = (roof[0][0] ~/ 3) * 3;
      final boxCol = (roof[0][1] ~/ 3) * 3;
      final boxCells = [
        for (var r = boxRow; r < boxRow + 3; r++)
          for (var c = boxCol; c < boxCol + 3; c++) [r, c],
      ];
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
            explanation: '${roof[0][0] + 1}행${roof[0][1] + 1}열과 '
                '${roof[1][0] + 1}행${roof[1][1] + 1}열의 추가 후보를 하나로 '
                '합쳐서 보면, 다른 칸들과 함께 $digitsDesc만 남는 조합을 '
                '이뤄요. 그래서 같은 구역의 나머지 칸에서는 $digitsDesc을(를) '
                '후보에서 지울 수 있습니다.',
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
  ]) {
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
          explanation: '${roof[0][0] + 1}행${roof[0][1] + 1}열과 '
              '${roof[1][0] + 1}행${roof[1][1] + 1}열이 있는 줄에서 숫자 '
              '$lockedDigit는 이 두 칸에만 들어갈 수 있어요. 그러면 $otherDigit가 '
              '두 칸에 그대로 남아있을 경우 퍼즐 해가 두 개가 되므로, 두 칸 '
              '모두에서 $otherDigit를 후보에서 지울 수 있습니다.',
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
