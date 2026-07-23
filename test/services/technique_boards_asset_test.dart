import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/hint_engine.dart';
import 'package:sudoku/services/technique_queue_manager.dart';

void main() {
  test('every bundled technique board still makes its own technique fire, '
      'soundly — guards assets/data/technique_boards.json against engine '
      'changes (regenerate via tool/generate_technique_boards.dart)', () {
    final engine = HintEngine();
    final json = jsonDecode(
            File('assets/data/technique_boards.json').readAsStringSync())
        as Map<String, dynamic>;

    expect(json.keys.toSet(),
        TechniqueQueueManager.supportedTechniques.map((t) => t.name).toSet());

    for (final technique in TechniqueQueueManager.supportedTechniques) {
      final boards = json[technique.name] as List<dynamic>;
      expect(boards.length, greaterThanOrEqualTo(3),
          reason: '${technique.name} bundle is thin');

      for (final entry in boards) {
        final puzzle = SudokuPuzzle.fromJson(entry as Map<String, dynamic>);
        final hint =
            engine.findTechnique(technique, puzzle.puzzle.toJson());

        expect(hint, isNotNull,
            reason: 'a ${technique.name} bundled board went silent');
        expect(hint!.technique, technique);
        if (hint.type == HintType.reveal) {
          expect(puzzle.solution.get(hint.row!, hint.col!), hint.value);
        }
        for (final e in hint.eliminations) {
          expect(puzzle.solution.get(e.row, e.col), isNot(e.digit),
              reason: '${technique.name} board eliminated a solution digit');
        }
      }
    }
  });
}
