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
}
