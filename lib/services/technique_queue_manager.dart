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

/// Bundled starter boards (see tool/generate_technique_boards.dart) used to
/// fill any technique still empty after [TechniqueQueueManager.take]'s lazy
/// load — most notably the very first use, before any background mining has
/// run.
const _assetPath = 'assets/data/technique_boards.json';

/// Keeps up to [capacity] boards queued per technique for the "이 기법이
/// 나오는 보드 풀기" feature (today the debug 힌트 데모; planned as a
/// premium perk): every queued board makes its technique's own finder fire
/// with a solution-sound conclusion. [take] pops a RANDOM queued board so
/// repeat visits see different puzzles, then refills in the background on
/// an [Isolate] via [mineTechniqueBoard] (mining is random-search, so rare
/// techniques can take a while — the queue is the buffer). Persisted via
/// [StorageService] so mined boards survive restarts.
///
/// BUG+1 is excluded ([supportedTechniques]): its precondition never
/// arises on fresh candidates, so it can't be mined — how to demo it is an
/// open question.
class TechniqueQueueManager extends ChangeNotifier {
  TechniqueQueueManager({
    StorageService? storage,
    Future<SudokuPuzzle?> Function(HintTechnique technique)? mineBoard,
    Random? random,
  })  : _storage = storage ?? StorageService(),
        _mineBoard = mineBoard ?? _isolateMineBoard,
        _random = random ?? Random();

  static final instance = TechniqueQueueManager();

  static const capacity = 3;

  static final supportedTechniques = List<HintTechnique>.unmodifiable([
    for (final t in hintTechniqueOrder)
      if (t != HintTechnique.bugPlusOne) t,
  ]);

  final StorageService _storage;
  final Future<SudokuPuzzle?> Function(HintTechnique) _mineBoard;
  final Random _random;

  final Map<HintTechnique, List<SudokuPuzzle>> _queues = {
    for (final t in supportedTechniques) t: <SudokuPuzzle>[],
  };

  /// The bundled boards, kept around as a bottomless fallback so [take]
  /// never comes back empty even if mining hasn't caught up.
  final Map<HintTechnique, List<SudokuPuzzle>> _bundled = {};

  final Set<HintTechnique> _pending = {};
  Future<void>? _activeProcessing;
  Future<void>? _loading;

  int countFor(HintTechnique technique) => _queues[technique]?.length ?? 0;

  /// Pops a random queued board for [technique] (falling back to a random
  /// bundled one on a miss) and schedules a background refill. Await-able
  /// but fast: the only awaited work is the one-time lazy load.
  Future<SudokuPuzzle?> take(HintTechnique technique) async {
    if (!_queues.containsKey(technique)) return null; // unsupported (BUG+1)
    await (_loading ??= _load());
    // Read AFTER the load — _load replaces the per-technique lists, so a
    // reference captured earlier would still point at the empty originals.
    final queue = _queues[technique]!;
    SudokuPuzzle? puzzle;
    if (queue.isNotEmpty) {
      puzzle = queue.removeAt(_random.nextInt(queue.length));
      unawaited(_persist());
    } else {
      final bundled = _bundled[technique];
      if (bundled != null && bundled.isNotEmpty) {
        puzzle = bundled[_random.nextInt(bundled.length)];
      }
    }
    _scheduleRefillIfNeeded(technique);
    notifyListeners();
    return puzzle;
  }

  Future<void> _load() async {
    try {
      final loaded = await _storage.loadTechniqueQueue();
      for (final entry in loaded.entries) {
        if (_queues.containsKey(entry.key)) {
          _queues[entry.key] = entry.value;
        }
      }
    } catch (_) {
      // Corrupt persisted state — start over from the bundle.
    }
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final technique in supportedTechniques) {
        final seeded = json[technique.name] as List<dynamic>?;
        if (seeded == null) continue;
        _bundled[technique] = seeded
            .map((p) => SudokuPuzzle.fromJson(p as Map<String, dynamic>))
            .toList();
        if (_queues[technique]!.isEmpty) {
          _queues[technique] = [..._bundled[technique]!];
        }
      }
    } catch (_) {
      // Asset missing/corrupt — take() falls back to mining-only refills.
    }
  }

  void _scheduleRefillIfNeeded(HintTechnique technique) {
    if ((_queues[technique]?.length ?? capacity) >= capacity) return;
    if (!_pending.add(technique)) return;
    _activeProcessing ??=
        _processPending().whenComplete(() => _activeProcessing = null);
  }

  Future<void> _processPending() async {
    while (_pending.isNotEmpty) {
      final next = supportedTechniques.firstWhere(_pending.contains);
      _pending.remove(next);
      try {
        // One board per pass — mining is unbounded random search, so keep
        // slices small and re-queue until the technique is back at capacity.
        final mined = await _mineBoard(next);
        if (mined == null) continue; // budget ran out; retried on next take
        _queues[next]!.add(mined);
        await _persist();
        notifyListeners();
        if (_queues[next]!.length < capacity) _pending.add(next);
      } catch (_) {
        // A mining failure for one technique must not stop the others.
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

Future<SudokuPuzzle?> _isolateMineBoard(HintTechnique technique) async {
  final json = await Isolate.run(() => _mineBoardJson(technique));
  return json == null ? null : SudokuPuzzle.fromJson(json);
}

// Top-level so the closure Isolate.run sends across the isolate boundary
// only captures the enum; returns JSON since that's the proven-sendable
// shape (same pattern as PuzzleQueueManager).
Map<String, dynamic>? _mineBoardJson(HintTechnique technique) =>
    mineTechniqueBoard(technique)?.toJson();
