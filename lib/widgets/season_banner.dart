import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/season.dart';
import '../services/season_service.dart';
import 'pixel_icon.dart';
import 'pop_card.dart';

/// Slim header card showing the current ranked season and a countdown to the
/// next reset ("Season 1 · D-12"). Self-fetching and silent until loaded —
/// renders nothing while loading, on error, or when no season is configured,
/// so drop-in placement never leaves an empty slot (mirrors the profile
/// screen's rating-trend card behavior).
class SeasonBanner extends StatefulWidget {
  const SeasonBanner({super.key, this.service});

  /// Injectable for tests; defaults to a real [SeasonService].
  final SeasonService? service;

  @override
  State<SeasonBanner> createState() => _SeasonBannerState();
}

class _SeasonBannerState extends State<SeasonBanner> {
  late final SeasonService _service = widget.service ?? SeasonService();
  Season? _season;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final season = await _service.fetchCurrentSeason();
      if (!mounted) return;
      setState(() => _season = season);
    } catch (_) {
      // Silent: the banner just stays absent if the season can't be loaded.
    }
  }

  @override
  Widget build(BuildContext context) {
    final season = _season;
    if (season == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.primary;
    return PopCard(
      tint: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(PixelIcons.calendar, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            l10n.seasonName(season.id),
            style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 16),
          ),
          const Spacer(),
          Text(
            l10n.seasonDaysLeft(season.daysRemaining),
            style: TextStyle(
              fontFamily: 'Mulmaru',
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
