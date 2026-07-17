import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
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
import '../theme/board_colors.dart';
import '../widgets/game_controls_row.dart';
import '../widgets/number_pad_widget.dart';
import '../widgets/puzzle_share_dialog.dart';
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
    }
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
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.exitDialogTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.continueAction),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _restartGame();
            },
            child: Text(l10n.restartAction),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _giveUp();
              _popToHome();
            },
            child: Text(l10n.endGameAction),
          ),
        ],
      ),
    );
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

  Widget _buildGrid() => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => SudokuGridWidget(controller: _controller),
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

  void _onHintPressed() {
    final l10n = AppLocalizations.of(context)!;
    if (_controller.hasUnresolvedMistake) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.clearWrongFirst)),
      );
      return;
    }
    if (!_controller.hasAvailableHint) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noHintAvailable)),
      );
      return;
    }
    // requestHint() (which sets activeHint and draws the highlight on the
    // board) only runs once the reward is actually earned — never before
    // or during the ad — so backing out mid-ad leaves no hint highlighted
    // with no explanatory sheet to match it.
    final hint = _controller.requestHintFromNotes(l10n: l10n);
    if (hint != null) {
      _showHintDialog(hint);
    } else {
      _showAutoCandidatePrompt(l10n);
    }
    // AdService.instance.showRewardedAd(
    //   onUserEarnedReward: () {
    //     if (!mounted) return;
    //     // Stage 1: analyze using only the board and the player's own notes.
    //     final hint = _controller.requestHintFromNotes(l10n: l10n);
    //     if (hint != null) {
    //       _showHintDialog(hint);
    //     } else {
    //       _showAutoCandidatePrompt(l10n);
    //     }
    //   },
    //   onAdUnavailable: () {
    //     if (!mounted) return;
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text(l10n.adNotLoaded)),
    //     );
    //   },
    // );
  }

  /// Shown when a stage-1 (notes-only) hint search comes up empty: offers to
  /// auto-generate candidates and re-run the search (stage 2) — no second ad,
  /// since the reward was already earned for this hint request.
  void _showAutoCandidatePrompt(AppLocalizations l10n) {
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
              final hint = _controller.requestHint(l10n: l10n);
              if (!mounted) return;
              if (hint != null) {
                _showHintDialog(hint);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.noHintAvailable)),
                );
              }
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
    showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final stage = _controller.hintStage;
          final isFinal = stage >= 2;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hint.technique.label(context),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  if (stage == 1 && hint.mainInfo != null) ...[
                    const SizedBox(height: 12),
                    Text(hint.mainInfo!),
                  ],
                  if (isFinal) ...[
                    const SizedBox(height: 12),
                    Text(hint.explanation),
                    const SizedBox(height: 8),
                    Text(
                      hint.actionSummary,
                      style: Theme.of(sheetContext).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(l10n.closeAction),
                      ),
                      if (isFinal)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _controller.applyHint();
                            HapticService.medium();
                            _saveProgress();
                          },
                          child: Text(l10n.applyAction),
                        )
                      else
                        TextButton(
                          // Skips the mainInfo stage for techniques that
                          // don't supply one, so the button never reveals
                          // nothing new.
                          onPressed: () => setSheetState(() {
                            _controller.advanceHintStage();
                            if (_controller.hintStage == 1 &&
                                hint.mainInfo == null) {
                              _controller.advanceHintStage();
                            }
                          }),
                          child: Text(l10n.hintRevealMoreAction),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
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
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackPressed,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
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
                  Text(
                    widget.isDaily
                        ? AppLocalizations.of(context)!.dailyTitle
                        : _controller.difficulty.label(context),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const Spacer(),
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
                    width: 90,
                    child: Text(
                      AppLocalizations.of(context)!.mistakesLabel(
                        _controller.mistakes,
                        GameController.maxMistakes,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Container(
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
                    // Top-aligned (not centered) so leftover space collects
                    // below the grid instead of splitting evenly — keeps the
                    // grid sitting close to the app bar.
                    child: Align(
                      alignment: Alignment.topCenter,
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
                  ),
                ),
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
                  ),
                ),
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => NumberPadWidget(
                    controller: _controller,
                    isNotePad: false,
                    onNumberSelected: _onNumberSelected,
                  ),
                ),
                const SizedBox(height: 28),
                // The notes pad always reserves its layout space and only
                // fades in/out — unlike a height-collapsing animation, this
                // keeps the total height below the grid constant regardless of
                // note mode, so the Expanded grid above never resizes/shifts.
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => AnimatedOpacity(
                    opacity: _controller.isNoteMode ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_controller.isNoteMode,
                      child: NumberPadWidget(
                        controller: _controller,
                        isNotePad: true,
                        onNumberSelected: _onNoteNumberSelected,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
