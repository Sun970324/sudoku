import 'package:flutter/material.dart';

/// The app's two ThemeData instances, extracted from main.dart so theme
/// decisions live beside the palette. Jua (bundled, single Regular weight)
/// covers display/headline/title text — the "game voice" — while body and
/// label styles stay on the system font for long-form readability. Every
/// Jua style pins `fontWeight: normal`: the family has no bold cut, and a
/// synthesized faux-bold distorts its rounded shapes.
class AppTheme {
  AppTheme._();

  static const _jua = 'Jua';

  static TextTheme _juaTitles(TextTheme base) => base.copyWith(
        displayLarge: base.displayLarge
            ?.copyWith(fontFamily: _jua, fontWeight: FontWeight.normal),
        displayMedium: base.displayMedium
            ?.copyWith(fontFamily: _jua, fontWeight: FontWeight.normal),
        displaySmall: base.displaySmall
            ?.copyWith(fontFamily: _jua, fontWeight: FontWeight.normal),
        headlineMedium: base.headlineMedium
            ?.copyWith(fontFamily: _jua, fontWeight: FontWeight.normal),
        headlineSmall: base.headlineSmall
            ?.copyWith(fontFamily: _jua, fontWeight: FontWeight.normal),
        titleLarge: base.titleLarge
            ?.copyWith(fontFamily: _jua, fontWeight: FontWeight.normal),
      );

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6E56FF),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      // Kept as-is: the game screen (outside the redesign) paints on this.
      scaffoldBackgroundColor: const Color(0xFFF6F5FF),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFFF6F5FF),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFF241B4B),
          fontSize: 22,
          fontFamily: _jua,
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
    return base.copyWith(textTheme: _juaTitles(base.textTheme));
  }

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9D8CFF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0D0B1E),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFF0D0B1E),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFFF0EEFF),
          fontSize: 22,
          fontFamily: _jua,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
      ),
    );
    return base.copyWith(textTheme: _juaTitles(base.textTheme));
  }
}
