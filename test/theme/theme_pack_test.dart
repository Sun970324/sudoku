import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/state/premium_controller.dart';
import 'package:sudoku/state/settings_controller.dart';
import 'package:sudoku/theme/app_palette.dart';
import 'package:sudoku/theme/board_colors.dart';
import 'package:sudoku/theme/theme_pack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ThemePack.active is process-global state — restore the default after
  // every test so ordering never leaks a pack into another test.
  tearDown(() => ThemePack.active = ThemePack.classic);

  group('classic is pixel-identical to the pre-pack hardcoded values', () {
    test('board structural colors', () {
      expect(BoardColors.cellDefault(false), const Color(0xFFFFFFFF));
      expect(BoardColors.cellDefault(true), const Color(0xFF17132F));
      expect(BoardColors.cellSelected(false), const Color(0xFFDCD6FF));
      expect(
        BoardColors.cellSelected(true),
        Color.alphaBlend(
            const Color(0xFF9D8CFF).withValues(alpha: 0.55),
            Colors.grey.shade900),
      );
      expect(BoardColors.textFixed(false), const Color(0xFF241B4B));
      expect(BoardColors.textEntered(true), const Color(0xFF65E9FF));
      expect(BoardColors.outerBorder(false), const Color(0xFF5341D8));
      expect(BoardColors.outerBorder(true), const Color(0xFF9D8CFF));
      expect(BoardColors.innerBorder(false), const Color(0xFFC8C1F2));
      expect(BoardColors.padTextValue(false), const Color(0xFF5341D8));
      expect(BoardColors.padBgValue(false), const Color(0xFFE0DCFF));
      expect(BoardColors.padBgDisabled(true), const Color(0xFF252042));
      expect(BoardColors.controlIconDefault(true), const Color(0xFF65E9FF));
      expect(
          BoardColors.controlCircleBaseColor(false), const Color(0xFF6E56FF));
      expect(BoardColors.controlCircleBaseColor(true), const Color(0xFF65E9FF));
      expect(BoardColors.remainingCountText(false), const Color(0xFF716A96));
    });

    test('app palette identity colors', () {
      expect(AppPalette.bgGradient(false),
          const [Color(0xFFEDE8FF), Color(0xFFDDF1FF)]);
      expect(AppPalette.bgGradient(true),
          const [Color(0xFF1C1440), Color(0xFF0D0B1E)]);
      expect(AppPalette.primaryGradient(false),
          const [Color(0xFF8B72FF), Color(0xFF6E56FF)]);
      expect(AppPalette.cardSurface(true), const Color(0xFF241E48));
      expect(AppPalette.cardShadow(false),
          const Color(0xFF6E56FF).withValues(alpha: 0.14));
    });
  });

  test('byName resolves ids and falls back to classic on unknown/null', () {
    expect(ThemePack.byName('ocean'), ThemePack.ocean);
    expect(ThemePack.byName('sepiaPaper'), ThemePack.sepiaPaper);
    expect(ThemePack.byName('does-not-exist'), ThemePack.classic);
    expect(ThemePack.byName(null), ThemePack.classic);
  });

  test('all packs have unique ids and only classic is free', () {
    expect(ThemePack.all.map((p) => p.id).toSet().length, ThemePack.all.length);
    expect(ThemePack.all.where((p) => !p.isPremium).toList(),
        [ThemePack.classic]);
  });

  test('monochrome yields a truly greyscale ColorScheme (no green primary)',
      () {
    // ColorScheme.fromSeed's default variant force-raises chroma, turning a
    // grey seed into a green-ish primary — the monochrome pack must opt into
    // the greyscale variant instead.
    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: ThemePack.monochrome.of(brightness == Brightness.dark).seed,
        brightness: brightness,
        dynamicSchemeVariant: ThemePack.monochrome.schemeVariant,
      );
      expect(HSLColor.fromColor(scheme.primary).saturation, lessThan(0.01),
          reason: '$brightness primary should be grey');
    }
    // The other packs keep the colorful default variant.
    expect(ThemePack.classic.schemeVariant, DynamicSchemeVariant.tonalSpot);
  });

  test('switching the active pack changes delegated colors', () {
    ThemePack.active = ThemePack.ocean;
    expect(BoardColors.outerBorder(false), const Color(0xFF0277BD));
    expect(AppPalette.primaryGradient(false),
        const [Color(0xFF29B6F6), Color(0xFF0277BD)]);
  });

  group('SettingsController load clamp', () {
    test('a stored premium pack falls back to classic without entitlement',
        () async {
      SharedPreferences.setMockInitialValues({'theme_pack': 'ocean'});
      await PremiumController.instance.setMockPremium(false);
      final settings = SettingsController();
      await settings.load();
      expect(settings.themePack, ThemePack.classic);
      expect(ThemePack.active, ThemePack.classic);
    });

    test('a stored premium pack is kept with entitlement', () async {
      SharedPreferences.setMockInitialValues({'theme_pack': 'ocean'});
      await PremiumController.instance.setMockPremium(true);
      final settings = SettingsController();
      await settings.load();
      expect(settings.themePack, ThemePack.ocean);
      expect(ThemePack.active, ThemePack.ocean);
      await PremiumController.instance.setMockPremium(false);
    });
  });
}
