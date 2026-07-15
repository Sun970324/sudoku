import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'difficulty.dart';

enum Tier { bronze, silver, gold, platinum, diamond, master, challenger }

Tier tierFromName(String name) => Tier.values.byName(name);

extension TierInfo on Tier {
  Difficulty get raceDifficulty => switch (this) {
        Tier.bronze => Difficulty.beginner,
        Tier.silver => Difficulty.easy,
        Tier.gold => Difficulty.medium,
        Tier.platinum => Difficulty.hard,
        // Older profiles can still contain this legacy tier.
        Tier.diamond || Tier.master => Difficulty.master,
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
      case Tier.platinum:
        return l10n.tierPlatinum;
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
      case Tier.platinum:
        return isDark ? Colors.teal.shade200 : Colors.teal.shade600;
      case Tier.diamond:
        return isDark ? Colors.lightBlue.shade200 : Colors.lightBlue.shade700;
      case Tier.master:
        return isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade600;
      case Tier.challenger:
        return isDark ? Colors.redAccent.shade100 : Colors.redAccent.shade700;
    }
  }
}
