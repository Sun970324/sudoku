import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_icon.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';
import '../../models/daily.dart';
import '../../models/sudoku_puzzle.dart';
import '../../services/daily_puzzle_service.dart';
import '../game_screen.dart';

/// A fresh daily win's payload, held in memory so a failed submit can be
/// retried from this screen (submit_daily_result is `on conflict do
/// nothing`, so retries are idempotent).
class DailySubmission {
  const DailySubmission({
    required this.board,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsUsed,
  });

  final List<List<int>> board;
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
}

/// Terminal screen of the daily flow: submits a fresh win (when
/// [submission] is set), then shows today's rank + top-10 leaderboard.
/// Entered three ways: right after a win (submission set), straight from
/// the entry point when today was already completed ([preloaded] set), or
/// after a replay win (both null — fetch only, nothing to submit).
class DailyResultScreen extends StatefulWidget {
  const DailyResultScreen({
    super.key,
    required this.puzzle,
    this.submission,
    this.preloaded,
  });

  final SudokuPuzzle puzzle;
  final DailySubmission? submission;
  final DailyLeaderboard? preloaded;

  @override
  State<DailyResultScreen> createState() => _DailyResultScreenState();
}

class _DailyResultScreenState extends State<DailyResultScreen> {
  final DailyPuzzleService _service = DailyPuzzleService();

  DailyLeaderboard? _leaderboard;
  bool _loading = false;
  bool _failed = false;

  /// True when a submission was attempted but not recorded (already done
  /// today, or finished past the day boundary) — shows dailyNotRankedNotice.
  bool _notRanked = false;

  @override
  void initState() {
    super.initState();
    _leaderboard = widget.preloaded;
    if (_leaderboard == null || widget.submission != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final submission = widget.submission;
      if (submission != null) {
        final recorded = await _service.submitResult(
          board: submission.board,
          elapsedSeconds: submission.elapsedSeconds,
          mistakes: submission.mistakes,
          hintsUsed: submission.hintsUsed,
        );
        _notRanked = !recorded;
      }
      final leaderboard = await _service.fetchLeaderboard();
      if (!mounted) return;
      setState(() {
        _leaderboard = leaderboard;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(title: Text(l10n.dailyResultTitle)),
      body: _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.dailySubmitFailed),
                  const SizedBox(height: 16),
                  PopButton(
                    onPressed: _load,
                    variant: PopButtonVariant.outline,
                    label: l10n.retryAction,
                  ),
                ],
              ),
            )
          : _loading || _leaderboard == null
              ? const Center(child: CircularProgressIndicator())
              : _buildResult(l10n, _leaderboard!),
    );
  }

  Widget _buildResult(AppLocalizations l10n, DailyLeaderboard board) {
    final myTime =
        board.myElapsedSeconds ?? widget.submission?.elapsedSeconds;
    return CelebrationOverlay(
      play: board.myRank != null,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    Color(0xFFFFD24A),
                    Color(0xFFFFA726),
                  ]),
                ),
                child:
                    const Icon(PixelIcons.calendar, size: 48, color: Colors.white),
              )
                  .animate()
                  .scale(
                      begin: const Offset(0.5, 0.5),
                      curve: Curves.elasticOut,
                      duration: 700.ms),
              const SizedBox(height: 16),
              if (board.myRank != null)
                Text(
                  l10n.dailyMyRankLabel(board.myRank!, board.total),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              if (myTime != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatTime(myTime),
                  style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 44),
                ),
              ],
              if (_notRanked) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.dailyNotRankedNotice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PopCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.dailyLeaderboardTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (board.entries.isEmpty)
                  Text(l10n.dailyEmptyLeaderboard)
                else
                  ...board.entries.map(_buildEntryRow),
              ],
            ),
        ),
        const SizedBox(height: 24),
        PopButton(
          onPressed: () => Navigator.pop(context),
          label: l10n.homeButton,
          expanded: true,
        ),
        const SizedBox(height: 12),
        PopButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen.daily(
                puzzle: widget.puzzle,
                dailyAlreadyCompleted: true,
              ),
            ),
          ),
          variant: PopButtonVariant.outline,
          label: l10n.dailyReplayAction,
          expanded: true,
        ),
      ],
    ),
    );
  }

  Widget _buildEntryRow(DailyLeaderboardEntry entry) {
    final isSelf = entry.profileId == _service.selfId;
    return Container(
      decoration: isSelf
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${entry.rank}.',
              style: TextStyle(
                  fontWeight: isSelf ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          Expanded(
            child: Text(
              entry.username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: isSelf ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          Text(
            _formatTime(entry.elapsedSeconds),
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: isSelf ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
