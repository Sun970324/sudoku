import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/hint_engine.dart';

// A genuine Multi-Coloring position (found by searching generated puzzles: a
// board reduced by singles alone to a stall, where two separate conjugate-pair
// color clusters for digit 5 exist and Simple Coloring does NOT apply — so the
// solver genuinely reaches Multi-Coloring). Singles-only reduction places no
// eliminations, so freshCandidates reproduces the exact stall state.
const _board = [
  [8, 0, 4, 7, 0, 1, 6, 3, 9],
  [0, 3, 0, 6, 0, 0, 0, 1, 0],
  [1, 0, 6, 3, 0, 9, 0, 0, 0],
  [6, 4, 5, 9, 0, 0, 1, 7, 2],
  [7, 0, 0, 2, 0, 0, 3, 8, 5],
  [3, 8, 2, 5, 1, 7, 9, 6, 4],
  [0, 0, 8, 1, 0, 0, 0, 4, 3],
  [4, 6, 3, 8, 9, 0, 7, 0, 1],
  [2, 0, 0, 4, 0, 0, 8, 9, 6],
];

void main() {
  test('Multi-Coloring eliminates a digit trapped by two color clusters, '
      'where Simple Coloring does not apply', () {
    final engine = HintEngine();
    // Simple Coloring must miss this board — otherwise it would preempt.
    expect(engine.findSimpleColoring(_board), isNull);

    final hint = engine.findMultiColoring(_board);
    expect(hint, isNotNull);
    expect(hint!.technique, HintTechnique.multiColoring);
    expect(hint.type, HintType.eliminate);
    expect(hint.eliminations, contains(const HintElimination(6, 4, 5)));
    // Two distinct color clusters underpin the deduction.
    expect(hint.colorGroupA, isNotEmpty);
    expect(hint.colorGroupB, isNotEmpty);
    expect(hint.colorGroupA.intersection(hint.colorGroupB), isEmpty);
  });
}
