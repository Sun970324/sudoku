import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/sudoku_solver.dart';
import 'package:sudoku/services/technique_queue_manager.dart';

SudokuPuzzle _fakePuzzle() {
  final solved =
      SudokuSolver().solve(List.generate(9, (_) => List.filled(9, 0)))!;
  return SudokuPuzzle(
    puzzle: SudokuGrid(solved),
    solution: SudokuGrid(solved),
    fixedMask: List.generate(9, (_) => List.filled(9, true)),
    difficulty: Difficulty.expert,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('take() serves a bundled board immediately and refills back to '
      'capacity in the background', () async {
    final mined = <HintTechnique>[];
    final manager = TechniqueQueueManager(mineBoard: (t) async {
      mined.add(t);
      return _fakePuzzle();
    });

    final puzzle = await manager.take(HintTechnique.xWing);

    expect(puzzle, isNotNull);
    await manager.waitUntilIdle();
    expect(manager.countFor(HintTechnique.xWing),
        TechniqueQueueManager.capacity);
    expect(mined, isNotEmpty);
    expect(mined.every((t) => t == HintTechnique.xWing), isTrue);
  });

  test('an empty queue falls back to a bundled board instead of returning '
      'null, even when mining keeps failing', () async {
    final manager = TechniqueQueueManager(mineBoard: (_) async => null);

    // Drain the seeded queue, then keep taking: the bundle backstops.
    for (var i = 0; i < TechniqueQueueManager.capacity + 2; i++) {
      final puzzle = await manager.take(HintTechnique.skyscraper);
      expect(puzzle, isNotNull, reason: 'take #${i + 1} came back empty');
      await manager.waitUntilIdle();
    }
    expect(manager.countFor(HintTechnique.skyscraper), 0);
  });

  test('mined boards persist across manager instances', () async {
    final first = TechniqueQueueManager(mineBoard: (_) async => _fakePuzzle());
    await first.take(HintTechnique.xyWing);
    await first.waitUntilIdle();

    // A fresh manager (same mock prefs store) must see the persisted queue.
    // (Its own take() still schedules a refill for the taken technique —
    // that's fine; the assertion is about the untouched xyWing queue.)
    final second = TechniqueQueueManager(mineBoard: (_) async => null);
    final puzzle = await second.take(HintTechnique.turbotFish);
    expect(puzzle, isNotNull);
    await second.waitUntilIdle();
    expect(second.countFor(HintTechnique.xyWing),
        TechniqueQueueManager.capacity);
  });

  test('BUG+1 is unsupported: take() returns null and supportedTechniques '
      'excludes it', () async {
    expect(TechniqueQueueManager.supportedTechniques,
        isNot(contains(HintTechnique.bugPlusOne)));
    final manager = TechniqueQueueManager(mineBoard: (_) async => null);
    expect(await manager.take(HintTechnique.bugPlusOne), isNull);
  });
}
