import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The app's two ThemeData instances, extracted from main.dart so theme
/// decisions live beside the palette. Mulmaru (bundled, single Regular weight)
/// is the app-wide font, set as the base `fontFamily` so every text style —
/// body, label, and titles — renders in it. Display/headline/title styles pin
/// `fontWeight: normal` for the "game voice" look and because the family has
/// no bold cut (a synthesized faux-bold would distort it).
class AppTheme {
  AppTheme._();

  static const _mulmaru = 'Mulmaru';

  /// The platform's default UI font. The Sudoku board and number pad use this
  /// to opt out of the app-wide [_mulmaru] font — digits read cleaner in the
  /// system typeface. A concrete family is required (not null) so it overrides
  /// the inherited Mulmaru during [TextStyle] merge instead of falling back to it.
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
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6E56FF),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: _mulmaru,
      // Kept as-is: the game screen (outside the redesign) paints on this.
      scaffoldBackgroundColor: const Color(0xFFF6F5FF),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFFF6F5FF),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFF241B4B),
          fontSize: 22,
          fontFamily: _mulmaru,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6E56FF),
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: const Color(0xFF6E56FF).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
    return base.copyWith(textTheme: _mulmaruTitles(base.textTheme));
  }

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9D8CFF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: _mulmaru,
      scaffoldBackgroundColor: const Color(0xFF0D0B1E),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFF0D0B1E),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFFF0EEFF),
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
