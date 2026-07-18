import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../models/tier.dart';
import '../../models/user_profile.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';
import '../../widgets/sign_in_prompt.dart';
import '../../widgets/tier_badge.dart';
import 'friend_match_screen.dart';
import 'matchmaking_screen.dart';

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
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
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
                if (profile != null) _ProfileCard(profile: profile),
                const SizedBox(height: 24),
                PopButton(
                  onPressed: _onFriendMatchPressed,
                  icon: Icons.group,
                  color: const Color(0xFFD99A06),
                  variant: PopButtonVariant.secondary,
                  label: l10n.friendMatchButton,
                  expanded: true,
                ),
                const SizedBox(height: 16),
                PopButton(
                  onPressed: _onRankedPressed,
                  icon: Icons.military_tech,
                  label: l10n.rankedMatchButton,
                  expanded: true,
                ),
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
  const _ProfileCard({required this.profile});

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
              style: const TextStyle(fontFamily: 'Jua', fontSize: 22)),
          const SizedBox(height: 10),
          TierBadge(tier: profile.tier, large: true),
          const SizedBox(height: 10),
          Text(
            l10n.ratingAndRecord(profile.rating, profile.wins, profile.losses),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
