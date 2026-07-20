import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/ko_josa.dart';
import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../models/hint.dart';
import '../models/sudoku_puzzle.dart';
import '../services/ad_service.dart';
import '../services/generation/difficulty_evaluator.dart';
import '../services/generation/human_solver.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../state/game_controller.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../theme/board_colors.dart';
import '../widgets/coach_mark.dart';
import '../widgets/game_controls_row.dart';
import '../widgets/number_pad_widget.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/pop_button.dart';
import '../widgets/puzzle_share_dialog.dart';
import '../widgets/quick_input_toggle.dart';
import '../widgets/sudoku_grid_widget.dart';
import '../widgets/sudoku_preview_board.dart';
import 'daily/daily_result_screen.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen.newGame({
    super.key,
    required Difficulty this.difficulty,
    this.puzzle,
  })  : resumeSnapshot = null,
        isDaily = false,
        dailyAlreadyCompleted = false;

  const GameScreen.resume(
      {super.key, required GameSnapshot this.resumeSnapshot})
      : difficulty = null,
        puzzle = null,
        isDaily = false,
        dailyAlreadyCompleted = false;

  /// Today's shared ranked puzzle. Daily games never touch local solo
  /// stats or the in-progress save slot, and on win route to
  /// [DailyResultScreen] instead of [ResultScreen].
  const GameScreen.daily({
    super.key,
    required SudokuPuzzle this.puzzle,
    this.dailyAlreadyCompleted = false,
  })  : difficulty = null,
        resumeSnapshot = null,
        isDaily = true;

  final Difficulty? difficulty;
  final GameSnapshot? resumeSnapshot;
  final bool isDaily;

  /// A daily replay run after today's record already exists — the win is
  /// shown but never submitted (the server would ignore it anyway).
  final bool dailyAlreadyCompleted;

  /// A pre-generated puzzle (e.g. from [PuzzleQueueManager]) to use instead
  /// of generating one synchronously. Null falls back to generating on the
  /// spot — see [GameController.startNewGame].
  final SudokuPuzzle? puzzle;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameController _controller;
  final StorageService _storage = StorageService();
  Timer? _timer;
  bool _dialogShown = false;
  bool _abandoningGame = false;

  /// Shows a decorative, non-interactive clone of the board (paired with
  /// SudokuPreviewBoard's Hero on HomeScreen) growing on top of the real
  /// grid while entering the game — flipped off once that push transition
  /// finishes (see [_onEntranceAnimationStatus]). The real grid underneath
  /// is never itself Hero-tagged, so it stays tappable from the very first
  /// frame instead of being made non-hit-testable for the flight's duration
  /// the way Hero(child: _buildGrid()) directly would (Hero wraps its own
  /// child in an Offstage while flying).
  bool _showEntranceHero = true;
  Animation<double>? _entranceAnimation;

  // Coach-mark anchors + one-shot guard for the first-entry game tutorial.
  final _gridKey = GlobalKey();
  final _numberPadKey = GlobalKey();
  final _noteButtonKey = GlobalKey();
  final _hintButtonKey = GlobalKey();
  final _mistakesKey = GlobalKey();
  final _quickInputKey = GlobalKey();
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    _controller = GameController();
    final snapshot = widget.resumeSnapshot;
    if (snapshot != null) {
      _controller.resumeFrom(snapshot);
    } else {
      // Daily mode has no difficulty param — the puzzle (required there)
      // carries its own.
      _controller.startNewGame(
        widget.difficulty ?? widget.puzzle!.difficulty,
        puzzle: widget.puzzle,
      );
    }
    _startTimer();
    _controller.addListener(_onGameStateChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _entranceAnimation) {
      _entranceAnimation?.removeStatusListener(_onEntranceAnimationStatus);
      _entranceAnimation = animation;
      animation?.addStatusListener(_onEntranceAnimationStatus);
    }
  }

  void _onEntranceAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _showEntranceHero = false);
      _maybeShowTutorial();
    }
  }

  /// Spotlights the board, number pad, note toggle, hint, and mistake
  /// counter on the player's first real game. Runs once, after the entrance
  /// animation settles so the highlight rects are final; resumed games are
  /// skipped (the player has already played that board).
  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked || widget.resumeSnapshot != null) return;
    _tutorialChecked = true;
    if (!mounted) return;
    if (await _storage.loadSeenGameTutorial()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    // Freeze the clock while the tutorial is up so the intro doesn't count
    // against the player's solve time — resumed once the whole walkthrough
    // (game steps, then the chained quick-input tip) finishes.
    _timer?.cancel();
    showCoachMark(
      context,
      steps: [
        CoachMarkStep(
          targetKey: _gridKey,
          title: l10n.tutorialGameGridTitle,
          body: l10n.tutorialGameGridBody,
          align: ContentAlign.bottom,
        ),
        CoachMarkStep(
          targetKey: _numberPadKey,
          title: l10n.tutorialGameNumbersTitle,
          body: l10n.tutorialGameNumbersBody,
          align: ContentAlign.top,
        ),
        CoachMarkStep(
          targetKey: _noteButtonKey,
          title: l10n.tutorialGameNoteTitle,
          body: l10n.tutorialGameNoteBody,
          align: ContentAlign.top,
        ),
        CoachMarkStep(
          targetKey: _hintButtonKey,
          title: l10n.tutorialGameHintTitle,
          body: l10n.tutorialGameHintBody,
          align: ContentAlign.top,
        ),
        CoachMarkStep(
          targetKey: _mistakesKey,
          title: l10n.tutorialGameMistakesTitle,
          body: l10n.tutorialGameMistakesBody,
          align: ContentAlign.bottom,
        ),
      ],
      onDone: () {
        _storage.saveSeenGameTutorial(true);
        // Chain straight into the quick-input tip (keeps the clock frozen
        // until it too is done, which restarts the timer).
        _maybeShowQuickInputTutorial();
      },
    );
  }

  /// One-shot spotlight on the quick-input toggle, chained on right after the
  /// game tutorial's last step (see [_maybeShowTutorial]). Its own "seen" flag
  /// keeps it to a single showing and lets the settings "replay" re-trigger it
  /// alongside the game tutorial. Restarts the clock when dismissed.
  Future<void> _maybeShowQuickInputTutorial() async {
    if (!mounted) return;
    if (await _storage.loadSeenQuickInputTutorial()) {
      // Nothing to show — make sure the clock is running again (it may have
      // been frozen by a game tutorial that chained here).
      if (mounted) _startTimer();
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _timer?.cancel();
    showCoachMark(
      context,
      steps: [
        CoachMarkStep(
          targetKey: _quickInputKey,
          title: l10n.tutorialQuickInputTitle,
          body: l10n.tutorialQuickInputBody,
          align: ContentAlign.top,
        ),
      ],
      onDone: () {
        _storage.saveSeenQuickInputTutorial(true);
        if (mounted) _startTimer();
      },
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _controller.tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    // Daily games are never persisted/resumed: abandoning one simply means
    // retrying from 0:00 later (matching the retry-until-first-completion
    // policy), and a snapshot surviving past the KST midnight boundary
    // would resurrect a stale board no longer tied to any ranking.
    if (widget.isDaily) return;
    // dispose() calls this unconditionally as a just-in-case save, which
    // would otherwise race clearInProgressGame() in _giveUp() (status is
    // still `playing` at that point) and can re-persist the game the user
    // just abandoned if this save's write lands after the clear's.
    if (_abandoningGame) return;
    if (_controller.status == GameStatus.playing) {
      await _storage.saveInProgressGame(_controller.toSnapshot());
    }
  }

  void _onGameStateChanged() {
    if (_dialogShown) return;
    if (_controller.status == GameStatus.won) {
      _dialogShown = true;
      _timer?.cancel();
      HapticService.celebrate();
      _onWin();
    } else if (_controller.status == GameStatus.gameOver) {
      _dialogShown = true;
      _timer?.cancel();
      _showGameOverDialog();
    }
  }

  Future<void> _onWin() async {
    final difficulty = _controller.difficulty;
    final elapsedSeconds = _controller.elapsedSeconds;
    final mistakes = _controller.mistakes;
    final hintsUsed = _controller.hintsUsed;

    if (widget.isDaily) {
      // No local stats/in-progress bookkeeping for daily games. The submit
      // RPC itself runs inside DailyResultScreen so its loading/retry UX
      // lives in one place.
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DailyResultScreen(
            puzzle: _controller.puzzle,
            submission: widget.dailyAlreadyCompleted
                ? null
                : DailySubmission(
                    board: _controller.boardSnapshot,
                    elapsedSeconds: elapsedSeconds,
                    mistakes: mistakes,
                    hintsUsed: hintsUsed,
                  ),
          ),
        ),
      );
      return;
    }

    // Read the previous best before recordGameResult overwrites it, so the
    // result screen can tell "first clear" / "new best" / "same as before"
    // apart.
    final statsBefore = await _storage.getStats();
    final previousBestSeconds =
        statsBefore.byDifficulty[difficulty]!.bestTimeSeconds;

    await _storage.clearInProgressGame();
    await _storage.recordGameResult(
      difficulty: difficulty,
      won: true,
      finishTimeSeconds: elapsedSeconds,
      mistakes: mistakes,
      hintsUsed: hintsUsed,
    );

    final solveResult = HumanSolver().solve(_controller.puzzle.puzzle.toJson());
    final difficultyResult = DifficultyEvaluator().evaluate(solveResult);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          difficulty: difficulty,
          elapsedSeconds: elapsedSeconds,
          mistakes: mistakes,
          hintsUsed: hintsUsed,
          difficultyResult: difficultyResult,
          isNewBest: previousBestSeconds == null ||
              elapsedSeconds < previousBestSeconds,
          previousBestSeconds: previousBestSeconds,
          puzzle: _controller.puzzle,
        ),
      ),
    );
  }

  Future<void> _giveUp() async {
    // Abandoning a daily attempt has no local-stats consequence and there's
    // no saved slot to clear — the user can simply retry from the entry
    // point until their first completion.
    if (widget.isDaily) return;
    _abandoningGame = true;
    await _storage.clearInProgressGame();
    await _storage.recordGameResult(
      difficulty: _controller.difficulty,
      won: false,
    );
  }

  void _popToHome() {
    Navigator.pop(context);
  }

  void _onBackPressed() {
    // A dialog (win/game-over) is already up and deciding the round's
    // outcome — don't stack a second one on top of it.
    if (_dialogShown) return;
    // Pause the clock while the exit dialog is open — resumed only if the
    // player picks "continue". Restart/end-game paths start their own timer
    // (or leave the screen), so they never need this one resumed.
    _timer?.cancel();
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    // Restart/end-game manage the timer themselves; every other way the
    // dialog closes (continue, tap-outside, system back) should resume it.
    var handled = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: AppPalette.cardSurface(isDark),
            borderRadius: BorderRadius.circular(AppDims.cardRadius),
            border: isDark
                ? Border.all(
                    color: AppPalette.primaryGradient(isDark)
                        .last
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppPalette.cardShadow(isDark),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: AppPalette.primaryGradient(isDark),
                  ),
                ),
                child:
                    const Icon(PixelIcons.pause, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.exitDialogTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Mulmaru',
                  fontSize: 20,
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              PopButton(
                onPressed: () => Navigator.pop(dialogContext),
                label: l10n.continueAction,
                icon: PixelIcons.play,
                expanded: true,
              ),
              const SizedBox(height: 12),
              PopButton(
                onPressed: () {
                  handled = true;
                  Navigator.pop(dialogContext);
                  _restartGame();
                },
                label: l10n.restartAction,
                icon: PixelIcons.refresh,
                variant: PopButtonVariant.outline,
                expanded: true,
              ),
              const SizedBox(height: 12),
              PopButton(
                onPressed: () {
                  handled = true;
                  Navigator.pop(dialogContext);
                  _giveUp();
                  _popToHome();
                },
                label: l10n.endGameAction,
                icon: PixelIcons.close,
                color: AppPalette.raceCoral,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Resume the clock unless a restart/end-game action already took over
      // (and only while the round is still in progress and on-screen).
      if (handled || !mounted) return;
      if (_controller.status == GameStatus.playing) _startTimer();
    });
  }

  void _restartGame() {
    _controller.startNewGame(_controller.difficulty,
        puzzle: _controller.puzzle);
    _startTimer();
    _saveProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveProgress();
    _controller.removeListener(_onGameStateChanged);
    _controller.dispose();
    _entranceAnimation?.removeStatusListener(_onEntranceAnimationStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    // Show hours only once past the hour mark so a normal game stays "MM:SS"
    // but a long one ("1:23:45") no longer overflows its slot in the app bar.
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// The cell-first / digit-first switch shown right above the number pad —
  /// a single bolt icon that lights up while quick (digit-first) input is on.
  /// Right-aligned: it sits inside the same horizontal padding as the grid, so
  /// its right edge lines up with the board's right edge.
  Widget _buildQuickInputToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        QuickInputToggle(
          key: _quickInputKey,
          active: _controller.quickInputMode,
          onToggle: _setQuickInputMode,
        ),
      ],
    );
  }

  Widget _buildGrid() => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => SudokuGridWidget(
            controller: _controller, onQuickInput: _onQuickInput),
      );

  void _showGameOverDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.gameOverTitle),
        content: Text(l10n.gameOverContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _giveUp();
              _popToHome();
            },
            child: Text(l10n.giveUpAction),
          ),
          TextButton(
            onPressed: () {
              // Deliberately doesn't pop dialogContext here — only once the
              // reward is actually earned. The rewarded ad is a native
              // fullscreen overlay regardless (see AdService.showRewardedAd),
              // so leaving this dialog mounted underneath is invisible while
              // it's up; if the player backs out before earning the reward,
              // this same dialog is still exactly where they left it instead
              // of having been dismissed for nothing.
              AdService.instance.showRewardedAd(
                onUserEarnedReward: () {
                  Navigator.pop(dialogContext);
                  _dialogShown = false;
                  _controller.reviveAfterAd();
                  _startTimer();
                },
                onAdUnavailable: () {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.adNotLoaded)),
                  );
                },
              );
            },
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
  }

  /// True while a background hint search is running — blocks all board
  /// input via the overlay in [build] (so the board can't change under a
  /// search in flight) and re-entrant hint taps here.
  bool _hintSearching = false;

  Future<void> _onHintPressed() async {
    if (_hintSearching) return;
    final l10n = AppLocalizations.of(context)!;
    if (_controller.hasUnresolvedMistake) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.clearWrongFirst)),
      );
      return;
    }
    setState(() => _hintSearching = true);
    try {
      // Stage 1: analyze using only the board and the player's own notes.
      final hint = await _controller.requestHintFromNotes(l10n: l10n);
      if (!mounted) return;
      if (hint != null) {
        _revealHintWithAd(() => _showHintDialog(hint));
        // _showHintDialog(hint);
        return;
      }
      // Stage 2, searched up front but NOT committed: the repaired-notes
      // result is held while the player decides whether to accept
      // auto-corrected candidates, then applied on consent — one search
      // instead of an availability probe plus a re-search.
      final prepared = await _controller.prepareRepairedHint(l10n: l10n);
      if (!mounted) return;
      if (prepared.hint == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noHintAvailable)),
        );
        return;
      }
      _showAutoCandidatePrompt(l10n, prepared);
    } finally {
      if (mounted) setState(() => _hintSearching = false);
    }
  }

  /// Gates a hint reveal behind a rewarded ad. Called only once a hint is
  /// known to be available, so an ad is never spent on a "no hint" outcome.
  /// If no ad is loaded yet the hint is shown for free rather than punishing
  /// the player for a failed ad load — [AdService.showRewardedAd] routes that
  /// case to [onAdUnavailable]. Backing out before earning the reward fires
  /// neither callback, so no hint is revealed.
  void _revealHintWithAd(VoidCallback onReveal) {
    AdService.instance.showRewardedAd(
      onUserEarnedReward: () {
        if (mounted) onReveal();
      },
      onAdUnavailable: () {
        if (mounted) onReveal();
      },
    );
  }

  /// Shown when a stage-1 (notes-only) hint search comes up empty: offers to
  /// accept auto-generated candidates. The stage-2 search already ran in the
  /// background ([prepared] holds its result and is known to carry a hint);
  /// consenting only commits it — the modal dialog blocks all board input in
  /// between, so the prepared result can't go stale.
  void _showAutoCandidatePrompt(AppLocalizations l10n, PreparedHint prepared) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.hintNoTechniqueWithNotes),
        content: Text(l10n.hintAutoGenerateCandidatesPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _revealHintWithAd(() {
                final hint =
                    _controller.applyPreparedHint(prepared, l10n: l10n);
                if (!mounted) return;
                if (hint != null) {
                  _showHintDialog(hint);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.noHintAvailable)),
                  );
                }
              });
            },
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
  }

  void _showHintDialog(Hint hint) {
    final l10n = AppLocalizations.of(context)!;
    // A centered AlertDialog sits right on top of the grid, hiding the
    // amber hint highlight no matter how light its barrier is. A bottom
    // sheet stays anchored below the grid instead, so the highlighted
    // cell(s) remain visible while the explanation is showing.
    final isDark = AppPalette.isDark(context);
    final accent = BoardColors.hintArrow(isDark);
    // Drives the step walkthrough's swipeable pager; the prev/next buttons
    // animate it too, so every path shares the PageView's snap physics and
    // lands in onPageChanged, the single place the controller is synced.
    final stepPageController =
        PageController(initialPage: _controller.hintStepIndex);
    showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      // The card surface is drawn by the Container below, so the sheet frame
      // itself is transparent (no double background / default rounded chrome).
      backgroundColor: Colors.transparent,
      // The hint explanation reads better in the system font than the pixel
      // Mulmaru theme font. Override the family for the whole sheet subtree:
      // Theme covers styled widgets (titleLarge, buttons), DefaultTextStyle
      // covers the plain explanation Text.
      builder: (sheetContext) => Theme(
        data: Theme.of(sheetContext).copyWith(
          textTheme: Theme.of(sheetContext)
              .textTheme
              .apply(fontFamily: AppTheme.systemFontFamily),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontFamily: AppTheme.systemFontFamily),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final stage = _controller.hintStage;
              final isFinal = stage >= 2;
              return Container(
                decoration: BoxDecoration(
                  color: AppPalette.cardSurface(isDark),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDims.cardRadius),
                  ),
                  border: isDark
                      ? Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.cardShadow(isDark),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(PixelIcons.lightbulb, color: accent, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hint.technique.label(context),
                                style:
                                    Theme.of(sheetContext).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        if (stage == 1 && hint.mainInfo != null) ...[
                          const SizedBox(height: 12),
                          Text(applyKoJosa(hint.mainInfo!)),
                        ],
                        // Step walkthrough: one narrated slice of the
                        // visualization at a time. The text lives in a
                        // real PageView so swiping gets drag-follow and
                        // snap physics; the invisible copies of every
                        // step's text size the Stack to the tallest page,
                        // so the sheet's height never jumps mid-swipe.
                        // The board redraws through the controller's
                        // notify (synced in onPageChanged); this sheet
                        // through setSheetState.
                        if (isFinal && _controller.hintSteps.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Stack(
                            children: [
                              for (final step in _controller.hintSteps)
                                Opacity(
                                    opacity: 0,
                                    child: Text(applyKoJosa(step.text))),
                              Positioned.fill(
                                child: PageView.builder(
                                  controller: stepPageController,
                                  itemCount: _controller.hintSteps.length,
                                  onPageChanged: (i) => setSheetState(
                                      () => _controller.setHintStep(i)),
                                  itemBuilder: (_, i) => Text(applyKoJosa(
                                      _controller.hintSteps[i].text)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _controller.hintStepIndex > 0
                                    ? () => stepPageController.animateToPage(
                                        _controller.hintStepIndex - 1,
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeOut)
                                    : null,
                                icon:
                                    Icon(PixelIcons.chevronLeft, color: accent),
                                color: accent,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                tooltip: l10n.hintStepPrevAction,
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0;
                                          i < _controller.hintSteps.length;
                                          i++)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                i == _controller.hintStepIndex
                                                    ? accent
                                                    : accent.withValues(
                                                        alpha: 0.25),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _controller.hintStepIndex <
                                        _controller.hintSteps.length - 1
                                    ? () => stepPageController.animateToPage(
                                        _controller.hintStepIndex + 1,
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeOut)
                                    : null,
                                icon: Icon(PixelIcons.chevronRight,
                                    color: accent),
                                color: accent,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                tooltip: l10n.hintStepNextAction,
                              ),
                            ],
                          ),
                        ],
                        // The full explanation is only for step-less hints —
                        // a walkthrough's conclusion step already narrates
                        // it, and repeating it made the sheet tall enough to
                        // cover the board. The compact notation line still
                        // joins a walkthrough at its final step.
                        if (isFinal && _controller.hintSteps.isEmpty) ...[
                          const SizedBox(height: 12),
                          Text(applyKoJosa(hint.explanation)),
                        ],
                        if (isFinal) ...[
                          const SizedBox(height: 8),
                          // Always laid out at the final stage and only
                          // *revealed* on the conclusion step (or for
                          // step-less hints) — an appearing row would make
                          // the sheet's height jump while paging steps.
                          Opacity(
                            opacity: _controller.hintSteps.isEmpty ||
                                    _controller.hintStepIndex >=
                                        _controller.hintSteps.length - 1
                                ? 1
                                : 0,
                            child: Text(
                              hint.actionSummary,
                              style:
                                  Theme.of(sheetContext).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: PopButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                label: l10n.closeAction,
                                variant: PopButtonVariant.outline,
                                fontSize: 16,
                                expanded: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isFinal)
                              Expanded(
                                child: PopButton(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _controller.applyHint();
                                    HapticService.medium();
                                    _saveProgress();
                                  },
                                  label: l10n.applyAction,
                                  icon: PixelIcons.check,
                                  color: accent,
                                  fontSize: 16,
                                  expanded: true,
                                ),
                              )
                            else
                              Expanded(
                                child: PopButton(
                                  // Skips the mainInfo stage for techniques
                                  // that don't supply one, so the button never
                                  // reveals nothing new.
                                  onPressed: () => setSheetState(() {
                                    _controller.advanceHintStage();
                                    if (_controller.hintStage == 1 &&
                                        hint.mainInfo == null) {
                                      _controller.advanceHintStage();
                                    }
                                  }),
                                  label: l10n.hintRevealMoreAction,
                                  color: accent,
                                  fontSize: 16,
                                  expanded: true,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ).then((_) {
      stepPageController.dispose();
      // Covers barrier-tap / drag-down dismissal, where neither action
      // button ran. No-op if applyHint() already cleared it.
      if (identical(_controller.activeHint, hint)) {
        _controller.dismissHint();
      }
    });
  }

  void _onAutoFillNotesPressed() {
    AdService.instance.showRewardedAd(
      onUserEarnedReward: () {
        _controller.autoFillNotes();
        HapticService.medium();
        _saveProgress();
      },
      onAdUnavailable: () {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adNotLoaded)),
        );
      },
    );
  }

  void _onNumberSelected(int value) {
    final row = _controller.selectedRow;
    final col = _controller.selectedCol;
    _controller.inputValue(value);
    if (row != null && col != null) {
      if (_controller.isWrong(row, col)) {
        HapticService.heavy();
        SoundService.wrong();
      } else {
        HapticService.light();
        SoundService.correct();
      }
    }
    _saveProgress();
  }

  void _onNoteNumberSelected(int value) {
    _controller.toggleNote(value);
    if (_controller.conflictFlashCells.isNotEmpty) {
      HapticService.heavy();
      SoundService.wrong();
    } else {
      HapticService.selection();
      SoundService.click();
    }
    _saveProgress();
  }

  /// Quick-input dispatch: fired by the grid when a cell is tapped while a
  /// pad digit is active (the cell is already selected). Routes into the
  /// exact cell-first handlers so correctness feedback and progress saving
  /// stay identical to select-then-type.
  void _onQuickInput(int digit) {
    if (_controller.activeDigitIsNote) {
      _onNoteNumberSelected(digit);
      return;
    }
    final row = _controller.selectedRow;
    final col = _controller.selectedCol;
    // Digit-first convention: re-tapping a cell already holding the active
    // digit erases it. Givens and locked-correct cells no-op via canErase.
    if (row != null && col != null && _controller.valueAt(row, col) == digit) {
      _onErase();
      return;
    }
    _onNumberSelected(digit);
    // The pad button disables once a digit is fully placed; drop it as the
    // active digit too, otherwise every further tap would be a guaranteed
    // wrong placement of a digit with none left to place.
    if (_controller.activeDigit == digit &&
        _controller.remainingCount(digit) <= 0) {
      _controller.selectActiveDigit(digit, asNote: false);
    }
  }

  /// Value-pad tap in quick input mode: fixes the digit for value placement
  /// (or re-tap clears it) instead of writing into a cell.
  void _onQuickValuePadTap(int value) {
    HapticService.selection();
    SoundService.click();
    _controller.selectActiveDigit(value, asNote: false);
  }

  /// Notes-pad tap in quick input mode: fixes the digit for memo placement.
  void _onQuickNotePadTap(int value) {
    HapticService.selection();
    SoundService.click();
    _controller.selectActiveDigit(value, asNote: true);
  }

  void _setQuickInputMode(bool enabled) {
    if (enabled == _controller.quickInputMode) return;
    HapticService.selection();
    SoundService.click();
    _controller.setQuickInputMode(enabled);
    _storage.saveQuickInputEnabled(enabled);
  }

  void _onErase() {
    _controller.eraseSelected();
    _saveProgress();
  }

  void _onUndo() {
    _controller.undo();
    _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          // Explicit instead of Flutter's automatic back button: this
          // screen can be the app's very first route (resumed straight
          // into on launch, see main.dart/home_screen.dart), where
          // Navigator.canPop is false and no back button would otherwise
          // appear at all. Always routes through the same exit-confirmation
          // dialog as every other back-navigation path.
          leading: IconButton(
            icon: const Icon(PixelIcons.pause),
            onPressed: _onBackPressed,
          ),
          actions: [
            IconButton(
              icon: const Icon(PixelIcons.share),
              onPressed: () => showPuzzleShareDialog(
                context,
                puzzle: _controller.puzzle,
              ),
            ),
          ],
          titleSpacing: 0,
          title: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    // scaleDown shrinks the title to fit the space left by the
                    // fixed-width timer/mistakes rather than truncating it, so
                    // a longer locale (English "Daily Sudoku") stays whole.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.isDaily
                            ? AppLocalizations.of(context)!.dailyTitle
                            : _controller.difficulty.label(context),
                        maxLines: 1,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _controller.elapsedSecondsNotifier,
                    builder: (context, seconds, _) => SizedBox(
                      width: 64,
                      child: Text(
                        _formatTime(seconds),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    key: _mistakesKey,
                    width: 90,
                    // scaleDown (like the title/timer) shrinks the longer
                    // English "Mistakes: 0/3" to fit the fixed width instead of
                    // clipping it with an ellipsis.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppLocalizations.of(context)!.mistakesLabel(
                          _controller.mistakes,
                          GameController.maxMistakes,
                        ),
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            _buildBody(context),
            // Blocks every board interaction while a hint search runs on
            // the background isolate — the search reads a snapshot of the
            // board/notes, so nothing may change until it resolves.
            if (_hintSearching)
              const Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xFF15102C), Color(0xFF0D0B1E)]
              : const [Color(0xFFF6F5FF), Color(0xFFECE9FF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Expanded (instead of a fixed height fraction) so the grid
            // claims all vertical space left over after the controls/
            // number pads below — it grows as large as the screen
            // allows, capped only by width via the AspectRatio inside
            // SudokuGridWidget. Without this, the AspectRatio's loose
            // height constraint inside a plain Column lets it size up to
            // the full screen WIDTH as its height too, overflowing the
            // Column on any screen where that exceeds the actual
            // available height.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                // Board + quick-input toggle as one top-aligned group. The
                // board is Flexible so it still caps to the available height
                // (shrinking on short screens instead of overflowing), while
                // leftover vertical space now collects *below* the toggle
                // rather than between the board and it — keeping the toggle
                // tucked right under the grid.
                child: Column(
                  children: [
                    Flexible(
                      // The real, interactive grid is always present and
                      // never itself Hero-tagged, so taps register from the
                      // first frame. A separate, non-interactive clone
                      // (paired with the same tag on SudokuPreviewBoard in
                      // HomeScreen) is stacked on top purely for the
                      // entrance grow animation, and is removed once that
                      // push transition completes (see
                      // _onEntranceAnimationStatus).
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          DecoratedBox(
                            key: _gridKey,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: BoardColors.outerBorder(
                                          BoardColors.isDark(context))
                                      .withValues(alpha: 0.28),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: _buildGrid(),
                          ),
                          if (_showEntranceHero)
                            IgnorePointer(
                              child: Hero(
                                tag: 'sudoku-board',
                                child: SudokuPreviewBoard(
                                    puzzle: _controller.puzzle),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => _buildQuickInputToggle(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => GameControlsRow(
                canUndo: _controller.canUndo,
                onUndo: _onUndo,
                canErase: _controller.canErase,
                onErase: _onErase,
                isNoteMode: _controller.isNoteMode,
                onToggleNoteMode: _controller.toggleNoteMode,
                onHint: _onHintPressed,
                canAutoFillNotes: _controller.canAutoFillNotes,
                onAutoFillNotes: _onAutoFillNotesPressed,
                noteButtonKey: _noteButtonKey,
                hintButtonKey: _hintButtonKey,
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              key: _numberPadKey,
              listenable: _controller,
              // In quick input mode this pad fixes the active value digit
              // (cells are then tapped to place it); it's highlighted only
              // while the active digit was picked from the value pad.
              builder: (context, _) => NumberPadWidget(
                controller: _controller,
                isNotePad: false,
                onNumberSelected: _controller.quickInputMode
                    ? _onQuickValuePadTap
                    : _onNumberSelected,
                selectedNumber:
                    _controller.quickInputMode && !_controller.activeDigitIsNote
                        ? _controller.activeDigit
                        : null,
              ),
            ),
            const SizedBox(height: 24),
            // The notes pad always reserves its layout space and only
            // fades in/out — unlike a height-collapsing animation, this
            // keeps the total height below the grid constant regardless of
            // note mode, so the Expanded grid above never resizes/shifts.
            // The notes pad's visibility is governed by note mode alone (the
            // memo control button) in both cell-first and quick input — the
            // two are independent of which pad a quick-input digit was picked
            // from. In quick input it's the memo half of the picker, and it
            // highlights its digit only while the active one was picked here.
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final showNotesPad = _controller.isNoteMode;
                return AnimatedOpacity(
                  opacity: showNotesPad ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !showNotesPad,
                    child: NumberPadWidget(
                      controller: _controller,
                      isNotePad: true,
                      onNumberSelected: _controller.quickInputMode
                          ? _onQuickNotePadTap
                          : _onNoteNumberSelected,
                      selectedNumber: _controller.quickInputMode &&
                              _controller.activeDigitIsNote
                          ? _controller.activeDigit
                          : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ));
}
