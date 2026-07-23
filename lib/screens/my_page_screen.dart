import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/season.dart';
import '../models/tier.dart';
import '../models/user_profile.dart';
import '../services/season_service.dart';
import '../state/auth_controller.dart';
import '../theme/app_palette.dart';
import 'favorites/favorites_screen.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/pixel_back_button.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/pop_button.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/pop_card.dart';
import '../widgets/tier_badge.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    required this.auth,
    this.seasonService,
  });

  final AuthController auth;

  /// Injectable for tests; defaults to a real [SeasonService].
  final SeasonService? seasonService;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _usernameController = TextEditingController();
  bool _editingUsername = false;
  late final SeasonService _seasonService =
      widget.seasonService ?? SeasonService();

  /// Fetched once (not per auth-notify rebuild) — past-season standings only
  /// ever change at a season rollover.
  Future<List<SeasonStanding>>? _pastSeasons;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    if (widget.auth.isSignedIn) {
      _pastSeasons = _seasonService.fetchMyStandings();
    }
  }

  void _onAuthChanged() {
    if (widget.auth.isSignedIn && _pastSeasons == null) {
      _pastSeasons = _seasonService.fetchMyStandings();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(
          leading: const PixelBackButton(), title: Text(l10n.myPageTitle)),
      body: AnimatedBuilder(
        animation: widget.auth,
        builder: (context, _) {
          final profile = widget.auth.profile;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.auth.errorMessage != null) ...[
                Text(
                  l10n.errorOccurred(widget.auth.errorMessage!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              if (profile == null)
                _SignInSection(auth: widget.auth)
              else
                _ProfileSection(
                  auth: widget.auth,
                  profile: profile,
                  pastSeasons: _pastSeasons,
                  editing: _editingUsername,
                  usernameController: _usernameController,
                  onEditPressed: () {
                    _usernameController.text = profile.username;
                    setState(() => _editingUsername = true);
                  },
                  onSavePressed: () async {
                    await widget.auth.updateUsername(_usernameController.text);
                    if (!mounted) return;
                    setState(() => _editingUsername = false);
                  },
                  onCancelPressed: () =>
                      setState(() => _editingUsername = false),
                ),
              if (widget.auth.isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Archived past-season results — the season's recognition reward: each
/// closed season's final tier and rank, on permanent display. Silently
/// absent while loading, on error, or before any season has closed for
/// this player (mirrors [_PastSeasonsCard]'s own silent-until-ready pattern).
class _PastSeasonsCard extends StatelessWidget {
  const _PastSeasonsCard({required this.future});

  final Future<List<SeasonStanding>>? future;

  @override
  Widget build(BuildContext context) {
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<SeasonStanding>>(
      future: future,
      builder: (context, snapshot) {
        final standings = snapshot.data;
        if (standings == null || standings.isEmpty) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: PopCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.pastSeasonsTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final standing in standings)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          l10n.seasonName(standing.seasonId),
                          style: const TextStyle(
                              fontFamily: 'Mulmaru', fontSize: 15),
                        ),
                        const Spacer(),
                        TierBadge(tier: standing.finalTier),
                        const SizedBox(width: 8),
                        Text(l10n.seasonStandingDetail(standing.finalRank,
                            standing.wins, standing.losses)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignInSection extends StatelessWidget {
  const _SignInSection({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.signInPromptTitle, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GoogleAuthButton(
          onPressed: auth.signInWithGoogle,
          label: l10n.signInWithGoogle,
        ),
        const SizedBox(height: 12),
        AppleAuthButton(
          onPressed: auth.signInWithApple,
          label: l10n.signInWithApple,
        ),
        const SizedBox(height: 16),
        PopButton(
          onPressed: auth.signInAnonymously,
          label: l10n.signInAsGuest,
          variant: PopButtonVariant.outline,
          expanded: true,
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.auth,
    required this.profile,
    required this.pastSeasons,
    required this.editing,
    required this.usernameController,
    required this.onEditPressed,
    required this.onSavePressed,
    required this.onCancelPressed,
  });

  final AuthController auth;
  final UserProfile profile;
  final Future<List<SeasonStanding>>? pastSeasons;
  final bool editing;
  final TextEditingController usernameController;
  final VoidCallback onEditPressed;
  final VoidCallback onSavePressed;
  final VoidCallback onCancelPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    final tierColor = profile.tier.color(isDark);
    final next = profile.tier.nextTier;
    final winRate = profile.wins + profile.losses == 0
        ? 0
        : profile.wins * 100 ~/ (profile.wins + profile.losses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopCard(
          tint: tierColor,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: tierColor.withValues(alpha: 0.2),
                child: Text(
                  profile.username.isEmpty
                      ? '?'
                      : profile.username.characters.first.toUpperCase(),
                  style: TextStyle(
                      fontFamily: 'Mulmaru', fontSize: 26, color: tierColor),
                ),
              ),
              const SizedBox(height: 12),
              if (editing)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: usernameController,
                        autofocus: true,
                        maxLength: 12,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(PixelIcons.check),
                      onPressed: onSavePressed,
                    ),
                    IconButton(
                      icon: const Icon(PixelIcons.close),
                      onPressed: onCancelPressed,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(profile.username,
                        style: const TextStyle(
                            fontFamily: 'Mulmaru', fontSize: 22)),
                    IconButton(
                      icon: const Icon(PixelIcons.edit, size: 18),
                      onPressed: onEditPressed,
                    ),
                  ],
                ),
              TierBadge(tier: profile.tier, large: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PopCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                '${profile.rating}',
                style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 36),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.ratingAndRecord(
                    profile.rating, profile.wins, profile.losses),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.winRateLabel(winRate),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Progress toward the next tier's rating floor, over the
              // current tier's band.
              if (next != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ((profile.rating - profile.tier.minRating) /
                            (next.minRating - profile.tier.minRating))
                        .clamp(0.0, 1.0),
                    minHeight: 10,
                    color: tierColor,
                    backgroundColor: tierColor.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                next == null
                    ? l10n.tierTopReached
                    : l10n.tierPromotionRemaining(
                        (next.minRating - profile.rating)
                            .clamp(0, next.minRating),
                        next.label(context),
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
        _PastSeasonsCard(future: pastSeasons),
        const SizedBox(height: 16),
        PopButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesScreen()),
          ),
          label: l10n.favoritesTitle,
          icon: PixelIcons.star,
          variant: PopButtonVariant.outline,
          expanded: true,
        ),
        const SizedBox(height: 16),
        PopCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (auth.isAnonymous) ...[
                Text(l10n.linkAccountPrompt, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                GoogleAuthButton(
                  onPressed: auth.linkGoogle,
                  label: l10n.linkGoogleAction,
                ),
                const SizedBox(height: 12),
                AppleAuthButton(
                  onPressed: auth.linkApple,
                  label: l10n.linkAppleAction,
                ),
                const SizedBox(height: 16),
              ],
              PopButton(
                onPressed: auth.signOut,
                label: l10n.signOutAction,
                variant: PopButtonVariant.outline,
                expanded: true,
              ),
            ],
          ),
        ),
      ]
          .animate(interval: 60.ms)
          .fadeIn(duration: 250.ms)
          .slideY(begin: 0.08, curve: Curves.easeOutCubic),
    );
  }
}
