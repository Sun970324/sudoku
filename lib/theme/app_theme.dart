import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme_pack.dart';

/// The app's two ThemeData instances, extracted from main.dart so theme
/// decisions live beside the palette. Mulmaru (bundled, single Regular weight)
/// is the app-wide font, set as the base `fontFamily` so every text style —
/// body, label, and titles — renders in it. Display/headline/title styles pin
/// `fontWeight: normal` for the "game voice" look and because the family has
/// no bold cut (a synthesized faux-bold would distort it).
/// User-selectable font for the Sudoku board & number-pad digits.
/// [classic] is the clean system typeface (the long-standing default);
/// [dot] switches digits to the pixel Mulmaru face for a retro board.
enum BoardFont { classic, dot }

class AppTheme {
  AppTheme._();

  static const _mulmaru = 'Mulmaru';

  /// Active board-digit font, driven by [SettingsController] and read by the
  /// board cell / number-pad widgets via [boardFontFamily]. Static (mirrors
  /// [ThemePack.active]) so a settings change repaints through the app-wide
  /// rebuild without threading the value through every board widget.
  static BoardFont activeBoardFont = BoardFont.classic;

  /// Font family for board & number-pad digits: the [systemFontFamily] for
  /// [BoardFont.classic], Mulmaru for [BoardFont.dot].
  static String get boardFontFamily =>
      activeBoardFont == BoardFont.dot ? _mulmaru : systemFontFamily;

  /// The platform's default UI font. The Sudoku board and number pad use this
  /// (via [boardFontFamily]) to opt out of the app-wide [_mulmaru] font —
  /// digits read cleaner in the system typeface. A concrete family is required
  /// (not null) so it overrides the inherited Mulmaru during [TextStyle] merge
  /// instead of falling back to it.
  static String get systemFontFamily {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'CupertinoSystemText';
      case TargetPlatform.windows:
        return 'Segoe UI';
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return 'Roboto';
    }
  }

  static TextTheme _mulmaruTitles(TextTheme base) => base.copyWith(
        displayLarge: base.displayLarge
            ?.copyWith(fontFamily: _mulmaru, fontWeight: FontWeight.normal),
        displayMedium: base.displayMedium
            ?.copyWith(fontFamily: _mulmaru, fontWeight: FontWeight.normal),
        displaySmall: base.displaySmall
            ?.copyWith(fontFamily: _mulmaru, fontWeight: FontWeight.normal),
        headlineMedium: base.headlineMedium
            ?.copyWith(fontFamily: _mulmaru, fontWeight: FontWeight.normal),
        headlineSmall: base.headlineSmall
            ?.copyWith(fontFamily: _mulmaru, fontWeight: FontWeight.normal),
        titleLarge: base.titleLarge
            ?.copyWith(fontFamily: _mulmaru, fontWeight: FontWeight.normal),
      );

  static ThemeData light() {
    final pack = ThemePack.active.of(false);
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: pack.seed,
        brightness: Brightness.light,
        dynamicSchemeVariant: ThemePack.active.schemeVariant,
      ),
      useMaterial3: true,
      fontFamily: _mulmaru,
      // Kept as-is: the game screen (outside the redesign) paints on this.
      scaffoldBackgroundColor: pack.scaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: pack.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: pack.appBarTitle,
          fontSize: 22,
          fontFamily: _mulmaru,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pack.seed,
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: pack.seed.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
    return base.copyWith(textTheme: _mulmaruTitles(base.textTheme));
  }

  static ThemeData dark() {
    final pack = ThemePack.active.of(true);
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: pack.seed,
        brightness: Brightness.dark,
        dynamicSchemeVariant: ThemePack.active.schemeVariant,
      ),
      useMaterial3: true,
      fontFamily: _mulmaru,
      scaffoldBackgroundColor: pack.scaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: pack.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: pack.appBarTitle,
          fontSize: 22,
          fontFamily: _mulmaru,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
      ),
    );
    return base.copyWith(textTheme: _mulmaruTitles(base.textTheme));
  }
}
