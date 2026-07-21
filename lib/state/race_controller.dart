import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../models/race.dart';
import '../models/sudoku_puzzle.dart';
import '../models/user_profile.dart';
import '../services/generation/sudoku_generator.dart';
import '../services/profile_service.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/race_service.dart';
import '../services/storage_service.dart';
import 'game_controller.dart';

/// Off-thread fallback for a race whose provider found its puzzle queue
/// empty. Same top-level-function + JSON-across-the-boundary shape as
/// PuzzleQueueManager's batch generator, and for the same reason: the
/// closure must only capture trivially-sendable values.
Future<SudokuPuzzle> _isolateGeneratePuzzle(Difficulty difficulty) async {
  final json = await Isolate.run(() => _generatePuzzleJson(difficulty));
  return SudokuPuzzle.fromJson(json);
}

Map<String, dynamic> _generatePuzzleJson(Difficulty difficulty) =>
    SudokuGenerator().generate(difficulty).toJson();

enum RacePhase {
  matching,
  waitingForPuzzle,
  readyCheck,
  racing,
  finished,
  aborted,
}

/// Orchestrates one race end-to-end: matchmaking, puzzle exchange, the
/// ready-check handshake, and (via the wrapped [game]) actual play — see
/// the Phase 3 plan's §4 flow. [game] is only started once the race
/// actually begins (`RacePhase.racing`); before that, screens should show
/// [Race.puzzle] as a static preview (e.g. via `SudokuPreviewBoard`)
/// instead, so no player can start entering digits before `start_race`
/// records a fair, server-agreed start time.
class RaceController extends ChangeNotifier {
  RaceController({
    required Difficulty difficulty,
    required PuzzleQueueManager puzzleQueue,
    RaceService? raceService,
    ProfileService? profileService,
    StorageService? storage,
  })  : _difficulty = difficulty,
        _puzzleQueue = puzzleQueue,
        _raceService = raceService ?? RaceService(),
        _profileService = profileService ?? ProfileService(),
        _storage = storage ?? StorageService();

  /// Grace period after the opponent's realtime presence drops before their
  /// disconnect is claimed as a win — long enough to ride out a brief
  /// background/network blip (the server's own staleness threshold is looser
  /// still, at 30s, so a claim fired at 0 reliably passes). See
  /// [claim_disconnect_win] / [race_heartbeat] in migration 0015.
  static const graceSeconds = 45;

  final Difficulty _difficulty;
  final PuzzleQueueManager _puzzleQueue;
  final RaceService _raceService;
  final ProfileService _profileService;
  final StorageService _storage;

  final GameController game = GameController();

  RacePhase phase = RacePhase.matching;

  /// The room code to show the friend — set only on the hosting side of a
  /// private match (see [startPrivateHost]), null in every other flow.
  String? joinCode;

  Race? _race;
  UserProfile? opponentProfile;
  UserProfile? selfProfile;

  /// True while the opponent's realtime presence is dropped and the grace
  /// countdown ([disconnectSeconds]) is running. Cleared if they return
  /// before it elapses.
  bool opponentLeft = false;

  /// Seconds left before the opponent's disconnect is claimed as a win —
  /// non-null only while [opponentLeft] is true.
  int? disconnectSeconds;
  int opponentFilledCount = 0;
  int opponentMistakes = 0;

  String get selfId => _raceService.selfId;
  bool get isWinner => _race?.winnerId == selfId;

  /// Whether this is a friendly (room-code) match — no rating at stake, so
  /// result UI should show a friendly-match label instead of waiting for
  /// rating deltas that will never arrive.
  bool get isPrivate => _race?.isPrivate ?? false;
  int? get selfRatingAfter => _race?.ratingAfterFor(selfId);
  int? get opponentRatingAfter =>
      _race?.ratingAfterFor(_race?.opponentOf(selfId) ?? selfId);
  SudokuPuzzle? get puzzle => _race?.puzzle;

  /// Rating this side of the race started with — set once, alongside the
  /// initial [opponentProfile] fetch, so [selfRatingDelta]/
  /// [opponentRatingDelta] can compare against the post-race rating in
  /// [selfProfile]/[opponentProfile] once those are refreshed on finish.
  int? _selfRatingBefore;
  int? _opponentRatingBefore;

  int? get selfRatingDelta => _race?.ratingDeltaFor(selfId) ??
      (selfProfile == null || _selfRatingBefore == null
          ? null
          : selfProfile!.rating - _selfRatingBefore!);
  int? get opponentRatingDelta => _race?.ratingDeltaFor(
          _race?.opponentOf(selfId) ?? selfId) ??
      (opponentProfile == null || _opponentRatingBefore == null
          ? null
          : opponentProfile!.rating - _opponentRatingBefore!);

  StreamSubscription<Race?>? _matchSubscription;
  StreamSubscription<Race?>? _raceSubscription;
  RealtimeChannel? _channel;
  Timer? _progressTimer;
  // Polling fallbacks alongside the realtime streams above — a dropped or
  // missed Postgres Changes event (backgrounding, a network switch, a
  // flaky connection) would otherwise leave a client stuck indefinitely
  // with no other signal that anything changed server-side.
  Timer? _matchPollTimer;
  Timer? _racePollTimer;
  Timer? _heartbeatTimer;
  Timer? _disconnectTimer;
  bool _attached = false;
  bool _puzzleProvided = false;
  bool _startRequested = false;
  bool _initialProfilesRequested = false;

  /// Guards the one-time race-replay save at finish: [_gameStarted] rules out a
  /// cold restore that lands in `finished` without ever loading the board (so
  /// [game] has no puzzle to package), and [_replaySaved] keeps repeated
  /// `finished` stream updates from saving twice.
  bool _gameStarted = false;
  bool _replaySaved = false;

  /// Set by [restore] so the racing transition resumes this board instead of
  /// starting a fresh one — the reconnect-after-app-kill path.
  GameSnapshot? _resumeSnapshot;

  Future<void> start() async {
    final raceId = await _raceService.enqueue(_difficulty);
    if (raceId != null) {
      _attachToRace(raceId);
    } else {
      _watchForMatch();
    }
  }

  /// Hosts a private (friend) room: registers it server-side, exposes its
  /// join code via [joinCode], then waits for the friend exactly the way a
  /// ranked waiter does — the join creates a `races` row naming this side
  /// as player_a, which [_watchForMatch]'s stream/polling picks up.
  Future<void> startPrivateHost() async {
    joinCode = await _raceService.createPrivateRoom(_difficulty);
    notifyListeners();
    _watchForMatch();
  }

  /// Joins a friend's room by its code. Rethrows the service error for an
  /// unknown/expired code — the caller shows it and pops; nothing has been
  /// attached yet, so there is no state to unwind.
  Future<void> joinPrivateRoom(String code) async {
    final raceId = await _raceService.joinPrivateRoom(code);
    _attachToRace(raceId);
  }

  /// Waits (stream + polling fallback) for a `races` row naming this side
  /// as player_a — shared by ranked matching and private hosting.
  void _watchForMatch() {
    _matchSubscription = _raceService.watchForMatch().listen((race) {
      if (race == null) return;
      _matchSubscription?.cancel();
      _attachToRace(race.id);
    });
    _matchPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final race = await _raceService.fetchActiveMatch();
      if (race != null) {
        await _matchSubscription?.cancel();
        _attachToRace(race.id);
      }
    });
  }

  /// Restores a race the app was in when it was last closed. [board], when
  /// given (a locally-persisted snapshot for this same [raceId]), resumes
  /// play from where the player left off instead of a fresh board — the
  /// reconnect path. A still-in-progress race thus continues rather than
  /// being forfeited.
  Future<void> restore(String raceId, {GameSnapshot? board}) async {
    _resumeSnapshot = board;
    _attachToRace(raceId);
    await _onRaceUpdate(await _raceService.fetchRace(raceId));
  }

  /// Guarded by [_attached] since both the realtime match listener and its
  /// polling fallback in [start] can race to call this for the same match.
  void _attachToRace(String raceId) {
    if (_attached) return;
    _attached = true;
    _matchPollTimer?.cancel();
    _raceSubscription = _raceService.watchRace(raceId).listen(_onRaceUpdate);
    _racePollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final race = await _raceService.fetchRace(raceId);
      if (race != null) unawaited(_onRaceUpdate(race));
    });
  }

  Future<void> _onRaceUpdate(Race? race) async {
    if (race == null) return;
    _race = race;

    if (!_initialProfilesRequested) {
      _initialProfilesRequested = true;
      unawaited(_loadInitialProfiles(race.opponentOf(selfId)));
    }

    switch (race.status) {
      case RaceStatus.pendingPuzzle:
        phase = RacePhase.waitingForPuzzle;
        if (race.isPuzzleProvider(selfId) && !_puzzleProvided) {
          _puzzleProvided = true;
          try {
            // takeLast, not take: the front of the queue is what
            // HomeScreen's difficulty-picker preview shows, so using it here
            // could hand out a puzzle either player had already glimpsed. An
            // exhausted queue falls back to generating in an isolate — a null
            // here previously just never called markPuzzleReady, leaving both
            // players stuck on "preparing puzzle" forever.
            final puzzle = _puzzleQueue.takeLast(race.difficulty) ??
                await _isolateGeneratePuzzle(race.difficulty);
            await _raceService.markPuzzleReady(raceId: race.id, puzzle: puzzle);
          } catch (_) {
            // Let the 3s race poll re-enter this case and try again.
            _puzzleProvided = false;
          }
        }
      case RaceStatus.ready:
        phase = RacePhase.readyCheck;
        _joinRaceChannel(race.id);
      case RaceStatus.inProgress:
        if (phase != RacePhase.racing) {
          phase = RacePhase.racing;
          final resume = _resumeSnapshot;
          if (resume != null) {
            game.resumeFrom(resume);
            _resumeSnapshot = null;
          } else {
            game.startNewGame(race.difficulty, puzzle: race.puzzle);
          }
          _gameStarted = true;
          game.addListener(_onGameChanged);
          // A cold restore lands straight in inProgress without passing
          // through the ready branch, so join the channel here too (no-op
          // if already joined) — otherwise presence/disconnect detection
          // wouldn't work on a resumed race.
          _joinRaceChannel(race.id);
          _startProgressTimer();
          _startHeartbeat(race.id);
        }
      case RaceStatus.finished:
        phase = RacePhase.finished;
        _cleanupRealtime();
        unawaited(_storage.clearRaceProgress());
        // Save my move log for replay (premium), win or loss — but only if the
        // board actually loaded this session, and only once across repeated
        // `finished` updates.
        if (_gameStarted && !_replaySaved && game.eventLog.isNotEmpty) {
          _replaySaved = true;
          unawaited(_storage.saveRaceReplay(
              game.toReplay(won: race.winnerId == selfId, raceId: race.id)));
        }
        // Both a normal win and a forfeit-loss (see abort_race) update
        // rating/tier server-side — refetch so the result screen can show
        // the before/after delta via selfRatingDelta/opponentRatingDelta.
        unawaited(_refreshProfilesAfterFinish(race.opponentOf(selfId)));
      case RaceStatus.aborted:
        phase = RacePhase.aborted;
        _cleanupRealtime();
        unawaited(_storage.clearRaceProgress());
    }
    notifyListeners();
  }

  Future<void> _loadInitialProfiles(String opponentId) async {
    try {
      final results = await Future.wait([
        _profileService.fetchProfile(selfId),
        _profileService.fetchProfile(opponentId),
      ]);
      _selfRatingBefore = results[0].rating;
      _opponentRatingBefore = results[1].rating;
      opponentProfile = results[1];
      notifyListeners();
    } catch (_) {
      // Best-effort — the rating delta simply won't be shown.
    }
  }

  Future<void> _refreshProfilesAfterFinish(String opponentId) async {
    try {
      final results = await Future.wait([
        _profileService.fetchProfile(selfId),
        _profileService.fetchProfile(opponentId),
      ]);
      selfProfile = results[0];
      opponentProfile = results[1];
      notifyListeners();
    } catch (_) {
      // Best-effort — the rating delta simply won't be shown.
    }
  }

  void _joinRaceChannel(String raceId) {
    if (_channel != null) return;
    final channel = _raceService.raceChannel(raceId)
      ..onPresenceSync((_) => _onPresenceSync(raceId))
      ..onPresenceLeave((_) => _onOpponentLeft())
      ..onBroadcast(event: 'progress', callback: _onOpponentProgress);
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.track({});
      }
    });
    _channel = channel;
  }

  void _onPresenceSync(String raceId) {
    final count = _channel?.presenceState().length ?? 0;
    if (phase == RacePhase.readyCheck) {
      _checkBothReady(raceId);
    } else if (phase == RacePhase.racing && opponentLeft && count >= 2) {
      // Opponent's presence came back before the grace ran out — abort the
      // pending disconnect claim and carry on racing.
      _cancelDisconnectCountdown();
    }
  }

  void _checkBothReady(String raceId) {
    if (_startRequested) return;
    if ((_channel?.presenceState().length ?? 0) >= 2) {
      _startRequested = true;
      unawaited(_raceService.startRace(raceId));
    }
  }

  void _startHeartbeat(String raceId) {
    _heartbeatTimer?.cancel();
    unawaited(_raceService.heartbeat(raceId));
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10),
        (_) => unawaited(_raceService.heartbeat(raceId)));
  }

  /// Opponent's realtime presence dropped — start the grace countdown. If it
  /// reaches zero, claim the win (server-verified against their heartbeat).
  void _onOpponentLeft() {
    if (opponentLeft || phase != RacePhase.racing) return;
    opponentLeft = true;
    disconnectSeconds = graceSeconds;
    notifyListeners();
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = (disconnectSeconds ?? 0) - 1;
      if (remaining <= 0) {
        disconnectSeconds = 0;
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        notifyListeners();
        unawaited(_claimDisconnectWin());
      } else {
        disconnectSeconds = remaining;
        notifyListeners();
      }
    });
  }

  void _cancelDisconnectCountdown() {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    opponentLeft = false;
    disconnectSeconds = null;
    notifyListeners();
  }

  Future<void> _claimDisconnectWin() async {
    final race = _race;
    if (race == null) return;
    try {
      final won = await _raceService.claimDisconnectWin(race.id);
      if (won) {
        // Reflect the server's decision promptly rather than waiting on the
        // 3s poll; _onRaceUpdate then drives the transition to the result.
        unawaited(_onRaceUpdate(await _raceService.fetchRace(race.id)));
      } else {
        // Opponent was actually still alive (or the race was already
        // decided) — clear the banner and keep playing.
        _cancelDisconnectCountdown();
      }
    } catch (_) {
      _cancelDisconnectCountdown();
    }
  }

  void _onOpponentProgress(Map<String, dynamic> payload) {
    opponentFilledCount = payload['filledCount'] as int? ?? opponentFilledCount;
    opponentMistakes = payload['mistakes'] as int? ?? opponentMistakes;
    notifyListeners();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _broadcastProgress();
      _persistRaceProgress();
    });
  }

  /// Snapshots the live board to disk (keyed by race id) so a killed app can
  /// resume this race — see [restore] and StorageService.saveRaceProgress.
  void _persistRaceProgress() {
    final race = _race;
    if (race == null) return;
    unawaited(_storage.saveRaceProgress(race.id, game.toSnapshot()));
  }

  void _broadcastProgress() {
    _channel?.sendBroadcastMessage(event: 'progress', payload: {
      'filledCount': _filledCount(),
      'mistakes': game.mistakes,
    });
  }

  int _filledCount() {
    final board = game.boardSnapshot;
    var count = 0;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board[r][c] != 0 && board[r][c] == game.puzzle.solutionValue(r, c)) {
          count++;
        }
      }
    }
    return count;
  }

  void _onGameChanged() {
    final race = _race;
    if (race != null && game.status == GameStatus.won) {
      unawaited(_raceService.submitFinish(race.id, game.boardSnapshot));
    }
  }

  /// Leaves the queue while still in [RacePhase.matching] — nothing to
  /// clean up server-side once matched (a `races` row exists by then, and
  /// leaving mid-race goes through [abort] instead).
  Future<void> cancelWhileMatching() async {
    _matchPollTimer?.cancel();
    await _matchSubscription?.cancel();
    await _raceService.cancelQueue();
  }

  /// The private-host counterpart of [cancelWhileMatching]: tears down the
  /// room server-side, which also aborts a race a joiner created in the
  /// same instant (that joiner's client sees the aborted status and exits).
  Future<void> cancelPrivateHost() async {
    _matchPollTimer?.cancel();
    await _matchSubscription?.cancel();
    await _raceService.cancelPrivateRoom();
  }

  Future<void> abort() async {
    final race = _race;
    if (race != null) await _raceService.abortRace(race.id);
  }

  void _cleanupRealtime() {
    _progressTimer?.cancel();
    _racePollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _disconnectTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      _raceService.leaveChannel(channel);
      _channel = null;
    }
  }

  @override
  void dispose() {
    _matchPollTimer?.cancel();
    _matchSubscription?.cancel();
    _raceSubscription?.cancel();
    _cleanupRealtime();
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }
}
