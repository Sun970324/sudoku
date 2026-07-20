import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../models/race.dart';
import '../../models/tier.dart';
import '../../models/user_profile.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../services/race_service.dart';
import '../../services/season_service.dart';
import '../../services/storage_service.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/coach_mark.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_icon.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';
import '../../widgets/season_banner.dart';
import '../../widgets/sign_in_prompt.dart';
import '../../widgets/tier_badge.dart';
import '../game_screen.dart';
import 'friend_match_screen.dart';
import 'matchmaking_screen.dart';
import 'rating_leaderboard_screen.dart';

/// Entry hub for all racing: shows the player's own standing (username,
/// tier, rating/record) and branches into ranked matchmaking or the
/// friend-match (room code) flow. Also the single sign-in gate for racing —
/// downstream screens can assume a signed-in user.
class RaceLobbyScreen extends StatefulWidget {
  const RaceLobbyScreen({
    super.key,
    required this.auth,
    required this.puzzleQueue,
  });

  final AuthController auth;
  final PuzzleQueueManager puzzleQueue;

  @override
  State<RaceLobbyScreen> createState() => _RaceLobbyScreenState();
}

class _RaceLobbyScreenState extends State<RaceLobbyScreen> {
  Future<List<RaceHistoryEntry>>? _historyFuture;

  // Coach-mark anchors + one-shot guard for the first-entry race tutorial.
  final _profileKey = GlobalKey();
  final _friendKey = GlobalKey();
  final _rankedKey = GlobalKey();
  final _leaderboardKey = GlobalKey();
  bool _tutorialChecked = false;
  bool _seasonSummaryChecked = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    if (widget.auth.isSignedIn) {
      _historyFuture = RaceService().fetchHistory();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
    _maybeShowSeasonSummary();
  }

  void _onAuthChanged() {
    if (widget.auth.isSignedIn && _historyFuture == null) {
      _historyFuture = RaceService().fetchHistory();
    }
    if (mounted) setState(() {});
    _maybeShowTutorial();
    _maybeShowSeasonSummary();
  }

  /// One-time end-of-season celebration: if the player's newest archived
  /// standing is for a season we haven't celebrated yet, show its final
  /// tier/rank/record plus the fresh (post-reset) starting rating. Players
  /// who didn't play the closed season have no standings row, so nothing
  /// shows for them.
  Future<void> _maybeShowSeasonSummary() async {
    if (_seasonSummaryChecked || !widget.auth.isSignedIn) return;
    _seasonSummaryChecked = true;
    try {
      final standings = await SeasonService().fetchMyStandings();
      if (standings.isEmpty) return;
      final latest = standings.first;
      if (latest.seasonId <= await StorageService().loadCelebratedSeasonId()) {
        return;
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.seasonEndedTitle(latest.seasonId)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TierBadge(tier: latest.finalTier, large: true),
              const SizedBox(height: 12),
              Text(l10n.seasonStandingDetail(
                  latest.finalRank, latest.wins, latest.losses)),
              if (widget.auth.profile != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.seasonEndedNewStart(widget.auth.profile!.rating),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.okAction),
            ),
          ],
        ),
      );
      // Persisted only after the dialog is dismissed, so a kill mid-dialog
      // shows it again next time rather than silently losing it.
      await StorageService().saveCelebratedSeasonId(latest.seasonId);
    } catch (_) {
      // Transient fetch failure: allow a retry on the next lobby entry.
      _seasonSummaryChecked = false;
    }
  }

  /// Spotlights the profile card, friend/ranked buttons, and leaderboard —
  /// only once the player is signed in with a loaded profile (the anchors
  /// don't exist behind the sign-in gate). Signed-out visitors just see the
  /// self-explanatory [SignInPrompt].
  void _maybeShowTutorial() {
    if (_tutorialChecked) return;
    if (!widget.auth.isSignedIn || widget.auth.profile == null) return;
    _tutorialChecked = true;
    // Let the staggered list entrance animation settle before measuring.
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      if (await StorageService().loadSeenRaceTutorial()) return;
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showCoachMark(
        context,
        steps: [
          CoachMarkStep(
            targetKey: _profileKey,
            title: l10n.tutorialRaceProfileTitle,
            body: l10n.tutorialRaceProfileBody,
            align: ContentAlign.bottom,
          ),
          CoachMarkStep(
            targetKey: _friendKey,
            title: l10n.tutorialRaceFriendTitle,
            body: l10n.tutorialRaceFriendBody,
            align: ContentAlign.bottom,
          ),
          CoachMarkStep(
            targetKey: _rankedKey,
            title: l10n.tutorialRaceRankedTitle,
            body: l10n.tutorialRaceRankedBody,
            align: ContentAlign.top,
          ),
          CoachMarkStep(
            targetKey: _leaderboardKey,
            title: l10n.tutorialRaceLeaderboardTitle,
            body: l10n.tutorialRaceLeaderboardBody,
            align: ContentAlign.top,
          ),
        ],
        onDone: () => StorageService().saveSeenRaceTutorial(true),
      );
    });
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onRankedPressed() {
    final difficulty = widget.auth.profile?.tier.raceDifficulty ??
        Difficulty.medium;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchmakingScreen(
          auth: widget.auth,
          puzzleQueue: widget.puzzleQueue,
          difficulty: difficulty,
        ),
      ),
    );
  }

  void _onFriendMatchPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendMatchScreen(
          auth: widget.auth,
          puzzleQueue: widget.puzzleQueue,
        ),
      ),
    );
  }

  void _onLeaderboardPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatingLeaderboardScreen(auth: widget.auth),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  /// One finished race, tappable to replay its puzzle — moved here from
  /// StatsScreen so past races live where racing starts.
  Widget _buildRaceHistoryTile(RaceHistoryEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final delta = entry.ratingDelta;
    final deltaColor = delta >= 0 ? Colors.green : Colors.red;
    final deltaText = delta >= 0 ? '+$delta' : '$delta';
    final resultLabel =
        entry.won ? l10n.raceHistoryResultWon : l10n.raceHistoryResultLost;
    const baseStyle = TextStyle(fontSize: 13);
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen.newGame(
              difficulty: entry.puzzle.difficulty,
              puzzle: entry.puzzle,
            ),
          ),
        ),
        leading: Icon(
          entry.won ? PixelIcons.trophy : PixelIcons.sadFace,
          color:
              entry.won ? Colors.amber : Theme.of(context).colorScheme.outline,
        ),
        title: Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(
                  text:
                      '($resultLabel) ${_formatDate(entry.finishedAt)} vs ${entry.opponentUsername} ${entry.ratingAfter}'),
              const TextSpan(text: ' ('),
              TextSpan(
                text: deltaText,
                style: baseStyle.copyWith(
                  color: deltaColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: ')'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = widget.auth.profile;
    return GradientScaffold(
      appBar: AppBar(title: Text(l10n.raceLobbyTitle)),
      body: !widget.auth.isSignedIn
          ? Center(
              child: SignInPrompt(
                auth: widget.auth,
                title: l10n.signInPromptTitle,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SeasonBanner(),
                const SizedBox(height: 16),
                if (profile != null)
                  _ProfileCard(key: _profileKey, profile: profile),
                const SizedBox(height: 24),
                PopButton(
                  key: _friendKey,
                  onPressed: _onFriendMatchPressed,
                  icon: PixelIcons.group,
                  color: const Color(0xFFD99A06),
                  variant: PopButtonVariant.secondary,
                  label: l10n.friendMatchButton,
                  expanded: true,
                ),
                const SizedBox(height: 16),
                PopButton(
                  key: _rankedKey,
                  onPressed: _onRankedPressed,
                  icon: PixelIcons.medal,
                  label: l10n.rankedMatchButton,
                  expanded: true,
                ),
                const SizedBox(height: 16),
                PopButton(
                  key: _leaderboardKey,
                  onPressed: _onLeaderboardPressed,
                  icon: PixelIcons.leaderboard,
                  variant: PopButtonVariant.outline,
                  label: l10n.leaderboardButton,
                  expanded: true,
                ),
                if (_historyFuture != null) ...[
                  const SizedBox(height: 24),
                  Text(l10n.raceHistoryTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FutureBuilder<List<RaceHistoryEntry>>(
                    future: _historyFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final history = snapshot.data!;
                      if (history.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l10n.raceHistoryEmpty),
                        );
                      }
                      return Column(
                        children:
                            history.map(_buildRaceHistoryTile).toList(),
                      );
                    },
                  ),
                ],
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutCubic),
            ),
    );
  }
}

/// The player's standing, mirroring MyPageScreen's profile header (tier
/// chip + rating/record line) in read-only card form — kept separate
/// rather than extracted from MyPage, whose version is entangled with
/// username editing state.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tierColor = profile.tier.color(AppPalette.isDark(context));
    return PopCard(
      tint: tierColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(profile.username,
              style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 22)),
          const SizedBox(height: 10),
          TierBadge(tier: profile.tier, large: true),
          const SizedBox(height: 10),
          Text(
            l10n.ratingAndRecord(profile.rating, profile.wins, profile.losses),
            textAlign: TextAlign.center,
          ),
          // Placement progress for the season's first 5 ranked games (the
          // server's high-K calibration window is longer — 30 games — but 5
          // is what reads as "placements" without dragging on).
          if (profile.seasonGames < 5) ...[
            const SizedBox(height: 6),
            Text(
              l10n.placementProgress(profile.seasonGames, 5),
              style: TextStyle(fontSize: 13, color: tierColor),
            ),
          ],
        ],
      ),
    );
  }
}
