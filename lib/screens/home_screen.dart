import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../models/race.dart';
import '../models/sudoku_puzzle.dart';
import '../models/tier.dart';
import '../services/haptic_service.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/race_service.dart';
import '../services/sound_service.dart';
import '../state/auth_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/sudoku_preview_board.dart';
import 'game_screen.dart';
import 'my_page_screen.dart';
import 'puzzle_share/enter_code_screen.dart';
import 'race/matchmaking_screen.dart';
import 'race/race_result_screen.dart';
import 'stats_screen.dart';
import '../state/race_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.puzzleQueue,
    required this.auth,
    this.initialResumeSnapshot,
  });

  final SettingsController settings;
  final PuzzleQueueManager puzzleQueue;
  final AuthController auth;

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
  late final FixedExtentScrollController _wheelController =
      FixedExtentScrollController();
  int _selectedIndex = 0;
  bool _checkedForUnfinishedRace = false;

  @override
  void initState() {
    super.initState();
    final snapshot = widget.initialResumeSnapshot;
    if (snapshot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openGame(GameScreen.resume(resumeSnapshot: snapshot));
      });
    }
    widget.auth.addListener(_recoverUnfinishedRace);
    _recoverUnfinishedRace();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_recoverUnfinishedRace);
    _wheelController.dispose();
    super.dispose();
  }

  Future<void> _recoverUnfinishedRace() async {
    if (_checkedForUnfinishedRace || !widget.auth.isSignedIn) return;
    _checkedForUnfinishedRace = true;
    try {
      final service = RaceService();
      final race = await service.fetchActiveMatch();
      if (race == null || race.status != RaceStatus.inProgress) return;
      await service.abortRace(race.id);
      final controller = RaceController(
        difficulty: race.difficulty,
        puzzleQueue: widget.puzzleQueue,
        raceService: service,
      );
      await controller.restore(race.id);
      if (!mounted) {
        controller.dispose();
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RaceResultScreen(controller: controller),
        ),
      );
    } catch (_) {
      // A later app launch can retry if the network was unavailable.
      _checkedForUnfinishedRace = false;
    }
  }

  Future<void> _openGame(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // Returning from a game (win, give up, or a redeemed share code) may
    // have taken from widget.puzzleQueue, so rebuild to show the new front
    // of the queue in the preview board — the queue itself isn't
    // Listenable, so this screen only learns about that on its own return.
    if (mounted) setState(() {});
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

  Future<void> _onEnterCodePressed() async {
    final puzzle = await Navigator.push<SudokuPuzzle>(
      context,
      MaterialPageRoute(builder: (_) => const EnterCodeScreen()),
    );
    if (puzzle == null) return;
    _openGame(
        GameScreen.newGame(difficulty: puzzle.difficulty, puzzle: puzzle));
  }

  void _onRacePressed() {
    final difficulty = widget.auth.profile?.tier.raceDifficulty ??
        Difficulty.values[_selectedIndex];
    _openGame(MatchmakingScreen(
      auth: widget.auth,
      puzzleQueue: widget.puzzleQueue,
      difficulty: difficulty,
    ));
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
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _openGame(StatsScreen(auth: widget.auth)),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _onEnterCodePressed,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _openGame(MyPageScreen(auth: widget.auth)),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedBuilder(
              animation: widget.auth,
              builder: (context, _) {
                final profile = widget.auth.profile;
                if (profile == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => _openGame(MyPageScreen(auth: widget.auth)),
                    child: Text(
                      l10n.homeRatingLabel(
                          profile.tier.label(context), profile.rating),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: profile.tier.color(
                            Theme.of(context).brightness == Brightness.dark),
                      ),
                    ),
                  ),
                );
              },
            ),
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
            OutlinedButton(
              onPressed: _onRacePressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child:
                    Text(l10n.raceButton, style: const TextStyle(fontSize: 18)),
              ),
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
