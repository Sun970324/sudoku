import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';

Hint _eliminate(List<HintElimination> eliminations) => Hint(
      technique: HintTechnique.nakedPair,
      type: HintType.eliminate,
      explanation: '',
      primaryCells: const {},
      eliminations: eliminations,
    );

void main() {
  group('Hint.actionSummary', () {
    test('a reveal reads as an assignment in r_c_ notation', () {
      const hint = Hint(
        technique: HintTechnique.nakedSingle,
        type: HintType.reveal,
        explanation: '',
        primaryCells: {},
        row: 3,
        col: 6,
        value: 5,
      );

      expect(hint.actionSummary, 'r4c7 = 5');
    });

    test('cells sharing a row collapse into one column run', () {
      final hint = _eliminate(const [
        HintElimination(3, 1, 7),
        HintElimination(3, 4, 7),
        HintElimination(3, 7, 7),
      ]);

      expect(hint.actionSummary, 'r4c258<>7');
    });

    test('cells sharing a column collapse into one row run', () {
      final hint = _eliminate(const [
        HintElimination(1, 3, 7),
        HintElimination(4, 3, 7),
        HintElimination(7, 3, 7),
      ]);

      expect(hint.actionSummary, 'r258c4<>7');
    });

    test('cells sharing neither row nor column group per row', () {
      final hint = _eliminate(const [
        HintElimination(0, 0, 4),
        HintElimination(0, 2, 4),
        HintElimination(5, 8, 4),
      ]);

      expect(hint.actionSummary, 'r1c13,r6c9<>4');
    });

    test('digits are listed in ascending order, each with its own cells', () {
      final hint = _eliminate(const [
        HintElimination(2, 2, 9),
        HintElimination(0, 0, 3),
      ]);

      expect(hint.actionSummary, 'r1c1<>3, r3c3<>9');
    });

    test('a single elimination needs no compaction', () {
      final hint = _eliminate(const [HintElimination(8, 8, 1)]);

      expect(hint.actionSummary, 'r9c9<>1');
    });

    test('eliminations are sorted by row then column, not input order', () {
      final hint = _eliminate(const [
        HintElimination(3, 7, 7),
        HintElimination(3, 1, 7),
      ]);

      expect(hint.actionSummary, 'r4c28<>7');
    });
  });

  group('Hint.withExplanation', () {
    test('carries mainInfo across, so the middle reveal stage survives the '
        'note-repair rewrite', () {
      const hint = Hint(
        technique: HintTechnique.hiddenSingle,
        type: HintType.reveal,
        explanation: 'original',
        primaryCells: {},
        mainInfo: 'Row 4',
        row: 0,
        col: 0,
        value: 1,
      );

      final rewritten = hint.withExplanation('repaired');

      expect(rewritten.explanation, 'repaired');
      expect(rewritten.mainInfo, 'Row 4');
    });
  });
}
