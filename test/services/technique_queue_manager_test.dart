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
    final mined = <Set<HintTechnique>>[];
    final manager = TechniqueQueueManager(mineBoard: (techs) async {
      mined.add(techs);
      return _fakePuzzle();
    });

    final puzzle = await manager.take('xWing');

    expect(puzzle, isNotNull);
    await manager.waitUntilIdle();
    expect(manager.countFor('xWing'), TechniqueQueueManager.capacity);
    expect(mined, isNotEmpty);
  });

  test('take() refills the queue to capacity and persists it', () async {
    final manager =
        TechniqueQueueManager(mineBoard: (_) async => _fakePuzzle());
    await manager.take('xyWing');
    await manager.waitUntilIdle();
    expect(manager.countFor('xyWing'), TechniqueQueueManager.capacity);

    // A fresh manager (same mock prefs store) loads the persisted queue
    // without mining anything.
    final reloaded = TechniqueQueueManager(
        mineBoard: (_) async => fail('should not mine on a warm queue'));
    final puzzle = await reloaded.take('xyWing');
    expect(puzzle, isNotNull);
  });

  test('an unknown item id returns null', () async {
    final manager = TechniqueQueueManager(mineBoard: (_) async => null);
    expect(await manager.take('bugPlusOne'), isNull);
    expect(await manager.take('nonsense'), isNull);
  });

  test('the practice list excludes BUG+1', () {
    final ids = TechniqueQueueManager.items.map((i) => i.id).toSet();
    expect(ids, isNot(contains('bugPlusOne')));
    for (final item in TechniqueQueueManager.items) {
      expect(item.techniques, isNot(contains(HintTechnique.bugPlusOne)));
    }
  });
}
