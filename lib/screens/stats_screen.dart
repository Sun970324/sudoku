import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/stats.dart';
import '../services/percentile_estimator.dart';
import '../services/storage_service.dart';
import '../state/auth_controller.dart';
import '../theme/app_palette.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/pop_card.dart';
import 'stats/daily_calendar_card.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late Future<Stats> _statsFuture;

  /// Drives the difficulty TabBar. There is deliberately no TabBarView —
  /// the screen stays one ListView (the daily calendar above must scroll
  /// with the stats), so the bar just swaps the card below it.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _statsFuture = _storage.getStats();
    _tabController =
        TabController(length: Difficulty.values.length, vsync: this)
          ..addListener(() {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    final difficulty = Difficulty.values[_tabController.index];
    final accent = AppPalette.difficultyColor(difficulty, isDark);

    return GradientScaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: FutureBuilder<Stats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entry = snapshot.data!.byDifficulty[difficulty]!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DailyCalendarCard(auth: widget.auth),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorColor: accent,
                labelColor: accent,
                labelStyle: const TextStyle(fontFamily: 'Jua', fontSize: 15),
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                tabs: [
                  for (final d in Difficulty.values) Tab(text: d.label(context)),
                ],
              ),
              const SizedBox(height: 16),
              _DifficultyStatsCard(
                difficulty: difficulty,
                entry: entry,
                accent: accent,
                formatTime: _formatTime,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DifficultyStatsCard extends StatelessWidget {
  const _DifficultyStatsCard({
    required this.difficulty,
    required this.entry,
    required this.accent,
    required this.formatTime,
  });

  final Difficulty difficulty;
  final DifficultyStats entry;
  final Color accent;
  final String Function(int) formatTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final average = entry.averageWinSeconds;
    final best = entry.bestTimeSeconds;
    return PopCard(
      tint: accent,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow(
            icon: Icons.check_circle_outline,
            label: l10n.statsCompletedLabel,
            value: '${entry.won} / ${entry.played}',
            accent: accent,
          ),
          _StatRow(
            icon: Icons.star_outline,
            label: l10n.statsPerfectLabel,
            value: '${entry.perfectWins}',
            accent: accent,
          ),
          _StatRow(
            icon: Icons.timelapse,
            label: l10n.statsAverageLabel,
            value: average == null ? l10n.statsNoRecord : formatTime(average),
            accent: accent,
            badgePercent: average == null
                ? null
                : 100 - estimateFasterThanPercent(difficulty, average),
          ),
          _StatRow(
            icon: Icons.emoji_events_outlined,
            label: l10n.statsBestLabel,
            value: best == null ? l10n.statsNoRecord : formatTime(best),
            accent: accent,
            badgePercent: best == null
                ? null
                : 100 - estimateFasterThanPercent(difficulty, best),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.mockDataDisclaimer,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.badgePercent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  /// "top N%" mock badge (see percentile_estimator) — null hides the badge.
  final int? badgePercent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (badgePercent != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppLocalizations.of(context)!
                    .statsTopPercentBadge(badgePercent!),
                style: TextStyle(fontSize: 12, color: accent),
              ),
            ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'Jua', fontSize: 18),
          ),
        ],
      ),
    );
  }
}
