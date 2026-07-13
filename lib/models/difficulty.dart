import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

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
        return 37;
      case Difficulty.medium:
        return 30;
      case Difficulty.hard:
        return 27;
      case Difficulty.master:
        return 24;
      case Difficulty.expert:
        return 20;
    }
  }

  /// Requires a [BuildContext] (unlike [givenCount]) since the display name
  /// is localized — see [AppLocalizations].
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case Difficulty.beginner:
        return l10n.difficultyBeginner;
      case Difficulty.easy:
        return l10n.difficultyEasy;
      case Difficulty.medium:
        return l10n.difficultyMedium;
      case Difficulty.hard:
        return l10n.difficultyHard;
      case Difficulty.master:
        return l10n.difficultyMaster;
      case Difficulty.expert:
        return l10n.difficultyExpert;
    }
  }
}
