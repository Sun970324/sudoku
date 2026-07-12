import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
import '../widgets/game_controls_row.dart';
import '../widgets/number_pad_widget.dart';
import '../widgets/sudoku_grid_widget.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen.newGame({
    super.key,
    required Difficulty this.difficulty,
    this.puzzle,
  }) : resumeSnapshot = null;

  const GameScreen.resume(
      {super.key, required GameSnapshot this.resumeSnapshot})
      : difficulty = null,
        puzzle = null;

  final Difficulty? difficulty;
  final GameSnapshot? resumeSnapshot;

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
  BannerAd? _bannerAd;
  Timer? _timer;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _controller = GameController();
    final snapshot = widget.resumeSnapshot;
    if (snapshot != null) {
      _controller.resumeFrom(snapshot);
    } else {
      _controller.startNewGame(widget.difficulty!, puzzle: widget.puzzle);
    }
    _startTimer();
    _controller.addListener(_onGameStateChanged);
    WidgetsBinding.instance.addObserver(this);
    _bannerAd = AdService.instance.createBannerAd(
      onAdLoaded: (ad) => setState(() {}),
      onAdFailedToLoad: () => setState(() => _bannerAd = null),
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

    final solveResult =
        HumanSolver().solve(_controller.puzzle.puzzle.toJson());
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
        ),
      ),
    );
  }

  Future<void> _giveUp() async {
    await _storage.clearInProgressGame();
    await _storage.recordGameResult(
      difficulty: _controller.difficulty,
      won: false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveProgress();
    _controller.removeListener(_onGameStateChanged);
    _controller.dispose();
    _bannerAd?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showGameOverDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('실수 3회'),
        content: const Text('광고를 보고 계속하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _giveUp();
              Navigator.pop(context);
            },
            child: const Text('포기하고 나가기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              AdService.instance.showRewardedAd(
                onUserEarnedReward: () {
                  _dialogShown = false;
                  _controller.reviveAfterAd();
                  _startTimer();
                },
                onAdUnavailable: () {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('광고를 아직 불러오지 못했어요. 잠시 후 다시 시도해주세요.'),
                    ),
                  );
                  _showGameOverDialog();
                },
              );
            },
            child: const Text('계속하기'),
          ),
        ],
      ),
    );
  }

  void _onHintPressed() {
    if (_controller.hasUnresolvedMistake) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오답을 먼저 지워주세요.')),
      );
      return;
    }
    if (!_controller.hasAvailableHint) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지금은 사용할 수 있는 힌트가 없어요.')),
      );
      return;
    }
    // requestHint() (which sets activeHint and draws the highlight on the
    // board) only runs once the reward is actually earned — never before
    // or during the ad — so backing out mid-ad leaves no hint highlighted
    // with no explanatory sheet to match it.
    AdService.instance.showRewardedAd(
      onUserEarnedReward: () {
        final hint = _controller.requestHint();
        if (hint != null) _showHintDialog(hint);
      },
      onAdUnavailable: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('광고를 아직 불러오지 못했어요. 잠시 후 다시 시도해주세요.')),
        );
      },
    );
  }

  void _showHintDialog(Hint hint) {
    // A centered AlertDialog sits right on top of the grid, hiding the
    // amber hint highlight no matter how light its barrier is. A bottom
    // sheet stays anchored below the grid instead, so the highlighted
    // cell(s) remain visible while the explanation is showing.
    showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint.technique.label,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(hint.explanation),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('닫기'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _controller.applyHint();
                      HapticService.medium();
                      _saveProgress();
                    },
                    child: const Text('적용하기'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('광고를 아직 불러오지 못했어요. 잠시 후 다시 시도해주세요.')),
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  _controller.difficulty.label,
                  style: const TextStyle(fontSize: 20),
                ),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: _controller.elapsedSecondsNotifier,
                  builder: (context, seconds, _) => SizedBox(
                    width: 40,
                    child: Text(
                      _formatTime(seconds),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 55,
                  child: Text(
                    '실수: ${_controller.mistakes}/${GameController.maxMistakes}',
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
      body: SafeArea(
        child: Column(
          children: [
            // Expanded (instead of a fixed height fraction) so the grid
            // claims all vertical space left over after the controls/number
            // pads below — it grows as large as the screen allows, capped
            // only by width via the AspectRatio inside SudokuGridWidget.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                // Top-aligned (not centered) so leftover space collects
                // below the grid instead of splitting evenly — keeps the
                // grid sitting close to the app bar.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) =>
                        SudokuGridWidget(controller: _controller),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => NumberPadWidget(
                controller: _controller,
                isNotePad: false,
                onNumberSelected: _onNumberSelected,
              ),
            ),
            const SizedBox(height: 8),
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
            // Breathing room above the banner ad so number-pad taps near
            // the bottom edge don't accidentally hit the ad instead.
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: _bannerAd == null
          ? null
          : SafeArea(
              top: false,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
    );
  }
}
