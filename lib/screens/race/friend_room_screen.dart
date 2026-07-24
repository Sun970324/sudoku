import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../state/race_controller.dart';
import '../../widgets/copyable_code_box.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pulse_ring.dart';
import 'race_screen.dart';

/// Waiting room for a friend match, in either role: the host shows its join
/// code and waits for the friend; the joiner submits a code and rides the
/// same pipeline. Owns the [RaceController] until racing begins, then hands
/// it to [RaceScreen] — same hand-off contract as MatchmakingScreen.
class FriendRoomScreen extends StatefulWidget {
  const FriendRoomScreen.host({
    super.key,
    required this.puzzleQueue,
    required Difficulty this.difficulty,
  }) : code = null;

  const FriendRoomScreen.join({
    super.key,
    required this.puzzleQueue,
    required String this.code,
  }) : difficulty = null;

  final PuzzleQueueManager puzzleQueue;

  /// Host mode: the difficulty the room is created with. Null when joining.
  final Difficulty? difficulty;

  /// Join mode: the friend's room code. Null when hosting.
  final String? code;

  bool get isHost => difficulty != null;

  @override
  State<FriendRoomScreen> createState() => _FriendRoomScreenState();
}

class _FriendRoomScreenState extends State<FriendRoomScreen> {
  late final RaceController _controller;

  /// True once this screen has handed the controller off to [RaceScreen] —
  /// dispose() must then leave it alone instead of tearing it down out from
  /// under the screen that now owns it.
  bool _handedOff = false;

  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _controller = RaceController(
      // The joiner's difficulty comes from the race row the host created;
      // this parameter only matters for enqueue/host paths.
      difficulty: widget.difficulty ?? Difficulty.medium,
      puzzleQueue: widget.puzzleQueue,
    );
    _controller.addListener(_onRaceChanged);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    if (widget.isHost) {
      _controller.startPrivateHost();
    } else {
      _join();
    }
  }

  Future<void> _join() async {
    try {
      await _controller.joinPrivateRoom(widget.code!);
    } catch (_) {
      // Unknown/expired/self-owned code — nothing was attached, so just
      // report and leave.
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.roomCodeInvalid)));
      Navigator.pop(context);
    }
  }

  void _onRaceChanged() {
    if (_handedOff) return;
    if (_controller.phase == RacePhase.racing) {
      _handedOff = true;
      _controller.removeListener(_onRaceChanged);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RaceScreen(controller: _controller)),
      );
    } else if (_controller.phase == RacePhase.aborted) {
      // Host cancelled while we were joining (or vice versa).
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  Future<void> _cancel() async {
    if (_controller.phase == RacePhase.matching) {
      if (widget.isHost) {
        await _controller.cancelPrivateHost();
      }
      // A joiner in `matching` never got attached (join failed or is in
      // flight) — nothing to clean up server-side.
    } else {
      await _controller.abort();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    if (!_handedOff) {
      _controller.removeListener(_onRaceChanged);
      _controller.dispose();
    }
    super.dispose();
  }

  String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final joinCode = _controller.joinCode;
    return GradientScaffold(
      appBar: AppBar(
          leading: const PixelBackButton(),
          title: Text(
              widget.isHost ? l10n.waitingForFriendTitle : l10n.joinRoomTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isHost && joinCode != null) ...[
                // scaleDown keeps the hint on a single line in every locale
                // (English is wider than Korean) by shrinking it to fit the
                // width rather than wrapping or clipping.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l10n.roomCodeShareHint,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),
                CopyableCodeBox(code: joinCode),
                const SizedBox(height: 32),
              ],
              const PulseRing(),
              const SizedBox(height: 24),
              Text(
                _statusText(l10n),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.matchmakingElapsed(_formatElapsed(_elapsedSeconds)),
                  style: TextStyle(
                      fontFamily: 'Mulmaru',
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 32),
              PopButton(
                onPressed: _cancel,
                variant: PopButtonVariant.outline,
                label: l10n.cancelAction,
              ),
            ],
          ).animate().fadeIn(duration: 250.ms),
        ),
      ),
    );
  }

  String _statusText(AppLocalizations l10n) {
    switch (_controller.phase) {
      case RacePhase.waitingForPuzzle:
        return l10n.matchmakingPreparingPuzzle;
      case RacePhase.readyCheck:
        return l10n.matchmakingReadyCheck;
      case RacePhase.matching:
      case RacePhase.racing:
      case RacePhase.finished:
      case RacePhase.aborted:
        return widget.isHost
            ? l10n.waitingForFriend
            : l10n.matchmakingSearching;
    }
  }
}
