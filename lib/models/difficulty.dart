enum Difficulty { beginner, easy, medium, hard, master, expert }

/// Parses a [Difficulty] from a stored name, tolerating `'challenger'` —
/// this enum value's name before it was renamed to `expert` — so puzzles
/// saved to local storage under the old name still load instead of
/// throwing.
Difficulty difficultyFromName(String name) =>
    name == 'challenger' ? Difficulty.expert : Difficulty.values.byName(name);

extension DifficultyInfo on Difficulty {
  /// Starting point for [ClueRemover]'s dig — a generation-speed
  /// optimization only, per generator.md's "Hint Count 정책". The actual
  /// difficulty tier is decided by [DifficultyEvaluator] from which
  /// techniques [HumanSolver] needed, not by this count — easier tiers will
  /// typically plateau well above their target once digging is bounded by
  /// that tier's technique ceiling.
  int get givenCount {
    switch (this) {
      case Difficulty.beginner:
        return 45;
      case Difficulty.easy:
        return 40;
      case Difficulty.medium:
        return 33;
      case Difficulty.hard:
        return 27;
      case Difficulty.master:
        return 24;
      case Difficulty.expert:
        return 20;
    }
  }

  String get label {
    switch (this) {
      case Difficulty.beginner:
        return '초보자';
      case Difficulty.easy:
        return '쉬움';
      case Difficulty.medium:
        return '보통';
      case Difficulty.hard:
        return '어려움';
      case Difficulty.master:
        return '마스터';
      case Difficulty.expert:
        return '익스퍼트';
    }
  }
}
