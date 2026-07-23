// One-off build-time generator for assets/data/technique_boards.json — the
// per-practice-item bundled boards behind the "힌트 데모" queue (see
// TechniqueQueueManager). Every board SHOWS its item's technique per
// [boardShowsItem]: solving within that item's difficulty ceiling actually
// uses it. Rare/heavy items (AIC, Sue de Coq, Triple Firework) can take many
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
import 'package:sudoku/services/generation/technique_board_miner.dart';

const _perItem = 3;
const _rareExtra = {'tripleFirework': 5};
const _maxSeeds = 60000;

int _want(PracticeItem item) => _rareExtra[item.id] ?? _perItem;

final _log = File('/tmp/mine_progress.txt');
void _note(String line) =>
    _log.writeAsStringSync('$line\n', mode: FileMode.append);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _log.writeAsStringSync('');
  final rng = Random(7);
  final result = <String, dynamic>{};
  for (final item in practiceItems) {
    final boards = <Map<String, dynamic>>[];
    while (boards.length < _want(item)) {
      _note('mining ${item.id} ${boards.length + 1}/${_want(item)}...');
      final puzzle =
          mineTechniqueBoard(item.techniques, maxSeeds: _maxSeeds, random: rng);
      if (puzzle == null) {
        _note('BUDGET EXHAUSTED for ${item.id}');
        throw StateError('mining budget exhausted for ${item.id}');
      }
      boards.add(puzzle.toJson());
    }
    result[item.id] = boards;
  }
  final file = File('assets/data/technique_boards.json');
  await file.create(recursive: true);
  await file.writeAsString(jsonEncode(result));
  _note('WROTE ${file.path}');
}
