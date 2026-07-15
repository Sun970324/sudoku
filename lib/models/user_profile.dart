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
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        rating: json['rating'] as int,
        tier: tierFromName(json['tier'] as String),
        wins: json['wins'] as int,
        losses: json['losses'] as int,
      );

  final String id;
  final String username;
  final String? avatarUrl;
  final int rating;
  final Tier tier;
  final int wins;
  final int losses;
}
