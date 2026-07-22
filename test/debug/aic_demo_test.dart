import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/debug/aic_demo.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/hint_engine.dart';

void main() {
  test('the AIC demo board still yields an X-Chain / AIC hint — guards the '
      'debug "AIC hint demo" entry against engine changes', () {
    final puzzle = aicDemoPuzzle();
    final board = puzzle.puzzle.toJson();
    final engine = HintEngine();

    // The debug entry auto-fills notes (fresh candidates), then asks the
    // engine for an AIC (falling back to X-Chain) — mirror that here.
    final hint = engine.findAic(board) ?? engine.findXChain(board);

    expect(hint, isNotNull);
    expect(hint!.technique,
        anyOf(HintTechnique.aic, HintTechnique.xChain));
    expect(hint.eliminations, isNotEmpty);
    expect(hint.chainLinks, isNotEmpty);

    // Sound: no eliminated candidate is the cell's real answer.
    for (final e in hint.eliminations) {
      expect(puzzle.solution.get(e.row, e.col), isNot(e.digit));
    }
  });

  test('the grouped demo board yields a Grouped X-Chain through the debug '
      'fallback — no plain chain may preempt it', () {
    final puzzle = groupedChainDemoPuzzle();
    final board = puzzle.puzzle.toJson();
    final engine = HintEngine();

    // The bug icon tries the plain finders first; this board was mined so
    // they stay silent and the grouped finder is what the user sees.
    expect(engine.findAic(board), isNull);
    expect(engine.findXChain(board), isNull);

    final hint = engine.findGroupedXChain(board);

    expect(hint, isNotNull);
    expect(hint!.technique, HintTechnique.groupedXChain);
    expect(hint.eliminations, isNotEmpty);
    expect(
        hint.chainLinks
            .any((l) => l.from.cells.length > 1 || l.to.cells.length > 1),
        isTrue,
        reason: 'the demo must actually show a multi-cell group node');

    for (final e in hint.eliminations) {
      expect(puzzle.solution.get(e.row, e.col), isNot(e.digit));
    }
  });

  test('every ALS-family demo board still makes its own technique fire, '
      'soundly — guards the settings "ALS 기법 데모" entries', () {
    final engine = HintEngine();
    final finders = <HintTechnique,
        Hint? Function(List<List<int>> board)>{
      HintTechnique.wxyzWing: engine.findWXYZWing,
      HintTechnique.alsXZ: engine.findAlsXZ,
      HintTechnique.sueDeCoq: engine.findSueDeCoq,
      HintTechnique.tripleFirework: engine.findTripleFirework,
      HintTechnique.alsAic: engine.findAlsAic,
    };

    for (final entry in finders.entries) {
      final puzzle = alsDemoPuzzle(entry.key);
      final hint = entry.value(puzzle.puzzle.toJson());

      expect(hint, isNotNull, reason: '${entry.key} demo board went silent');
      expect(hint!.technique, entry.key);
      expect(hint.eliminations, isNotEmpty);
      for (final e in hint.eliminations) {
        expect(puzzle.solution.get(e.row, e.col), isNot(e.digit),
            reason: '${entry.key} demo eliminated a solution digit');
      }
    }
  });
}
