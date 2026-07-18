import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../state/settings_controller.dart';
import '../theme/app_palette.dart';

/// The settings bottom sheet (theme / language / haptics / sound) — grew
/// out of an inline method on HomeScreen. Selection rows are pill chips in
/// a [Wrap] rather than segmented buttons, so the longer English labels
/// ("Follow System") flow to a new line instead of overflowing.
void showSettingsSheet(BuildContext context, SettingsController settings) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppPalette.cardSurface(AppPalette.isDark(context)),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
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
            ],
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
          style: const TextStyle(fontFamily: 'Jua', fontSize: 17),
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
