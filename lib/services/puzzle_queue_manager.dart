import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/difficulty.dart';
import '../models/sudoku_puzzle.dart';
import 'generation/sudoku_generator.dart';
import 'storage_service.dart';

/// Bundled fallback puzzles (see tool/generate_seed_puzzles.dart) used to
/// fill any tier still empty after [PuzzleQueueManager.loadFromDisk] — most
/// notably the very first launch, before any background generation has had
/// a chance to run.
const _seedAssetPath = 'assets/data/seed_puzzles.json';

/// Keeps up to [capacity] pre-generated puzzles queued per [Difficulty]
/// tier, generated on a background [Isolate] so "새 게임" can return
/// instantly instead of blocking the UI thread on [SudokuGenerator.generate]
/// (which can take anywhere from ~1s to ~70s depending on tier). Refills a
/// tier back up to [capacity] once it drops to 1 or fewer, processing tiers
/// serially in ascending difficulty order to avoid running multiple heavy
/// generations at once. The queue is persisted via [StorageService] so it
/// survives app restarts.
///
/// Extends [ChangeNotifier] (notifying whenever a tier's count changes or a
/// refill starts/stops) so screens like the home difficulty picker can
/// disable "시작하기" and show a generating indicator while a tier is empty,
/// instead of silently falling back to a slow synchronous generation.
class PuzzleQueueManager extends ChangeNotifier {
  PuzzleQueueManager({
    StorageService? storage,
    Future<List<SudokuPuzzle>> Function(Difficulty difficulty, int count)?
        generateBatch,
  })  : _storage = storage ?? StorageService(),
        _generateBatch = generateBatch ?? _isolateGenerateBatch;

  static const capacity = 3;

  final StorageService _storage;
  final Future<List<SudokuPuzzle>> Function(Difficulty, int) _generateBatch;
  final Map<Difficulty, List<SudokuPuzzle>> _queues = {
    for (final d in Difficulty.values) d: <SudokuPuzzle>[],
  };
  final Set<Difficulty> _pending = {};
  Future<void>? _activeProcessing;

  int countFor(Difficulty difficulty) => _queues[difficulty]!.length;

  /// Non-mutating look at the next puzzle queued for [difficulty] — unlike
  /// [take], never removes from the queue or triggers a refill. Used by the
  /// home screen's live difficulty-picker preview.
  SudokuPuzzle? peek(Difficulty difficulty) {
    final queue = _queues[difficulty]!;
    return queue.isEmpty ? null : queue.first;
  }

  /// Loads any previously-persisted queue. Call and await before first use
  /// (e.g. in `main()`) so an immediate "새 게임" tap doesn't race the disk
  /// load and wrongly treat a non-empty persisted queue as empty. Any tier
  /// still empty afterwards (most notably on the very first launch, before
  /// a real queue has ever been persisted) is filled from the bundled seed
  /// asset instead, so "시작하기" isn't stuck disabled until the first
  /// background generation finishes.
  Future<void> loadFromDisk() async {
    final loaded = await _storage.loadPuzzleQueue();
    for (final entry in loaded.entries) {
      _queues[entry.key] = entry.value;
    }
    if (Difficulty.values.every((d) => _queues[d]!.isNotEmpty)) return;
    try {
      final raw = await rootBundle.loadString(_seedAssetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final difficulty in Difficulty.values) {
        if (_queues[difficulty]!.isNotEmpty) continue;
        final seeded = json[difficulty.name] as List<dynamic>?;
        if (seeded == null) continue;
        _queues[difficulty] = seeded
            .map((p) => SudokuPuzzle.fromJson(p as Map<String, dynamic>))
            .toList();
      }
      unawaited(_persist());
    } catch (_) {
      // Seed asset missing/corrupt — fine, warmUp() generates from scratch
      // in the background same as before this fallback existed.
    }
  }

  /// Kicks off refills for every tier currently at or below 1. Call once
  /// after [loadFromDisk]; fire-and-forget (not awaited) — background work
  /// proceeds independently of the caller.
  void warmUp() {
    for (final difficulty in Difficulty.values) {
      _scheduleRefillIfNeeded(difficulty);
    }
  }

  /// Synchronous, instant pop — the "새 게임" happy path. Returns null on a
  /// queue miss; the caller falls back to a direct
  /// `SudokuGenerator.generate` call, matching pre-queue behavior.
  SudokuPuzzle? take(Difficulty difficulty) {
    final queue = _queues[difficulty]!;
    if (queue.isEmpty) return null;
    final puzzle = queue.removeAt(0);
    unawaited(_persist());
    _scheduleRefillIfNeeded(difficulty);
    notifyListeners();
    return puzzle;
  }

  /// Re-triggers a refill for [difficulty] if it's currently empty — a
  /// no-op if one is already pending/in-flight (`_scheduleRefillIfNeeded`'s
  /// own guard) or the tier isn't actually empty. Exists for callers like
  /// the home screen that disable "시작하기" while a tier is empty: since
  /// disabling the button also stops it from calling [take] (which is what
  /// normally re-triggers a refill), a silently-swallowed generation
  /// failure would otherwise leave that tier stuck forever with nothing
  /// scheduled to retry it.
  void ensureRefillScheduled(Difficulty difficulty) {
    if (countFor(difficulty) == 0) _scheduleRefillIfNeeded(difficulty);
  }

  /// Same as [take], but pops from the back of the queue instead of the
  /// front. [peek] (and therefore HomeScreen's difficulty-picker preview)
  /// always shows the front puzzle, so a race's puzzle_provider using
  /// plain [take] could hand out a puzzle either player had already seen
  /// on the home screen — an unfair head start. Used only where that
  /// matters (race puzzle uploads).
  SudokuPuzzle? takeLast(Difficulty difficulty) {
    final queue = _queues[difficulty]!;
    if (queue.isEmpty) return null;
    final puzzle = queue.removeLast();
    unawaited(_persist());
    _scheduleRefillIfNeeded(difficulty);
    notifyListeners();
    return puzzle;
  }

  void _scheduleRefillIfNeeded(Difficulty difficulty) {
    if (_queues[difficulty]!.length > 1) return; // refill only at <=1
    if (!_pending.add(difficulty)) return; // already scheduled
    _activeProcessing ??=
        _processPending().whenComplete(() => _activeProcessing = null);
  }

  Future<void> _processPending() async {
    while (_pending.isNotEmpty) {
      // Ascending difficulty order regardless of insertion order into
      // _pending, so easier tiers always fill first.
      final next = Difficulty.values.firstWhere(_pending.contains);
      _pending.remove(next);
      final needed = capacity - _queues[next]!.length;
      if (needed <= 0) continue;
      try {
        final generated = await _generateBatch(next, needed);
        _queues[next]!.addAll(generated);
        await _persist();
        notifyListeners();
      } catch (_) {
        // A generation failure for one tier must not stop the others; it'll
        // be retried the next time this tier drops to <=1 and take()/
        // warmUp() schedules it again.
      }
    }
  }

  Future<void> _persist() => _storage.savePuzzleQueue(_queues);

  /// Test-only: lets tests await background work instead of racing it.
  @visibleForTesting
  Future<void> waitUntilIdle() async {
    while (_activeProcessing != null) {
      await _activeProcessing;
    }
  }
}

Future<List<SudokuPuzzle>> _isolateGenerateBatch(
  Difficulty difficulty,
  int count,
) async {
  final jsonList =
      await Isolate.run(() => _generatePuzzleBatchJson(difficulty, count));
  return jsonList.map(SudokuPuzzle.fromJson).toList();
}

// Top-level (not a method) so the closure Isolate.run sends across the
// isolate boundary only captures trivially-sendable values (the enum and
// int) — returns JSON (not SudokuPuzzle directly) since that's already a
// proven-sendable, proven-correct shape via existing toJson()/fromJson().
List<Map<String, dynamic>> _generatePuzzleBatchJson(
  Difficulty difficulty,
  int count,
) {
  final generator = SudokuGenerator();
  return List.generate(count, (i) {
    return generator.generate(difficulty).toJson();
  });
}
