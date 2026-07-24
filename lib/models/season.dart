import 'tier.dart';

/// The active ranked season (a row from the `seasons` table). A profile's
/// rating/tier are the *current season's* values; this carries the season's
/// identity and end time so the UI can show a countdown to the next reset.
class Season {
  const Season({
    required this.id,
    required this.startedAt,
    required this.endsAt,
    required this.status,
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        id: json['id'] as int,
        startedAt: DateTime.parse(json['started_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        status: json['status'] as String,
      );

  /// The season number (1, 2, 3, …), shown as "Season {id}".
  final int id;
  final DateTime startedAt;
  final DateTime endsAt;
  final String status;

  /// Whole days remaining until the season ends (never negative). Rounded up
  /// so the final partial day still reads as "1 day left" rather than 0.
  int get daysRemaining {
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    return (remaining.inMinutes / (60 * 24)).ceil();
  }
}

/// One archived season result for a player — a `season_standings` row,
/// snapshotted by the rollover at season close (so it survives the soft
/// reset). wins/losses here are that season's record, not lifetime.
class SeasonStanding {
  const SeasonStanding({
    required this.seasonId,
    required this.finalRating,
    required this.finalTier,
    required this.finalRank,
    required this.wins,
    required this.losses,
  });

  factory SeasonStanding.fromJson(Map<String, dynamic> json) => SeasonStanding(
        seasonId: json['season_id'] as int,
        finalRating: json['final_rating'] as int,
        finalTier: tierFromName(json['final_tier'] as String),
        finalRank: json['final_rank'] as int,
        wins: json['wins'] as int,
        losses: json['losses'] as int,
      );

  final int seasonId;
  final int finalRating;
  final Tier finalTier;
  final int finalRank;
  final int wins;
  final int losses;
}
