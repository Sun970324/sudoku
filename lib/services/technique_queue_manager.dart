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

/// Keeps up to [capacity] boards queued per [PracticeItem] for the technique
/// practice screen (learning mode; beginner/easy items free, the rest a
/// premium perk) and the debug 힌트 데모: every queued board shows its item's
/// technique in a ceiling-capped solve (see [boardShowsItem]). [take] pops a
/// RANDOM queued
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

  /// How many isolates race to mine one board on the on-demand path (a user
  /// tapped an item with an empty queue). Each explores different random
  /// boards, so the first to hit wins — roughly an N× wall-clock speedup for
  /// rare techniques, where a single search can take many seconds.
  static const _onDemandParallelism = 3;

  /// How many items may be mined at once during background refill/warm-up —
  /// bounded so pre-warming the whole list doesn't peg every core.
  static const _maxConcurrentMines = 2;

  /// The practice list the UI iterates.
  static List<PracticeItem> get items => practiceItems;

  /// Runs up to [k] mines concurrently and resolves with the first non-null
  /// board (or null if all come back empty). Losing isolates finish in the
  /// background — harmless, their results are dropped.
  Future<SudokuPuzzle?> _mineRaced(Set<HintTechnique> techniques, int k) {
    if (k <= 1) return _mineBoard(techniques);
    final completer = Completer<SudokuPuzzle?>();
    var remaining = k;
    for (var i = 0; i < k; i++) {
      _mineBoard(techniques).then((p) {
        if (p != null && !completer.isCompleted) completer.complete(p);
      }, onError: (_) {}).whenComplete(() {
        if (--remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }
    return completer.future;
  }

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
  Future<void>? _warming;

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
        // No bundle yet — mine one on the spot (first-run path), racing a few
        // isolates so a rare technique doesn't leave the user waiting on a
        // single slow search.
        puzzle = await _mineRaced(item.techniques, _onDemandParallelism);
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
    // A small worker pool drains _pending [_maxConcurrentMines] at a time, so
    // refilling several items (or one item to capacity) doesn't serialize on a
    // single slow search.
    Future<void> worker() async {
      while (_pending.isNotEmpty) {
        final itemId = _pending.first;
        _pending.remove(itemId);
        await _mineOneInto(itemId);
      }
    }

    await Future.wait([for (var i = 0; i < _maxConcurrentMines; i++) worker()]);
  }

  /// Mines one board for [itemId] and appends it, re-queuing the item if it's
  /// still below capacity. A failure for one item must not stop the others.
  Future<void> _mineOneInto(String itemId) async {
    final item = _itemById(itemId);
    if (item == null) return;
    try {
      final mined = await _mineBoard(item.techniques);
      if (mined == null) return; // budget ran out; retried on next take
      _queues[itemId]!.add(mined);
      await _persist();
      notifyListeners();
      if (_queues[itemId]!.length < capacity) _pending.add(itemId);
    } catch (_) {
      // Swallow — background mining is best-effort.
    }
  }

  /// Pre-mines one board for every currently-empty item (the practice screen
  /// calls this on open), so tapping an item is instant instead of waiting on
  /// a live mine. Only fills to a single board — capacity refills lazily after
  /// a real [take] — so a cold first open doesn't churn the whole list to
  /// capacity. Idempotent: a run already in flight is reused.
  Future<void> warmUp() =>
      _warming ??= _warmUp().whenComplete(() => _warming = null);

  Future<void> _warmUp() async {
    await (_loading ??= _load());
    final empty = <String>[
      for (final item in practiceItems)
        if (countFor(item.id) == 0) item.id,
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < empty.length) {
        final itemId = empty[next++];
        if (countFor(itemId) > 0) continue; // filled by another path meanwhile
        final item = _itemById(itemId);
        if (item == null) continue;
        try {
          final mined = await _mineBoard(item.techniques);
          if (mined == null) continue;
          _queues[itemId]!.add(mined);
          await _persist();
          notifyListeners();
        } catch (_) {
          // best-effort
        }
      }
    }

    await Future.wait([for (var i = 0; i < _maxConcurrentMines; i++) worker()]);
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
