import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/l10n/generated/app_localizations.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/game_snapshot.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/hint_engine.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';
import 'package:sudoku/state/game_controller.dart';

/// A stand-in for [HintEngine] whose result is fully controlled by the test,
/// so hint-application behavior can be verified independently of whatever
/// technique the real engine would or wouldn't find on a given board.
class _FakeHintEngine extends HintEngine {
  Hint? nextHint;

  @override
  Hint? findHint(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) =>
      nextHint;
}

/// A stand-in for [HintEngine] that returns a scripted sequence of hints —
/// each call to [findHint] advances to the next entry in [hints] (repeating
/// the last one once exhausted) — for testing [GameController]'s
/// repair-and-retry loop around a hint whose own cells turn out to have
/// incomplete notes.
class _ScriptedHintEngine extends HintEngine {
  List<Hint?> hints = const [null];
  int _index = 0;

  @override
  Hint? findHint(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final hint = hints[_index];
    if (_index < hints.length - 1) _index++;
    return hint;
  }
}

/// Asserts every cell's notes equal its true candidate set given the
/// current board — the invariant `autoFillNotes`/`applyHint` both maintain,
/// regardless of what the player had (or hadn't) noted beforehand.
void _expectNotesMatchTrueCandidates(GameController controller) {
  final grid = SudokuGrid(controller.boardSnapshot);
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      expect(controller.notesAt(r, c), grid.candidatesAt(r, c),
          reason: 'cell ($r, $c)');
    }
  }
}

/// The legal candidates for (row, col) on the controller's current board, as
/// a list — `toggleNote` now rejects any digit not in this set, so tests
/// that need to set a note must pick from here instead of hardcoding digits.
List<int> _candidates(GameController controller, int row, int col) =>
    SudokuGrid(controller.boardSnapshot).candidatesAt(row, col).toList();

/// A `solution` grid that trivially agrees with every placed digit in
/// [board] (blanks filled with an arbitrary 1), for hint-technique
/// fixtures that only care about board structure and never actually
/// consult `solution` — except now `hasUnresolvedMistake` does check every
/// placed digit against it, so it can no longer be an unrelated dummy
/// grid, or every non-1 given would look like an uncorrected mistake.
List<List<int>> _echoAsSolution(List<List<int>> board) =>
    board.map((row) => row.map((v) => v == 0 ? 1 : v).toList()).toList();

void main() {
  late GameController controller;
  late _FakeHintEngine hintEngine;

  setUp(() {
    // Seeded generator makes the puzzle deterministic across test runs.
    hintEngine = _FakeHintEngine();
    controller = GameController(
      generator: SudokuGenerator(random: Random(7)),
      hintEngine: hintEngine,
    )..startNewGame(Difficulty.easy);
  });

  int? firstEmptyEditableCellRow;
  int? firstEmptyEditableCellCol;
  void locateFirstEditableCell() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (!controller.isFixed(r, c)) {
          firstEmptyEditableCellRow = r;
          firstEmptyEditableCellCol = c;
          return;
        }
      }
    }
  }

  /// Finds an empty, non-fixed cell distinct from (excludeRow, excludeCol)
  /// and fully notes it, so it's safe to use as a fake eliminate-type
  /// hint's `primaryCells` without tripping `requestHint`'s
  /// incomplete-notes repair — tests that need a hint shaped like a real
  /// technique (pattern cells separate from whatever cell they're
  /// exercising via `eliminations`) use this for the pattern side.
  (int, int) fullyNotedOtherCell(int excludeRow, int excludeCol) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (r == excludeRow && c == excludeCol) continue;
        if (controller.isFixed(r, c) || controller.valueAt(r, c) != 0) {
          continue;
        }
        controller.selectCell(r, c);
        final trueCandidates =
            SudokuGrid(controller.boardSnapshot).candidatesAt(r, c);
        for (final d in trueCandidates) {
          if (!controller.notesAt(r, c).contains(d)) {
            controller.toggleNote(d);
          }
        }
        return (r, c);
      }
    }
    throw StateError('no other empty editable cell found');
  }

  test('selecting a fixed (given) cell still selects it, but its value stays put',
      () {
    // Find a fixed cell.
    int? fixedRow, fixedCol;
    outer:
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (controller.isFixed(r, c)) {
          fixedRow = r;
          fixedCol = c;
          break outer;
        }
      }
    }
    final originalValue = controller.valueAt(fixedRow!, fixedCol!);

    controller.selectCell(fixedRow, fixedCol);
    expect(controller.selectedRow, fixedRow);
    expect(controller.selectedCol, fixedCol);

    controller.inputValue(originalValue == 9 ? 1 : originalValue + 1);
    expect(controller.valueAt(fixedRow, fixedCol), originalValue);
  });

  test('selecting the already-selected cell again deselects it', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    expect(controller.selectedRow, row);
    expect(controller.selectedCol, col);

    controller.selectCell(row, col);
    expect(controller.selectedRow, isNull);
    expect(controller.selectedCol, isNull);

    controller.selectCell(row, col);
    expect(controller.selectedRow, row);
    expect(controller.selectedCol, col);
  });

  test(
      'selectCellForDrag selects a cell without toggling it off when '
      'called again with the same cell', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    int? otherRow;
    int? otherCol;
    outer:
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if ((r != row || c != col) && !controller.isFixed(r, c)) {
          otherRow = r;
          otherCol = c;
          break outer;
        }
      }
    }
    expect(otherRow, isNotNull);

    controller.selectCellForDrag(row, col);
    expect(controller.selectedRow, row);
    expect(controller.selectedCol, col);

    // Unlike selectCell, calling again with the same cell does not
    // toggle it off — as if the finger swept back over its starting
    // cell mid-drag.
    controller.selectCellForDrag(row, col);
    expect(controller.selectedRow, row);
    expect(controller.selectedCol, col);

    controller.selectCellForDrag(otherRow!, otherCol!);
    expect(controller.selectedRow, otherRow);
    expect(controller.selectedCol, otherCol);
  });

  test('selectCellForDrag clears the active hint, like selectCell', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);

    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedSingle,
      type: HintType.reveal,
      explanation: 'test',
      primaryCells: {HintCell(row, col)},
      row: row,
      col: col,
      value: correctValue,
    );
    controller.requestHint();
    expect(controller.activeHint, isNotNull);

    controller.selectCellForDrag(row, col);

    expect(controller.activeHint, isNull);
  });

  test('entering the correct value leaves no mistake and no red flag', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);

    controller.selectCell(row, col);
    controller.inputValue(correctValue);

    expect(controller.mistakes, 0);
    expect(controller.isWrong(row, col), isFalse);
    expect(controller.valueAt(row, col), correctValue);
  });

  test('entering a wrong value increments the mistake counter', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);
    final wrongValue = correctValue == 9 ? 1 : correctValue + 1;

    controller.selectCell(row, col);
    controller.inputValue(wrongValue);

    expect(controller.mistakes, 1);
    expect(controller.isWrong(row, col), isTrue);
    expect(controller.status, GameStatus.playing);
  });

  test('three mistakes trigger game over', () {
    var mistakesMade = 0;
    for (var r = 0; r < 9 && mistakesMade < 3; r++) {
      for (var c = 0; c < 9 && mistakesMade < 3; c++) {
        if (controller.isFixed(r, c)) continue;
        final correctValue = controller.puzzle.solutionValue(r, c);
        final wrongValue = correctValue == 9 ? 1 : correctValue + 1;
        controller.selectCell(r, c);
        controller.inputValue(wrongValue);
        mistakesMade++;
      }
    }

    expect(controller.mistakes, 3);
    expect(controller.status, GameStatus.gameOver);
  });

  test('undo does nothing once the game is over — only reviveAfterAd may '
      'resume play', () {
    var mistakesMade = 0;
    for (var r = 0; r < 9 && mistakesMade < 3; r++) {
      for (var c = 0; c < 9 && mistakesMade < 3; c++) {
        if (controller.isFixed(r, c)) continue;
        final correctValue = controller.puzzle.solutionValue(r, c);
        final wrongValue = correctValue == 9 ? 1 : correctValue + 1;
        controller.selectCell(r, c);
        controller.inputValue(wrongValue);
        mistakesMade++;
      }
    }
    expect(controller.status, GameStatus.gameOver);
    expect(controller.canUndo, isFalse);

    controller.undo();

    expect(controller.status, GameStatus.gameOver);
  });

  test('reviveAfterAd knocks mistakes back to 2 and resumes play after '
      'game over', () {
    var mistakesMade = 0;
    for (var r = 0; r < 9 && mistakesMade < 3; r++) {
      for (var c = 0; c < 9 && mistakesMade < 3; c++) {
        if (controller.isFixed(r, c)) continue;
        final correctValue = controller.puzzle.solutionValue(r, c);
        final wrongValue = correctValue == 9 ? 1 : correctValue + 1;
        controller.selectCell(r, c);
        controller.inputValue(wrongValue);
        mistakesMade++;
      }
    }
    expect(controller.status, GameStatus.gameOver);

    controller.reviveAfterAd();

    expect(controller.status, GameStatus.playing);
    // Not a full reset to 0 — reviving only forgives one mistake's worth
    // of headroom (back to maxMistakes - 1), not a clean slate.
    expect(controller.mistakes, 2);
  });

  test('applyHint fills the target cell with a reveal-type hint\'s value', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);

    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedSingle,
      type: HintType.reveal,
      explanation: 'test',
      primaryCells: {HintCell(row, col)},
      row: row,
      col: col,
      value: correctValue,
    );

    expect(controller.requestHint(), isNotNull);
    controller.applyHint();

    expect(controller.valueAt(row, col), correctValue);
    expect(controller.hintsUsed, 1);
    expect(controller.selectedRow, row);
    expect(controller.selectedCol, col);
  });

  test('requestHint returns null and leaves the board untouched when no '
      'hint is found', () {
    hintEngine.nextHint = null;
    final before = controller.boardSnapshot;

    final hint = controller.requestHint();

    expect(hint, isNull);
    expect(controller.activeHint, isNull);
    expect(controller.boardSnapshot, before);
  });

  test(
      'applyHint removes only the hint\'s eliminated digits from notes, '
      'leaving every other cell untouched', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final originalValue = controller.valueAt(row, col);
    // A separate, fully-noted cell to stand in for the hint's own pattern
    // (primaryCells).
    final (patternRow, patternCol) = fullyNotedOtherCell(row, col);

    // requestHint's own solution-digit repair (see _findHintWithRepair)
    // will fill in (row, col) regardless of what's noted there going in,
    // so the "before" snapshot that applyHint must preserve is taken
    // *after* requestHint, not before — and the eliminated digit is
    // picked from whatever ends up actually noted there.
    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedPair,
      type: HintType.eliminate,
      explanation: 'test',
      primaryCells: {HintCell(patternRow, patternCol)},
      eliminations: const [],
    );
    controller.requestHint();
    final eliminatedDigit = controller.notesAt(row, col).first;
    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedPair,
      type: HintType.eliminate,
      explanation: 'test',
      primaryCells: {HintCell(patternRow, patternCol)},
      eliminations: [HintElimination(row, col, eliminatedDigit)],
    );
    controller.requestHint();

    final notesBefore = List.generate(
      9,
      (r) =>
          List.generate(9, (c) => Set<int>.from(controller.notesAt(r, c))),
    );

    controller.applyHint();

    // The eliminated digit is gone from the target cell, but its other
    // true candidates (from requestHint's own repair) remain...
    expect(controller.notesAt(row, col),
        notesBefore[row][col].difference({eliminatedDigit}));
    // ...and every other cell's notes are exactly what they were right
    // before applyHint ran — applying an eliminate-type hint must not
    // blanket unrelated cells with pencil marks beyond what requestHint
    // itself already repaired.
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (r == row && c == col) continue;
        expect(controller.notesAt(r, c), notesBefore[r][c],
            reason: 'cell ($r, $c)');
      }
    }
    expect(controller.valueAt(row, col), originalValue);
    expect(controller.hintsUsed, 1);
  });

  test(
      'applyHint is a no-op on notes for an eliminated digit that was '
      'never a valid candidate there', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    // A digit that's flatly impossible at (row, col) — requestHint's
    // solution-digit repair only ever adds *legitimate* candidates, so
    // this can never end up noted there no matter what gets repaired.
    final trueCandidates =
        SudokuGrid(controller.boardSnapshot).candidatesAt(row, col);
    final impossibleDigit =
        [for (var d = 1; d <= 9; d++) d].firstWhere(
            (d) => !trueCandidates.contains(d));
    // A separate, fully-noted cell to stand in for the hint's own pattern
    // (primaryCells).
    final (patternRow, patternCol) = fullyNotedOtherCell(row, col);

    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedPair,
      type: HintType.eliminate,
      explanation: 'test',
      primaryCells: {HintCell(patternRow, patternCol)},
      eliminations: [HintElimination(row, col, impossibleDigit)],
    );
    controller.requestHint();
    controller.applyHint();

    // requestHint's repair fills (row, col) with its true candidates;
    // applying the (impossible) elimination changes nothing further.
    expect(controller.notesAt(row, col), trueCandidates);
  });

  test('undo after an eliminate-type applyHint restores the exact prior '
      'notes grid', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    // A separate, fully-noted cell to stand in for the hint's own pattern
    // (primaryCells).
    final (patternRow, patternCol) = fullyNotedOtherCell(row, col);

    // Same two-step setup as above: let requestHint's repair fill in
    // (row, col) first, then target one of whatever ended up noted there.
    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedPair,
      type: HintType.eliminate,
      explanation: 'test',
      primaryCells: {HintCell(patternRow, patternCol)},
      eliminations: const [],
    );
    controller.requestHint();
    final eliminatedDigit = controller.notesAt(row, col).first;
    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedPair,
      type: HintType.eliminate,
      explanation: 'test',
      primaryCells: {HintCell(patternRow, patternCol)},
      eliminations: [HintElimination(row, col, eliminatedDigit)],
    );
    controller.requestHint();

    final notesBefore = List.generate(
      9,
      (r) => List.generate(
          9, (c) => Set<int>.from(controller.notesAt(r, c))),
    );

    controller.applyHint();
    expect(controller.notesAt(row, col),
        isNot(contains(eliminatedDigit)));

    controller.undo();

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        expect(controller.notesAt(r, c), notesBefore[r][c],
            reason: 'cell ($r, $c)');
      }
    }
    expect(controller.valueAt(row, col), 0);
  });

  test('activeHint reflects the last requestHint result and clears on '
      'dismiss, apply, and any other board action', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);
    final hint = Hint(
      technique: HintTechnique.nakedSingle,
      type: HintType.reveal,
      explanation: 'test',
      primaryCells: {HintCell(row, col)},
      row: row,
      col: col,
      value: correctValue,
    );
    hintEngine.nextHint = hint;

    controller.requestHint();
    expect(controller.activeHint, hint);

    controller.dismissHint();
    expect(controller.activeHint, isNull);

    controller.requestHint();
    expect(controller.activeHint, hint);
    controller.selectCell(row, col);
    expect(controller.activeHint, isNull);

    controller.requestHint();
    controller.applyHint();
    expect(controller.activeHint, isNull);
  });

  /// Builds a reveal hint for the first editable cell — enough for the
  /// stage tests, which only care about the progressive reveal, not about
  /// which technique found the hint.
  Hint scriptRevealHint() {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final hint = Hint(
      technique: HintTechnique.nakedSingle,
      type: HintType.reveal,
      explanation: 'test',
      primaryCells: {HintCell(row, col)},
      mainInfo: 'test-main-info',
      row: row,
      col: col,
      value: controller.puzzle.solutionValue(row, col),
    );
    hintEngine.nextHint = hint;
    return hint;
  }

  test('a new hint starts at stage 0 and advances one step at a time up to '
      'the final stage', () {
    scriptRevealHint();

    controller.requestHint();
    expect(controller.hintStage, 0);

    controller.advanceHintStage();
    expect(controller.hintStage, 1);

    controller.advanceHintStage();
    expect(controller.hintStage, 2);

    // Clamped — there is no stage past the full reveal.
    controller.advanceHintStage();
    expect(controller.hintStage, 2);
  });

  test('the board visualises a hint only at the final stage', () {
    final hint = scriptRevealHint();

    controller.requestHint();
    expect(controller.activeHint, hint);
    expect(controller.visualizedHint, isNull);

    controller.advanceHintStage();
    expect(controller.visualizedHint, isNull);

    controller.advanceHintStage();
    expect(controller.visualizedHint, hint);
  });

  test('stage resets when a hint is dismissed, applied, or superseded, so a '
      'new hint never inherits the previous one\'s stage', () {
    scriptRevealHint();

    controller.requestHint();
    controller.advanceHintStage();
    controller.advanceHintStage();
    expect(controller.hintStage, 2);

    controller.dismissHint();
    expect(controller.hintStage, 0);

    // Superseded by a fresh request.
    controller.requestHint();
    controller.advanceHintStage();
    controller.requestHint();
    expect(controller.hintStage, 0);

    // Cleared by an unrelated board action.
    controller.advanceHintStage();
    controller.selectCell(0, 0);
    expect(controller.hintStage, 0);

    scriptRevealHint();
    controller.requestHint();
    controller.advanceHintStage();
    controller.advanceHintStage();
    controller.applyHint();
    expect(controller.hintStage, 0);
  });

  test('advanceHintStage is a no-op with no active hint', () {
    expect(controller.activeHint, isNull);

    controller.advanceHintStage();

    expect(controller.hintStage, 0);
  });

  test('undo reverts the most recent move', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    controller.inputValue(5);
    expect(controller.canUndo, isTrue);

    controller.undo();

    expect(controller.valueAt(row, col), 0);
    expect(controller.canUndo, isFalse);
  });

  test('undo reverts a note toggle', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    final digit = _candidates(controller, row, col).first;
    controller.toggleNote(digit);
    expect(controller.notesAt(row, col), {digit});

    controller.undo();

    expect(controller.notesAt(row, col), isEmpty);
  });

  test('undo after placing a value restores the notes it wiped out, '
      'including peer cells', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final value = controller.puzzle.solutionValue(row, col);

    int? peerCol;
    for (var c = 0; c < 9; c++) {
      if (c != col &&
          !controller.isFixed(row, c) &&
          SudokuGrid(controller.boardSnapshot).isValidPlacement(row, c, value)) {
        peerCol = c;
        break;
      }
    }
    expect(peerCol, isNotNull);

    controller.selectCell(row, peerCol!);
    controller.toggleNote(value);
    controller.selectCell(row, col);
    final ownDigit = _candidates(controller, row, col).first;
    controller.toggleNote(ownDigit);
    expect(controller.notesAt(row, col), {ownDigit});
    expect(controller.notesAt(row, peerCol), {value});

    controller.inputValue(value);
    expect(controller.notesAt(row, col), isEmpty);
    expect(controller.notesAt(row, peerCol), isEmpty);

    controller.undo();

    expect(controller.valueAt(row, col), 0);
    expect(controller.notesAt(row, col), {ownDigit});
    expect(controller.notesAt(row, peerCol), {value});
  });

  test('filling every cell with the solution wins the game', () {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (controller.isFixed(r, c)) continue;
        controller.selectCell(r, c);
        controller.inputValue(controller.puzzle.solutionValue(r, c));
      }
    }

    expect(controller.status, GameStatus.won);
    for (var digit = 1; digit <= 9; digit++) {
      expect(controller.remainingCount(digit), 0);
    }
  });

  test('remainingCount reflects givens already correctly placed at game start',
      () {
    for (var digit = 1; digit <= 9; digit++) {
      var givenCount = 0;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (controller.isFixed(r, c) && controller.valueAt(r, c) == digit) {
            givenCount++;
          }
        }
      }
      expect(controller.remainingCount(digit), 9 - givenCount);
    }
  });

  test('remainingCount decreases only when a digit is placed correctly', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);
    final wrongValue = correctValue == 9 ? 1 : correctValue + 1;
    final correctBefore = controller.remainingCount(correctValue);
    final wrongBefore = controller.remainingCount(wrongValue);

    controller.selectCell(row, col);
    controller.inputValue(wrongValue);
    expect(controller.remainingCount(correctValue), correctBefore);
    expect(controller.remainingCount(wrongValue), wrongBefore);

    controller.inputValue(correctValue);
    expect(controller.remainingCount(correctValue), correctBefore - 1);
  });

  test('toggleNote adds and removes a candidate digit in the selected cell',
      () {
    int? row, col;
    var candidates = const <int>[];
    outer:
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (controller.isFixed(r, c)) continue;
        final cands = _candidates(controller, r, c);
        if (cands.length >= 2) {
          row = r;
          col = c;
          candidates = cands;
          break outer;
        }
      }
    }
    expect(row, isNotNull, reason: 'expected some cell with 2+ candidates');
    final a = candidates[0];
    final b = candidates[1];

    controller.selectCell(row!, col!);
    controller.toggleNote(a);
    expect(controller.notesAt(row, col), {a});

    controller.toggleNote(b);
    expect(controller.notesAt(row, col), {a, b});

    controller.toggleNote(a);
    expect(controller.notesAt(row, col), {b});
  });

  test('toggleNote does nothing on a cell that already holds a value', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    controller.inputValue(controller.puzzle.solutionValue(row, col));
    controller.toggleNote(3);

    expect(controller.notesAt(row, col), isEmpty);
  });

  test('toggleNoteMode flips isNoteMode, defaulting to on for a new game',
      () {
    expect(controller.isNoteMode, isTrue);
    controller.toggleNoteMode();
    expect(controller.isNoteMode, isFalse);
    controller.toggleNoteMode();
    expect(controller.isNoteMode, isTrue);
  });

  test('selectedValue is null when nothing is selected or the cell is empty',
      () {
    expect(controller.selectedValue, isNull);

    locateFirstEditableCell();
    controller.selectCell(firstEmptyEditableCellRow!, firstEmptyEditableCellCol!);
    expect(controller.selectedValue, isNull);
  });

  test('selectedValue reflects the digit in the selected cell', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);

    controller.selectCell(row, col);
    controller.inputValue(correctValue);

    expect(controller.selectedValue, correctValue);
  });

  test('filling a cell with a value clears its own notes', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    final notedDigits = _candidates(controller, row, col).take(2).toSet();
    for (final digit in notedDigits) {
      controller.toggleNote(digit);
    }
    expect(controller.notesAt(row, col), notedDigits);

    controller.inputValue(controller.puzzle.solutionValue(row, col));

    expect(controller.notesAt(row, col), isEmpty);
  });

  test('eraseSelected clears any notes left in the erased cell', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    final notedDigits = _candidates(controller, row, col).take(2).toSet();
    for (final digit in notedDigits) {
      controller.toggleNote(digit);
    }
    expect(controller.notesAt(row, col), notedDigits);

    controller.eraseSelected();

    expect(controller.notesAt(row, col), isEmpty);
    expect(controller.valueAt(row, col), 0);
  });

  test('applyHint clears the notes of the cell a reveal-type hint fills',
      () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);

    controller.selectCell(row, col);
    final digit = _candidates(controller, row, col).first;
    controller.toggleNote(digit);
    expect(controller.notesAt(row, col), {digit});

    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedSingle,
      type: HintType.reveal,
      explanation: 'test',
      primaryCells: {HintCell(row, col)},
      row: row,
      col: col,
      value: correctValue,
    );
    controller.requestHint();
    controller.applyHint();

    expect(controller.notesAt(row, col), isEmpty);
  });

  test('undo after a reveal-type applyHint restores the board value and '
      'notes', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);

    controller.selectCell(row, col);
    final digit = _candidates(controller, row, col).first;
    controller.toggleNote(digit);

    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedSingle,
      type: HintType.reveal,
      explanation: 'test',
      primaryCells: {HintCell(row, col)},
      row: row,
      col: col,
      value: correctValue,
    );
    controller.requestHint();
    controller.applyHint();
    expect(controller.valueAt(row, col), correctValue);

    controller.undo();

    expect(controller.valueAt(row, col), 0);
    expect(controller.notesAt(row, col), {digit});
  });

  test('placing a value removes it from peer notes in the same row', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final value = controller.puzzle.solutionValue(row, col);

    int? peerCol;
    for (var c = 0; c < 9; c++) {
      if (c != col &&
          !controller.isFixed(row, c) &&
          SudokuGrid(controller.boardSnapshot).isValidPlacement(row, c, value)) {
        peerCol = c;
        break;
      }
    }
    expect(peerCol, isNotNull);

    controller.selectCell(row, peerCol!);
    controller.toggleNote(value);
    expect(controller.notesAt(row, peerCol), {value});

    controller.selectCell(row, col);
    controller.inputValue(value);

    expect(controller.notesAt(row, peerCol), isEmpty);
  });

  test('placing a WRONG value does not remove it from peer notes', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);
    final wrongValue = correctValue == 9 ? 1 : correctValue + 1;

    int? peerCol;
    for (var c = 0; c < 9; c++) {
      if (c != col &&
          !controller.isFixed(row, c) &&
          SudokuGrid(controller.boardSnapshot)
              .isValidPlacement(row, c, wrongValue)) {
        peerCol = c;
        break;
      }
    }
    expect(peerCol, isNotNull);

    controller.selectCell(row, peerCol!);
    controller.toggleNote(wrongValue);
    expect(controller.notesAt(row, peerCol), {wrongValue});

    controller.selectCell(row, col);
    controller.inputValue(wrongValue);

    // The wrong entry must not be treated as if it were confirmed —
    // peers keep the candidate note, since the digit hasn't actually been
    // placed correctly anywhere.
    expect(controller.isWrong(row, col), isTrue);
    expect(controller.notesAt(row, peerCol), {wrongValue});
  });

  test('placing a value does not touch notes in unrelated cells', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final value = controller.puzzle.solutionValue(row, col);

    int? unrelatedRow;
    int? unrelatedCol;
    outer:
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final sameRow = r == row;
        final sameCol = c == col;
        final sameBox = (r ~/ 3 == row ~/ 3) && (c ~/ 3 == col ~/ 3);
        if (!sameRow &&
            !sameCol &&
            !sameBox &&
            !controller.isFixed(r, c) &&
            SudokuGrid(controller.boardSnapshot).isValidPlacement(r, c, value)) {
          unrelatedRow = r;
          unrelatedCol = c;
          break outer;
        }
      }
    }
    expect(unrelatedRow, isNotNull);

    controller.selectCell(unrelatedRow!, unrelatedCol!);
    controller.toggleNote(value);
    expect(controller.notesAt(unrelatedRow, unrelatedCol), {value});

    controller.selectCell(row, col);
    controller.inputValue(value);

    expect(controller.notesAt(unrelatedRow, unrelatedCol), {value});
  });

  test('applyHint removes the placed digit from peer notes after a '
      'reveal-type hint, without touching unrelated cells', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final value = controller.puzzle.solutionValue(row, col);

    int? peerCol;
    for (var c = 0; c < 9; c++) {
      if (c != col &&
          !controller.isFixed(row, c) &&
          SudokuGrid(controller.boardSnapshot).isValidPlacement(row, c, value)) {
        peerCol = c;
        break;
      }
    }
    expect(peerCol, isNotNull);

    int? unrelatedRow;
    int? unrelatedCol;
    outer:
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final sameRow = r == row;
        final sameCol = c == col;
        final sameBox = (r ~/ 3 == row ~/ 3) && (c ~/ 3 == col ~/ 3);
        if (!sameRow &&
            !sameCol &&
            !sameBox &&
            !controller.isFixed(r, c) &&
            SudokuGrid(controller.boardSnapshot).isValidPlacement(r, c, value)) {
          unrelatedRow = r;
          unrelatedCol = c;
          break outer;
        }
      }
    }
    expect(unrelatedRow, isNotNull);

    controller.selectCell(row, peerCol!);
    controller.toggleNote(value);
    expect(controller.notesAt(row, peerCol), {value});

    controller.selectCell(unrelatedRow!, unrelatedCol!);
    controller.toggleNote(value);
    expect(controller.notesAt(unrelatedRow, unrelatedCol), {value});

    hintEngine.nextHint = Hint(
      technique: HintTechnique.nakedSingle,
      type: HintType.reveal,
      explanation: 'test',
      primaryCells: {HintCell(row, col)},
      row: row,
      col: col,
      value: value,
    );
    controller.requestHint();
    controller.applyHint();

    // The peer cell's stale note (the value newly placed at (row, col),
    // which it can no longer legally hold) is gone...
    expect(controller.notesAt(row, peerCol), isNot(contains(value)));
    // ...but the unrelated cell's note is untouched — applying a
    // reveal-type hint must not blanket the rest of the board in pencil
    // marks the player never asked for, same as a normal placement.
    expect(controller.notesAt(unrelatedRow, unrelatedCol), {value});
  });

  test('autoFillNotes overwrites every empty cell\'s notes with the true '
      'candidates, regardless of prior note state', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    // A deliberately wrong/incomplete note: a digit that can't actually go
    // here, given the confirmed board. toggleNote itself would now reject
    // this, so it's injected directly via resumeFrom — simulating notes
    // left over from before this validation existed (e.g. an older save).
    final grid = SudokuGrid(controller.boardSnapshot);
    final trueCandidates = grid.candidatesAt(row, col);
    final wrongDigit = [for (var d = 1; d <= 9; d++) d]
        .firstWhere((d) => !trueCandidates.contains(d));
    final snapshot = controller.toSnapshot();
    final mutatedNotes = snapshot.notes
        .map((r) => r.map((c) => List<int>.from(c)).toList())
        .toList();
    mutatedNotes[row][col] = [wrongDigit];
    controller.resumeFrom(GameSnapshot(
      puzzle: snapshot.puzzle,
      board: snapshot.board,
      notes: mutatedNotes,
      mistakes: snapshot.mistakes,
      elapsedSeconds: snapshot.elapsedSeconds,
      hintsUsed: snapshot.hintsUsed,
    ));
    expect(controller.notesAt(row, col), {wrongDigit});

    controller.autoFillNotes();

    _expectNotesMatchTrueCandidates(controller);
    // Given cells and filled cells never carry notes.
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (controller.isFixed(r, c) || controller.valueAt(r, c) != 0) {
          expect(controller.notesAt(r, c), isEmpty, reason: 'cell ($r, $c)');
        }
      }
    }
  });

  test('undo after autoFillNotes restores the exact prior notes grid', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    controller.toggleNote(_candidates(controller, row, col).first);
    final notesBefore = List.generate(
      9,
      (r) => List.generate(
          9, (c) => Set<int>.from(controller.notesAt(r, c))),
    );

    controller.autoFillNotes();
    _expectNotesMatchTrueCandidates(controller);

    controller.undo();

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        expect(controller.notesAt(r, c), notesBefore[r][c],
            reason: 'cell ($r, $c)');
      }
    }
  });

  test('autoFillNotes does nothing once the game is over', () {
    var mistakesMade = 0;
    for (var r = 0; r < 9 && mistakesMade < 3; r++) {
      for (var c = 0; c < 9 && mistakesMade < 3; c++) {
        if (controller.isFixed(r, c)) continue;
        final correctValue = controller.puzzle.solutionValue(r, c);
        final wrongValue = correctValue == 9 ? 1 : correctValue + 1;
        controller.selectCell(r, c);
        controller.inputValue(wrongValue);
        mistakesMade++;
      }
    }
    expect(controller.status, GameStatus.gameOver);
    final notesBefore = List.generate(
      9,
      (r) => List.generate(
          9, (c) => Set<int>.from(controller.notesAt(r, c))),
    );

    controller.autoFillNotes();

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        expect(controller.notesAt(r, c), notesBefore[r][c],
            reason: 'cell ($r, $c)');
      }
    }
    expect(controller.status, GameStatus.gameOver);
  });

  test('toggleNote blocks a digit already present in the row/column/box '
      'and flashes the conflicting cell(s)', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final trueCandidates = _candidates(controller, row, col).toSet();
    final blockedDigit = [for (var d = 1; d <= 9; d++) d]
        .firstWhere((d) => !trueCandidates.contains(d));

    final board = controller.boardSnapshot;
    final expectedConflicts = <HintCell>{};
    for (var c = 0; c < 9; c++) {
      if (c != col && board[row][c] == blockedDigit) {
        expectedConflicts.add(HintCell(row, c));
      }
    }
    for (var r = 0; r < 9; r++) {
      if (r != row && board[r][col] == blockedDigit) {
        expectedConflicts.add(HintCell(r, col));
      }
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (var r = boxRow; r < boxRow + 3; r++) {
      for (var c = boxCol; c < boxCol + 3; c++) {
        if ((r != row || c != col) && board[r][c] == blockedDigit) {
          expectedConflicts.add(HintCell(r, c));
        }
      }
    }
    expect(expectedConflicts, isNotEmpty);

    controller.selectCell(row, col);
    controller.toggleNote(blockedDigit);

    expect(controller.notesAt(row, col), isEmpty);
    expect(controller.conflictFlashCells, expectedConflicts);
  });

  test('conflictFlashCells auto-clears shortly after being set', () async {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final trueCandidates = _candidates(controller, row, col).toSet();
    final blockedDigit = [for (var d = 1; d <= 9; d++) d]
        .firstWhere((d) => !trueCandidates.contains(d));

    controller.selectCell(row, col);
    controller.toggleNote(blockedDigit);
    expect(controller.conflictFlashCells, isNotEmpty);

    await Future.delayed(const Duration(milliseconds: 600));

    expect(controller.conflictFlashCells, isEmpty);
  });

  test('selecting a cell clears an in-progress conflict flash', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final trueCandidates = _candidates(controller, row, col).toSet();
    final blockedDigit = [for (var d = 1; d <= 9; d++) d]
        .firstWhere((d) => !trueCandidates.contains(d));

    controller.selectCell(row, col);
    controller.toggleNote(blockedDigit);
    expect(controller.conflictFlashCells, isNotEmpty);

    controller.selectCell(row, col);
    expect(controller.conflictFlashCells, isEmpty);
  });

  test(
      'requestHint after applying an eliminate-type hint does not repeat '
      'the same elimination', () {
    // Same "pointing" fixture as hint_engine_test.dart: box (rows 0-2,
    // cols 0-2) has digits 1,2,3,4,6,7 placed, leaving {5,8,9} as
    // candidates at (0,0),(0,1),(0,2), each confined to row 0 within the
    // box — so digit 5 (then, after it's eliminated, digit 8) gets
    // pointed out of the box's row.
    final board = List.generate(9, (_) => List.filled(9, 0));
    board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
    board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];

    // Eliminate-type hints now reason over the player's own current notes
    // (not a hidden board-only recompute), so this fixture needs notes
    // already populated with the true candidates — as if the player had
    // used autoFillNotes — for the pointing pattern to be discoverable.
    final grid = SudokuGrid(board);
    final notes = List.generate(
      9,
      (r) => List.generate(9, (c) => grid.candidatesAt(r, c).toList()),
    );

    final snapshot = GameSnapshot(
      puzzle: SudokuPuzzle(
        puzzle: SudokuGrid(board),
        solution: SudokuGrid(_echoAsSolution(board)),
        fixedMask: List.generate(9, (_) => List.filled(9, false)),
        difficulty: Difficulty.easy,
      ),
      board: board,
      notes: notes,
      mistakes: 0,
      elapsedSeconds: 0,
      hintsUsed: 0,
    );

    final realController = GameController(
      generator: SudokuGenerator(random: Random(1)),
      hintEngine: HintEngine(),
    )..resumeFrom(snapshot);

    final hint1 = realController.requestHint();
    expect(hint1, isNotNull);
    expect(hint1!.technique, HintTechnique.intersectionPointing);
    final hint1Key =
        hint1.eliminations.map((e) => (e.row, e.col, e.digit)).toSet();
    expect(hint1Key, isNotEmpty);

    realController.applyHint();

    final hint2 = realController.requestHint();
    expect(hint2, isNotNull);
    final hint2Key =
        hint2!.eliminations.map((e) => (e.row, e.col, e.digit)).toSet();

    // The bug: without the fix, hint2 would be the exact same elimination
    // as hint1, forever, since applying an eliminate-type hint never
    // changes the board.
    expect(hint1Key.intersection(hint2Key), isEmpty);
  });

  test(
      'canAutoFillNotes is true and autoFillNotes fills notes even when a '
      'hint is already available from the board alone', () {
    // Naked single fixture (matches hint_engine_test.dart): (0,0) narrows
    // to candidate {1} from row/column exclusions alone, discoverable even
    // with completely empty notes. Auto-fill and hints are independent
    // features, so hint availability must not gate auto-fill.
    final board = List.generate(9, (_) => List.filled(9, 0));
    board[0] = [0, 0, 0, 4, 5, 6, 7, 8, 9];
    board[5][0] = 2;
    board[6][0] = 3;

    final snapshot = GameSnapshot(
      puzzle: SudokuPuzzle(
        puzzle: SudokuGrid(board),
        solution: SudokuGrid(_echoAsSolution(board)),
        fixedMask: List.generate(9, (_) => List.filled(9, false)),
        difficulty: Difficulty.easy,
      ),
      board: board,
      notes: List.generate(9, (_) => List.generate(9, (_) => <int>[])),
      mistakes: 0,
      elapsedSeconds: 0,
      hintsUsed: 0,
    );

    final realController = GameController(
      generator: SudokuGenerator(random: Random(1)),
      hintEngine: HintEngine(),
    )..resumeFrom(snapshot);

    expect(realController.requestHint(), isNotNull);
    expect(realController.canAutoFillNotes, isTrue);

    realController.autoFillNotes();

    _expectNotesMatchTrueCandidates(realController);
  });

  test(
      'canAutoFillNotes is true and autoFillNotes fills notes with the '
      'true candidates on a fixture with empty notes', () {
    // Same pointing fixture as above. Note: requestHint would now find
    // this same hint even before autoFillNotes runs, since its own
    // solution-digit repair (see _findHintWithRepair) fills in whatever
    // notes it needs — canAutoFillNotes is independent of that (see
    // "canAutoFillNotes is true ... even when a hint is already
    // available" above) and is what's under test here.
    final board = List.generate(9, (_) => List.filled(9, 0));
    board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
    board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];

    final snapshot = GameSnapshot(
      puzzle: SudokuPuzzle(
        puzzle: SudokuGrid(board),
        solution: SudokuGrid(_echoAsSolution(board)),
        fixedMask: List.generate(9, (_) => List.filled(9, false)),
        difficulty: Difficulty.easy,
      ),
      board: board,
      notes: List.generate(9, (_) => List.generate(9, (_) => <int>[])),
      mistakes: 0,
      elapsedSeconds: 0,
      hintsUsed: 0,
    );

    final realController = GameController(
      generator: SudokuGenerator(random: Random(1)),
      hintEngine: HintEngine(),
    )..resumeFrom(snapshot);

    expect(realController.canAutoFillNotes, isTrue);

    realController.autoFillNotes();

    _expectNotesMatchTrueCandidates(realController);
    expect(realController.requestHint(), isNotNull);
  });

  test(
      'hasAvailableHint reflects whether requestHint would return a hint, '
      'without mutating activeHint the way requestHint itself does', () {
    // Same naked single fixture as the canAutoFillNotes tests above: a
    // hint is discoverable from the board alone, even with empty notes.
    final board = List.generate(9, (_) => List.filled(9, 0));
    board[0] = [0, 0, 0, 4, 5, 6, 7, 8, 9];
    board[5][0] = 2;
    board[6][0] = 3;

    final snapshot = GameSnapshot(
      puzzle: SudokuPuzzle(
        puzzle: SudokuGrid(board),
        solution: SudokuGrid(_echoAsSolution(board)),
        fixedMask: List.generate(9, (_) => List.filled(9, false)),
        difficulty: Difficulty.easy,
      ),
      board: board,
      notes: List.generate(9, (_) => List.generate(9, (_) => <int>[])),
      mistakes: 0,
      elapsedSeconds: 0,
      hintsUsed: 0,
    );

    final realController = GameController(
      generator: SudokuGenerator(random: Random(1)),
      hintEngine: HintEngine(),
    )..resumeFrom(snapshot);

    expect(realController.hasAvailableHint, isTrue);
    // Checking availability must not itself set activeHint/draw a hint —
    // that's the whole point of having a separate, non-mutating getter.
    expect(realController.activeHint, isNull);
  });

  test('hasAvailableHint is false when no technique currently applies', () {
    // A fully empty board: every cell has all 9 candidates uniformly, so
    // no technique (not even after requestHint's own solution-digit
    // repair fills every cell in) ever finds a pattern to exploit. Unlike
    // the "pointing" fixture used elsewhere in this file, this one stays
    // hint-free even with fully-populated notes.
    final board = List.generate(9, (_) => List.filled(9, 0));

    final snapshot = GameSnapshot(
      puzzle: SudokuPuzzle(
        puzzle: SudokuGrid(board),
        solution: SudokuGrid(_echoAsSolution(board)),
        fixedMask: List.generate(9, (_) => List.filled(9, false)),
        difficulty: Difficulty.easy,
      ),
      board: board,
      notes: List.generate(9, (_) => List.generate(9, (_) => <int>[])),
      mistakes: 0,
      elapsedSeconds: 0,
      hintsUsed: 0,
    );

    final realController = GameController(
      generator: SudokuGenerator(random: Random(1)),
      hintEngine: HintEngine(),
    )..resumeFrom(snapshot);

    expect(realController.hasAvailableHint, isFalse);
  });

  group('requestHintFromNotes (stage 1: notes-only, no repair)', () {
    (GameController, _ScriptedHintEngine, int, int, int) buildMissingNoteCase() {
      final scriptedEngine = _ScriptedHintEngine();
      final testController = GameController(
        generator: SudokuGenerator(random: Random(7)),
        hintEngine: scriptedEngine,
      )..startNewGame(Difficulty.easy);

      int? row;
      int? col;
      outer:
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (testController.isFixed(r, c)) continue;
          if (_candidates(testController, r, c).length < 2) continue;
          row = r;
          col = c;
          break outer;
        }
      }
      final solutionDigit = testController.puzzle.solutionValue(row!, col!);
      final otherDigit = _candidates(testController, row, col)
          .firstWhere((d) => d != solutionDigit);
      return (testController, scriptedEngine, row, col, otherDigit);
    }

    test(
        'returns the engine hint verbatim, without repairing notes or '
        'prepending a repair notice, even when a cell is missing its '
        'solution digit', () {
      final (testController, scriptedEngine, row, col, otherDigit) =
          buildMissingNoteCase();
      testController.selectCell(row, col);
      testController.toggleNote(otherDigit);

      final placeholder = Hint(
        technique: HintTechnique.intersectionPointing,
        type: HintType.eliminate,
        explanation: 'fake',
        primaryCells: {HintCell(row, col)},
      );
      scriptedEngine.hints = [placeholder];

      final hint = testController.requestHintFromNotes();

      // Unlike requestHint, stage 1 does no repair: the explanation is
      // returned verbatim (no note-repair prefix) and the player's single
      // note is left exactly as they set it.
      expect(hint, isNotNull);
      expect(hint!.explanation, placeholder.explanation);
      expect(testController.notesAt(row, col), {otherDigit});
      expect(testController.activeHint, hint);
    });

    test('returns null and leaves the active hint cleared when the '
        'notes-only search finds nothing', () {
      final (testController, _, _, _, _) = buildMissingNoteCase();
      // Scripted engine defaults to returning null.
      expect(testController.requestHintFromNotes(), isNull);
      expect(testController.activeHint, isNull);
    });

    test('rejects a notes-only hint that would eliminate a cell\'s true '
        'solution digit (faulty notes) and returns null', () {
      // Simulates the "faulty notes → wrong deduction" case: the engine
      // returns an eliminate hint removing a cell's actual answer, exactly
      // what an understated Naked Pair could produce. It must NOT be shown.
      final (testController, scriptedEngine, row, col, _) =
          buildMissingNoteCase();
      final solutionDigit = testController.puzzle.solutionValue(row, col);
      scriptedEngine.hints = [
        Hint(
          technique: HintTechnique.nakedPair,
          type: HintType.eliminate,
          explanation: 'faulty',
          primaryCells: {HintCell(row, col)},
          eliminations: [HintElimination(row, col, solutionDigit)],
        ),
      ];

      expect(testController.requestHintFromNotes(), isNull);
      expect(testController.activeHint, isNull);
    });

    test('returns a notes-only hint whose eliminations agree with the '
        'solution', () {
      final (testController, scriptedEngine, row, col, otherDigit) =
          buildMissingNoteCase();
      // otherDigit is, by construction, NOT this cell's solution digit, so
      // eliminating it is solution-consistent and the hint is shown as-is.
      final hint = Hint(
        technique: HintTechnique.nakedPair,
        type: HintType.eliminate,
        explanation: 'ok',
        primaryCells: {HintCell(row, col)},
        eliminations: [HintElimination(row, col, otherDigit)],
      );
      scriptedEngine.hints = [hint];

      expect(testController.requestHintFromNotes(), same(hint));
      expect(testController.activeHint, same(hint));
    });
  });

  group('requestHint repairs notes missing the solution digit', () {
    // Finds the first non-fixed cell with at least 2 true candidates (so
    // there's a genuine choice between noting the solution digit and
    // noting something else), starts a deterministic game, and returns it
    // along with its solution digit and a same-cell alternative.
    (GameController, _ScriptedHintEngine, int, int, int, int)
        buildNotedCellCase() {
      final scriptedEngine = _ScriptedHintEngine();
      final testController = GameController(
        generator: SudokuGenerator(random: Random(7)),
        hintEngine: scriptedEngine,
      )..startNewGame(Difficulty.easy);

      int? row;
      int? col;
      outer:
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (testController.isFixed(r, c)) continue;
          if (_candidates(testController, r, c).length < 2) continue;
          row = r;
          col = c;
          break outer;
        }
      }
      expect(row, isNotNull,
          reason: 'fixture needs a cell with >= 2 true candidates');

      final solutionDigit = testController.puzzle.solutionValue(row!, col!);
      final otherDigit = _candidates(testController, row, col)
          .firstWhere((d) => d != solutionDigit);

      return (testController, scriptedEngine, row, col, solutionDigit,
          otherDigit);
    }

    test(
        'repairs a cell whose only note is NOT the solution digit, before '
        'searching for a hint', () {
      final (testController, scriptedEngine, row, col, _, otherDigit) =
          buildNotedCellCase();
      testController.selectCell(row, col);
      testController.toggleNote(otherDigit);

      final placeholder = Hint(
        technique: HintTechnique.intersectionPointing,
        type: HintType.eliminate,
        explanation: 'fake',
        primaryCells: {HintCell(row, col)},
      );
      scriptedEngine.hints = [placeholder];

      final hint = testController.requestHint();

      // A repair happened and the returned hint is eliminate-type, so its
      // explanation gets a prepended note about the correction.
      expect(hint, isNotNull);
      expect(hint!.explanation,
          '일부 칸의 후보 메모가 실제와 달라 먼저 자동으로 보정했어요. ${placeholder.explanation}');
      final trueCandidates =
          SudokuGrid(testController.boardSnapshot).candidatesAt(row, col);
      expect(testController.notesAt(row, col), trueCandidates);
    });

    test(
        'does NOT repair a cell whose notes are narrower than raw '
        'candidates but still contain the solution digit — e.g. after a '
        'validly applied advanced technique', () {
      final (testController, scriptedEngine, row, col, solutionDigit, _) =
          buildNotedCellCase();
      testController.selectCell(row, col);
      // Only the solution digit is noted — narrower than the full
      // candidatesAt set, exactly as it would look if an advanced
      // technique had correctly eliminated every other candidate there.
      testController.toggleNote(solutionDigit);
      final beforeRequest = Set<int>.from(testController.notesAt(row, col));

      final placeholder = Hint(
        technique: HintTechnique.intersectionPointing,
        type: HintType.eliminate,
        explanation: 'fake',
        primaryCells: {HintCell(row, col)},
      );
      scriptedEngine.hints = [placeholder];

      final hint = testController.requestHint();

      // (row, col) itself is left completely untouched — every other
      // still-empty cell on the board may still get repaired (they were
      // never noted at all, so the explanation still gets the prepended
      // note), but that's orthogonal to what's under test here.
      expect(hint, isNotNull);
      expect(hint!.explanation,
          '일부 칸의 후보 메모가 실제와 달라 먼저 자동으로 보정했어요. ${placeholder.explanation}');
      expect(testController.notesAt(row, col), beforeRequest);
    });

    test('undo after a note-repairing requestHint restores the prior notes',
        () {
      final (testController, scriptedEngine, row, col, _, otherDigit) =
          buildNotedCellCase();
      testController.selectCell(row, col);
      testController.toggleNote(otherDigit);
      final beforeRepair = Set<int>.from(testController.notesAt(row, col));

      scriptedEngine.hints = [
        Hint(
          technique: HintTechnique.intersectionPointing,
          type: HintType.eliminate,
          explanation: 'fake',
          primaryCells: {HintCell(row, col)},
        ),
      ];
      testController.requestHint();
      expect(testController.canUndo, isTrue);

      testController.undo();

      expect(testController.notesAt(row, col), beforeRepair);
    });

    test(
        'does not repair notes or add undo history when every cell is '
        'already fully noted', () {
      final scriptedEngine = _ScriptedHintEngine();
      final testController = GameController(
        generator: SudokuGenerator(random: Random(7)),
        hintEngine: scriptedEngine,
      )..startNewGame(Difficulty.easy);
      testController.autoFillNotes();
      expect(testController.canUndo, isTrue);

      int? row;
      int? col;
      outer:
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (!testController.isFixed(r, c) &&
              testController.notesAt(r, c).isNotEmpty) {
            row = r;
            col = c;
            break outer;
          }
        }
      }
      expect(row, isNotNull);

      final validHint = Hint(
        technique: HintTechnique.intersectionPointing,
        type: HintType.eliminate,
        explanation: 'fake',
        primaryCells: {HintCell(row!, col!)},
      );
      scriptedEngine.hints = [validHint];

      final beforeNotes = Set<int>.from(testController.notesAt(row, col));
      final hint = testController.requestHint();

      expect(hint, same(validHint));
      expect(testController.notesAt(row, col), beforeNotes);
      // Exactly one history entry (from autoFillNotes) — requestHint added
      // no extra one, since nothing needed repairing.
      testController.undo();
      expect(testController.canUndo, isFalse);
    });

    test('hasAvailableHint does not mutate notes even when repair would '
        'otherwise be needed', () {
      final (testController, scriptedEngine, row, col, _, otherDigit) =
          buildNotedCellCase();
      testController.selectCell(row, col);
      testController.toggleNote(otherDigit);
      final beforeCheck = Set<int>.from(testController.notesAt(row, col));

      scriptedEngine.hints = [
        Hint(
          technique: HintTechnique.intersectionPointing,
          type: HintType.eliminate,
          explanation: 'fake',
          primaryCells: {HintCell(row, col)},
        ),
      ];

      expect(testController.hasAvailableHint, isTrue);
      expect(testController.notesAt(row, col), beforeCheck);
    });

    test(
        'only prepends the note-repair explanation for eliminate-type '
        'hints, even when a repair happened', () {
      // A fresh game has every empty cell blank, so a full-board repair
      // is guaranteed to happen on the very first requestHint call
      // regardless of which hint technique ends up firing.
      final revealScripted = _ScriptedHintEngine();
      final revealController = GameController(
        generator: SudokuGenerator(random: Random(7)),
        hintEngine: revealScripted,
      )..startNewGame(Difficulty.easy);
      locateFirstEditableCell();
      final revealHint = Hint(
        technique: HintTechnique.nakedSingle,
        type: HintType.reveal,
        explanation: 'reveal fake',
        primaryCells: {
          HintCell(firstEmptyEditableCellRow!, firstEmptyEditableCellCol!)
        },
        row: firstEmptyEditableCellRow,
        col: firstEmptyEditableCellCol,
        value: 1,
      );
      revealScripted.hints = [revealHint];

      final gotRevealHint = revealController.requestHint();

      expect(gotRevealHint!.explanation, 'reveal fake');

      final eliminateScripted = _ScriptedHintEngine();
      final eliminateController = GameController(
        generator: SudokuGenerator(random: Random(7)),
        hintEngine: eliminateScripted,
      )..startNewGame(Difficulty.easy);
      final eliminateHint = Hint(
        technique: HintTechnique.intersectionPointing,
        type: HintType.eliminate,
        explanation: 'eliminate fake',
        primaryCells: {
          HintCell(firstEmptyEditableCellRow!, firstEmptyEditableCellCol!)
        },
      );
      eliminateScripted.hints = [eliminateHint];

      final gotEliminateHint = eliminateController.requestHint();

      expect(gotEliminateHint!.explanation,
          '일부 칸의 후보 메모가 실제와 달라 먼저 자동으로 보정했어요. eliminate fake');
    });
  });

  group('hint gating on unresolved mistakes', () {
    test(
        'hasUnresolvedMistake reflects whether any wrong value is on the '
        'board', () {
      locateFirstEditableCell();
      final row = firstEmptyEditableCellRow!;
      final col = firstEmptyEditableCellCol!;
      final correctValue = controller.puzzle.solutionValue(row, col);
      final wrongValue = correctValue == 9 ? 1 : correctValue + 1;

      expect(controller.hasUnresolvedMistake, isFalse);

      controller.selectCell(row, col);
      controller.inputValue(wrongValue);
      expect(controller.hasUnresolvedMistake, isTrue);

      controller.inputValue(correctValue);
      expect(controller.hasUnresolvedMistake, isFalse);
    });

    test(
        'requestHint and hasAvailableHint refuse while a wrong value is '
        'uncorrected, even if a hint would otherwise be available', () {
      locateFirstEditableCell();
      final row = firstEmptyEditableCellRow!;
      final col = firstEmptyEditableCellCol!;
      final correctValue = controller.puzzle.solutionValue(row, col);
      final wrongValue = correctValue == 9 ? 1 : correctValue + 1;

      // A different cell holds the wrong value; the fake engine is primed
      // to return a hint regardless, to isolate the gate itself from
      // whatever a real technique would or wouldn't find.
      int? otherRow;
      int? otherCol;
      outer:
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if ((r != row || c != col) && !controller.isFixed(r, c)) {
            otherRow = r;
            otherCol = c;
            break outer;
          }
        }
      }
      expect(otherRow, isNotNull);

      hintEngine.nextHint = Hint(
        technique: HintTechnique.nakedSingle,
        type: HintType.reveal,
        explanation: 'test',
        primaryCells: {HintCell(otherRow!, otherCol!)},
        row: otherRow,
        col: otherCol,
        value: 1,
      );

      controller.selectCell(row, col);
      controller.inputValue(wrongValue);

      expect(controller.hasAvailableHint, isFalse);
      expect(controller.requestHint(), isNull);
      expect(controller.activeHint, isNull);
    });
  });

  test('canErase is false when no cell is selected', () {
    expect(controller.selectedRow, isNull);
    expect(controller.canErase, isFalse);
  });

  test('canErase is false for a fixed (given) cell', () {
    outer:
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (controller.isFixed(r, c)) {
          controller.selectCell(r, c);
          break outer;
        }
      }
    }
    expect(controller.canErase, isFalse);
  });

  test(
      'canErase is false for a confirmed-correct digit, and eraseSelected '
      'is a no-op on it', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);

    controller.selectCell(row, col);
    controller.inputValue(correctValue);
    expect(controller.canUndo, isTrue);

    expect(controller.canErase, isFalse);
    controller.eraseSelected();

    // Unchanged, and no extra history entry was pushed: exactly one undo
    // (undoing the original inputValue) restores the empty cell.
    expect(controller.valueAt(row, col), correctValue);
    controller.undo();
    expect(controller.valueAt(row, col), 0);
    expect(controller.canUndo, isFalse);
  });

  test('canErase is true for a wrong digit, and eraseSelected clears it', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);
    final wrongValue = correctValue == 1 ? 2 : 1;

    controller.selectCell(row, col);
    controller.inputValue(wrongValue);
    expect(controller.isWrong(row, col), isTrue);

    expect(controller.canErase, isTrue);
    controller.eraseSelected();

    expect(controller.valueAt(row, col), 0);
  });

  test(
      'eraseSelected on an already-empty cell with no notes does not add '
      'to history', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;

    controller.selectCell(row, col);
    expect(controller.canUndo, isFalse);
    expect(controller.valueAt(row, col), 0);
    expect(controller.notesAt(row, col), isEmpty);

    controller.eraseSelected();

    expect(controller.canUndo, isFalse);
  });

  test(
      'pressing eraseSelected twice in a row on the same cell only adds '
      'one history entry', () {
    locateFirstEditableCell();
    final row = firstEmptyEditableCellRow!;
    final col = firstEmptyEditableCellCol!;
    final correctValue = controller.puzzle.solutionValue(row, col);
    final wrongValue = correctValue == 1 ? 2 : 1;

    controller.selectCell(row, col);
    controller.inputValue(wrongValue);

    controller.eraseSelected();
    expect(controller.valueAt(row, col), 0);
    controller.eraseSelected();

    // Exactly two real moves happened (place the wrong digit, then erase
    // it) — the second, no-op erase press must not have pushed a third,
    // redundant entry. One undo unwinds the erase; a second unwinds the
    // original placement; a third would have nothing left to do.
    controller.undo();
    expect(controller.valueAt(row, col), wrongValue);
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.valueAt(row, col), 0);
    expect(controller.canUndo, isFalse);
  });

  test('startNewGame uses a supplied puzzle directly instead of calling the '
      'generator, e.g. one popped from PuzzleQueueManager', () {
    final board = List.generate(9, (_) => List.filled(9, 0));
    board[0][0] = 5;
    final suppliedPuzzle = SudokuPuzzle(
      puzzle: SudokuGrid(board),
      solution: SudokuGrid(List.generate(9, (_) => List.filled(9, 1))),
      fixedMask: List.generate(9, (_) => List.filled(9, false)),
      difficulty: Difficulty.expert,
    );

    // A generator that would build a completely different (empty) puzzle,
    // so any use of it — instead of the supplied puzzle — is detectable.
    final fresh = GameController(
      generator: SudokuGenerator(random: Random(99)),
      hintEngine: HintEngine(),
    )..startNewGame(Difficulty.expert, puzzle: suppliedPuzzle);

    expect(fresh.puzzle, same(suppliedPuzzle));
    expect(fresh.boardSnapshot, board);
    expect(fresh.difficulty, Difficulty.expert);
  });
}
