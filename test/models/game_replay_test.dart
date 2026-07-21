import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/game_replay.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';
import 'package:sudoku/services/storage_service.dart';

GameReplay _replay(
  SudokuPuzzle puzzle,
  List<GameEvent> events, {
  bool autoRemove = false,
  int elapsedSeconds = 10,
  String? raceId,
}) =>
    GameReplay(
      puzzle: puzzle,
      events: events,
      autoRemoveNotes: autoRemove,
      won: true,
      elapsedSeconds: elapsedSeconds,
      mistakes: 0,
      hintsUsed: 0,
      finishedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      raceId: raceId,
    );

void main() {
  final puzzle = SudokuGenerator(random: Random(5)).generate(Difficulty.easy);
  final firstEmpty = () {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (puzzle.puzzle.get(r, c) == 0) return [r, c];
      }
    }
    throw StateError('no empty cell');
  }();

  test('fillNotes sets every cell to its candidates', () {
    final replay = _replay(puzzle, [const GameEvent.fillNotes(0)]);
    final (_, notes) = reconstructReplay(replay, 1);
    final grid = SudokuGrid(puzzle.puzzle.toJson());
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        expect(notes[r][c], grid.candidatesAt(r, c));
      }
    }
  });

  test('eliminate removes just the named candidate', () {
    final r = firstEmpty[0], c = firstEmpty[1];
    final digit = SudokuGrid(puzzle.puzzle.toJson()).candidatesAt(r, c).first;
    final replay = _replay(puzzle, [
      const GameEvent.fillNotes(0),
      GameEvent.eliminate([
        [r, c, digit]
      ], 1),
    ]);
    final (_, notes) = reconstructReplay(replay, 2);
    expect(notes[r][c].contains(digit), isFalse);
  });

  test('a correct placement clears the digit from empty peers when autoRemove',
      () {
    final r = firstEmpty[0], c = firstEmpty[1];
    final value = puzzle.solution.get(r, c);
    final replay = _replay(
      puzzle,
      [const GameEvent.fillNotes(0), GameEvent.place(r, c, value, 1)],
      autoRemove: true,
    );
    final (_, notes) = reconstructReplay(replay, 2);
    for (final p in SudokuGrid.peersOf(r, c)) {
      expect(notes[p[0]][p[1]].contains(value), isFalse,
          reason: 'peer ${p[0]},${p[1]} still notes $value');
    }
  });

  test('toJson/fromJson round-trips every event type', () {
    final events = <GameEvent>[
      const GameEvent.place(0, 1, 5, 3),
      const GameEvent.note(2, 2, 7, 4),
      const GameEvent.eliminate([
        [1, 1, 2],
        [3, 3, 4]
      ], 5),
      const GameEvent.repair([
        [0, 0],
        [8, 8]
      ], 6),
      const GameEvent.fillNotes(7),
    ];
    final replay = _replay(puzzle, events, autoRemove: true, raceId: 'abc');
    final restored = GameReplay.fromJson(
        jsonDecode(jsonEncode(replay.toJson())) as Map<String, dynamic>);

    expect(restored.raceId, 'abc');
    expect(restored.autoRemoveNotes, isTrue);
    expect(restored.events.length, events.length);
    // Reconstructing the restored replay matches the original's final state.
    final (b1, n1) = reconstructReplay(replay, replay.events.length);
    final (b2, n2) = reconstructReplay(restored, restored.events.length);
    expect(b2, b1);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        expect(n2[r][c], n1[r][c]);
      }
    }
  });

  test('saveReplay keeps only the newest maxReplays, newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    for (var i = 0; i < StorageService.maxReplays + 3; i++) {
      await storage.saveReplay(
          _replay(puzzle, const [], elapsedSeconds: i));
    }
    final loaded = await storage.loadReplays();
    expect(loaded.length, StorageService.maxReplays);
    expect(loaded.first.elapsedSeconds, StorageService.maxReplays + 2);
    expect(loaded.last.elapsedSeconds, 3);
  });
}
