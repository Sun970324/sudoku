import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/daily.dart';
import '../../models/difficulty.dart';
import '../../models/sudoku_puzzle.dart';
import '../../services/daily_puzzle_service.dart';
import '../../services/generation/sudoku_generator.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../state/auth_controller.dart';
import '../../widgets/sign_in_prompt.dart';
import '../game_screen.dart';
import 'daily_result_screen.dart';

/// Gate + router for the daily puzzle: requires sign-in (guest ok), then
/// fetches (or first-writer-wins seeds) today's shared puzzle and routes
/// either into the game or — when today is already completed — straight to
/// the leaderboard. Modeled on MatchmakingScreen.
class DailyEntryScreen extends StatefulWidget {
  const DailyEntryScreen({
    super.key,
    required this.auth,
    required this.puzzleQueue,
  });

  final AuthController auth;
  final PuzzleQueueManager puzzleQueue;

  @override
  State<DailyEntryScreen> createState() => _DailyEntryScreenState();
}

class _DailyEntryScreenState extends State<DailyEntryScreen> {
  final DailyPuzzleService _service = DailyPuzzleService();
  bool _loading = false;
  bool _failed = false;

  /// Guards against the auth listener and a retry racing to route twice.
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    if (widget.auth.isSignedIn) _load();
  }

  void _onAuthChanged() {
    if (widget.auth.isSignedIn && !_loading && !_routed) _load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        _service.fetchTodayPuzzle(),
        _service.fetchLeaderboard(),
      ]);
      var today = results[0] as DailyPuzzle?;
      final leaderboard = results[1] as DailyLeaderboard;

      if (today == null) {
        // Nobody has seeded today yet — this client provides the puzzle.
        // takeLast (not take): the queue's front is what HomeScreen's
        // preview shows, so it must never become the shared daily board.
        // create_daily_puzzle is first-writer-wins and always returns the
        // canonical row, so a concurrent seeder is harmless.
        final candidate = widget.puzzleQueue.takeLast(Difficulty.medium) ??
            await _generateMediumPuzzle();
        today = await _service.createTodayPuzzle(candidate);
      }

      if (!mounted || _routed) return;
      _routed = true;
      if (leaderboard.completedToday) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DailyResultScreen(
              puzzle: today!.puzzle,
              preloaded: leaderboard,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen.daily(puzzle: today!.puzzle),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailyTitle)),
      body: Center(
        child: !widget.auth.isSignedIn
            ? SignInPrompt(
                auth: widget.auth,
                title: l10n.dailySignInPromptTitle,
              )
            : _failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.dailySubmitFailed),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _load,
                        child: Text(l10n.retryAction),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.dailyLoading),
                    ],
                  ),
      ),
    );
  }
}

Future<SudokuPuzzle> _generateMediumPuzzle() async {
  final json = await Isolate.run(_generateMediumPuzzleJson);
  return SudokuPuzzle.fromJson(json);
}

// Top-level (not a method) so the closure Isolate.run sends across the
// isolate boundary captures nothing, and JSON (not SudokuPuzzle) crosses
// back — same reasoning as PuzzleQueueManager's _isolateGenerateBatch.
Map<String, dynamic> _generateMediumPuzzleJson() =>
    SudokuGenerator().generate(Difficulty.medium).toJson();
