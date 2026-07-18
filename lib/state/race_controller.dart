import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/difficulty.dart';
import '../models/race.dart';
import '../models/sudoku_puzzle.dart';
import '../models/user_profile.dart';
import '../services/generation/sudoku_generator.dart';
import '../services/profile_service.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/race_service.dart';
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
  })  : _difficulty = difficulty,
        _puzzleQueue = puzzleQueue,
        _raceService = raceService ?? RaceService(),
        _profileService = profileService ?? ProfileService();

  final Difficulty _difficulty;
  final PuzzleQueueManager _puzzleQueue;
  final RaceService _raceService;
  final ProfileService _profileService;

  final GameController game = GameController();

  RacePhase phase = RacePhase.matching;

  /// The room code to show the friend — set only on the hosting side of a
  /// private match (see [startPrivateHost]), null in every other flow.
  String? joinCode;

  Race? _race;
  UserProfile? opponentProfile;
  UserProfile? selfProfile;
  bool opponentLeft = false;
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
  bool _attached = false;
  bool _puzzleProvided = false;
  bool _startRequested = false;
  bool _initialProfilesRequested = false;

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

  /// Restores a race resolved while the app was not running.
  Future<void> restore(String raceId) async {
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
          game.startNewGame(race.difficulty, puzzle: race.puzzle);
          game.addListener(_onGameChanged);
          _startProgressTimer();
        }
      case RaceStatus.finished:
        phase = RacePhase.finished;
        _cleanupRealtime();
        // Both a normal win and a forfeit-loss (see abort_race) update
        // rating/tier server-side — refetch so the result screen can show
        // the before/after delta via selfRatingDelta/opponentRatingDelta.
        unawaited(_refreshProfilesAfterFinish(race.opponentOf(selfId)));
      case RaceStatus.aborted:
        phase = RacePhase.aborted;
        _cleanupRealtime();
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
      ..onPresenceSync((_) => _checkBothReady(raceId))
      ..onPresenceLeave((_) => _onOpponentLeft())
      ..onBroadcast(event: 'progress', callback: _onOpponentProgress);
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.track({});
      }
    });
    _channel = channel;
  }

  void _checkBothReady(String raceId) {
    if (_startRequested) return;
    if ((_channel?.presenceState().length ?? 0) >= 2) {
      _startRequested = true;
      unawaited(_raceService.startRace(raceId));
    }
  }

  void _onOpponentLeft() {
    opponentLeft = true;
    notifyListeners();
  }

  void _onOpponentProgress(Map<String, dynamic> payload) {
    opponentFilledCount = payload['filledCount'] as int? ?? opponentFilledCount;
    opponentMistakes = payload['mistakes'] as int? ?? opponentMistakes;
    notifyListeners();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _broadcastProgress());
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
