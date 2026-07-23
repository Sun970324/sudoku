import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/debug/technique_demos.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/hint_engine.dart';

void main() {
  test('every technique has a demo board on which its own finder fires with '
      'a sound conclusion — guards the settings "힌트 데모" entries against '
      'engine changes', () {
    final engine = HintEngine();

    for (final technique in HintTechnique.values) {
      expect(techniqueDemoAvailable(technique), isTrue,
          reason: '${technique.name} has no demo board');
      final puzzle = techniqueDemoPuzzle(technique)!;
      final board = puzzle.puzzle.toJson();
      // Mirror the demo flow: BUG+1 loads its pre-narrowed notes, everything
      // else runs on fresh candidates.
      final notes = techniqueDemoNotes(technique);

      final hint = engine.findTechnique(technique, board, notes);

      expect(hint, isNotNull,
          reason: '${technique.name} demo board went silent');
      expect(hint!.technique, technique);

      if (hint.type == HintType.reveal) {
        expect(puzzle.solution.get(hint.row!, hint.col!), hint.value,
            reason: '${technique.name} demo revealed a wrong value');
      }
      for (final e in hint.eliminations) {
        expect(puzzle.solution.get(e.row, e.col), isNot(e.digit),
            reason: '${technique.name} demo eliminated a solution digit');
      }
    }
  });
}
