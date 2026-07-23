import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';
import '../models/favorite_puzzle.dart';
import '../models/game_replay.dart';
import '../models/game_snapshot.dart';
import '../models/hint.dart';
import '../models/stats.dart';
import '../models/sudoku_puzzle.dart';

class StorageService {
  static const _inProgressKey = 'in_progress_game';
  static const _replaysKey = 'game_replays';
  static const _raceReplaysKey = 'race_replays';
  static const _favoritesKey = 'favorite_puzzles';

  /// How many finished solo games are kept for replay — newest first, oldest
  /// pruned past this. Premium-only feature; see [PremiumController].
  static const maxReplays = 10;

  /// Cap on saved favorite puzzles. Unlike replays these are user-curated, so
  /// the cap blocks new saves rather than evicting an existing favorite.
  static const maxFavorites = 30;
  static const _statsKey = 'stats';
  static const _themeModeKey = 'theme_mode';
  static const _localeOverrideKey = 'locale_override';
  static const _hapticsEnabledKey = 'haptics_enabled';
  static const _soundEnabledKey = 'sound_enabled';
  static const _wrongNoteWarningEnabledKey = 'wrong_note_warning_enabled';
  static const _autoRemoveNotesEnabledKey = 'auto_remove_notes_enabled';
  static const _quickInputEnabledKey = 'quick_input_enabled';
  static const _premiumMockKey = 'premium_mock';
  static const _puzzleQueueKey = 'puzzle_queue';
  static const _techniqueQueueKey = 'technique_queue';
  static const _raceProgressKey = 'race_in_progress';
  static const _seenHomeTutorialKey = 'seen_home_tutorial';
  static const _seenGameTutorialKey = 'seen_game_tutorial';
  static const _seenRaceTutorialKey = 'seen_race_tutorial';
  static const _seenStatsTutorialKey = 'seen_stats_tutorial';
  static const _seenQuickInputTutorialKey = 'seen_quick_input_tutorial';
  static const _celebratedSeasonKey = 'celebrated_season_id';
  static const _themePackKey = 'theme_pack';
  static const _boardFontKey = 'board_font';
  static const _techniqueCodexKey = 'technique_codex';

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

  /// Prepends [replay] to the stored solo-game replays, newest first, and
  /// prunes the list to [maxReplays]. Called when a solo game finishes
  /// (win or game-over); abandoned and daily games are never recorded.
  Future<void> saveReplay(GameReplay replay) async {
    final replays = await loadReplays();
    replays.insert(0, replay);
    if (replays.length > maxReplays) {
      replays.removeRange(maxReplays, replays.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _replaysKey, jsonEncode(replays.map((r) => r.toJson()).toList()));
  }

  Future<List<GameReplay>> loadReplays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_replaysKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => GameReplay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Race replays live in their own most-recent-[maxReplays] bucket (separate
  /// from solo games), keyed by race id so the race lobby can surface a replay
  /// for a history entry. Re-finishing the same race replaces its old entry.
  Future<void> saveRaceReplay(GameReplay replay) async {
    final replays = await loadRaceReplays();
    replays.removeWhere((r) => r.raceId == replay.raceId);
    replays.insert(0, replay);
    if (replays.length > maxReplays) {
      replays.removeRange(maxReplays, replays.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _raceReplaysKey, jsonEncode(replays.map((r) => r.toJson()).toList()));
  }

  Future<List<GameReplay>> loadRaceReplays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_raceReplaysKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => GameReplay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Identity of a puzzle for favorites dedup/lookup — its givens grid, which
  /// uniquely pins the puzzle (the same givens always have the same solution).
  static String _puzzleKey(SudokuPuzzle puzzle) =>
      jsonEncode(puzzle.puzzle.toJson());

  Future<List<FavoritePuzzle>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => FavoritePuzzle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeFavorites(List<FavoritePuzzle> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _favoritesKey, jsonEncode(favorites.map((f) => f.toJson()).toList()));
  }

  /// Saves [puzzle] to favorites (newest first). Returns false without saving
  /// when already at [maxFavorites] and [puzzle] isn't among them — the user
  /// must remove one first (curated list, nothing auto-evicted). Already-saved
  /// puzzles are a no-op returning true.
  Future<bool> saveFavorite(SudokuPuzzle puzzle) async {
    final favorites = await loadFavorites();
    final key = _puzzleKey(puzzle);
    if (favorites.any((f) => _puzzleKey(f.puzzle) == key)) return true;
    if (favorites.length >= maxFavorites) return false;
    favorites.insert(
        0, FavoritePuzzle(puzzle: puzzle, savedAt: DateTime.now()));
    await _writeFavorites(favorites);
    return true;
  }

  Future<void> removeFavorite(SudokuPuzzle puzzle) async {
    final favorites = await loadFavorites();
    final key = _puzzleKey(puzzle);
    favorites.removeWhere((f) => _puzzleKey(f.puzzle) == key);
    await _writeFavorites(favorites);
  }

  Future<bool> isFavorite(SudokuPuzzle puzzle) async {
    final favorites = await loadFavorites();
    final key = _puzzleKey(puzzle);
    return favorites.any((f) => _puzzleKey(f.puzzle) == key);
  }

  /// Merges one solved puzzle's technique counts into the cumulative codex:
  /// per technique, `uses` grows by that puzzle's count and `puzzles` by one.
  /// Called on a solo win, where the counts are already computed for the
  /// result screen (see GameScreen._onWin) — so recording costs nothing extra.
  Future<void> recordTechniqueCounts(Map<HintTechnique, int> counts) async {
    if (counts.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_techniqueCodexKey);
    final json = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    for (final entry in counts.entries) {
      final existing = json[entry.key.name] as Map<String, dynamic>?;
      json[entry.key.name] = {
        'u': (existing?['u'] as int? ?? 0) + entry.value,
        'p': (existing?['p'] as int? ?? 0) + 1,
      };
    }
    await prefs.setString(_techniqueCodexKey, jsonEncode(json));
  }

  /// The cumulative technique codex: total uses and number of solved puzzles
  /// each technique appeared in. Techniques never encountered are absent.
  /// Unknown stored names (a removed technique) are skipped, not fatal.
  Future<Map<HintTechnique, ({int uses, int puzzles})>>
      loadTechniqueCodex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_techniqueCodexKey);
    if (raw == null) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final result = <HintTechnique, ({int uses, int puzzles})>{};
    for (final entry in json.entries) {
      final technique = HintTechnique.values
          .where((t) => t.name == entry.key)
          .firstOrNull;
      if (technique == null) continue;
      final value = entry.value as Map<String, dynamic>;
      result[technique] =
          (uses: value['u'] as int? ?? 0, puzzles: value['p'] as int? ?? 0);
    }
    return result;
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

  /// The debug/mockup premium entitlement flag — see [PremiumController] and
  /// [MockPurchaseService]. Placeholder for the real store entitlement.
  Future<void> savePremiumMock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumMockKey, value);
  }

  Future<bool> loadPremiumMock() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumMockKey) ?? false;
  }

  Future<void> saveQuickInputEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quickInputEnabledKey, enabled);
  }

  Future<bool> loadQuickInputEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_quickInputEnabledKey) ?? false;
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

  /// The technique-practice board queue (see TechniqueQueueManager) — same
  /// shape as the per-difficulty puzzle queue, keyed by practice-item id.
  /// Unknown ids are skipped on load so renaming/removing an item can never
  /// brick startup.
  Future<void> saveTechniqueQueue(
      Map<String, List<SudokuPuzzle>> queues) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      for (final entry in queues.entries)
        entry.key: entry.value.map((p) => p.toJson()).toList(),
    };
    await prefs.setString(_techniqueQueueKey, jsonEncode(json));
  }

  Future<Map<String, List<SudokuPuzzle>>> loadTechniqueQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, List<SudokuPuzzle>>{};
    final raw = prefs.getString(_techniqueQueueKey);
    if (raw == null) return result;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    for (final entry in json.entries) {
      result[entry.key] = (entry.value as List<dynamic>)
          .map((p) => SudokuPuzzle.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    return result;
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

  Future<void> saveSeenStatsTutorial(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenStatsTutorialKey, seen);
  }

  Future<bool> loadSeenStatsTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenStatsTutorialKey) ?? false;
  }

  Future<void> saveSeenQuickInputTutorial(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenQuickInputTutorialKey, seen);
  }

  Future<bool> loadSeenQuickInputTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenQuickInputTutorialKey) ?? false;
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

  /// The active theme pack, stored by enum name. Null (never chosen) and
  /// unknown names both resolve to classic — see ThemePack.byName.
  Future<void> saveThemePackName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePackKey, name);
  }

  Future<String?> loadThemePackName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themePackKey);
  }

  /// The board/number-pad digit font, stored by [BoardFont] enum name. Null
  /// (never chosen) and unknown names both resolve to classic — see
  /// SettingsController.load.
  Future<void> saveBoardFontName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_boardFontKey, name);
  }

  Future<String?> loadBoardFontName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_boardFontKey);
  }

  /// Clears all first-entry tutorial flags so they re-trigger on next visit —
  /// used by the "replay tutorial" action in the settings sheet.
  Future<void> resetTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenHomeTutorialKey);
    await prefs.remove(_seenGameTutorialKey);
    await prefs.remove(_seenRaceTutorialKey);
    await prefs.remove(_seenStatsTutorialKey);
    await prefs.remove(_seenQuickInputTutorialKey);
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
