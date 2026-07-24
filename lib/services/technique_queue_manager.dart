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
/// used to fill any category still empty after a lazy load. Absent until the
/// bundle is mined for a release — until then [take] falls back to live
/// mining.
const _assetPath = 'assets/data/technique_boards.json';

/// Keeps up to [capacity] boards queued per [TechniqueCategory] for the
/// technique practice screen (Singles/Intersections free, the rest a premium
/// perk) and the debug 힌트 데모. Every queued board is a genuine practice case
/// for its category — solvable within the category ceiling and actually
/// needing it (see [mineCategoryBoard]/[boardRequiresCategory]). [take] pops a
/// RANDOM queued board so repeat visits differ, then refills in the background
/// on an [Isolate]. Persisted via [StorageService] so mined boards survive
/// restarts.
class TechniqueQueueManager extends ChangeNotifier {
  TechniqueQueueManager({
    StorageService? storage,
    Future<SudokuPuzzle?> Function(TechniqueCategory category)? mineBoard,
    Random? random,
  })  : _storage = storage ?? StorageService(),
        _mineBoard = mineBoard ?? _isolateMineBoard,
        _random = random ?? Random();

  static final instance = TechniqueQueueManager();

  static const capacity = 3;

  /// How many isolates race to mine one board on the on-demand path (a user
  /// tapped a category with an empty queue). Each explores different random
  /// boards, so the first to hit wins — roughly an N× wall-clock speedup for
  /// rare categories, where a single search can take many seconds.
  static const _onDemandParallelism = 3;

  /// How many categories may be mined at once during background refill/warm-up
  /// — bounded so pre-warming the whole list doesn't peg every core.
  static const _maxConcurrentMines = 2;

  /// The category list the UI iterates (ascending difficulty).
  static List<TechniqueCategory> get categories => TechniqueCategory.values;

  /// Runs up to [k] mines concurrently and resolves with the first non-null
  /// board (or null if all come back empty). Losing isolates finish in the
  /// background — harmless, their results are dropped.
  Future<SudokuPuzzle?> _mineRaced(TechniqueCategory category, int k) {
    if (k <= 1) return _mineBoard(category);
    final completer = Completer<SudokuPuzzle?>();
    var remaining = k;
    for (var i = 0; i < k; i++) {
      _mineBoard(category).then((p) {
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
  final Future<SudokuPuzzle?> Function(TechniqueCategory) _mineBoard;
  final Random _random;

  final Map<String, List<SudokuPuzzle>> _queues = {
    for (final category in TechniqueCategory.values)
      category.name: <SudokuPuzzle>[],
  };
  final Map<String, List<SudokuPuzzle>> _bundled = {};
  final Set<String> _pending = {};
  Future<void>? _activeProcessing;
  Future<void>? _loading;
  Future<void>? _warming;

  int countFor(TechniqueCategory category) =>
      _queues[category.name]?.length ?? 0;

  /// Pops a random queued board for [category] (falling back to a random
  /// bundled one, then to live mining) and schedules a background refill.
  Future<SudokuPuzzle?> take(TechniqueCategory category) async {
    final key = category.name;
    await (_loading ??= _load());
    final queue = _queues[key]!;
    SudokuPuzzle? puzzle;
    if (queue.isNotEmpty) {
      puzzle = queue.removeAt(_random.nextInt(queue.length));
      unawaited(_persist());
    } else {
      final bundled = _bundled[key];
      if (bundled != null && bundled.isNotEmpty) {
        puzzle = bundled[_random.nextInt(bundled.length)];
      } else {
        // No bundle yet — mine one on the spot (first-run path), racing a few
        // isolates so a rare category doesn't leave the user waiting on a
        // single slow search.
        puzzle = await _mineRaced(category, _onDemandParallelism);
      }
    }
    _scheduleRefillIfNeeded(category);
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
      for (final category in TechniqueCategory.values) {
        final seeded = json[category.name] as List<dynamic>?;
        if (seeded == null) continue;
        _bundled[category.name] = seeded
            .map((p) => SudokuPuzzle.fromJson(p as Map<String, dynamic>))
            .toList();
        if (_queues[category.name]!.isEmpty) {
          _queues[category.name] = [..._bundled[category.name]!];
        }
      }
    } catch (_) {
      // No bundle asset yet — take() live-mines instead.
    }
  }

  void _scheduleRefillIfNeeded(TechniqueCategory category) {
    if ((_queues[category.name]?.length ?? capacity) >= capacity) return;
    if (!_pending.add(category.name)) return;
    _activeProcessing ??=
        _processPending().whenComplete(() => _activeProcessing = null);
  }

  Future<void> _processPending() async {
    // A small worker pool drains _pending [_maxConcurrentMines] at a time, so
    // refilling several categories (or one to capacity) doesn't serialize on a
    // single slow search.
    Future<void> worker() async {
      while (_pending.isNotEmpty) {
        final key = _pending.first;
        _pending.remove(key);
        await _mineOneInto(key);
      }
    }

    await Future.wait([for (var i = 0; i < _maxConcurrentMines; i++) worker()]);
  }

  /// Mines one board for the category named [key] and appends it, re-queuing it
  /// if still below capacity. A failure for one category must not stop others.
  Future<void> _mineOneInto(String key) async {
    final category = TechniqueCategory.values.asNameMap()[key];
    if (category == null) return;
    try {
      final mined = await _mineBoard(category);
      if (mined == null) return; // budget ran out; retried on next take
      _queues[key]!.add(mined);
      await _persist();
      notifyListeners();
      if (_queues[key]!.length < capacity) _pending.add(key);
    } catch (_) {
      // Swallow — background mining is best-effort.
    }
  }

  /// Pre-mines one board for every currently-empty category (the practice
  /// screen calls this on open), so tapping one is instant instead of waiting
  /// on a live mine. Only fills to a single board — capacity refills lazily
  /// after a real [take] — so a cold first open doesn't churn the whole list to
  /// capacity. Idempotent: a run already in flight is reused.
  Future<void> warmUp() =>
      _warming ??= _warmUp().whenComplete(() => _warming = null);

  Future<void> _warmUp() async {
    await (_loading ??= _load());
    final empty = <TechniqueCategory>[
      for (final category in TechniqueCategory.values)
        if (countFor(category) == 0) category,
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < empty.length) {
        final category = empty[next++];
        if (countFor(category) > 0) continue; // filled by another path meanwhile
        try {
          final mined = await _mineBoard(category);
          if (mined == null) continue;
          _queues[category.name]!.add(mined);
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

Future<SudokuPuzzle?> _isolateMineBoard(TechniqueCategory category) async {
  final json = await Isolate.run(() => _mineBoardJson(category));
  return json == null ? null : SudokuPuzzle.fromJson(json);
}

Map<String, dynamic>? _mineBoardJson(TechniqueCategory category) =>
    mineCategoryBoard(category)?.toJson();
