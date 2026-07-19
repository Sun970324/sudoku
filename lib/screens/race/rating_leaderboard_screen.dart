import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/rating_leaderboard.dart';
import '../../models/tier.dart';
import '../../services/profile_service.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';
import '../../widgets/tier_badge.dart';

/// Global rating leaderboard — the top 100 played players by rating, plus
/// the viewer's own rank. Mirrors the daily leaderboard's load/state/row
/// structure ([DailyResultScreen]) so ranking presentation stays consistent.
class RatingLeaderboardScreen extends StatefulWidget {
  const RatingLeaderboardScreen({
    super.key,
    required this.auth,
    this.service,
  });

  final AuthController auth;

  /// Injectable for tests; defaults to a real [ProfileService].
  final ProfileService? service;

  @override
  State<RatingLeaderboardScreen> createState() =>
      _RatingLeaderboardScreenState();
}

class _RatingLeaderboardScreenState extends State<RatingLeaderboardScreen> {
  late final ProfileService _service = widget.service ?? ProfileService();

  RatingLeaderboard? _leaderboard;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(title: Text(l10n.leaderboardTitle)),
      body: _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.leaderboardLoadFailed),
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
              : _buildBody(l10n, _leaderboard!),
    );
  }

  Widget _buildBody(AppLocalizations l10n, RatingLeaderboard board) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Text(
            board.myRank != null
                ? l10n.leaderboardMyRankLabel(board.myRank!, board.total)
                : l10n.leaderboardMyRankUnranked,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
        PopCard(
          child: board.entries.isEmpty
              ? Text(l10n.leaderboardEmpty)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: board.entries.map(_buildEntryRow).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildEntryRow(RatingLeaderboardEntry entry) {
    final isSelf = entry.profileId == widget.auth.profile?.id;
    final weight = isSelf ? FontWeight.bold : FontWeight.normal;
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
            width: 36,
            child: Text('${entry.rank}.', style: TextStyle(fontWeight: weight)),
          ),
          Expanded(
            child: Text(
              entry.username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: weight),
            ),
          ),
          const SizedBox(width: 8),
          TierBadge(tier: entry.tier),
          const SizedBox(width: 8),
          Text(
            '${entry.rating}',
            style: TextStyle(
              fontFamily: 'Jua',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: entry.tier.color(AppPalette.isDark(context)),
            ),
          ),
        ],
      ),
    );
  }
}
