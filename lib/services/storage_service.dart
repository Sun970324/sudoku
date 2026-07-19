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
  static const _puzzleQueueKey = 'puzzle_queue';

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
  }) async {
    final stats = await getStats();
    final current = stats.byDifficulty[difficulty]!;
    final isNewBest = won &&
        finishTimeSeconds != null &&
        (current.bestTimeSeconds == null ||
            finishTimeSeconds < current.bestTimeSeconds!);
    final isPerfectWin = won && mistakes == 0;
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

  Future<void> savePuzzleQueue(Map<Difficulty, List<SudokuPuzzle>> queues) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      for (final entry in queues.entries)
        entry.key.name: entry.value.map((p) => p.toJson()).toList(),
    };
    await prefs.setString(_puzzleQueueKey, jsonEncode(json));
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
