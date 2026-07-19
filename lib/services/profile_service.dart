import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rating_history.dart';
import '../models/rating_leaderboard.dart';
import '../models/user_profile.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile> fetchProfile(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).single();
    return UserProfile.fromJson(row);
  }

  Future<RatingLeaderboard> fetchLeaderboard() async {
    final result = await _client.rpc('get_rating_leaderboard');
    return RatingLeaderboard.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<List<RatingHistoryPoint>> fetchRatingHistory() async {
    final result = await _client.rpc('get_my_rating_history');
    return (result as List)
        .map((e) =>
            RatingHistoryPoint.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Throws [PostgrestException] (code 23505) if [username] is already taken
  /// — the `profiles.username` unique constraint is the source of truth.
  Future<void> updateUsername(String userId, String username) async {
    await _client
        .from('profiles')
        .update({'username': username}).eq('id', userId);
  }
}
