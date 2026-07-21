import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../content/policy_texts.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/policy_screen.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../state/premium_controller.dart';
import '../state/settings_controller.dart';
import '../theme/app_palette.dart';
import 'pixel_icon.dart';

/// The settings bottom sheet (theme / language / haptics / sound) — grew
/// out of an inline method on HomeScreen. Selection rows are pill chips in
/// a [Wrap] rather than segmented buttons, so the longer English labels
/// ("Follow System") flow to a new line instead of overflowing.
void showSettingsSheet(
  BuildContext context,
  SettingsController settings, {
  VoidCallback? onReplayTutorial,
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
