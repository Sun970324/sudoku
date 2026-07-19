/// One point in the caller's rating trend — their post-race rating and the
/// change from that race — as returned by the `get_my_rating_history` RPC
/// (derived from the `races` table, not a dedicated history table).
class RatingHistoryPoint {
  const RatingHistoryPoint({
    required this.finishedAt,
    required this.rating,
    required this.delta,
  });

  factory RatingHistoryPoint.fromJson(Map<String, dynamic> json) =>
      RatingHistoryPoint(
        finishedAt: DateTime.parse(json['finished_at'] as String),
        rating: json['rating'] as int,
        delta: json['delta'] as int,
      );

  final DateTime finishedAt;
  final int rating;
  final int delta;

  /// The rating going *into* this race — used to seed the trend's starting
  /// point from the earliest entry.
  int get ratingBefore => rating - delta;
}
