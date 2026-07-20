import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../models/stats.dart';
import '../models/sudoku_puzzle.dart';

class StorageService {
  static const _inProgressKey = 'in_progress_game';
  static const _statsKey = 'stats';
  static const _themeModeKey = 'theme_mode';
  static const _localeOverrideKey = 'locale_override';
  static const _hapticsEnabledKey = 'haptics_enabled';
  static const _soundEnabledKey = 'sound_enabled';
  static const _wrongNoteWarningEnabledKey = 'wrong_note_warning_enabled';
  static const _autoRemoveNotesEnabledKey = 'auto_remove_notes_enabled';
  static const _puzzleQueueKey = 'puzzle_queue';
  static const _raceProgressKey = 'race_in_progress';
  static const _seenHomeTutorialKey = 'seen_home_tutorial';
  static const _seenGameTutorialKey = 'seen_game_tutorial';
  static const _seenRaceTutorialKey = 'seen_race_tutorial';
  static const _celebratedSeasonKey = 'celebrated_season_id';

  Future<void> saveInProgressGame(GameSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inProgressKey, jsonEncode(snapshot.toJson()));
  }

  Future<GameSnapshot?> loadInProgressGame() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inProgressKey);
    if (raw == null) return null;
    return GameSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearInProgressGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inProgressKey);
  }

  /// Persists the current race's board so a killed-and-relaunched app can
  /// resume it (see RaceController) instead of forfeiting. Keyed by race id
  /// so a stale snapshot from a different, already-finished race is never
  /// resumed by mistake.
  Future<void> saveRaceProgress(String raceId, GameSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _raceProgressKey,
        jsonEncode({'raceId': raceId, 'snapshot': snapshot.toJson()}));
  }

  Future<({String raceId, GameSnapshot snapshot})?> loadRaceProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_raceProgressKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (
      raceId: json['raceId'] as String,
      snapshot:
          GameSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
    );
  }

  Future<void> clearRaceProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_raceProgressKey);
  }

  Future<Stats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) return Stats.empty();
    return Stats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> recordGameResult({
    required Difficulty difficulty,
    required bool won,
    int? finishTimeSeconds,
    int? mistakes,
    int? hintsUsed,
  }) async {
    final stats = await getStats();
    final current = stats.byDifficulty[difficulty]!;
    final isNewBest = won &&
        finishTimeSeconds != null &&
        (current.bestTimeSeconds == null ||
            finishTimeSeconds < current.bestTimeSeconds!);
    final isPerfectWin = won && mistakes == 0 && hintsUsed == 0;
    final isTimedWin = won && finishTimeSeconds != null;

    stats.byDifficulty[difficulty] = DifficultyStats(
      played: current.played + 1,
      won: won ? current.won + 1 : current.won,
      bestTimeSeconds: isNewBest ? finishTimeSeconds : current.bestTimeSeconds,
      perfectWins: isPerfectWin ? current.perfectWins + 1 : current.perfectWins,
      totalWinSeconds: isTimedWin
          ? current.totalWinSeconds + finishTimeSeconds
          : current.totalWinSeconds,
      timedWins: isTimedWin ? current.timedWins + 1 : current.timedWins,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    return raw == null ? ThemeMode.system : ThemeMode.values.byName(raw);
  }

  /// Null means "follow system" — the same tri-state pattern as
  /// [ThemeMode.system], just without a dedicated enum value since [Locale]
  /// has no such member.
  Future<void> saveLocaleOverride(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeOverrideKey);
    } else {
      await prefs.setString(_localeOverrideKey, locale.languageCode);
    }
  }

  Future<Locale?> loadLocaleOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localeOverrideKey);
    return raw == null ? null : Locale(raw);
  }

  Future<void> saveHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsEnabledKey, enabled);
  }

  Future<bool> loadHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticsEnabledKey) ?? true;
  }

  Future<void> saveSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }

  Future<bool> loadSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true;
  }

  Future<void> saveWrongNoteWarningEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wrongNoteWarningEnabledKey, enabled);
  }

  Future<bool> loadWrongNoteWarningEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wrongNoteWarningEnabledKey) ?? true;
  }

  Future<void> saveAutoRemoveNotesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRemoveNotesEnabledKey, enabled);
  }

  Future<bool> loadAutoRemoveNotesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoRemoveNotesEnabledKey) ?? true;
  }

  Future<void> savePuzzleQueue(Map<Difficulty, List<SudokuPuzzle>> queues) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      for (final entry in queues.entries)
        entry.key.name: entry.value.map((p) => p.toJson()).toList(),
    };
    await prefs.setString(_puzzleQueueKey, jsonEncode(json));
  }

  Future<void> saveSeenHomeTutorial(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenHomeTutorialKey, seen);
  }

  Future<bool> loadSeenHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenHomeTutorialKey) ?? false;
  }

  Future<void> saveSeenGameTutorial(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenGameTutorialKey, seen);
  }

  Future<bool> loadSeenGameTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenGameTutorialKey) ?? false;
  }

  Future<void> saveSeenRaceTutorial(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenRaceTutorialKey, seen);
  }

  Future<bool> loadSeenRaceTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenRaceTutorialKey) ?? false;
  }

  /// The highest archived season id whose end-of-season summary dialog has
  /// already been shown (0 = never shown) — so the race lobby celebrates
  /// each closed season exactly once.
  Future<void> saveCelebratedSeasonId(int seasonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_celebratedSeasonKey, seasonId);
  }

  Future<int> loadCelebratedSeasonId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_celebratedSeasonKey) ?? 0;
  }

  /// Clears all first-entry tutorial flags so they re-trigger on next visit —
  /// used by the "replay tutorial" action in the settings sheet.
  Future<void> resetTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenHomeTutorialKey);
    await prefs.remove(_seenGameTutorialKey);
    await prefs.remove(_seenRaceTutorialKey);
  }

  Future<Map<Difficulty, List<SudokuPuzzle>>> loadPuzzleQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final result = {for (final d in Difficulty.values) d: <SudokuPuzzle>[]};
    final raw = prefs.getString(_puzzleQueueKey);
    if (raw == null) return result;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    for (final entry in json.entries) {
      result[difficultyFromName(entry.key)] = (entry.value as List<dynamic>)
          .map((p) => SudokuPuzzle.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    return result;
  }
}
