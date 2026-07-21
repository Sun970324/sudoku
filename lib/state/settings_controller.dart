import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../theme/theme_pack.dart';
import 'game_controller.dart';
import 'premium_controller.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({StorageService? storage})
      : _storage = storage ?? StorageService();

  final StorageService _storage;
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _localeOverride;
  bool _hapticsEnabled = true;
  bool _soundEnabled = true;
  bool _wrongNoteWarningEnabled = true;
  bool _autoRemoveNotesEnabled = true;
  ThemePack _themePack = ThemePack.classic;

  ThemeMode get themeMode => _themeMode;

  /// Null means "follow system locale" — see [StorageService.loadLocaleOverride].
  Locale? get localeOverride => _localeOverride;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get wrongNoteWarningEnabled => _wrongNoteWarningEnabled;
  bool get autoRemoveNotesEnabled => _autoRemoveNotesEnabled;
  ThemePack get themePack => _themePack;

  Future<void> load() async {
    _themeMode = await _storage.loadThemeMode();
    _localeOverride = await _storage.loadLocaleOverride();
    _hapticsEnabled = await _storage.loadHapticsEnabled();
    _soundEnabled = await _storage.loadSoundEnabled();
    _wrongNoteWarningEnabled = await _storage.loadWrongNoteWarningEnabled();
    _autoRemoveNotesEnabled = await _storage.loadAutoRemoveNotesEnabled();
    HapticService.enabled = _hapticsEnabled;
    SoundService.enabled = _soundEnabled;
    GameController.wrongNoteWarningEnabled = _wrongNoteWarningEnabled;
    GameController.autoRemoveNotesEnabled = _autoRemoveNotesEnabled;
    // No field/setter of its own: the quick-input toggle lives on the game
    // screen (not the settings sheet), which persists changes directly via
    // StorageService — load-time push into the static default is all that's
    // needed here.
    GameController.quickInputDefault = await _storage.loadQuickInputEnabled();
    // Resolve the stored theme pack, clamping a premium pack back to classic
    // when the entitlement is gone (expired/debug-toggled off) — requires
    // PremiumController.load() to have run first, see main(). The stored
    // name is left untouched so regaining premium restores the choice.
    final pack = ThemePack.byName(await _storage.loadThemePackName());
    _themePack = pack.isPremium && !PremiumController.instance.isPremium
        ? ThemePack.classic
        : pack;
    ThemePack.active = _themePack;
    notifyListeners();
  }

  Future<void> setThemePack(ThemePack pack) async {
    if (pack == _themePack) return;
    _themePack = pack;
    ThemePack.active = pack;
    notifyListeners();
    await _storage.saveThemePackName(pack.id.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.saveThemeMode(mode);
  }

  Future<void> setLocaleOverride(Locale? locale) async {
    if (locale == _localeOverride) return;
    _localeOverride = locale;
    notifyListeners();
    await _storage.saveLocaleOverride(locale);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (enabled == _hapticsEnabled) return;
    _hapticsEnabled = enabled;
    HapticService.enabled = enabled;
    notifyListeners();
    await _storage.saveHapticsEnabled(enabled);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    if (enabled == _soundEnabled) return;
    _soundEnabled = enabled;
    SoundService.enabled = enabled;
    notifyListeners();
    await _storage.saveSoundEnabled(enabled);
  }

  Future<void> setWrongNoteWarningEnabled(bool enabled) async {
    if (enabled == _wrongNoteWarningEnabled) return;
    _wrongNoteWarningEnabled = enabled;
    GameController.wrongNoteWarningEnabled = enabled;
    notifyListeners();
    await _storage.saveWrongNoteWarningEnabled(enabled);
  }

  Future<void> setAutoRemoveNotesEnabled(bool enabled) async {
    if (enabled == _autoRemoveNotesEnabled) return;
    _autoRemoveNotesEnabled = enabled;
    GameController.autoRemoveNotesEnabled = enabled;
    notifyListeners();
    await _storage.saveAutoRemoveNotesEnabled(enabled);
  }
}
