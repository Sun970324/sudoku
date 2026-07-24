// One-off build-time generator for assets/data/technique_boards.json — the
// per-category bundled boards behind the technique-practice queue (see
// TechniqueQueueManager). Every board is a genuine practice case for its
// category per [boardRequiresCategory]: solvable within the category ceiling
// and actually needing it. Rare/heavy categories (Chains, ALS) can take many
// seeds — run this offline (e.g. overnight) when preparing a release.
//
//   flutter test tool/generate_technique_boards.dart
//
// Live progress is appended to /tmp/mine_progress.txt (flutter test buffers
// stdout until the test ends, so tail that file to watch).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/technique_board_miner.dart';

const _perCategory = 3;
const _rareExtra = {'chainsAndLoops': 5, 'almostLockedSets': 5};
const _maxSeeds = 60000;

int _want(TechniqueCategory category) =>
    _rareExtra[category.name] ?? _perCategory;

final _log = File('/tmp/mine_progress.txt');
void _note(String line) =>
    _log.writeAsStringSync('$line\n', mode: FileMode.append);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _log.writeAsStringSync('');
  final rng = Random(7);
  final result = <String, dynamic>{};
  for (final category in TechniqueCategory.values) {
    final boards = <Map<String, dynamic>>[];
    while (boards.length < _want(category)) {
      _note('mining ${category.name} ${boards.length + 1}/${_want(category)}...');
      final puzzle =
          mineCategoryBoard(category, maxSeeds: _maxSeeds, random: rng);
      if (puzzle == null) {
        _note('BUDGET EXHAUSTED for ${category.name}');
        throw StateError('mining budget exhausted for ${category.name}');
      }
      boards.add(puzzle.toJson());
    }
    result[category.name] = boards;
  }
  final file = File('assets/data/technique_boards.json');
  await file.create(recursive: true);
  await file.writeAsString(jsonEncode(result));
  _note('WROTE ${file.path}');
}
