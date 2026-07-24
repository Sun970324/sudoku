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

  test('take() live-mines a board when nothing is queued, and refills back '
      'to capacity in the background', () async {
    final mined = <TechniqueCategory>[];
    final manager = TechniqueQueueManager(mineBoard: (category) async {
      mined.add(category);
      return _fakePuzzle();
    });

    final puzzle = await manager.take(TechniqueCategory.basicFish);

    expect(puzzle, isNotNull);
    await manager.waitUntilIdle();
    expect(manager.countFor(TechniqueCategory.basicFish),
        TechniqueQueueManager.capacity);
    expect(mined, isNotEmpty);
  });

  test('take() refills the queue to capacity and persists it', () async {
    final manager =
        TechniqueQueueManager(mineBoard: (_) async => _fakePuzzle());
    await manager.take(TechniqueCategory.wings);
    await manager.waitUntilIdle();
    expect(manager.countFor(TechniqueCategory.wings),
        TechniqueQueueManager.capacity);

    // A fresh manager (same mock prefs store) loads the persisted queue
    // without mining anything.
    final reloaded = TechniqueQueueManager(
        mineBoard: (_) async => fail('should not mine on a warm queue'));
    final puzzle = await reloaded.take(TechniqueCategory.wings);
    expect(puzzle, isNotNull);
  });

  test('warmUp pre-mines exactly one board for every empty category (not to '
      'capacity)', () async {
    final mined = <TechniqueCategory>[];
    final manager = TechniqueQueueManager(mineBoard: (category) async {
      mined.add(category);
      return _fakePuzzle();
    });

    await manager.warmUp();

    for (final category in TechniqueQueueManager.categories) {
      expect(manager.countFor(category), 1,
          reason: '${category.name} should be warmed to a single board');
    }
    // One mine per category — warm-up fills to one, never to capacity.
    expect(mined.length, TechniqueQueueManager.categories.length);
  });
}
