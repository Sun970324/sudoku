import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({StorageService? storage})
      : _storage = storage ?? StorageService();

  final StorageService _storage;
  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticsEnabled = true;
  bool _soundEnabled = true;

  ThemeMode get themeMode => _themeMode;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get soundEnabled => _soundEnabled;

  Future<void> load() async {
    _themeMode = await _storage.loadThemeMode();
    _hapticsEnabled = await _storage.loadHapticsEnabled();
    _soundEnabled = await _storage.loadSoundEnabled();
    HapticService.enabled = _hapticsEnabled;
    SoundService.enabled = _soundEnabled;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.saveThemeMode(mode);
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
}
