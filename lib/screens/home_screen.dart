import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../models/race.dart';
import '../models/sudoku_puzzle.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/race_service.dart';
import '../state/auth_controller.dart';
import '../state/settings_controller.dart';
import '../theme/app_palette.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/pop_button.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/sudoku_preview_board.dart';
import '../widgets/tier_badge.dart';
import 'daily/daily_entry_screen.dart';
import 'game_screen.dart';
import 'my_page_screen.dart';
import 'puzzle_share/enter_code_screen.dart';
import 'race/race_lobby_screen.dart';
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
      if (race == null) return;
      // A race stuck before in_progress (both apps killed mid-handshake —
      // most likely a friend room whose players never both arrived) has no
      // outcome worth showing; just clear it so it stops shadowing future
      // matches in watchForMatch/fetchActiveMatch.
      if (race.status == RaceStatus.pendingPuzzle ||
          race.status == RaceStatus.ready) {
        await service.abortRace(race.id);
        return;
      }
      if (race.status != RaceStatus.inProgress) return;
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
      MaterialPageRoute(
          builder: (_) => EnterCodeScreen(
                auth: widget.auth,
                puzzleQueue: widget.puzzleQueue,
              )),
    );
    if (puzzle == null) return;
    _openGame(
        GameScreen.newGame(difficulty: puzzle.difficulty, puzzle: puzzle));
  }

  void _onRacePressed() {
    _openGame(RaceLobbyScreen(
      auth: widget.auth,
      puzzleQueue: widget.puzzleQueue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedDifficulty = Difficulty.values[_selectedIndex];
    final previewPuzzle = widget.puzzleQueue.peek(selectedDifficulty);

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Text(
                    l10n.appTitle,
                    style: TextStyle(
                      fontFamily: 'Jua',
                      fontSize: 26,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  _RoundIconButton(
                    icon: Icons.bar_chart,
                    onPressed: () => _openGame(StatsScreen(auth: widget.auth)),
                  ),
                  _RoundIconButton(
                    icon: Icons.qr_code,
                    onPressed: _onEnterCodePressed,
                  ),
                  _RoundIconButton(
                    icon: Icons.person,
                    onPressed: () => _openGame(MyPageScreen(auth: widget.auth)),
                  ),
                  _RoundIconButton(
                    icon: Icons.settings,
                    onPressed: () =>
                        showSettingsSheet(context, widget.settings),
                  ),
                ],
              ).animate().fadeIn(duration: 250.ms),
            ),
            AnimatedBuilder(
              animation: widget.auth,
              builder: (context, _) {
                final profile = widget.auth.profile;
                if (profile == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => _openGame(MyPageScreen(auth: widget.auth)),
                    child:
                        TierBadge(tier: profile.tier, rating: profile.rating),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 60.ms, duration: 250.ms)
                    .slideY(begin: 0.08, curve: Curves.easeOutCubic);
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
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center selection band the wheel scrolls behind.
                  IgnorePointer(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 72),
                      decoration: BoxDecoration(
                        color: AppPalette.difficultyColor(
                                selectedDifficulty, AppPalette.isDark(context))
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  ListWheelScrollView(
                    controller: _wheelController,
                    itemExtent: 44,
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
                              fontFamily: isSelected ? 'Jua' : null,
                              fontSize: isSelected ? 20 : 16,
                              color: isSelected
                                  ? AppPalette.difficultyColor(
                                      difficulty, AppPalette.isDark(context))
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 250.ms),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: PopButton(
                onPressed: _onStartPressed,
                label: l10n.startGame,
                fontSize: 20,
                expanded: true,
              ),
            )
                .animate()
                .fadeIn(delay: 180.ms, duration: 250.ms)
                .slideY(begin: 0.08, curve: Curves.easeOutCubic),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: PopButton(
                      onPressed: _onRacePressed,
                      label: l10n.raceButton,
                      icon: Icons.sports_esports,
                      color: AppPalette.raceCoral,
                      variant: PopButtonVariant.secondary,
                      fontSize: 16,
                      expanded: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PopButton(
                      onPressed: () => _openGame(DailyEntryScreen(
                          auth: widget.auth, puzzleQueue: widget.puzzleQueue)),
                      label: l10n.dailyButton,
                      icon: Icons.today,
                      color: AppPalette.dailyTeal,
                      variant: PopButtonVariant.secondary,
                      fontSize: 16,
                      expanded: true,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 240.ms, duration: 250.ms)
                .slideY(begin: 0.08, curve: Curves.easeOutCubic),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // (settings sheet moved to lib/widgets/settings_sheet.dart)
}

/// Small circular icon button for the home header — a soft card-surface
/// disc so the actions read as game chrome rather than a toolbar.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: AppPalette.cardSurface(isDark),
        shape: const CircleBorder(),
        elevation: isDark ? 0 : 2,
        shadowColor: AppPalette.cardShadow(isDark),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon,
                size: 20, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
