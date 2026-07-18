import 'package:flutter/material.dart';

import '../models/tier.dart';
import '../theme/app_palette.dart';

/// Pill badge for a player's tier (optionally with their rating) — the
/// shared rendering behind the home header, race lobby profile, and my
/// page, so tier presentation can't drift between them.
class TierBadge extends StatelessWidget {
  const TierBadge({
    super.key,
    required this.tier,
    this.rating,
    this.large = false,
  });

  final Tier tier;
  final int? rating;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = tier.color(AppPalette.isDark(context));
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
          Icon(Icons.military_tech, size: fontSize + 2, color: color),
          const SizedBox(width: 4),
          Text(
            rating == null
                ? tier.label(context)
                : '${tier.label(context)} · $rating',
            style: TextStyle(
              fontFamily: 'Jua',
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
