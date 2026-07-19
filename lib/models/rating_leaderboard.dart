import 'tier.dart';

class RatingLeaderboardEntry {
  const RatingLeaderboardEntry({
    required this.rank,
    required this.profileId,
    required this.username,
    required this.rating,
    required this.tier,
    required this.wins,
    required this.losses,
  });

  factory RatingLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      RatingLeaderboardEntry(
        rank: json['rank'] as int,
        profileId: json['profile_id'] as String,
        username: json['username'] as String,
        rating: json['rating'] as int,
        tier: tierFromName(json['tier'] as String),
        wins: json['wins'] as int,
        losses: json['losses'] as int,
      );

  final int rank;
  final String profileId;
  final String username;
  final int rating;
  final Tier tier;
  final int wins;
  final int losses;
}

/// The `get_rating_leaderboard` RPC's payload: the played-player count, the
/// caller's own rank/rating (both null when they haven't played a ranked
/// game yet), and the top 100 by rating.
class RatingLeaderboard {
  const RatingLeaderboard({
    required this.total,
    this.myRank,
    this.myRating,
    required this.entries,
  });

  factory RatingLeaderboard.fromJson(Map<String, dynamic> json) =>
      RatingLeaderboard(
        total: json['total'] as int,
        myRank: json['my_rank'] as int?,
        myRating: json['my_rating'] as int?,
        entries: (json['entries'] as List<dynamic>)
            .map((e) => RatingLeaderboardEntry.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );

  final int total;
  final int? myRank;
  final int? myRating;
  final List<RatingLeaderboardEntry> entries;
}
