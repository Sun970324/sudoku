import 'package:flutter/material.dart';

/// Premium theme packs: each pack swaps the app's identity colors (background/
/// button gradients, ColorScheme seed, card surface) and the board's
/// *structural* colors (cell backgrounds, selection/peer highlights, borders,
/// digit colors, pad fills). Colors with gameplay *meaning* — hint reds/
/// greens/teals/ambers, the wrong-digit red, neutral disabled greys — are
/// deliberately NOT part of a pack and stay fixed in [BoardColors], so a skin
/// can never change what a highlight means.
///
/// [classic] is a field-for-field extraction of the previous hardcoded values,
/// so the default look is pixel-identical to before packs existed.
enum ThemePackId { classic, midnightNeon, sepiaPaper, monochrome, forest, ocean }

/// One mode's (light or dark) worth of colors for a pack. Fields map 1:1 onto
/// the delegating getters in AppTheme / AppPalette / BoardColors.
class ThemePackColors {
  const ThemePackColors({
    required this.seed,
    required this.accent,
    required this.scaffoldBg,
    required this.appBarTitle,
    required this.bgGradient,
    required this.primaryGradient,
    required this.cardSurface,
    required this.cellDefault,
    required this.cellSelected,
    required this.cellPeer,
    required this.textFixed,
    required this.textEntered,
    required this.outerBorder,
    required this.innerBorder,
    required this.padBgValue,
    required this.padBgNote,
    required this.padBgDisabled,
    required this.remainingCountText,
  });

  /// ColorScheme seed; also the filled-button color and the light-mode card
  /// shadow tint.
  final Color seed;

  /// Interactive accent (control-circle base color).
  final Color accent;

  /// Scaffold and AppBar background (the game screen paints on this).
  final Color scaffoldBg;
  final Color appBarTitle;

  /// GradientScaffold background, top to bottom.
  final List<Color> bgGradient;

  /// Primary button fill gradient.
  final List<Color> primaryGradient;
  final Color cardSurface;

  // Board.
  final Color cellDefault;
  final Color cellSelected;
  final Color cellPeer;
  final Color textFixed;

  /// User-entered digit color; also the value-pad text and control icons.
  final Color textEntered;
  final Color outerBorder;
  final Color innerBorder;
  final Color padBgValue;
  final Color padBgNote;
  final Color padBgDisabled;
  final Color remainingCountText;
}

/// Blends [accent] at low opacity over the dark cell background — same helper
/// BoardColors used for its dark-mode highlight washes, kept here so pack
/// definitions reproduce the exact legacy blend values.
Color _tintOnDark(Color accent, double opacity) =>
    Color.alphaBlend(accent.withValues(alpha: opacity), Colors.grey.shade900);

class ThemePack {
  ThemePack({
    required this.id,
    required this.isPremium,
    required this.light,
    required this.dark,
    this.schemeVariant = DynamicSchemeVariant.tonalSpot,
  });

  final ThemePackId id;
  final bool isPremium;
  final ThemePackColors light;
  final ThemePackColors dark;

  /// How [ColorScheme.fromSeed] expands the seed. The default (tonalSpot)
  /// force-raises chroma, which turns a grey seed into a green-ish primary —
  /// so the monochrome pack overrides this with a true greyscale variant.
  final DynamicSchemeVariant schemeVariant;

  ThemePackColors of(bool isDark) => isDark ? dark : light;

  /// The pack currently in effect, pushed by SettingsController (same static
  /// push pattern as GameController.wrongNoteWarningEnabled). Everything that
  /// paints reads through this.
  static ThemePack active = classic;

  static final List<ThemePack> all = [
    classic,
    midnightNeon,
    sepiaPaper,
    monochrome,
    forest,
    ocean,
  ];

  /// Resolves a stored pack name; unknown/null falls back to [classic] so a
  /// removed pack (or fresh install) can never break startup.
  static ThemePack byName(String? name) => all.firstWhere(
        (p) => p.id.name == name,
        orElse: () => classic,
      );

  /// The pre-pack look, extracted verbatim from BoardColors/AppPalette/
  /// AppTheme — free for everyone.
  static final classic = ThemePack(
    id: ThemePackId.classic,
    isPremium: false,
    light: const ThemePackColors(
      seed: Color(0xFF6E56FF),
      accent: Color(0xFF6E56FF),
      scaffoldBg: Color(0xFFF6F5FF),
      appBarTitle: Color(0xFF241B4B),
      bgGradient: [Color(0xFFEDE8FF), Color(0xFFDDF1FF)],
      primaryGradient: [Color(0xFF8B72FF), Color(0xFF6E56FF)],
      cardSurface: Colors.white,
      cellDefault: Color(0xFFFFFFFF),
      cellSelected: Color(0xFFDCD6FF),
      cellPeer: Color(0xFFF0EEFF),
      textFixed: Color(0xFF241B4B),
      textEntered: Color(0xFF5341D8),
      outerBorder: Color(0xFF5341D8),
      innerBorder: Color(0xFFC8C1F2),
      padBgValue: Color(0xFFE0DCFF),
      padBgNote: Color(0xFFE1DEFA),
      padBgDisabled: Color(0xFFE9E6FA),
      remainingCountText: Color(0xFF716A96),
    ),
    dark: ThemePackColors(
      seed: const Color(0xFF9D8CFF),
      accent: const Color(0xFF65E9FF),
      scaffoldBg: const Color(0xFF0D0B1E),
      appBarTitle: const Color(0xFFF0EEFF),
      bgGradient: const [Color(0xFF1C1440), Color(0xFF0D0B1E)],
      primaryGradient: const [Color(0xFF9D8CFF), Color(0xFF7A63FF)],
      cardSurface: const Color(0xFF241E48),
      cellDefault: const Color(0xFF17132F),
      cellSelected: _tintOnDark(const Color(0xFF9D8CFF), 0.55),
      cellPeer: _tintOnDark(const Color(0xFF9D8CFF), 0.12),
      textFixed: const Color(0xFFE8E4FF),
      textEntered: const Color(0xFF65E9FF),
      outerBorder: const Color(0xFF9D8CFF),
      innerBorder: const Color(0xFF36305D),
      padBgValue: const Color(0xFF302966),
      padBgNote: const Color(0xFF322C57),
      padBgDisabled: const Color(0xFF252042),
      remainingCountText: const Color(0xFFB9B3D8),
    ),
  );

  /// Deep ink-navy with neon cyan (and a magenta-leaning button gradient).
  static final midnightNeon = ThemePack(
    id: ThemePackId.midnightNeon,
    isPremium: true,
    light: const ThemePackColors(
      seed: Color(0xFF0091EA),
      accent: Color(0xFF00A8CC),
      scaffoldBg: Color(0xFFF2FAFF),
      appBarTitle: Color(0xFF0B2540),
      bgGradient: [Color(0xFFE1F5FF), Color(0xFFF3E8FF)],
      primaryGradient: [Color(0xFF00ACC1), Color(0xFFAB47BC)],
      cardSurface: Colors.white,
      cellDefault: Color(0xFFFFFFFF),
      cellSelected: Color(0xFFC8F2FF),
      cellPeer: Color(0xFFEAFAFF),
      textFixed: Color(0xFF0B2540),
      textEntered: Color(0xFF0086A8),
      outerBorder: Color(0xFF0091B8),
      innerBorder: Color(0xFFB8E4F2),
      padBgValue: Color(0xFFD6F4FC),
      padBgNote: Color(0xFFDFF3F8),
      padBgDisabled: Color(0xFFEAF4F7),
      remainingCountText: Color(0xFF6E8CA0),
    ),
    dark: ThemePackColors(
      seed: const Color(0xFF00E5FF),
      accent: const Color(0xFF00E5FF),
      scaffoldBg: const Color(0xFF060B1A),
      appBarTitle: const Color(0xFFE3F8FF),
      bgGradient: const [Color(0xFF0B1230), Color(0xFF05070F)],
      primaryGradient: const [Color(0xFF00C6FF), Color(0xFFB537F2)],
      cardSurface: const Color(0xFF10193A),
      cellDefault: const Color(0xFF0B132B),
      cellSelected: _tintOnDark(const Color(0xFF00E5FF), 0.45),
      cellPeer: _tintOnDark(const Color(0xFF00E5FF), 0.10),
      textFixed: const Color(0xFFE3F8FF),
      textEntered: const Color(0xFF00E5FF),
      outerBorder: const Color(0xFF00E5FF),
      innerBorder: const Color(0xFF1E2A52),
      padBgValue: const Color(0xFF0F2C46),
      padBgNote: const Color(0xFF14213E),
      padBgDisabled: const Color(0xFF0D1730),
      remainingCountText: const Color(0xFF8FA8C7),
    ),
  );

  /// Warm cream paper with brown ink; dark mode is aged leather and amber.
  static final sepiaPaper = ThemePack(
    id: ThemePackId.sepiaPaper,
    isPremium: true,
    light: const ThemePackColors(
      seed: Color(0xFF9C6B3C),
      accent: Color(0xFF9C6B3C),
      scaffoldBg: Color(0xFFFAF3E6),
      appBarTitle: Color(0xFF43301F),
      bgGradient: [Color(0xFFF6EBD6), Color(0xFFEFE3CE)],
      primaryGradient: [Color(0xFFC59A6B), Color(0xFF9C6B3C)],
      cardSurface: Color(0xFFFFFBF2),
      cellDefault: Color(0xFFFDF7EA),
      cellSelected: Color(0xFFEBD8B5),
      cellPeer: Color(0xFFF6ECDA),
      textFixed: Color(0xFF43301F),
      textEntered: Color(0xFF8F5714),
      outerBorder: Color(0xFF7A5C3E),
      innerBorder: Color(0xFFDCC9A6),
      padBgValue: Color(0xFFF0E2C8),
      padBgNote: Color(0xFFF2E7D2),
      padBgDisabled: Color(0xFFF5EEDF),
      remainingCountText: Color(0xFF8C7A5F),
    ),
    dark: ThemePackColors(
      seed: const Color(0xFFD8AC6E),
      accent: const Color(0xFFE3B778),
      scaffoldBg: const Color(0xFF1B140D),
      appBarTitle: const Color(0xFFF2E4CE),
      bgGradient: const [Color(0xFF2A2013), Color(0xFF171009)],
      primaryGradient: const [Color(0xFFD8AC6E), Color(0xFFA97844)],
      cardSurface: const Color(0xFF2C2216),
      cellDefault: const Color(0xFF211910),
      cellSelected: _tintOnDark(const Color(0xFFE3B778), 0.45),
      cellPeer: _tintOnDark(const Color(0xFFE3B778), 0.10),
      textFixed: const Color(0xFFF2E4CE),
      textEntered: const Color(0xFFF0C888),
      outerBorder: const Color(0xFFD8AC6E),
      innerBorder: const Color(0xFF433525),
      padBgValue: const Color(0xFF3B2E1C),
      padBgNote: const Color(0xFF352A1B),
      padBgDisabled: const Color(0xFF2A2115),
      remainingCountText: const Color(0xFFC0AB8C),
    ),
  );

  /// Pure greys — ink on paper, no hue at all.
  static final monochrome = ThemePack(
    id: ThemePackId.monochrome,
    isPremium: true,
    schemeVariant: DynamicSchemeVariant.monochrome,
    light: const ThemePackColors(
      seed: Color(0xFF616161),
      accent: Color(0xFF424242),
      scaffoldBg: Color(0xFFF7F7F7),
      appBarTitle: Color(0xFF1C1C1C),
      bgGradient: [Color(0xFFF2F2F2), Color(0xFFE4E4E4)],
      primaryGradient: [Color(0xFF757575), Color(0xFF424242)],
      cardSurface: Colors.white,
      cellDefault: Color(0xFFFFFFFF),
      cellSelected: Color(0xFFD9D9D9),
      cellPeer: Color(0xFFF0F0F0),
      textFixed: Color(0xFF1C1C1C),
      textEntered: Color(0xFF5C5C5C),
      outerBorder: Color(0xFF2B2B2B),
      innerBorder: Color(0xFFCFCFCF),
      padBgValue: Color(0xFFE8E8E8),
      padBgNote: Color(0xFFEDEDED),
      padBgDisabled: Color(0xFFF3F3F3),
      remainingCountText: Color(0xFF8A8A8A),
    ),
    dark: ThemePackColors(
      seed: const Color(0xFFBDBDBD),
      accent: const Color(0xFFE0E0E0),
      scaffoldBg: const Color(0xFF0E0E0E),
      appBarTitle: const Color(0xFFF5F5F5),
      bgGradient: const [Color(0xFF1F1F1F), Color(0xFF0A0A0A)],
      primaryGradient: const [Color(0xFF9E9E9E), Color(0xFF616161)],
      cardSurface: const Color(0xFF1F1F1F),
      cellDefault: const Color(0xFF161616),
      cellSelected: _tintOnDark(const Color(0xFFE0E0E0), 0.40),
      cellPeer: _tintOnDark(const Color(0xFFE0E0E0), 0.10),
      textFixed: const Color(0xFFF5F5F5),
      textEntered: const Color(0xFFBDBDBD),
      outerBorder: const Color(0xFFE0E0E0),
      innerBorder: const Color(0xFF383838),
      padBgValue: const Color(0xFF2E2E2E),
      padBgNote: const Color(0xFF292929),
      padBgDisabled: const Color(0xFF1E1E1E),
      remainingCountText: const Color(0xFFA5A5A5),
    ),
  );

  /// Pine greens on soft moss; dark mode is a night forest.
  static final forest = ThemePack(
    id: ThemePackId.forest,
    isPremium: true,
    light: const ThemePackColors(
      seed: Color(0xFF2E7D4F),
      accent: Color(0xFF2E7D4F),
      scaffoldBg: Color(0xFFF4FAF2),
      appBarTitle: Color(0xFF1C3A28),
      bgGradient: [Color(0xFFE4F4E0), Color(0xFFD8EFE3)],
      primaryGradient: [Color(0xFF66BB6A), Color(0xFF2E7D4F)],
      cardSurface: Colors.white,
      cellDefault: Color(0xFFFEFFFC),
      cellSelected: Color(0xFFCDEBD2),
      cellPeer: Color(0xFFEDF7EC),
      textFixed: Color(0xFF1C3A28),
      textEntered: Color(0xFF2E7D4F),
      outerBorder: Color(0xFF2E7D4F),
      innerBorder: Color(0xFFC2DFC6),
      padBgValue: Color(0xFFDDF0DE),
      padBgNote: Color(0xFFE3F2E3),
      padBgDisabled: Color(0xFFECF5EB),
      remainingCountText: Color(0xFF77937D),
    ),
    dark: ThemePackColors(
      seed: const Color(0xFF81C784),
      accent: const Color(0xFF7BE495),
      scaffoldBg: const Color(0xFF0C1911),
      appBarTitle: const Color(0xFFE4F4E6),
      bgGradient: const [Color(0xFF16301F), Color(0xFF08110B)],
      primaryGradient: const [Color(0xFF66BB6A), Color(0xFF2E7D4F)],
      cardSurface: const Color(0xFF16281C),
      cellDefault: const Color(0xFF102117),
      cellSelected: _tintOnDark(const Color(0xFF7BE495), 0.40),
      cellPeer: _tintOnDark(const Color(0xFF7BE495), 0.10),
      textFixed: const Color(0xFFE4F4E6),
      textEntered: const Color(0xFF7BE495),
      outerBorder: const Color(0xFF7BE495),
      innerBorder: const Color(0xFF29402F),
      padBgValue: const Color(0xFF1D3826),
      padBgNote: const Color(0xFF1A3222),
      padBgDisabled: const Color(0xFF14271A),
      remainingCountText: const Color(0xFF93B39A),
    ),
  );

  /// Sea blues and teals; dark mode is deep water.
  static final ocean = ThemePack(
    id: ThemePackId.ocean,
    isPremium: true,
    light: const ThemePackColors(
      seed: Color(0xFF0277BD),
      accent: Color(0xFF0277BD),
      scaffoldBg: Color(0xFFF2FAFD),
      appBarTitle: Color(0xFF0D3450),
      bgGradient: [Color(0xFFDDF1FB), Color(0xFFD3F3F0)],
      primaryGradient: [Color(0xFF29B6F6), Color(0xFF0277BD)],
      cardSurface: Colors.white,
      cellDefault: Color(0xFFFDFEFF),
      cellSelected: Color(0xFFC9E9FA),
      cellPeer: Color(0xFFEAF6FD),
      textFixed: Color(0xFF0D3450),
      textEntered: Color(0xFF0277BD),
      outerBorder: Color(0xFF0277BD),
      innerBorder: Color(0xFFBBDDF0),
      padBgValue: Color(0xFFD8EEFA),
      padBgNote: Color(0xFFDFF0F8),
      padBgDisabled: Color(0xFFE9F4F9),
      remainingCountText: Color(0xFF6D91A6),
    ),
    dark: ThemePackColors(
      seed: const Color(0xFF4FC3F7),
      accent: const Color(0xFF4DD0E1),
      scaffoldBg: const Color(0xFF07131E),
      appBarTitle: const Color(0xFFE1F4FD),
      bgGradient: const [Color(0xFF0C2437), Color(0xFF050D14)],
      primaryGradient: const [Color(0xFF29B6F6), Color(0xFF00838F)],
      cardSurface: const Color(0xFF102A3C),
      cellDefault: const Color(0xFF0B1F2E),
      cellSelected: _tintOnDark(const Color(0xFF4DD0E1), 0.42),
      cellPeer: _tintOnDark(const Color(0xFF4DD0E1), 0.10),
      textFixed: const Color(0xFFE1F4FD),
      textEntered: const Color(0xFF4DD0E1),
      outerBorder: const Color(0xFF4DD0E1),
      innerBorder: const Color(0xFF1D3A50),
      padBgValue: const Color(0xFF15374D),
      padBgNote: const Color(0xFF123147),
      padBgDisabled: const Color(0xFF0D2536),
      remainingCountText: const Color(0xFF8FB0C4),
    ),
  );
}
