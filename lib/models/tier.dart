import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'difficulty.dart';

enum Tier { bronze, silver, gold, diamond, master, challenger }

/// `platinum` was replaced with `diamond`; accepting it keeps profiles
/// readable until the server-side data migration has run.
Tier tierFromName(String name) =>
    name == 'platinum' ? Tier.diamond : Tier.values.byName(name);

extension TierInfo on Tier {
  /// The minimum rating at which this tier's band begins, mirroring the
  /// server's `tier_for_rating` thresholds (supabase migration 0008) — keep
  /// the two in sync. Note `challenger` is NOT reachable by rating alone
  /// server-side (it's leaderboard-gated: only kept while already challenger
  /// and rating >= 1900), so 1900 here is purely the challenger score line
  /// used to show "points remaining" for a master, not an auto-promotion.
  int get minRating => switch (this) {
        Tier.bronze => 0,
        Tier.silver => 1100,
        Tier.gold => 1300,
        Tier.diamond => 1500,
        Tier.master => 1700,
        Tier.challenger => 1900,
      };

  /// The next tier up the ladder, or null if this is already the top
  /// (challenger). Relies on [Tier] being declared in ascending order.
  Tier? get nextTier {
    final index = Tier.values.indexOf(this);
    return index + 1 < Tier.values.length ? Tier.values[index + 1] : null;
  }

  Difficulty get raceDifficulty => switch (this) {
        Tier.bronze => Difficulty.beginner,
        Tier.silver => Difficulty.easy,
        Tier.gold => Difficulty.medium,
        Tier.diamond => Difficulty.hard,
        Tier.master => Difficulty.master,
        Tier.challenger => Difficulty.expert,
      };

  /// Requires a [BuildContext] (unlike [tierFromName]) since the display
  /// name is localized — see [AppLocalizations]. Mirrors [Difficulty.label].
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case Tier.bronze:
        return l10n.tierBronze;
      case Tier.silver:
        return l10n.tierSilver;
      case Tier.gold:
        return l10n.tierGold;
      case Tier.diamond:
        return l10n.tierDiamond;
      case Tier.master:
        return l10n.tierMaster;
      case Tier.challenger:
        return l10n.tierChallenger;
    }
  }

  /// Mirrors ResultScreen._difficultyColor's light/dark-aware pattern.
  Color color(bool isDark) {
    switch (this) {
      case Tier.bronze:
        return isDark ? Colors.brown.shade300 : Colors.brown.shade700;
      case Tier.silver:
        return isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade600;
      case Tier.gold:
        return isDark ? Colors.amber.shade300 : Colors.amber.shade800;
      case Tier.diamond:
        return isDark ? Colors.lightBlue.shade200 : Colors.lightBlue.shade700;
      case Tier.master:
        return isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade600;
      case Tier.challenger:
        return isDark ? Colors.redAccent.shade100 : Colors.redAccent.shade700;
    }
  }
}
