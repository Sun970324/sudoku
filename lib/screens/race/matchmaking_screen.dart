import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../state/auth_controller.dart';
import '../../state/race_controller.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pulse_ring.dart';
import '../../widgets/sign_in_prompt.dart';
import 'race_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({
    super.key,
    required this.auth,
    required this.puzzleQueue,
    required this.difficulty,
  });

  final AuthController auth;
  final PuzzleQueueManager puzzleQueue;
  final Difficulty difficulty;

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  RaceController? _controller;

  /// True once this screen has handed the controller off to [RaceScreen] —
  /// dispose() must then leave it alone instead of tearing it down out from
  /// under the screen that now owns it.
  bool _handedOff = false;

  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    if (widget.auth.isSignedIn) _startMatching();
  }

  void _onAuthChanged() {
    if (widget.auth.isSignedIn && _controller == null) _startMatching();
    if (mounted) setState(() {});
  }

  void _startMatching() {
    final controller = RaceController(
      difficulty: widget.difficulty,
      puzzleQueue: widget.puzzleQueue,
    );
    controller.addListener(_onRaceChanged);
    controller.start();
    _elapsedTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    setState(() => _controller = controller);
  }

  void _onRaceChanged() {
    final controller = _controller;
    if (controller == null || _handedOff) return;
    if (controller.phase == RacePhase.racing) {
      _handedOff = true;
      controller.removeListener(_onRaceChanged);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RaceScreen(controller: controller)),
      );
    } else {
      setState(() {});
    }
  }

  Future<void> _cancel() async {
    final controller = _controller;
    if (controller != null) {
      if (controller.phase == RacePhase.matching) {
        await controller.cancelWhileMatching();
      } else {
        await controller.abort();
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    widget.auth.removeListener(_onAuthChanged);
    if (!_handedOff) {
      _controller?.removeListener(_onRaceChanged);
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(title: Text(l10n.matchmakingTitle)),
      body: Center(
        child: !widget.auth.isSignedIn
            ? SignInPrompt(
                auth: widget.auth,
                title: l10n.signInPromptTitle,
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulseRing(),
                    const SizedBox(height: 24),
                    Text(
                      _statusText(l10n, _controller?.phase),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _ElapsedPill(
                        text: l10n.matchmakingElapsed(
                            _formatElapsed(_elapsedSeconds))),
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

  String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _statusText(AppLocalizations l10n, RacePhase? phase) {
    switch (phase) {
      case RacePhase.waitingForPuzzle:
        return l10n.matchmakingPreparingPuzzle;
      case RacePhase.readyCheck:
        return l10n.matchmakingReadyCheck;
      case RacePhase.matching:
      case RacePhase.racing:
      case RacePhase.finished:
      case RacePhase.aborted:
      case null:
        return l10n.matchmakingSearching;
    }
  }
}

/// Rounded pill showing the waiting timer.
class _ElapsedPill extends StatelessWidget {
  const _ElapsedPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Jua', color: scheme.primary),
      ),
    );
  }
}
