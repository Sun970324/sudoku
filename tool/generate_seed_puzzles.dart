// One-off build-time generator for assets/data/seed_puzzles.json — the
// puzzles bundled with the app so the very first launch (before any
// background generation has run) still has a few puzzles ready per
// difficulty instead of an empty queue. Not part of the app itself, and not
// picked up by a plain `flutter test` (lives outside test/). Run manually
// whenever the seed data needs regenerating:
//
//   flutter test tool/generate_seed_puzzles.dart
//
// (needs `flutter test`, not `dart run` — Difficulty/SudokuGenerator pull in
// package:flutter, which needs the dart:ui bindings flutter_test sets up.)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';

const _perDifficulty = 3;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final generator = SudokuGenerator();
  final result = <String, dynamic>{};
  for (final difficulty in Difficulty.values) {
    final puzzles = <Map<String, dynamic>>[];
    for (var i = 0; i < _perDifficulty; i++) {
      // ignore: avoid_print
      print('Generating ${difficulty.name} ${i + 1}/$_perDifficulty...');
      puzzles.add(generator.generate(difficulty).toJson());
    }
    result[difficulty.name] = puzzles;
  }
  final file = File('assets/data/seed_puzzles.json');
  await file.create(recursive: true);
  await file.writeAsString(jsonEncode(result));
  // ignore: avoid_print
  print('Wrote ${file.path}');
}
