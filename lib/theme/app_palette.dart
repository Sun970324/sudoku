import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../models/tier.dart';

/// App-wide "vivid pop" design tokens — gradients, category colors, and
/// surfaces for the redesigned (non-game) screens. Same static-utility,
/// `bool isDark` shape as [BoardColors], which stays the separate source of
/// truth for everything on the game board itself.
class AppPalette {
  AppPalette._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Background gradient consumed by `GradientScaffold` — lavender to sky
  /// in light, deep violet to near-black in dark.
  static List<Color> bgGradient(bool d) => d
      ? const [Color(0xFF1C1440), Color(0xFF0D0B1E)]
      : const [Color(0xFFEDE8FF), Color(0xFFDDF1FF)];

  /// The identity-violet fill for primary buttons.
  static List<Color> primaryGradient(bool d) => d
      ? const [Color(0xFF9D8CFF), Color(0xFF7A63FF)]
      : const [Color(0xFF8B72FF), Color(0xFF6E56FF)];

  /// Per-difficulty accent. Beginner/Easy deliberately reuse the
  /// Bronze/Silver tier colors — those two difficulties map 1:1 to a
  /// player's first two ranked tiers, so the same color carries across
  /// both contexts. Medium and up keep their own hues (blue/orange/
  /// deep-orange/purple), saturated for pop.
  static Color difficultyColor(Difficulty difficulty, bool d) =>
      switch (difficulty) {
        Difficulty.beginner => tierColor(Tier.bronze, d),
        Difficulty.easy => tierColor(Tier.silver, d),
        Difficulty.medium => tierColor(Tier.gold, d),
        Difficulty.hard => tierColor(Tier.diamond, d),
        Difficulty.master => tierColor(Tier.master, d),
        Difficulty.expert => tierColor(Tier.challenger, d),
      };

  /// Per-tier accent — [TierInfo.color] delegates here, so every existing
  /// call site picks these up unchanged.
  static Color tierColor(Tier tier, bool d) => switch (tier) {
        Tier.bronze => d ? const Color(0xFFD9A06B) : const Color(0xFFA9662F),
        Tier.silver => d ? const Color(0xFFB8C4D4) : const Color(0xFF64748B),
        Tier.gold => d ? const Color(0xFFFFD24A) : const Color(0xFFD99A06),
        Tier.diamond => d ? const Color(0xFF6FD6FF) : const Color(0xFF0284C7),
        Tier.master => d ? const Color(0xFFC4B0FF) : const Color(0xFF7C3AED),
        Tier.challenger =>
          d ? const Color(0xFFFF7B93) : const Color(0xFFE11D48),
      };

  /// Card face color. Dark mode gets a slightly-lifted violet surface —
  /// shadows read as nothing against the dark gradient, so depth there
  /// comes from surface contrast plus a tinted border glow instead.
  static Color cardSurface(bool d) =>
      d ? const Color(0xFF241E48) : Colors.white;

  static Color cardShadow(bool d) => d
      ? Colors.black.withValues(alpha: 0.5)
      : const Color(0xFF6E56FF).withValues(alpha: 0.14);

  /// Accent colors for the home screen's secondary actions.
  static const raceCoral = Color(0xFFFF6B6B);
  static const dailyTeal = Color(0xFF14B8A6);
}

/// Corner-radius scale for the redesigned surfaces.
class AppDims {
  AppDims._();

  static const cardRadius = 24.0;
  static const buttonRadius = 18.0;
  static const fieldRadius = 16.0;
}
