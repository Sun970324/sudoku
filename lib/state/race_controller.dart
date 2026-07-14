import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/difficulty.dart';
import '../models/race.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/race_service.dart';
import 'game_controller.dart';

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
  Race? _race;
  UserProfile? opponentProfile;
  bool opponentLeft = false;
  int opponentFilledCount = 0;
  int opponentMistakes = 0;

  String get selfId => _raceService.selfId;
  bool get isWinner => _race?.winnerId == selfId;

  StreamSubscription<Race?>? _matchSubscription;
  StreamSubscription<Race?>? _raceSubscription;
  RealtimeChannel? _channel;
  Timer? _progressTimer;
  bool _puzzleProvided = false;
  bool _startRequested = false;

  Future<void> start() async {
    final raceId = await _raceService.enqueue(_difficulty);
    if (raceId != null) {
      _attachToRace(raceId);
    } else {
      _matchSubscription = _raceService.watchForMatch().listen((race) {
        if (race == null) return;
        _matchSubscription?.cancel();
        _attachToRace(race.id);
      });
    }
  }

  void _attachToRace(String raceId) {
    _raceSubscription = _raceService.watchRace(raceId).listen(_onRaceUpdate);
  }

  Future<void> _onRaceUpdate(Race? race) async {
    if (race == null) return;
    _race = race;

    if (opponentProfile == null) {
      unawaited(_profileService
          .fetchProfile(race.opponentOf(selfId))
          .then((profile) {
        opponentProfile = profile;
        notifyListeners();
      }).catchError((_) {}));
    }

    switch (race.status) {
      case RaceStatus.pendingPuzzle:
        phase = RacePhase.waitingForPuzzle;
        if (race.isPuzzleProvider(selfId) && !_puzzleProvided) {
          _puzzleProvided = true;
          // takeLast, not take: the front of the queue is what
          // HomeScreen's difficulty-picker preview shows, so using it here
          // could hand out a puzzle either player had already glimpsed.
          final puzzle = _puzzleQueue.takeLast(race.difficulty);
          if (puzzle != null) {
            await _raceService.markPuzzleReady(raceId: race.id, puzzle: puzzle);
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
      case RaceStatus.aborted:
        phase = RacePhase.aborted;
        _cleanupRealtime();
    }
    notifyListeners();
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
    await _matchSubscription?.cancel();
    await _raceService.cancelQueue();
  }

  Future<void> abort() async {
    final race = _race;
    if (race != null) await _raceService.abortRace(race.id);
  }

  void _cleanupRealtime() {
    _progressTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      _raceService.leaveChannel(channel);
      _channel = null;
    }
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _raceSubscription?.cancel();
    _cleanupRealtime();
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }
}
