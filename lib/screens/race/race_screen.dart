import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/race.dart';
import '../../services/storage_service.dart';
import '../../state/game_controller.dart';
import '../../state/race_controller.dart';
import '../../widgets/game_controls_row.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/number_pad_widget.dart';
import '../../widgets/pixel_icon.dart';
import '../../widgets/quick_input_toggle.dart';
import '../../widgets/sudoku_grid_widget.dart';
import 'race_result_screen.dart';

/// Shown once [controller] reaches [RacePhase.racing] — [MatchmakingScreen]
/// owns every earlier phase (matching, puzzle exchange, ready-check).
class RaceScreen extends StatefulWidget {
  const RaceScreen({super.key, required this.controller});

  final RaceController controller;

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  Timer? _timer;
  final StorageService _storage = StorageService();

  /// True once this screen has handed the controller off to
  /// [RaceResultScreen] — dispose() must then leave it alone. Aborting
  /// (and popping straight back to Home) is the only other terminal path,
  /// and it still owns (and must dispose) the controller in that case.
  bool _handedOff = false;

  /// True while the give-up confirmation ([_confirmAbort]) is on screen —
  /// lets [_onRaceChanged] dismiss it before navigating away if the race
  /// gets decided out from under the player while they're deciding. Without
  /// this, a pushReplacement/pop fired with that dialog's route on top would
  /// act on the *dialog's* route instead of this screen's, leaving
  /// RaceScreen alive-but-hidden underneath with a controller the next
  /// screen goes on to dispose — see the Home-button crash this guards
  /// against.
  bool _abortDialogShowing = false;

  /// True once [widget.controller.phase] has reached [RacePhase.finished]
  /// and this screen has started handling it (either straight to the result
  /// screen, or via the continue-or-exit prompt below).
  bool _raceDecided = false;

  /// True while the continue-or-exit prompt ([_promptContinueOrExit]) is on
  /// screen — mirrors [_abortDialogShowing] for the same dismiss-before-nav
  /// reason, and also holds off [_onGameChanged]'s post-decision win/loss
  /// check until the player has actually chosen to keep playing.
  bool _resolvingContinue = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onRaceChanged);
    widget.controller.game.addListener(_onGameChanged);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => widget.controller.game.tick());
  }

  void _onRaceChanged() {
    if (_handedOff || _raceDecided) return;
    if (widget.controller.phase == RacePhase.finished) {
      _raceDecided = true;
      _timer?.cancel();
      widget.controller.removeListener(_onRaceChanged);
      if (_abortDialogShowing) Navigator.of(context).pop();
      if (widget.controller.game.status == GameStatus.playing) {
        // Race decided by something other than this player finishing (or
        // running out of mistakes) themselves — opponent gave up,
        // disconnected, finished first, or forfeited on their 3rd mistake.
        // Offer to keep solving instead of yanking the board away mid-move.
        _promptContinueOrExit();
      } else {
        _goToResult();
      }
    } else if (widget.controller.phase == RacePhase.aborted) {
      _timer?.cancel();
      if (_abortDialogShowing) Navigator.of(context).pop();
      Navigator.pop(context);
    } else {
      // Opponent disconnect is now handled non-modally: a countdown banner
      // (below) plus an automatic server-verified win claim in the
      // controller — no dialog, and crucially no "give up" option (which
      // used to make the still-present player lose).
      setState(() {});
    }
  }

  void _onGameChanged() {
    setState(() {});
    if (!_raceDecided || _resolvingContinue) return;
    // Free-play after the race was already decided (the player chose "keep
    // solving") — the outcome is locked in either way, so just wait for
    // them to finish or run out of mistakes and hand off to the result.
    final status = widget.controller.game.status;
    if (status == GameStatus.won || status == GameStatus.gameOver) {
      _goToResult();
    }
  }

  String _finishTitle(AppLocalizations l10n, RaceFinishReason? reason) {
    switch (reason) {
      case RaceFinishReason.gaveUp:
        return l10n.raceOpponentGaveUpTitle;
      case RaceFinishReason.disconnected:
        return l10n.raceOpponentDisconnectedTitle;
      case RaceFinishReason.mistakes:
        return l10n.raceOpponentMistakesForfeitTitle;
      case RaceFinishReason.completed:
      case null:
        return l10n.raceOpponentFinishedFirstTitle;
    }
  }

  String _finishBody(AppLocalizations l10n, RaceFinishReason? reason) {
    switch (reason) {
      case RaceFinishReason.gaveUp:
        return l10n.raceOpponentGaveUpBody;
      case RaceFinishReason.disconnected:
        return l10n.raceOpponentDisconnectedBody;
      case RaceFinishReason.mistakes:
        return l10n.raceOpponentMistakesForfeitBody;
      case RaceFinishReason.completed:
      case null:
        return l10n.raceOpponentFinishedFirstBody;
    }
  }

  Future<void> _promptContinueOrExit() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final reason = widget.controller.finishReason;
    _resolvingContinue = true;
    final keepSolving = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_finishTitle(l10n, reason)),
        content: Text(_finishBody(l10n, reason)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.exitAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.keepSolvingAction),
          ),
        ],
      ),
    );
    _resolvingContinue = false;
    if (!mounted) return;
    if (keepSolving == true) {
      setState(() {});
    } else {
      _goToResult();
    }
  }

  void _goToResult() {
    if (_handedOff) return;
    widget.controller.removeListener(_onRaceChanged);
    widget.controller.game.removeListener(_onGameChanged);
    _handedOff = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => RaceResultScreen(controller: widget.controller)),
    );
  }

  // Quick-input (digit-first) handlers, mirroring the solo game screen. The
  // game controller's notifyListeners drives the rebuild via _onGameChanged,
  // so these just mutate. The bolt toggle, pads, and grid are all wired below.
  void _onQuickInput(int digit) {
    final game = widget.controller.game;
    if (game.activeDigitIsNote) {
      game.toggleNote(digit);
      return;
    }
    final row = game.selectedRow;
    final col = game.selectedCol;
    // Re-tapping a cell already holding the active digit erases it.
    if (row != null && col != null && game.valueAt(row, col) == digit) {
      game.eraseSelected();
      return;
    }
    game.inputValue(digit);
    // Drop the active digit once it's fully placed so further taps aren't
    // guaranteed wrong placements of a depleted digit.
    if (game.activeDigit == digit && game.remainingCount(digit) <= 0) {
      game.selectActiveDigit(digit, asNote: false);
    }
  }

  void _onQuickValuePadTap(int value) =>
      widget.controller.game.selectActiveDigit(value, asNote: false);

  void _onQuickNotePadTap(int value) =>
      widget.controller.game.selectActiveDigit(value, asNote: true);

  void _setQuickInputMode(bool enabled) {
    final game = widget.controller.game;
    if (enabled == game.quickInputMode) return;
    game.setQuickInputMode(enabled);
    // Same shared preference as the solo screen — the choice carries across.
    _storage.saveQuickInputEnabled(enabled);
  }

  Future<void> _confirmAbort() async {
    if (_abortDialogShowing || _raceDecided) return;
    final l10n = AppLocalizations.of(context)!;
    _abortDialogShowing = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.raceAbortConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.continueAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.giveUpAction),
          ),
        ],
      ),
    );
    _abortDialogShowing = false;
    if (confirmed == true) await widget.controller.abort();
  }

  /// Routes the leading back button and the system/gesture back action to
  /// whichever dialog (if any) is currently in the way, so a back press
  /// never fights with a race-decided navigation racing in underneath it.
  void _onBackPressed() {
    if (_resolvingContinue) {
      Navigator.of(context).pop(false);
    } else if (_raceDecided) {
      _goToResult();
    } else {
      _confirmAbort();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_handedOff) {
      widget.controller.removeListener(_onRaceChanged);
      widget.controller.game.removeListener(_onGameChanged);
      widget.controller.dispose();
    }
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final game = widget.controller.game;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPressed();
      },
      child: GradientScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PixelIcons.arrowBack),
            onPressed: _onBackPressed,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatTime(game.elapsedSeconds)),
              const SizedBox(width: 14),
              Text(
                l10n.mistakesLabel(game.mistakes, GameController.maxMistakes),
                style: const TextStyle(
                  fontSize: 14,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _DuelProgressGauge(
                    selfFilled: game.correctFilledCount,
                    opponentFilled: widget.controller.opponentFilledCount,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                      child: Column(
                        children: [
                          Flexible(
                            child: SudokuGridWidget(
                                controller: game,
                                onQuickInput: _onQuickInput),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              QuickInputToggle(
                                active: game.quickInputMode,
                                onToggle: _setQuickInputMode,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GameControlsRow(
                    canUndo: game.canUndo,
                    onUndo: () => setState(() => game.undo()),
                    canErase: game.canErase,
                    onErase: () => setState(() => game.eraseSelected()),
                    isNoteMode: game.isNoteMode,
                    onToggleNoteMode: () =>
                        setState(() => game.toggleNoteMode()),
                    // Races offer no hint/auto-fill (no rewarded-ad wiring),
                    // so hide those assist buttons entirely rather than show
                    // a dead hint button and a misleading ad badge.
                    showAssists: false,
                  ),
                  const SizedBox(height: 16),
                  NumberPadWidget(
                    controller: game,
                    isNotePad: false,
                    onNumberSelected: game.quickInputMode
                        ? _onQuickValuePadTap
                        : (value) => setState(() => game.inputValue(value)),
                    selectedNumber:
                        game.quickInputMode && !game.activeDigitIsNote
                            ? game.activeDigit
                            : null,
                  ),
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    opacity: game.isNoteMode ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !game.isNoteMode,
                      child: NumberPadWidget(
                        controller: game,
                        isNotePad: true,
                        onNumberSelected: game.quickInputMode
                            ? _onQuickNotePadTap
                            : (value) => setState(() => game.toggleNote(value)),
                        selectedNumber:
                            game.quickInputMode && game.activeDigitIsNote
                                ? game.activeDigit
                                : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              // Overlaid rather than inserted into the Column above so its
              // appearance/disappearance never shifts the board's size —
              // it floats on top of the progress gauge instead of pushing
              // everything below it down.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !widget.controller.opponentLeft,
                  child: AnimatedOpacity(
                    opacity: widget.controller.opponentLeft ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l10n.opponentDisconnectedCountdown(
                            widget.controller.disconnectSeconds ??
                                RaceController.graceSeconds),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Self-vs-opponent progress on a shared 0-81 scale, so the *gap* between the
/// two bars reads at a glance instead of needing to compare two separate
/// numbers — with a pulsing highlight once the opponent is close to
/// finishing, for a bit of visual urgency.
class _DuelProgressGauge extends StatelessWidget {
  const _DuelProgressGauge({
    required this.selfFilled,
    required this.opponentFilled,
  });

  final int selfFilled;
  final int opponentFilled;

  static const _total = 81;
  static const _opponentColor = Color(0xFFE11D48);
  static const _leadColor = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final diff = selfFilled - opponentFilled;
    // Opponent is close to finishing and at least even with (or ahead of)
    // the player — the moment tension should spike.
    final opponentNearFinish = opponentFilled >= _total - 12 && diff <= 0;

    Widget track(int filled, Color color) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 14,
            color: color.withValues(alpha: 0.15),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (filled / _total).clamp(0.0, 1.0).toDouble(),
              child: Container(color: color),
            ),
          ),
        );

    Widget row(String label, int filled, Color color, {bool pulse = false}) {
      final bar = track(filled, color);
      return Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: pulse
                ? bar
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.04, 1.3),
                      duration: 550.ms,
                    )
                : bar,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$filled/$_total',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      );
    }

    final gapColor = diff > 0
        ? _leadColor
        : diff < 0
            ? _opponentColor
            : scheme.onSurfaceVariant;
    final gapText = diff > 0
        ? l10n.raceLeadingBy(diff)
        : diff < 0
            ? l10n.raceTrailingBy(-diff)
            : l10n.raceTied;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(l10n.raceSelfLabel, selfFilled, scheme.primary),
          const SizedBox(height: 6),
          row(l10n.opponentProgressLabel, opponentFilled, _opponentColor,
              pulse: opponentNearFinish),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              gapText,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: gapColor),
            ),
          ),
        ],
      ),
    );
  }
}
