// One-off build-time generator for assets/data/technique_boards.json — the
// per-technique bundled boards behind the "힌트 데모" queue (see
// TechniqueQueueManager). Every board makes its own technique's finder fire
// on fresh candidates with a solution-sound conclusion; Triple Firework
// gets extra copies since its live refill is the slowest (~0.6% of boards).
// BUG+1 is deliberately absent — unminable on fresh candidates.
//
//   flutter test tool/generate_technique_boards.dart
//
// (needs `flutter test`, not `dart run` — the models pull in
// package:flutter, which needs the dart:ui bindings flutter_test sets up.)
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/technique_board_miner.dart';

const _perTechnique = 3;
const _rareExtra = {HintTechnique.tripleFirework: 5};

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final result = <String, dynamic>{};
  final rng = Random(7);
  for (final technique in HintTechnique.values) {
    if (technique == HintTechnique.bugPlusOne) continue;
    final want = _rareExtra[technique] ?? _perTechnique;
    final boards = <Map<String, dynamic>>[];
    while (boards.length < want) {
      // ignore: avoid_print
      print('Mining ${technique.name} ${boards.length + 1}/$want...');
      final puzzle =
          mineTechniqueBoard(technique, maxBoards: 4000, random: rng);
      if (puzzle == null) {
        throw StateError('mining budget exhausted for ${technique.name}');
      }
      boards.add(puzzle.toJson());
    }
    result[technique.name] = boards;
  }
  final file = File('assets/data/technique_boards.json');
  await file.create(recursive: true);
  await file.writeAsString(jsonEncode(result));
  // ignore: avoid_print
  print('Wrote ${file.path}');
}
