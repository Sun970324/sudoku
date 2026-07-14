import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/race_controller.dart';
import '../../widgets/game_controls_row.dart';
import '../../widgets/number_pad_widget.dart';
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
      setState(() {});
    }
  }

  void _onGameChanged() => setState(() {});

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
            icon: const Icon(Icons.arrow_back),
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
                    l10n.opponentLeftBanner,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SudokuGridWidget(controller: game),
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
                // Hints/auto-fill aren't offered in races (no AdService
                // wiring here) — GameControlsRow always renders both
                // buttons, so these are no-ops rather than a new
                // hide-this-button flag on a widget every other screen uses.
                onHint: () {},
                canAutoFillNotes: false,
                onAutoFillNotes: () {},
              ),
              const SizedBox(height: 16),
              NumberPadWidget(
                controller: game,
                isNotePad: false,
                onNumberSelected: (value) => setState(() => game.inputValue(value)),
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
                    onNumberSelected: (value) =>
                        setState(() => game.toggleNote(value)),
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
