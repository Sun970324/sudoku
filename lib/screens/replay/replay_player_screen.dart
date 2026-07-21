import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/game_replay.dart';
import '../../models/game_snapshot.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pixel_icon.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/replay_board.dart';
import '../game_screen.dart';

/// Steps through one finished game's move log ([GameReplay]) a move at a time,
/// rebuilding the exact board/notes at each point via [reconstructReplay], with
/// an option to pick up solving from the current step.
class ReplayPlayerScreen extends StatefulWidget {
  const ReplayPlayerScreen({super.key, required this.replay});

  final GameReplay replay;

  @override
  State<ReplayPlayerScreen> createState() => _ReplayPlayerScreenState();
}

class _ReplayPlayerScreenState extends State<ReplayPlayerScreen> {
  /// How many moves are applied: 0 = the pristine puzzle, events.length = the
  /// final board the player ended on.
  int _step = 0;

  int get _total => widget.replay.events.length;

  int get _elapsed => _step == 0 ? 0 : widget.replay.events[_step - 1].elapsed;

  /// The single cell the current step just changed, for the board's highlight.
  ({int row, int col})? get _highlight {
    if (_step == 0) return null;
    final event = widget.replay.events[_step - 1];
    if (event.type == ReplayEventType.place ||
        event.type == ReplayEventType.note) {
      return (row: event.row!, col: event.col!);
    }
    return null;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _setStep(int step) {
    final clamped = step.clamp(0, _total);
    if (clamped == _step) return;
    setState(() => _step = clamped);
  }

  /// Reconstructs the state at the current step and hands it to a fresh game to
  /// keep solving from there. Mistakes/hints reset (a practice continue); the
  /// clock resumes from this move's elapsed time, and the move log so far is
  /// carried so the continued game still yields a complete replay on finish.
  void _resumeFromHere() {
    final (board, notes) = reconstructReplay(widget.replay, _step);
    final snapshot = GameSnapshot(
      puzzle: widget.replay.puzzle,
      board: board,
      notes: notes
          .map((row) => row.map((cell) => cell.toList()..sort()).toList())
          .toList(),
      mistakes: 0,
      elapsedSeconds: _elapsed,
      hintsUsed: 0,
      events: widget.replay.events.sublist(0, _step),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen.resume(resumeSnapshot: snapshot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (board, notes) = reconstructReplay(widget.replay, _step);

    return GradientScaffold(
      appBar: AppBar(
          leading: const PixelBackButton(), title: Text(l10n.replayTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ReplayBoard(
                puzzle: widget.replay.puzzle,
                board: board,
                notes: notes,
                highlight: _highlight,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PixelIcons.timelapse, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$_step / $_total · ${_formatTime(_elapsed)}',
                    style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 16),
                  ),
                ],
              ),
              if (_total > 0)
                Slider(
                  value: _step.toDouble(),
                  max: _total.toDouble(),
                  divisions: _total,
                  onChanged: (v) => _setStep(v.round()),
                ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: 28,
                    onPressed: _step > 0 ? () => _setStep(_step - 1) : null,
                    icon: const Icon(PixelIcons.chevronLeft),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filledTonal(
                    iconSize: 28,
                    onPressed:
                        _step < _total ? () => _setStep(_step + 1) : null,
                    icon: const Icon(PixelIcons.chevronRight),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              PopButton(
                onPressed: _resumeFromHere,
                label: l10n.replayResumeFromHere,
                icon: PixelIcons.play,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
