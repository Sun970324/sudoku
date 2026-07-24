import 'difficulty.dart';

class DifficultyStats {
  const DifficultyStats({
    this.played = 0,
    this.won = 0,
    this.bestTimeSeconds,
    this.perfectWins = 0,
    this.totalWinSeconds = 0,
    this.timedWins = 0,
  });

  factory DifficultyStats.fromJson(Map<String, dynamic> json) =>
      DifficultyStats(
        played: json['played'] as int? ?? 0,
        won: json['won'] as int? ?? 0,
        bestTimeSeconds: json['bestTimeSeconds'] as int?,
        perfectWins: json['perfectWins'] as int? ?? 0,
        totalWinSeconds: json['totalWinSeconds'] as int? ?? 0,
        timedWins: json['timedWins'] as int? ?? 0,
      );

  final int played;
  final int won;
  final int? bestTimeSeconds;

  /// Wins finished with zero mistakes. Only counted since this field was
  /// introduced — older wins predate mistake tracking and are not included.
  final int perfectWins;

  /// Sum of finish times over [timedWins] wins, for the average.
  final int totalWinSeconds;

  /// How many wins are included in [totalWinSeconds]. Deliberately separate
  /// from [won]: wins recorded before time tracking existed would otherwise
  /// sit in the average's denominator with no time in its numerator,
  /// skewing the average low.
  final int timedWins;

  /// Average finish time across tracked wins, or null with no data yet.
  int? get averageWinSeconds =>
      timedWins == 0 ? null : totalWinSeconds ~/ timedWins;

  Map<String, dynamic> toJson() => {
        'played': played,
        'won': won,
        'bestTimeSeconds': bestTimeSeconds,
        'perfectWins': perfectWins,
        'totalWinSeconds': totalWinSeconds,
        'timedWins': timedWins,
      };
}

class Stats {
  Stats(this.byDifficulty);

  factory Stats.empty() => Stats({
        for (final difficulty in Difficulty.values)
          difficulty: const DifficultyStats(),
      });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats({
        for (final difficulty in Difficulty.values)
          difficulty: json[difficulty.name] != null
              ? DifficultyStats.fromJson(
                  json[difficulty.name] as Map<String, dynamic>)
              : const DifficultyStats(),
      });

  final Map<Difficulty, DifficultyStats> byDifficulty;

  Map<String, dynamic> toJson() => {
        for (final entry in byDifficulty.entries)
          entry.key.name: entry.value.toJson(),
      };
}
