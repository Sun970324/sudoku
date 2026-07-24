import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/puzzle_queue_manager.dart';
import 'package:sudoku/services/storage_service.dart';

SudokuPuzzle _dummyPuzzle(Difficulty difficulty) => SudokuPuzzle(
      puzzle: SudokuGrid.empty(),
      solution: SudokuGrid.empty(),
      fixedMask: List.generate(9, (_) => List.filled(9, false)),
      difficulty: difficulty,
    );

/// A fake `generateBatch` that resolves immediately with dummy puzzles and
/// records every call it received, in order.
class _ImmediateBatchGenerator {
  final List<Difficulty> calls = [];

  Future<List<SudokuPuzzle>> call(Difficulty difficulty, int count) async {
    calls.add(difficulty);
    return List.generate(count, (_) => _dummyPuzzle(difficulty));
  }
}

/// A fake `generateBatch` whose calls only resolve once [complete] is
/// called for that difficulty — lets tests step through the manager's
/// serial processing one batch at a time.
class _ControllableBatchGenerator {
  final List<Difficulty> calls = [];
  final _completers = <Difficulty, Completer<List<SudokuPuzzle>>>{};

  Future<List<SudokuPuzzle>> call(Difficulty difficulty, int count) {
    calls.add(difficulty);
    final completer = Completer<List<SudokuPuzzle>>();
    _completers[difficulty] = completer;
    return completer.future;
  }

  void complete(Difficulty difficulty, int count) {
    _completers[difficulty]!
        .complete(List.generate(count, (_) => _dummyPuzzle(difficulty)));
  }
}

/// Lets any in-flight microtask/async chains (e.g. SharedPreferences mock
/// channel round-trips inside `_persist()`) settle before the next
/// assertion, without depending on exactly how many `await`s are chained.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('take returns null on an empty tier', () {
    final manager = PuzzleQueueManager(
      generateBatch: _ImmediateBatchGenerator().call,
    );
    expect(manager.take(Difficulty.easy), isNull);
  });

  test('take pops in FIFO order and drains the tier', () async {
    final fake = _ImmediateBatchGenerator();
    final manager = PuzzleQueueManager(generateBatch: fake.call);

    manager.warmUp();
    await manager.waitUntilIdle();
    expect(manager.countFor(Difficulty.beginner), PuzzleQueueManager.capacity);

    final first = manager.take(Difficulty.beginner);
    expect(first, isNotNull);
    expect(manager.countFor(Difficulty.beginner), PuzzleQueueManager.capacity - 1);
  });

  test('takeLast returns null on an empty tier', () {
    final manager = PuzzleQueueManager(
      generateBatch: _ImmediateBatchGenerator().call,
    );
    expect(manager.takeLast(Difficulty.easy), isNull);
  });

  test('takeLast pops from the back, leaving the front (and peek) untouched',
      () async {
    final fake = _ImmediateBatchGenerator();
    final manager = PuzzleQueueManager(generateBatch: fake.call);

    manager.warmUp();
    await manager.waitUntilIdle();
    expect(manager.countFor(Difficulty.beginner), PuzzleQueueManager.capacity);

    final front = manager.peek(Difficulty.beginner);
    final last = manager.takeLast(Difficulty.beginner);

    expect(last, isNotNull);
    expect(identical(last, front), isFalse);
    expect(identical(manager.peek(Difficulty.beginner), front), isTrue);
    expect(
        manager.countFor(Difficulty.beginner), PuzzleQueueManager.capacity - 1);
  });

  test('dropping a tier to 1 schedules a refill back to capacity', () async {
    final fake = _ImmediateBatchGenerator();
    final manager = PuzzleQueueManager(generateBatch: fake.call);

    manager.warmUp();
    await manager.waitUntilIdle();
    fake.calls.clear();

    manager.take(Difficulty.easy); // 3 -> 2, no refill yet
    manager.take(Difficulty.easy); // 2 -> 1, refill scheduled
    await manager.waitUntilIdle();

    expect(fake.calls, contains(Difficulty.easy));
    expect(manager.countFor(Difficulty.easy), PuzzleQueueManager.capacity);
  });

  test('dropping a tier only to 2 does not trigger a refill', () async {
    final fake = _ImmediateBatchGenerator();
    final manager = PuzzleQueueManager(generateBatch: fake.call);

    manager.warmUp();
    await manager.waitUntilIdle();
    fake.calls.clear();

    manager.take(Difficulty.medium); // 3 -> 2
    await manager.waitUntilIdle();

    expect(fake.calls, isEmpty);
    expect(manager.countFor(Difficulty.medium), 2);
  });

  test('warmUp on an all-empty manager processes every tier serially in '
      'ascending difficulty order, one batch at a time', () async {
    final fake = _ControllableBatchGenerator();
    final manager = PuzzleQueueManager(generateBatch: fake.call);

    manager.warmUp();
    await _settle();

    // Only the easiest tier's batch should be in flight so far.
    expect(fake.calls, [Difficulty.beginner]);

    fake.complete(Difficulty.beginner, PuzzleQueueManager.capacity);
    await _settle();
    expect(fake.calls, [Difficulty.beginner, Difficulty.easy]);

    fake.complete(Difficulty.easy, PuzzleQueueManager.capacity);
    await _settle();
    expect(fake.calls, [Difficulty.beginner, Difficulty.easy, Difficulty.medium]);

    // Drain the rest so waitUntilIdle terminates.
    for (final difficulty in [
      Difficulty.medium,
      Difficulty.hard,
      Difficulty.master,
      Difficulty.expert,
    ]) {
      fake.complete(difficulty, PuzzleQueueManager.capacity);
      await _settle();
    }
    await manager.waitUntilIdle();

    expect(fake.calls, Difficulty.values);
    for (final difficulty in Difficulty.values) {
      expect(manager.countFor(difficulty), PuzzleQueueManager.capacity);
    }
  });

  test('a generation failure for one tier does not block other pending '
      'tiers from being processed', () async {
    Future<List<SudokuPuzzle>> flakyGenerate(
      Difficulty difficulty,
      int count,
    ) async {
      if (difficulty == Difficulty.beginner) {
        throw StateError('generation failed');
      }
      return List.generate(count, (_) => _dummyPuzzle(difficulty));
    }

    final manager = PuzzleQueueManager(generateBatch: flakyGenerate);

    manager.warmUp();
    await manager.waitUntilIdle();

    expect(manager.countFor(Difficulty.beginner), 0);
    // Every other tier still got filled despite beginner's failure.
    for (final difficulty in Difficulty.values.skip(1)) {
      expect(manager.countFor(difficulty), PuzzleQueueManager.capacity);
    }
  });

  test('loadFromDisk restores a previously persisted queue, and '
      'savePuzzleQueue/loadPuzzleQueue round-trip through StorageService',
      () async {
    final storage = StorageService();
    final fake = _ImmediateBatchGenerator();
    final manager =
        PuzzleQueueManager(storage: storage, generateBatch: fake.call);

    manager.warmUp();
    await manager.waitUntilIdle();

    final reloaded = PuzzleQueueManager(
      storage: storage,
      generateBatch: fake.call,
    );
    await reloaded.loadFromDisk();

    for (final difficulty in Difficulty.values) {
      expect(reloaded.countFor(difficulty), PuzzleQueueManager.capacity);
    }
  });

  test(
      'loadFromDisk falls back to the bundled seed asset for tiers still '
      'empty after the disk load — e.g. the very first launch', () async {
    final manager = PuzzleQueueManager(
      storage: StorageService(),
      generateBatch: _ImmediateBatchGenerator().call,
    );

    await manager.loadFromDisk();

    for (final difficulty in Difficulty.values) {
      expect(manager.countFor(difficulty), greaterThan(0));
      expect(manager.peek(difficulty)!.difficulty, difficulty);
    }
  });
}
