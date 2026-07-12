import 'difficulty.dart';

class DifficultyStats {
  const DifficultyStats({this.played = 0, this.won = 0, this.bestTimeSeconds});

  factory DifficultyStats.fromJson(Map<String, dynamic> json) =>
      DifficultyStats(
        played: json['played'] as int? ?? 0,
        won: json['won'] as int? ?? 0,
        bestTimeSeconds: json['bestTimeSeconds'] as int?,
      );

  final int played;
  final int won;
  final int? bestTimeSeconds;

  Map<String, dynamic> toJson() => {
        'played': played,
        'won': won,
        'bestTimeSeconds': bestTimeSeconds,
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
