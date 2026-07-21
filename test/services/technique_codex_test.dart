import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('empty store loads an empty codex; empty record is a no-op', () async {
    final storage = StorageService();
    expect(await storage.loadTechniqueCodex(), isEmpty);
    await storage.recordTechniqueCounts({});
    expect(await storage.loadTechniqueCodex(), isEmpty);
  });

  test('recording accumulates uses and counts puzzles per record call',
      () async {
    final storage = StorageService();
    await storage.recordTechniqueCounts({
      HintTechnique.fullHouse: 3,
      HintTechnique.nakedSingle: 7,
    });
    await storage.recordTechniqueCounts({
      HintTechnique.fullHouse: 2,
      HintTechnique.xWing: 1,
    });

    final codex = await storage.loadTechniqueCodex();
    expect(codex[HintTechnique.fullHouse], (uses: 5, puzzles: 2));
    expect(codex[HintTechnique.nakedSingle], (uses: 7, puzzles: 1));
    expect(codex[HintTechnique.xWing], (uses: 1, puzzles: 1));
    expect(codex.length, 3);
  });

  test('unknown stored technique names are skipped, not fatal', () async {
    SharedPreferences.setMockInitialValues({
      'technique_codex':
          '{"fullHouse":{"u":4,"p":2},"removedTechnique":{"u":1,"p":1}}',
    });
    final codex = await StorageService().loadTechniqueCodex();
    expect(codex.length, 1);
    expect(codex[HintTechnique.fullHouse], (uses: 4, puzzles: 2));
  });
}
