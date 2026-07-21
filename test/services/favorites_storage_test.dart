import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/storage_service.dart';

/// A cheap puzzle with distinct givens per [seed] — favorites identity is the
/// givens grid, so this is enough to exercise dedup/cap without the generator.
SudokuPuzzle _fakePuzzle(int seed) {
  final grid = List.generate(9, (_) => List.filled(9, 0));
  grid[0][0] = (seed % 9) + 1;
  grid[0][1] = (seed ~/ 9) % 9;
  return SudokuPuzzle(
    puzzle: SudokuGrid(grid),
    solution: SudokuGrid.empty(),
    fixedMask: List.generate(9, (_) => List.filled(9, false)),
    difficulty: Difficulty.easy,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saveFavorite adds; isFavorite and loadFavorites reflect it', () async {
    final storage = StorageService();
    final p = _fakePuzzle(1);
    expect(await storage.isFavorite(p), isFalse);
    expect(await storage.saveFavorite(p), isTrue);
    expect(await storage.isFavorite(p), isTrue);
    expect((await storage.loadFavorites()).length, 1);
  });

  test('saving the same puzzle twice does not duplicate', () async {
    final storage = StorageService();
    final p = _fakePuzzle(1);
    await storage.saveFavorite(p);
    expect(await storage.saveFavorite(p), isTrue);
    expect((await storage.loadFavorites()).length, 1);
  });

  test('removeFavorite removes it', () async {
    final storage = StorageService();
    final p = _fakePuzzle(1);
    await storage.saveFavorite(p);
    await storage.removeFavorite(p);
    expect(await storage.isFavorite(p), isFalse);
    expect(await storage.loadFavorites(), isEmpty);
  });

  test('cap blocks a new save past maxFavorites but keeps existing', () async {
    final storage = StorageService();
    for (var i = 0; i < StorageService.maxFavorites; i++) {
      expect(await storage.saveFavorite(_fakePuzzle(i)), isTrue);
    }
    final extra = _fakePuzzle(StorageService.maxFavorites);
    expect(await storage.saveFavorite(extra), isFalse);
    expect(await storage.isFavorite(extra), isFalse);
    expect(
        (await storage.loadFavorites()).length, StorageService.maxFavorites);
    // An already-saved puzzle is still a no-op success even when full.
    expect(await storage.saveFavorite(_fakePuzzle(0)), isTrue);
  });
}
