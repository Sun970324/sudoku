import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/game_replay.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';
import 'package:sudoku/state/game_controller.dart';

List<List<int>> _emptyCells(SudokuPuzzle puzzle) {
  final cells = <List<int>>[];
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      if (puzzle.puzzle.get(r, c) == 0) cells.add([r, c]);
    }
  }
  return cells;
}

/// Reconstructing the controller's own move log must reproduce its live board
/// and notes exactly — the guarantee that a replay (and "resume from a replay
/// point") is faithful.
void _expectReconstructionMatches(GameController c) {
  final replay = c.toReplay(won: false);
  final (board, notes) = reconstructReplay(replay, replay.events.length);
  expect(board, c.boardSnapshot);
  for (var r = 0; r < 9; r++) {
    for (var col = 0; col < 9; col++) {
      expect(notes[r][col], c.notesAt(r, col), reason: 'notes at $r,$col');
    }
  }
}

void main() {
  setUp(() {
    GameController.autoRemoveNotesEnabled = true;
    GameController.wrongNoteWarningEnabled = false;
  });

  test('reconstruction reproduces a scripted playthrough', () {
    final puzzle = SudokuGenerator(random: Random(7)).generate(Difficulty.easy);
    final c = GameController();
    c.startNewGame(Difficulty.easy, puzzle: puzzle);
    final empties = _emptyCells(puzzle);

    // 1) place a correct value — auto-removes the digit from peers' notes.
    var cell = empties[0];
    c.selectCell(cell[0], cell[1]);
    c.inputValue(puzzle.solution.get(cell[0], cell[1]));

    // 2) pencil notes on another cell, including a remove (toggle off).
    cell = empties[1];
    c.selectCell(cell[0], cell[1]);
    c.toggleNote(1);
    c.toggleNote(4);
    c.toggleNote(7);
    c.toggleNote(4);

    // 3) place a wrong value, then erase it.
    cell = empties[2];
    final correct = puzzle.solution.get(cell[0], cell[1]);
    c.selectCell(cell[0], cell[1]);
    c.inputValue(correct == 9 ? 8 : correct + 1);
    c.eraseSelected();

    // 4) auto-fill notes across the board.
    c.autoFillNotes();

    _expectReconstructionMatches(c);

    // 5) undo the auto-fill — the event log pops in lockstep with history.
    c.undo();
    _expectReconstructionMatches(c);
  });

  test('resume restores the log so the finished replay stays complete', () {
    final puzzle = SudokuGenerator(random: Random(11)).generate(Difficulty.easy);
    final c1 = GameController();
    c1.startNewGame(Difficulty.easy, puzzle: puzzle);
    final empties = _emptyCells(puzzle);

    // Moves before an "app kill".
    c1.selectCell(empties[0][0], empties[0][1]);
    c1.inputValue(puzzle.solution.get(empties[0][0], empties[0][1]));
    c1.selectCell(empties[1][0], empties[1][1]);
    c1.toggleNote(2);
    final snapshot = c1.toSnapshot();

    // Resume in a fresh controller and keep playing.
    final c2 = GameController();
    c2.resumeFrom(snapshot);
    c2.selectCell(empties[2][0], empties[2][1]);
    c2.inputValue(puzzle.solution.get(empties[2][0], empties[2][1]));

    // The pre-kill moves survived, and the full replay still reconstructs.
    expect(c2.eventLog.length, greaterThanOrEqualTo(3));
    _expectReconstructionMatches(c2);
  });
}
