import '../models/difficulty.dart';

/// Placeholder average completion time per difficulty tier, used only to
/// produce a plausible-looking "faster than N% of players" figure until
/// real aggregated player data is available to replace this map.
const _averageSeconds = <Difficulty, int>{
  Difficulty.beginner: 180,
  Difficulty.easy: 300,
  Difficulty.medium: 480,
  Difficulty.hard: 720,
  Difficulty.master: 1200,
  Difficulty.expert: 1800,
};

/// Mock percentile: how many percent of (imaginary) other players this
/// [elapsedSeconds] finish beats, for the given [difficulty]. Deterministic
/// (not random) so the same result always shows the same figure. Finishing
/// exactly at the tier's average lands at 50; faster/slower move linearly
/// toward 99/1.
int estimateFasterThanPercent(Difficulty difficulty, int elapsedSeconds) {
  final average = _averageSeconds[difficulty]!;
  final ratio = average / elapsedSeconds.clamp(1, average * 10);
  final percent = (50 + (ratio - 1) * 40).round();
  return percent.clamp(1, 99);
}
