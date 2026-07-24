import 'tier.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.rating,
    required this.tier,
    required this.wins,
    required this.losses,
    required this.seasonWins,
    required this.seasonLosses,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        rating: json['rating'] as int,
        tier: tierFromName(json['tier'] as String),
        wins: json['wins'] as int,
        losses: json['losses'] as int,
        seasonWins: json['season_wins'] as int,
        seasonLosses: json['season_losses'] as int,
      );

  final String id;
  final String username;
  final String? avatarUrl;
  final int rating;
  final Tier tier;

  /// Lifetime (career) record; [seasonWins]/[seasonLosses] carry the current
  /// season's record, reset to 0 at every rollover (migration 0016/0017).
  final int wins;
  final int losses;
  final int seasonWins;
  final int seasonLosses;

  /// Ranked games played this season — drives the placement-progress chip.
  int get seasonGames => seasonWins + seasonLosses;
}
