import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../services/haptic_service.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../state/settings_controller.dart';
import '../widgets/sudoku_preview_board.dart';
import 'game_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.puzzleQueue,
    this.initialResumeSnapshot,
  });

  final SettingsController settings;
  final PuzzleQueueManager puzzleQueue;

  /// A game already in progress at app launch. When non-null, pushed
  /// automatically right after the first frame so the app still opens
  /// straight into the game — but with this [HomeScreen] underneath it in
  /// the navigator stack, unlike setting [GameScreen] directly as the
  /// app's `home`, which would leave it with no route to pop back to.
  final GameSnapshot? initialResumeSnapshot;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  late final FixedExtentScrollController _wheelController =
      FixedExtentScrollController();
  GameSnapshot? _savedGame;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedGame();
    final snapshot = widget.initialResumeSnapshot;
    if (snapshot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openGame(GameScreen.resume(resumeSnapshot: snapshot));
      });
    }
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedGame() async {
    final snapshot = await _storage.loadInProgressGame();
    if (!mounted) return;
    setState(() => _savedGame = snapshot);
  }

  Future<void> _openGame(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadSavedGame();
  }

  void _selectDifficulty(int index) {
    if (index == _selectedIndex) return;
    // onSelectedItemChanged fires as the wheel settles on the new item,
    // so _selectedIndex updates from that callback rather than here.
    _wheelController.animateToItem(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onStartPressed() {
    final difficulty = Difficulty.values[_selectedIndex];
    final puzzle = widget.puzzleQueue.take(difficulty);
    _openGame(GameScreen.newGame(difficulty: difficulty, puzzle: puzzle));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedDifficulty = Difficulty.values[_selectedIndex];
    final previewPuzzle = widget.puzzleQueue.peek(selectedDifficulty);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        // Flutter's AppBar swaps to colorScheme.surfaceContainer once
        // scrolled-under is detected (any Scrollable in the body, e.g. the
        // difficulty wheel, triggers this) — pinning backgroundColor to a
        // fixed value makes it resolve the same regardless of scroll state.
        backgroundColor: Theme.of(context).colorScheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Only added ahead of the grid when the continue-game button is
            // showing — otherwise Expanded (and the grid's own top: 8
            // padding) is the very first thing in this Column, matching
            // GameScreen exactly so the preview sits at the same position.
            if (_savedGame != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    _openGame(GameScreen.resume(resumeSnapshot: _savedGame!)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text(l10n.continueGame,
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: Padding(
                // Matches GameScreen's grid padding/alignment exactly. Width
                // is also pinned explicitly (rather than left to whatever
                // height Expanded happens to have left after the wheel and
                // buttons below) so this preview always renders at the same
                // size and top position as the real grid it Hero's into,
                // regardless of this screen's other content.
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width - 8,
                    child: Hero(
                      // Paired with the same tag on SudokuGridWidget in
                      // GameScreen so pushing into the game animates this
                      // preview board growing into the real one.
                      tag: 'sudoku-board',
                      child: SudokuPreviewBoard(puzzle: previewPuzzle),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListWheelScrollView(
                controller: _wheelController,
                itemExtent: 40,
                diameterRatio: 1.8,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) =>
                    setState(() => _selectedIndex = index),
                children: Difficulty.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final difficulty = entry.value;
                  final isSelected = difficulty == selectedDifficulty;
                  return GestureDetector(
                    onTap: () => _selectDifficulty(index),
                    child: Center(
                      child: Text(
                        difficulty.label(context),
                        style: TextStyle(
                          fontSize: isSelected ? 20 : 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _onStartPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child:
                    Text(l10n.startGame, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _openGame(const StatsScreen()),
              child: Text(l10n.viewStats),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) {
          final l10n = AppLocalizations.of(context)!;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(l10n.themeSectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                RadioGroup<ThemeMode>(
                  groupValue: widget.settings.themeMode,
                  onChanged: (mode) => widget.settings.setThemeMode(mode!),
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.followSystemTheme),
                        value: ThemeMode.system,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.lightTheme),
                        value: ThemeMode.light,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.darkTheme),
                        value: ThemeMode.dark,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(l10n.languageSectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                RadioGroup<Locale?>(
                  groupValue: widget.settings.localeOverride,
                  onChanged: (locale) =>
                      widget.settings.setLocaleOverride(locale),
                  child: Column(
                    children: [
                      RadioListTile<Locale?>(
                        title: Text(l10n.followSystemLanguage),
                        value: null,
                      ),
                      RadioListTile<Locale?>(
                        title: Text(l10n.koreanLanguage),
                        value: const Locale('ko'),
                      ),
                      RadioListTile<Locale?>(
                        title: Text(l10n.englishLanguage),
                        value: const Locale('en'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(l10n.hapticsLabel),
                  value: widget.settings.hapticsEnabled,
                  onChanged: (v) {
                    widget.settings.setHapticsEnabled(v);
                    if (v) HapticService.selection();
                  },
                ),
                SwitchListTile(
                  title: Text(l10n.soundLabel),
                  value: widget.settings.soundEnabled,
                  onChanged: (v) {
                    widget.settings.setSoundEnabled(v);
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
}
