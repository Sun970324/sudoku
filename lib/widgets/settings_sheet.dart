import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../content/policy_texts.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/hint.dart';
import '../screens/policy_screen.dart';
import '../screens/premium/premium_lock_screen.dart';
import '../services/haptic_service.dart';
import '../services/technique_queue_manager.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../state/premium_controller.dart';
import '../state/settings_controller.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../theme/theme_pack.dart';
import 'pixel_icon.dart';

/// The settings bottom sheet (theme / language / haptics / sound) — grew
/// out of an inline method on HomeScreen. Selection rows are pill chips in
/// a [Wrap] rather than segmented buttons, so the longer English labels
/// ("Follow System") flow to a new line instead of overflowing.
void showSettingsSheet(
  BuildContext context,
  SettingsController settings, {
  VoidCallback? onReplayTutorial,
  void Function(HintTechnique technique)? onHintDemo,
}) {
  showModalBottomSheet<void>(
    context: context,
    // Painted inside the AnimatedBuilder (not here) so it tracks the theme:
    // a color captured at show-time would stay frozen when the user switches
    // theme from within the sheet — only the background would fail to update.
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        // Material (not a plain Container) so the ListTiles/SwitchListTiles
        // inside have a surface to paint their ink splashes on — an opaque
        // Container between the sheet's Material and the tiles would hide
        // them (Flutter warns about exactly this).
        return Material(
          color: AppPalette.cardSurface(AppPalette.isDark(context)),
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _SectionTitle(l10n.themeSectionTitle),
                _ChoiceRow<ThemeMode>(
                  value: settings.themeMode,
                  onChanged: (mode) => settings.setThemeMode(mode),
                  options: [
                    (ThemeMode.system, l10n.followSystemTheme),
                    (ThemeMode.light, l10n.lightTheme),
                    (ThemeMode.dark, l10n.darkTheme),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle(l10n.themePackSectionTitle),
                // Also rebuilds on premium changes: the debug premium toggle
                // lives in this same sheet, and the lock badges must follow it.
                AnimatedBuilder(
                  animation: PremiumController.instance,
                  builder: (context, _) => _ThemePackRow(settings: settings),
                ),
                const SizedBox(height: 16),
                _SectionTitle(l10n.boardFontSectionTitle),
                _ChoiceRow<BoardFont>(
                  value: settings.boardFont,
                  onChanged: settings.setBoardFont,
                  options: [
                    (BoardFont.classic, l10n.boardFontClassic),
                    (BoardFont.dot, l10n.boardFontDot),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle(l10n.languageSectionTitle),
                _ChoiceRow<Locale?>(
                  value: settings.localeOverride,
                  onChanged: settings.setLocaleOverride,
                  options: [
                    (null, l10n.followSystemLanguage),
                    (const Locale('ko'), l10n.koreanLanguage),
                    (const Locale('en'), l10n.englishLanguage),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.hapticsLabel),
                  value: settings.hapticsEnabled,
                  onChanged: (v) {
                    settings.setHapticsEnabled(v);
                    if (v) HapticService.selection();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.soundLabel),
                  value: settings.soundEnabled,
                  onChanged: (v) {
                    settings.setSoundEnabled(v);
                    if (v) SoundService.click();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.wrongNoteWarningLabel),
                  subtitle: Text(l10n.wrongNoteWarningDescription),
                  value: settings.wrongNoteWarningEnabled,
                  onChanged: settings.setWrongNoteWarningEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.autoRemoveNotesLabel),
                  subtitle: Text(l10n.autoRemoveNotesDescription),
                  value: settings.autoRemoveNotesEnabled,
                  onChanged: settings.setAutoRemoveNotesEnabled,
                ),
                // Debug-only mockup toggle for the premium entitlement, so
                // premium-gated features can be exercised without real IAP.
                // Never shown in release builds.
                if (kDebugMode)
                  AnimatedBuilder(
                    animation: PremiumController.instance,
                    builder: (context, _) {
                      final ko = Localizations.localeOf(context).languageCode ==
                          'ko';
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ko ? '프리미엄 (디버그)' : 'Premium (debug)'),
                        subtitle: Text(ko
                            ? '결제 목업 · 유료 혜택 잠금 해제'
                            : 'Billing mock · unlock premium'),
                        value: PremiumController.instance.isPremium,
                        onChanged: (v) =>
                            PremiumController.instance.setMockPremium(v),
                      );
                    },
                  ),
                if (kDebugMode && onHintDemo != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(
                        Localizations.localeOf(context).languageCode == 'ko'
                            ? '힌트 데모 (디버그)'
                            : 'Hint demos (debug)'),
                    subtitle: Text(
                        Localizations.localeOf(context).languageCode == 'ko'
                            ? '기법 선택 → 보장 보드 로드 · 벌레 아이콘으로 확인'
                            : 'Pick a technique · loads its board · tap the bug icon'),
                    onTap: () async {
                      final picked = await showDialog<HintTechnique>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Hint demo'),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          content: SizedBox(
                            width: double.maxFinite,
                            height: 480,
                            child: ListView(
                              children: [
                                for (final technique in TechniqueQueueManager
                                    .supportedTechniques)
                                  ListTile(
                                    dense: true,
                                    title:
                                        Text(technique.label(dialogContext)),
                                    trailing: Text(
                                      techniqueDifficulty[technique]!.name,
                                      style: Theme.of(dialogContext)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    onTap: () => Navigator.pop(
                                        dialogContext, technique),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (picked == null) return;
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      onHintDemo(picked);
                    },
                  ),
                const Divider(),
                if (onReplayTutorial != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(PixelIcons.lightbulb),
                    title: Text(l10n.tutorialReplayLabel),
                    trailing: const Icon(PixelIcons.chevronRight),
                    onTap: () async {
                      await StorageService().resetTutorials();
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      onReplayTutorial();
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(PixelIcons.shield),
                  title: Text(l10n.privacyPolicyTitle),
                  trailing: const Icon(PixelIcons.chevronRight),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PolicyScreen(
                        title: l10n.privacyPolicyTitle,
                        bodyKo: privacyPolicyKo,
                        bodyEn: privacyPolicyEn,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(PixelIcons.document),
                  title: Text(l10n.termsOfServiceTitle),
                  trailing: const Icon(PixelIcons.chevronRight),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PolicyScreen(
                        title: l10n.termsOfServiceTitle,
                        bodyKo: termsOfServiceKo,
                        bodyEn: termsOfServiceEn,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(PixelIcons.creativeCommons),
                  title: Text(
                    Localizations.localeOf(context).languageCode == 'ko'
                        ? '오픈소스 라이선스'
                        : 'Open source licenses',
                  ),
                  trailing: const Icon(PixelIcons.chevronRight),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 17),
        ),
      );
}

/// The theme-pack picker: one tappable swatch per pack, premium packs locked
/// behind the upsell page for free users.
class _ThemePackRow extends StatelessWidget {
  const _ThemePackRow({required this.settings});

  final SettingsController settings;

  String _nameOf(AppLocalizations l10n, ThemePack pack) => switch (pack.id) {
        ThemePackId.classic => l10n.themePackClassic,
        ThemePackId.midnightNeon => l10n.themePackMidnightNeon,
        ThemePackId.sepiaPaper => l10n.themePackSepiaPaper,
        ThemePackId.monochrome => l10n.themePackMonochrome,
        ThemePackId.forest => l10n.themePackForest,
        ThemePackId.ocean => l10n.themePackOcean,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    final isPremiumUser = PremiumController.instance.isPremium;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final pack in ThemePack.all)
          _ThemePackChip(
            name: _nameOf(l10n, pack),
            colors: pack.of(isDark),
            selected: settings.themePack == pack,
            locked: pack.isPremium && !isPremiumUser,
            onTap: () {
              if (pack.isPremium && !isPremiumUser) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PremiumLockScreen(description: l10n.themePremiumBody),
                  ),
                );
              } else {
                settings.setThemePack(pack);
              }
            },
          ),
      ],
    );
  }
}

class _ThemePackChip extends StatelessWidget {
  const _ThemePackChip({
    required this.name,
    required this.colors,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String name;
  final ThemePackColors colors;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.primaryGradient,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                // A corner peek of the pack's board cell + digit color, so the
                // swatch hints at the in-game look, not just the button color.
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: colors.cellDefault,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.innerBorder),
                    ),
                    child: Center(
                      child: Text(
                        '5',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.0,
                          color: colors.textEntered,
                        ),
                      ),
                    ),
                  ),
                ),
                if (locked)
                  const Center(
                    child: Icon(Icons.lock, size: 18, color: Colors.white),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, String)> options;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (optionValue, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == optionValue,
            onSelected: (_) => onChanged(optionValue),
            selectedColor: primary.withValues(alpha: 0.18),
            labelStyle: TextStyle(
              color: value == optionValue ? primary : null,
              fontWeight:
                  value == optionValue ? FontWeight.bold : FontWeight.normal,
            ),
            shape: const StadiumBorder(),
            showCheckmark: false,
          ),
      ],
    );
  }
}
