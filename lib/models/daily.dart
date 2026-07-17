import 'sudoku_puzzle.dart';

/// One day's shared puzzle, as returned by the `get_daily_puzzle` /
/// `create_daily_puzzle` RPCs (a jsonb rendering of a `daily_puzzles` row).
class DailyPuzzle {
  const DailyPuzzle({required this.puzzleDate, required this.puzzle});

  factory DailyPuzzle.fromJson(Map<String, dynamic> json) => DailyPuzzle(
        puzzleDate: DateTime.parse(json['puzzle_date'] as String),
        puzzle: SudokuPuzzle.fromJson({
          'puzzle': json['puzzle'],
          'solution': json['solution'],
          'fixedMask': json['fixed_mask'],
          'difficulty': json['difficulty'],
        }),
      );

  final DateTime puzzleDate;
  final SudokuPuzzle puzzle;
}

class DailyLeaderboardEntry {
  const DailyLeaderboardEntry({
    required this.rank,
    required this.profileId,
    required this.username,
    required this.elapsedSeconds,
  });

  factory DailyLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      DailyLeaderboardEntry(
        rank: json['rank'] as int,
        profileId: json['profile_id'] as String,
        username: json['username'] as String,
        elapsedSeconds: json['elapsed_seconds'] as int,
      );

  final int rank;
  final String profileId;
  final String username;
  final int elapsedSeconds;
}

/// The `get_daily_leaderboard` RPC's payload: today's finisher count, the
/// caller's own rank/time (null while not yet completed — which doubles as
/// the "already completed today?" check), and the top 10.
class DailyLeaderboard {
  const DailyLeaderboard({
    required this.total,
    this.myRank,
    this.myElapsedSeconds,
    required this.entries,
  });

  factory DailyLeaderboard.fromJson(Map<String, dynamic> json) =>
      DailyLeaderboard(
        total: json['total'] as int,
        myRank: json['my_rank'] as int?,
        myElapsedSeconds: json['my_elapsed_seconds'] as int?,
        entries: (json['entries'] as List<dynamic>)
            .map((e) => DailyLeaderboardEntry.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );

  final int total;
  final int? myRank;
  final int? myElapsedSeconds;
  final List<DailyLeaderboardEntry> entries;

  bool get completedToday => myRank != null;
}
