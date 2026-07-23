import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/hint.dart';
import '../models/sudoku_puzzle.dart';
import 'generation/technique_board_miner.dart';
import 'storage_service.dart';

/// Optional bundled starter boards (see tool/generate_technique_boards.dart)
/// used to fill any item still empty after a lazy load. Absent until the
/// bundle is mined for a release — until then [take] falls back to live
/// mining.
const _assetPath = 'assets/data/technique_boards.json';

/// Keeps up to [capacity] boards queued per [PracticeItem] for the
/// technique-practice feature (today the debug 힌트 데모; planned as a
/// premium perk): every queued board shows its item's technique in a
/// ceiling-capped solve (see [boardShowsItem]). [take] pops a RANDOM queued
/// board so repeat visits differ, then refills in the background on an
/// [Isolate] via [mineTechniqueBoard]. Persisted via [StorageService] so
/// mined boards survive restarts.
class TechniqueQueueManager extends ChangeNotifier {
  TechniqueQueueManager({
    StorageService? storage,
    Future<SudokuPuzzle?> Function(Set<HintTechnique> techniques)? mineBoard,
    Random? random,
  })  : _storage = storage ?? StorageService(),
        _mineBoard = mineBoard ?? _isolateMineBoard,
        _random = random ?? Random();

  static final instance = TechniqueQueueManager();

  static const capacity = 3;

  /// The practice list the UI iterates.
  static List<PracticeItem> get items => practiceItems;

  final StorageService _storage;
  final Future<SudokuPuzzle?> Function(Set<HintTechnique>) _mineBoard;
  final Random _random;

  final Map<String, List<SudokuPuzzle>> _queues = {
    for (final item in practiceItems) item.id: <SudokuPuzzle>[],
  };
  final Map<String, List<SudokuPuzzle>> _bundled = {};
  final Set<String> _pending = {};
  Future<void>? _activeProcessing;
  Future<void>? _loading;

  int countFor(String itemId) => _queues[itemId]?.length ?? 0;

  static PracticeItem? _itemById(String id) {
    for (final item in practiceItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Pops a random queued board for [itemId] (falling back to a random
  /// bundled one, then to live mining) and schedules a background refill.
  Future<SudokuPuzzle?> take(String itemId) async {
    final item = _itemById(itemId);
    if (item == null) return null;
    await (_loading ??= _load());
    final queue = _queues[itemId]!;
    SudokuPuzzle? puzzle;
    if (queue.isNotEmpty) {
      puzzle = queue.removeAt(_random.nextInt(queue.length));
      unawaited(_persist());
    } else {
      final bundled = _bundled[itemId];
      if (bundled != null && bundled.isNotEmpty) {
        puzzle = bundled[_random.nextInt(bundled.length)];
      } else {
        // No bundle yet — mine one on the spot (debug/first-run path).
        puzzle = await _mineBoard(item.techniques);
      }
    }
    _scheduleRefillIfNeeded(itemId);
    notifyListeners();
    return puzzle;
  }

  Future<void> _load() async {
    try {
      final loaded = await _storage.loadTechniqueQueue();
      for (final entry in loaded.entries) {
        if (_queues.containsKey(entry.key)) _queues[entry.key] = entry.value;
      }
    } catch (_) {
      // Corrupt persisted state — start over from the (optional) bundle.
    }
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in practiceItems) {
        final seeded = json[item.id] as List<dynamic>?;
        if (seeded == null) continue;
        _bundled[item.id] = seeded
            .map((p) => SudokuPuzzle.fromJson(p as Map<String, dynamic>))
            .toList();
        if (_queues[item.id]!.isEmpty) {
          _queues[item.id] = [..._bundled[item.id]!];
        }
      }
    } catch (_) {
      // No bundle asset yet — take() live-mines instead.
    }
  }

  void _scheduleRefillIfNeeded(String itemId) {
    if ((_queues[itemId]?.length ?? capacity) >= capacity) return;
    if (!_pending.add(itemId)) return;
    _activeProcessing ??=
        _processPending().whenComplete(() => _activeProcessing = null);
  }

  Future<void> _processPending() async {
    while (_pending.isNotEmpty) {
      final itemId = _pending.first;
      _pending.remove(itemId);
      final item = _itemById(itemId);
      if (item == null) continue;
      try {
        final mined = await _mineBoard(item.techniques);
        if (mined == null) continue; // budget ran out; retried on next take
        _queues[itemId]!.add(mined);
        await _persist();
        notifyListeners();
        if (_queues[itemId]!.length < capacity) _pending.add(itemId);
      } catch (_) {
        // A mining failure for one item must not stop the others.
      }
    }
  }

  Future<void> _persist() => _storage.saveTechniqueQueue(_queues);

  /// Test-only: lets tests await background work instead of racing it.
  @visibleForTesting
  Future<void> waitUntilIdle() async {
    while (_activeProcessing != null) {
      await _activeProcessing;
    }
  }
}

Future<SudokuPuzzle?> _isolateMineBoard(Set<HintTechnique> techniques) async {
  final json = await Isolate.run(() => _mineBoardJson(techniques));
  return json == null ? null : SudokuPuzzle.fromJson(json);
}

Map<String, dynamic>? _mineBoardJson(Set<HintTechnique> techniques) =>
    mineTechniqueBoard(techniques)?.toJson();
