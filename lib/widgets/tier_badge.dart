import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/tier.dart';
import '../theme/app_palette.dart';
import 'pixel_icon.dart';

/// Pill badge for a player's tier (optionally with their rating) — the
/// shared rendering behind the home header, race lobby profile, and my
/// page, so tier presentation can't drift between them.
class TierBadge extends StatelessWidget {
  const TierBadge({
    super.key,
    required this.tier,
    this.rating,
    this.large = false,
    this.unranked = false,
  });

  final Tier tier;
  final int? rating;
  final bool large;

  /// True during a season's first placement games (see
  /// `UserProfile.seasonGames`) — shows a neutral "Unranked" pill instead of
  /// [tier]'s color/label, since a rating that hasn't been calibrated by any
  /// games yet this season doesn't actually mean anything.
  final bool unranked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = unranked
        ? AppPalette.isDark(context)
            ? Colors.grey.shade400
            : Colors.grey.shade600
        : tier.color(AppPalette.isDark(context));
    final fontSize = large ? 18.0 : 14.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PixelIcons.medal, size: fontSize + 2, color: color),
          const SizedBox(width: 4),
          Text(
            unranked
                ? l10n.tierUnranked
                : rating == null
                    ? tier.label(context)
                    : '${tier.label(context)} · $rating',
            style: TextStyle(
              fontFamily: 'Mulmaru',
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
