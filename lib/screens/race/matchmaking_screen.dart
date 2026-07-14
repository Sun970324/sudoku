import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../state/auth_controller.dart';
import '../../state/race_controller.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matchmakingTitle)),
      body: Center(
        child: !widget.auth.isSignedIn
            ? _SignInPrompt(auth: widget.auth)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusText(l10n, _controller?.phase)),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _cancel,
                      child: Text(l10n.cancelAction),
                    ),
                  ],
                ),
              ),
      ),
    );
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

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.signInPromptTitle, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: auth.signInWithGoogle,
            child: Text(l10n.signInWithGoogle),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: auth.signInWithApple,
            child: Text(l10n.signInWithApple),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: auth.signInAnonymously,
            child: Text(l10n.signInAsGuest),
          ),
        ],
      ),
    );
  }
}
