import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/storage_service.dart';
import '../../state/race_controller.dart';
import '../../widgets/game_controls_row.dart';
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onRaceChanged);
    widget.controller.game.addListener(_onGameChanged);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => widget.controller.game.tick());
  }

  void _onRaceChanged() {
    if (_handedOff) return;
    if (widget.controller.phase == RacePhase.finished) {
      _timer?.cancel();
      widget.controller.removeListener(_onRaceChanged);
      widget.controller.game.removeListener(_onGameChanged);
      _handedOff = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => RaceResultScreen(controller: widget.controller)),
      );
    } else if (widget.controller.phase == RacePhase.aborted) {
      _timer?.cancel();
      Navigator.pop(context);
    } else {
      // Opponent disconnect is now handled non-modally: a countdown banner
      // (below) plus an automatic server-verified win claim in the
      // controller — no dialog, and crucially no "give up" option (which
      // used to make the still-present player lose).
      setState(() {});
    }
  }

  void _onGameChanged() => setState(() {});

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
    final l10n = AppLocalizations.of(context)!;
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
    if (confirmed == true) await widget.controller.abort();
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
        _confirmAbort();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PixelIcons.arrowBack),
            onPressed: _confirmAbort,
          ),
          title: Text(_formatTime(game.elapsedSeconds)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.controller.opponentLeft)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l10n.opponentDisconnectedCountdown(
                        widget.controller.disconnectSeconds ??
                            RaceController.graceSeconds),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.opponentProgressLabel,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.controller.opponentFilledCount / 81,
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Column(
                    children: [
                      Flexible(
                        child: SudokuGridWidget(
                            controller: game, onQuickInput: _onQuickInput),
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
                onToggleNoteMode: () => setState(() => game.toggleNoteMode()),
                // Races offer no hint/auto-fill (no rewarded-ad wiring), so
                // hide those assist buttons entirely rather than show a dead
                // hint button and a misleading ad badge.
                showAssists: false,
              ),
              const SizedBox(height: 16),
              NumberPadWidget(
                controller: game,
                isNotePad: false,
                onNumberSelected: game.quickInputMode
                    ? _onQuickValuePadTap
                    : (value) => setState(() => game.inputValue(value)),
                selectedNumber: game.quickInputMode && !game.activeDigitIsNote
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
        ),
      ),
    );
  }
}
