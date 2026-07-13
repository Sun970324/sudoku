import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/hint.dart';
import '../models/sudoku_grid.dart';

part 'hint_engine/singles.dart';
part 'hint_engine/subsets.dart';
part 'hint_engine/intersections.dart';
part 'hint_engine/fish.dart';
part 'hint_engine/coloring.dart';
part 'hint_engine/wings.dart';
part 'hint_engine/unique_rectangles.dart';
part 'hint_engine/uniqueness.dart';

enum _UnitType { row, col, box }

class _Unit {
  const _Unit(this.cells, this.type, this.index);

  final List<List<int>> cells;

  /// Whether this unit is a row, column, or box.
  final _UnitType type;

  /// Row/column index (0-8), or box index (0-8, `boxRow * 3 + boxCol`).
  final int index;
}

/// Falls back to this locale wherever a caller doesn't supply one — every
/// caller that never displays `.explanation` to a player (HumanSolver during
/// generation, hint-availability checks, tests) can safely omit it. Only
/// [GameController.requestHint] threads the player's actual current locale
/// through, since that's the sole place `.explanation` is shown.
AppLocalizations _resolveL10n(AppLocalizations? l10n) =>
    l10n ?? lookupAppLocalizations(const Locale('ko'));

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

/// Cell-position layout of the 27 units never depends on board state, so
/// it's computed once and reused for the lifetime of the isolate rather
/// than rebuilt (with fresh nested lists) on every call.
List<_Unit>? _cachedUnits;
List<_Unit> _allUnits() => _cachedUnits ??= _buildUnits();

List<_Unit> _buildUnits() {
  final units = <_Unit>[];
  for (var r = 0; r < 9; r++) {
    units.add(_Unit(
      [
        for (var c = 0; c < 9; c++) [r, c]
      ],
      _UnitType.row,
      r,
    ));
  }
  for (var c = 0; c < 9; c++) {
    units.add(_Unit(
      [
        for (var r = 0; r < 9; r++) [r, c]
      ],
      _UnitType.col,
      c,
    ));
  }
  for (var boxRow = 0; boxRow < 3; boxRow++) {
    for (var boxCol = 0; boxCol < 3; boxCol++) {
      final cells = SudokuGrid.boxCellsOf(boxRow * 3, boxCol * 3);
      units.add(_Unit(
        cells,
        _UnitType.box,
        boxRow * 3 + boxCol,
      ));
    }
  }
  return units;
}

/// Localized description of a single row/column, built fresh per call (the
/// [_Unit] cell layout is cached process-wide, but the description text
/// can't be — it depends on whichever locale the caller currently wants).
String _rowDesc(int r, AppLocalizations l10n) => l10n.unitRow(r + 1);
String _colDesc(int c, AppLocalizations l10n) => l10n.unitCol(c + 1);

/// Localized description of a single cell, e.g. "3행4열"/"R3C4".
String _cellDesc(int r, int c, AppLocalizations l10n) =>
    l10n.unitCell(r + 1, c + 1);

String _boxDescription(int boxRow, int boxCol, AppLocalizations l10n) =>
    l10n.unitBox(
      boxRow * 3 + boxCol + 1,
      boxRow * 3 + 1,
      boxRow * 3 + 3,
      boxCol * 3 + 1,
      boxCol * 3 + 3,
    );

/// Localized description of [unit]. Computed fresh per call rather than
/// cached on [_Unit] itself — [_Unit]'s cell layout is cached process-wide
/// (see [_allUnits]), but its description can't be, since that would freeze
/// whichever locale happened to be active on the very first call for the
/// rest of the app's lifetime.
String _unitDescription(_Unit unit, AppLocalizations l10n) => switch (unit.type) {
      _UnitType.row => _rowDesc(unit.index, l10n),
      _UnitType.col => _colDesc(unit.index, l10n),
      _UnitType.box => _boxDescription(unit.index ~/ 3, unit.index % 3, l10n),
    };

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

/// Which cells are peers of (row, col) — delegates to [SudokuGrid.peersOf],
/// the shared, cached implementation used across the codebase (also by
/// [GameController] and [SudokuGrid] itself). Called heavily inside 81-cell
/// loops (directly, and indirectly via [_seeEachOther]) across several
/// techniques (XY-Wing, Simple Coloring, XY-Chain, ...).
List<List<int>> _peers(int row, int col) => SudokuGrid.peersOf(row, col);

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
  List<List<Set<int>>> _freshCandidates(List<List<int>> board) =>
      SudokuGrid(board).allCandidates();

  /// [candidates], if supplied, is shared across every eliminate-type
  /// technique tried in this call so the whole chain stays internally
  /// consistent; reveal-type techniques ignore it (see class doc). [l10n]
  /// controls the language of the returned [Hint.explanation] — omit it
  /// (as every caller except [GameController.requestHint] does) to get the
  /// [_resolveL10n] default, fine for callers that never display the text.
  Hint? findHint(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    final resolvedL10n = _resolveL10n(l10n);
    for (final technique in hintTechniqueOrder) {
      final hint = switch (technique) {
        HintTechnique.fullHouse => findFullHouse(board, resolvedL10n),
        HintTechnique.nakedSingle => findNakedSingle(board, null, resolvedL10n),
        HintTechnique.hiddenSingle =>
          findHiddenSingle(board, null, resolvedL10n),
        HintTechnique.nakedPair => findNakedPair(board, resolved, resolvedL10n),
        HintTechnique.nakedTriple =>
          findNakedTriple(board, resolved, resolvedL10n),
        HintTechnique.nakedQuad => findNakedQuad(board, resolved, resolvedL10n),
        HintTechnique.hiddenPair =>
          findHiddenPair(board, resolved, resolvedL10n),
        HintTechnique.hiddenTriple =>
          findHiddenTriple(board, resolved, resolvedL10n),
        HintTechnique.hiddenQuad =>
          findHiddenQuad(board, resolved, resolvedL10n),
        HintTechnique.intersectionPointing =>
          findIntersectionPointing(board, resolved, resolvedL10n),
        HintTechnique.intersectionClaiming =>
          findIntersectionClaiming(board, resolved, resolvedL10n),
        HintTechnique.xWing => findXWing(board, resolved, resolvedL10n),
        HintTechnique.simpleColoring =>
          findSimpleColoring(board, resolved, resolvedL10n),
        HintTechnique.xyWing => findXYWing(board, resolved, resolvedL10n),
        HintTechnique.swordfish =>
          findSwordfish(board, resolved, resolvedL10n),
        HintTechnique.finnedXWing =>
          findFinnedXWing(board, resolved, resolvedL10n),
        HintTechnique.sashimiXWing =>
          findSashimiXWing(board, resolved, resolvedL10n),
        HintTechnique.bugPlusOne =>
          findBugPlusOne(board, resolved, resolvedL10n),
        HintTechnique.xyChain => findXYChain(board, resolved, resolvedL10n),
        HintTechnique.jellyfish =>
          findJellyfish(board, resolved, resolvedL10n),
        HintTechnique.uniqueRectangleType1 =>
          findUniqueRectangleType1(board, resolved, resolvedL10n),
        HintTechnique.uniqueRectangleType2 =>
          findUniqueRectangleType2(board, resolved, resolvedL10n),
        HintTechnique.uniqueRectangleType3 =>
          findUniqueRectangleType3(board, resolved, resolvedL10n),
        HintTechnique.uniqueRectangleType4 =>
          findUniqueRectangleType4(board, resolved, resolvedL10n),
      };
      if (hint != null) return hint;
    }
    return null;
  }


  /// Intersection removal (pointing): a digit confined to one line within a
  /// box lets it be eliminated from the rest of that line outside the box.
  /// X-Wing: a digit confined to the same two columns across two rows (or
  /// symmetrically, the same two rows across two columns) forms a rectangle
  /// — the digit can be eliminated from the rest of those two columns (or
  /// rows), outside the rectangle's four corners.
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
  /// XY-Wing: a pivot cell with exactly 2 candidates {X, Y}, plus two wing
  /// cells (each a peer of the pivot, each with exactly 2 candidates)
  /// {X, Z} and {Y, Z} for some third digit Z. Whichever of X/Y the pivot
  /// turns out to be, one of the two wings is forced to Z, so any cell that
  /// is a peer of BOTH wings can't be Z either.
}
