import 'difficulty.dart';
import 'sudoku_puzzle.dart';

enum RaceStatus { pendingPuzzle, ready, inProgress, finished, aborted }

RaceStatus _raceStatusFromDb(String value) {
  switch (value) {
    case 'pending_puzzle':
      return RaceStatus.pendingPuzzle;
    case 'ready':
      return RaceStatus.ready;
    case 'in_progress':
      return RaceStatus.inProgress;
    case 'finished':
      return RaceStatus.finished;
    case 'aborted':
      return RaceStatus.aborted;
    default:
      throw ArgumentError('unknown race status: $value');
  }
}

/// Why a `finished` race ended — see migration 0020. Null (unknown) for any
/// race decided before that migration shipped.
enum RaceFinishReason { completed, gaveUp, disconnected, mistakes }

RaceFinishReason? _raceFinishReasonFromDb(String? value) {
  switch (value) {
    case 'completed':
      return RaceFinishReason.completed;
    case 'gave_up':
      return RaceFinishReason.gaveUp;
    case 'disconnected':
      return RaceFinishReason.disconnected;
    case 'mistakes':
      return RaceFinishReason.mistakes;
    default:
      return null;
  }
}

class Race {
  const Race({
    required this.id,
    required this.playerA,
    required this.playerB,
    required this.puzzleProvider,
    required this.difficulty,
    required this.status,
    this.isPrivate = false,
    this.puzzle,
    this.winnerId,
    this.finishReason,
    this.playerARatingAfter,
    this.playerARatingDelta,
    this.playerBRatingAfter,
    this.playerBRatingDelta,
  });

  factory Race.fromJson(Map<String, dynamic> json) {
    final puzzleJson = json['puzzle'];
    return Race(
      id: json['id'] as String,
      playerA: json['player_a'] as String,
      playerB: json['player_b'] as String,
      puzzleProvider: json['puzzle_provider'] as String,
      difficulty: difficultyFromName(json['difficulty'] as String),
      status: _raceStatusFromDb(json['status'] as String),
      // Tolerates rows/stream payloads from before migration 0010 added the
      // column — absent means a ranked race.
      isPrivate: json['is_private'] as bool? ?? false,
      winnerId: json['winner_id'] as String?,
      finishReason: _raceFinishReasonFromDb(json['finish_reason'] as String?),
      playerARatingAfter: json['player_a_rating_after'] as int?,
      playerARatingDelta: json['player_a_rating_delta'] as int?,
      playerBRatingAfter: json['player_b_rating_after'] as int?,
      playerBRatingDelta: json['player_b_rating_delta'] as int?,
      puzzle: puzzleJson == null
          ? null
          : SudokuPuzzle.fromJson({
              'puzzle': puzzleJson,
              'solution': json['solution'],
              'fixedMask': json['fixed_mask'],
              'difficulty': json['difficulty'],
            }),
    );
  }

  final String id;
  final String playerA;
  final String playerB;
  final String puzzleProvider;
  final Difficulty difficulty;
  final RaceStatus status;

  /// A friendly match created via room code (migration 0010): resolves like
  /// a ranked race but never touches rating/wins/losses/tier, so its
  /// rating_after/delta columns stay null.
  final bool isPrivate;
  final SudokuPuzzle? puzzle;
  final String? winnerId;
  final RaceFinishReason? finishReason;
  final int? playerARatingAfter;
  final int? playerARatingDelta;
  final int? playerBRatingAfter;
  final int? playerBRatingDelta;

  String opponentOf(String selfId) => selfId == playerA ? playerB : playerA;

  bool isPuzzleProvider(String selfId) => puzzleProvider == selfId;

  int? ratingAfterFor(String playerId) =>
      playerId == playerA ? playerARatingAfter : playerBRatingAfter;

  int? ratingDeltaFor(String playerId) =>
      playerId == playerA ? playerARatingDelta : playerBRatingDelta;
}

/// One row of a player's past-race list — a finished race seen from
/// [selfId]'s side, with the rating/tier outcome that race actually
/// produced (captured by `apply_race_result` at the time, since
/// `profiles.rating` only ever holds the *current* rating).
class RaceHistoryEntry {
  const RaceHistoryEntry({
    required this.id,
    required this.finishedAt,
    required this.opponentUsername,
    required this.won,
    required this.ratingAfter,
    required this.ratingDelta,
    required this.puzzle,
  });

  factory RaceHistoryEntry.fromJson(Map<String, dynamic> json, String selfId) {
    final isPlayerA = json['player_a'] == selfId;
    final opponentProfile = (isPlayerA ? json['player_b_profile'] : json['player_a_profile'])
        as Map<String, dynamic>;
    return RaceHistoryEntry(
      id: json['id'] as String,
      finishedAt: DateTime.parse(json['finished_at'] as String),
      opponentUsername: opponentProfile['username'] as String,
      won: json['winner_id'] == selfId,
      ratingAfter:
          (isPlayerA ? json['player_a_rating_after'] : json['player_b_rating_after']) as int,
      ratingDelta:
          (isPlayerA ? json['player_a_rating_delta'] : json['player_b_rating_delta']) as int,
      puzzle: Race.fromJson(json).puzzle!,
    );
  }

  final String id;
  final DateTime finishedAt;
  final String opponentUsername;
  final bool won;
  final int ratingAfter;
  final int ratingDelta;
  final SudokuPuzzle puzzle;
}
