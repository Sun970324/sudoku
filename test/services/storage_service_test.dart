import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/game_snapshot.dart';
import 'package:sudoku/models/stats.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/storage_service.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';

SudokuPuzzle _dummyPuzzle(Difficulty difficulty) => SudokuPuzzle(
      puzzle: SudokuGrid.empty(),
      solution: SudokuGrid.empty(),
      fixedMask: List.generate(9, (_) => List.filled(9, false)),
      difficulty: difficulty,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  GameSnapshot buildSnapshot({int elapsedSeconds = 42, int mistakes = 1}) {
    final puzzle = SudokuGenerator(random: Random(3)).generate(Difficulty.easy);
    final board = puzzle.puzzle.toJson();
    final notes = List.generate(9, (_) => List.generate(9, (_) => <int>[]));
    notes[0][0] = [1, 2];
    return GameSnapshot(
      puzzle: puzzle,
      board: board,
      notes: notes,
      mistakes: mistakes,
      elapsedSeconds: elapsedSeconds,
      hintsUsed: 2,
    );
  }

  test('loadInProgressGame returns null when nothing has been saved', () async {
    final storage = StorageService();
    expect(await storage.loadInProgressGame(), isNull);
  });

  test('saveInProgressGame/loadInProgressGame round-trips the snapshot', () async {
    final storage = StorageService();
    final snapshot = buildSnapshot();

    await storage.saveInProgressGame(snapshot);
    final loaded = await storage.loadInProgressGame();

    expect(loaded, isNotNull);
    expect(loaded!.mistakes, snapshot.mistakes);
    expect(loaded.elapsedSeconds, snapshot.elapsedSeconds);
    expect(loaded.hintsUsed, snapshot.hintsUsed);
    expect(loaded.puzzle.difficulty, snapshot.puzzle.difficulty);
    expect(loaded.board, snapshot.board);
    expect(loaded.notes, snapshot.notes);
    expect(loaded.puzzle.solution.cells, snapshot.puzzle.solution.cells);
  });

  test('clearInProgressGame removes the saved snapshot', () async {
    final storage = StorageService();
    await storage.saveInProgressGame(buildSnapshot());

    await storage.clearInProgressGame();

    expect(await storage.loadInProgressGame(), isNull);
  });

  test('loadRaceProgress returns null when nothing has been saved', () async {
    final storage = StorageService();
    expect(await storage.loadRaceProgress(), isNull);
  });

  test('saveRaceProgress/loadRaceProgress round-trips the race id and board',
      () async {
    final storage = StorageService();
    final snapshot = buildSnapshot(elapsedSeconds: 73, mistakes: 2);

    await storage.saveRaceProgress('race-abc', snapshot);
    final loaded = await storage.loadRaceProgress();

    expect(loaded, isNotNull);
    expect(loaded!.raceId, 'race-abc');
    expect(loaded.snapshot.elapsedSeconds, 73);
    expect(loaded.snapshot.mistakes, 2);
    expect(loaded.snapshot.board, snapshot.board);
    expect(loaded.snapshot.puzzle.solution.cells,
        snapshot.puzzle.solution.cells);
  });

  test('clearRaceProgress removes the saved race board', () async {
    final storage = StorageService();
    await storage.saveRaceProgress('race-abc', buildSnapshot());

    await storage.clearRaceProgress();

    expect(await storage.loadRaceProgress(), isNull);
  });

  test('getStats starts empty for every difficulty', () async {
    final storage = StorageService();
    final stats = await storage.getStats();

    for (final difficulty in Difficulty.values) {
      final entry = stats.byDifficulty[difficulty]!;
      expect(entry.played, 0);
      expect(entry.won, 0);
      expect(entry.bestTimeSeconds, isNull);
    }
  });

  test('recordGameResult tracks played/won counts and best time', () async {
    final storage = StorageService();

    await storage.recordGameResult(
      difficulty: Difficulty.easy,
      won: true,
      finishTimeSeconds: 120,
    );
    var stats = await storage.getStats();
    var easy = stats.byDifficulty[Difficulty.easy]!;
    expect(easy.played, 1);
    expect(easy.won, 1);
    expect(easy.bestTimeSeconds, 120);

    // A slower win afterwards should not overwrite the existing best time.
    await storage.recordGameResult(
      difficulty: Difficulty.easy,
      won: true,
      finishTimeSeconds: 200,
    );
    stats = await storage.getStats();
    easy = stats.byDifficulty[Difficulty.easy]!;
    expect(easy.played, 2);
    expect(easy.won, 2);
    expect(easy.bestTimeSeconds, 120);

    // A faster win should become the new best time.
    await storage.recordGameResult(
      difficulty: Difficulty.easy,
      won: true,
      finishTimeSeconds: 90,
    );
    stats = await storage.getStats();
    easy = stats.byDifficulty[Difficulty.easy]!;
    expect(easy.played, 3);
    expect(easy.won, 3);
    expect(easy.bestTimeSeconds, 90);
  });

  test('recordGameResult accumulates perfect wins and the timed-win average',
      () async {
    final storage = StorageService();

    // Perfect win (0 mistakes, 0 hints): counts toward perfectWins and the
    // average.
    await storage.recordGameResult(
      difficulty: Difficulty.easy,
      won: true,
      finishTimeSeconds: 100,
      mistakes: 0,
      hintsUsed: 0,
    );
    // Won with mistakes: average yes, perfect no.
    await storage.recordGameResult(
      difficulty: Difficulty.easy,
      won: true,
      finishTimeSeconds: 200,
      mistakes: 2,
      hintsUsed: 0,
    );
    // Loss: touches none of the new fields.
    await storage.recordGameResult(
      difficulty: Difficulty.easy,
      won: false,
      mistakes: 3,
    );

    final easy = (await storage.getStats()).byDifficulty[Difficulty.easy]!;
    expect(easy.perfectWins, 1);
    expect(easy.timedWins, 2);
    expect(easy.totalWinSeconds, 300);
    expect(easy.averageWinSeconds, 150);
  });

  test('a win recorded without mistakes info never counts as perfect, and '
      'legacy stats JSON without the new fields loads as zeros', () async {
    final storage = StorageService();

    await storage.recordGameResult(
      difficulty: Difficulty.easy,
      won: true,
      finishTimeSeconds: 100,
    );
    final easy = (await storage.getStats()).byDifficulty[Difficulty.easy]!;
    expect(easy.perfectWins, 0);
    expect(easy.timedWins, 1);

    // Legacy shape: only the fields that existed before this change. The
    // average must be null (not zero or a division error) — old wins carry
    // no time information.
    final legacy = DifficultyStats.fromJson(
        {'played': 5, 'won': 3, 'bestTimeSeconds': 80});
    expect(legacy.perfectWins, 0);
    expect(legacy.timedWins, 0);
    expect(legacy.totalWinSeconds, 0);
    expect(legacy.averageWinSeconds, isNull);
  });

  test('recordGameResult with a loss increments played but not won or best time',
      () async {
    final storage = StorageService();

    await storage.recordGameResult(difficulty: Difficulty.hard, won: false);

    final stats = await storage.getStats();
    final hard = stats.byDifficulty[Difficulty.hard]!;
    expect(hard.played, 1);
    expect(hard.won, 0);
    expect(hard.bestTimeSeconds, isNull);
  });

  test('stats for different difficulties are tracked independently', () async {
    final storage = StorageService();

    await storage.recordGameResult(
      difficulty: Difficulty.medium,
      won: true,
      finishTimeSeconds: 60,
    );

    final stats = await storage.getStats();
    expect(stats.byDifficulty[Difficulty.medium]!.played, 1);
    expect(stats.byDifficulty[Difficulty.easy]!.played, 0);
    expect(stats.byDifficulty[Difficulty.hard]!.played, 0);
  });

  test('loadThemeMode defaults to system when nothing has been saved',
      () async {
    final storage = StorageService();
    expect(await storage.loadThemeMode(), ThemeMode.system);
  });

  test('saveThemeMode/loadThemeMode round-trips every theme mode', () async {
    final storage = StorageService();
    for (final mode in ThemeMode.values) {
      await storage.saveThemeMode(mode);
      expect(await storage.loadThemeMode(), mode);
    }
  });

  test('loadHapticsEnabled defaults to true when nothing has been saved',
      () async {
    final storage = StorageService();
    expect(await storage.loadHapticsEnabled(), isTrue);
  });

  test('saveHapticsEnabled/loadHapticsEnabled round-trips false and true',
      () async {
    final storage = StorageService();

    await storage.saveHapticsEnabled(false);
    expect(await storage.loadHapticsEnabled(), isFalse);

    await storage.saveHapticsEnabled(true);
    expect(await storage.loadHapticsEnabled(), isTrue);
  });

  test('loadSoundEnabled defaults to true when nothing has been saved',
      () async {
    final storage = StorageService();
    expect(await storage.loadSoundEnabled(), isTrue);
  });

  test('saveSoundEnabled/loadSoundEnabled round-trips false and true',
      () async {
    final storage = StorageService();

    await storage.saveSoundEnabled(false);
    expect(await storage.loadSoundEnabled(), isFalse);

    await storage.saveSoundEnabled(true);
    expect(await storage.loadSoundEnabled(), isTrue);
  });

  test('loadPuzzleQueue returns an empty list per difficulty when nothing '
      'has been saved', () async {
    final storage = StorageService();
    final queues = await storage.loadPuzzleQueue();

    for (final difficulty in Difficulty.values) {
      expect(queues[difficulty], isEmpty);
    }
  });

  test('savePuzzleQueue/loadPuzzleQueue round-trips puzzles per difficulty',
      () async {
    final storage = StorageService();
    final queues = {
      for (final difficulty in Difficulty.values)
        difficulty: <SudokuPuzzle>[],
    };
    queues[Difficulty.beginner] = [
      _dummyPuzzle(Difficulty.beginner),
      _dummyPuzzle(Difficulty.beginner),
    ];
    queues[Difficulty.expert] = [_dummyPuzzle(Difficulty.expert)];

    await storage.savePuzzleQueue(queues);
    final loaded = await storage.loadPuzzleQueue();

    expect(loaded[Difficulty.beginner]!.length, 2);
    expect(loaded[Difficulty.beginner]!.every((p) => p.difficulty == Difficulty.beginner),
        isTrue);
    expect(loaded[Difficulty.expert]!.length, 1);
    expect(loaded[Difficulty.easy], isEmpty);
  });
}
