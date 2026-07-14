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

class Race {
  const Race({
    required this.id,
    required this.playerA,
    required this.playerB,
    required this.puzzleProvider,
    required this.difficulty,
    required this.status,
    this.puzzle,
    this.winnerId,
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
      winnerId: json['winner_id'] as String?,
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
  final SudokuPuzzle? puzzle;
  final String? winnerId;

  String opponentOf(String selfId) => selfId == playerA ? playerB : playerA;

  bool isPuzzleProvider(String selfId) => puzzleProvider == selfId;
}
