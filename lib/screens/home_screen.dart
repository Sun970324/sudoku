import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../debug/aic_demo.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../models/race.dart';
import '../models/sudoku_puzzle.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/race_service.dart';
import '../services/storage_service.dart';
import '../state/auth_controller.dart';
import '../state/settings_controller.dart';
import '../theme/app_palette.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/coach_mark.dart';
import '../widgets/pop_button.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/sudoku_preview_board.dart';
import 'daily/daily_entry_screen.dart';
import 'game_screen.dart';
import 'my_page_screen.dart';
import 'puzzle_share/enter_code_screen.dart';
import 'race/race_lobby_screen.dart';
import 'race/race_result_screen.dart';
import 'race/race_screen.dart';
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

  // Coach-mark anchors for the first-entry tutorial.
  final _menuKey = GlobalKey();
  final _wheelKey = GlobalKey();
  final _startKey = GlobalKey();
  final _raceKey = GlobalKey();
  final _dailyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final snapshot = widget.initialResumeSnapshot;
    if (snapshot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openGame(GameScreen.resume(resumeSnapshot: snapshot));
      });
    } else {
      // Only a genuine first entry (no game to resume) gets the tutorial.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
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

  Future<void> _maybeShowTutorial() async {
    if (!mounted) return;
    if (await StorageService().loadSeenHomeTutorial()) return;
    _showTutorial();
  }

  /// Spotlights the difficulty wheel, start button, top menu, and game-mode
  /// buttons. Also invoked from the settings sheet's "replay tutorial".
  void _showTutorial() {
    // Let the staggered entrance animations settle so the highlight rects
    // line up with the widgets' final positions (the last button finishes
    // its slide at ~430ms).
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showCoachMark(
        context,
        steps: [
          CoachMarkStep(
            targetKey: _menuKey,
            title: l10n.tutorialHomeIconsTitle,
            body: l10n.tutorialHomeIconsBody,
            align: ContentAlign.bottom,
          ),
          CoachMarkStep(
            targetKey: _wheelKey,
            title: l10n.tutorialHomeDifficultyTitle,
            body: l10n.tutorialHomeDifficultyBody,
            align: ContentAlign.top,
          ),
          CoachMarkStep(
            targetKey: _startKey,
            title: l10n.tutorialHomeStartTitle,
            body: l10n.tutorialHomeStartBody,
            align: ContentAlign.top,
          ),
          CoachMarkStep(
            targetKey: _raceKey,
            title: l10n.tutorialHomeRaceTitle,
            body: l10n.tutorialHomeRaceBody,
            align: ContentAlign.top,
          ),
          CoachMarkStep(
            targetKey: _dailyKey,
            title: l10n.tutorialHomeDailyTitle,
            body: l10n.tutorialHomeDailyBody,
            align: ContentAlign.top,
          ),
        ],
        onDone: () => StorageService().saveSeenHomeTutorial(true),
      );
    });
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

      // Resume an in-progress race from the locally-saved board (persisted
      // every second while racing) instead of forfeiting it. Only when the
      // saved snapshot is for this exact race — otherwise there's nothing to
      // resume from, so fall back to the old forfeit-and-show-result path.
      final saved = await StorageService().loadRaceProgress();
      final controller = RaceController(
        difficulty: race.difficulty,
        puzzleQueue: widget.puzzleQueue,
        raceService: service,
      );
      final canResume = saved != null && saved.raceId == race.id;
      if (canResume) {
        await controller.restore(race.id, board: saved.snapshot);
      } else {
        await service.abortRace(race.id);
        await controller.restore(race.id);
      }
      if (!mounted) {
        controller.dispose();
        return;
      }
      // If the race was decided while the app was away (or we forfeited it
      // just now), go straight to the result; otherwise resume play.
      final resumable = canResume &&
          controller.phase != RacePhase.finished &&
          controller.phase != RacePhase.aborted;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => resumable
              ? RaceScreen(controller: controller)
              : RaceResultScreen(controller: controller),
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

    return GradientScaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.puzzleQueue,
          builder: (context, _) {
            final previewPuzzle = widget.puzzleQueue.peek(selectedDifficulty);
            final canStart =
                widget.puzzleQueue.countFor(selectedDifficulty) > 0;
            if (!canStart) {
              widget.puzzleQueue.ensureRefillScheduled(selectedDifficulty);
            }
            return _buildContent(
              context,
              l10n,
              selectedDifficulty,
              previewPuzzle,
              canStart,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    Difficulty selectedDifficulty,
    SudokuPuzzle? previewPuzzle,
    bool canStart,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          child: Row(
            key: _menuKey,
            children: [
              Expanded(
                // scaleDown shrinks the title to fit rather than truncating
                // it — a longer locale (English "Sudoku League") stays fully
                // readable; a short one renders at its natural 26.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.appTitle,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Mulmaru',
                      fontSize: 26,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              _RoundIconButton(
                icon: PixelIcons.barChart,
                onPressed: () => _openGame(StatsScreen(auth: widget.auth)),
              ),
              _RoundIconButton(
                icon: Icons.qr_code,
                onPressed: _onEnterCodePressed,
              ),
              _RoundIconButton(
                icon: PixelIcons.person,
                onPressed: () => _openGame(MyPageScreen(auth: widget.auth)),
              ),
              _RoundIconButton(
                icon: PixelIcons.settings,
                onPressed: () => showSettingsSheet(
                  context,
                  widget.settings,
                  onReplayTutorial: _showTutorial,
                  onAicDemo: kDebugMode
                      ? () => _openGame(GameScreen.newGame(
                            difficulty: Difficulty.expert,
                            puzzle: aicDemoPuzzle(),
                          ))
                      : null,
                  onGroupedDemo: kDebugMode
                      ? () => _openGame(GameScreen.newGame(
                            difficulty: Difficulty.expert,
                            puzzle: groupedChainDemoPuzzle(),
                          ))
                      : null,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 250.ms),
        ),
        const SizedBox(height: 24),
        // AnimatedBuilder(
        //   animation: widget.auth,
        //   builder: (context, _) {
        //     final profile = widget.auth.profile;
        //     if (profile == null) return const SizedBox.shrink();
        //     return Padding(
        //       padding: const EdgeInsets.only(top: 8),
        //       child: GestureDetector(
        //         onTap: () => _openGame(MyPageScreen(auth: widget.auth)),
        //         child: TierBadge(tier: profile.tier, rating: profile.rating),
        //       ),
        //     )
        //         .animate()
        //         .fadeIn(delay: 60.ms, duration: 250.ms)
        //         .slideY(begin: 0.08, curve: Curves.easeOutCubic);
        //   },
        // ),
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
                  // During the flight the board is reparented into the
                  // Overlay, losing the Material/DefaultTextStyle ancestor
                  // that supplies the cell text style — so the number Texts
                  // fall back to the framework default (yellow underline,
                  // visible in release too). Re-supplying a transparent
                  // Material restores a proper text style. Defined only here
                  // yet covers both directions: on push GameScreen's Hero has
                  // no shuttle builder, so the flight falls back to this one.
                  flightShuttleBuilder: (flightContext, animation,
                      flightDirection, fromHeroContext, toHeroContext) {
                    return Material(
                      type: MaterialType.transparency,
                      child: toHeroContext.widget,
                    );
                  },
                  child: SudokuPreviewBoard(puzzle: previewPuzzle),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          key: _wheelKey,
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
                          fontFamily: isSelected ? 'Mulmaru' : null,
                          fontSize: isSelected ? 20 : 16,
                          color: isSelected
                              ? AppPalette.difficultyColor(
                                  difficulty, AppPalette.isDark(context))
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
          key: _startKey,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PopButton(
            onPressed: canStart ? _onStartPressed : null,
            label: canStart ? l10n.startGame : l10n.generatingPuzzle,
            loading: !canStart,
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
                  key: _raceKey,
                  onPressed: _onRacePressed,
                  label: l10n.raceButton,
                  icon: PixelIcons.gameController,
                  color: AppPalette.raceCoral,
                  variant: PopButtonVariant.secondary,
                  fontSize: 16,
                  expanded: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PopButton(
                  key: _dailyKey,
                  onPressed: () => _openGame(DailyEntryScreen(
                      auth: widget.auth, puzzleQueue: widget.puzzleQueue)),
                  label: l10n.dailyButton,
                  icon: PixelIcons.calendar,
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
      ],
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
