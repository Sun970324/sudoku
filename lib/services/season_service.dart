import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/season.dart';

class SeasonService {
  SeasonService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// The single active season, or null if none is configured. Reads the
  /// public `seasons` table directly (RLS grants select to everyone) rather
  /// than via an RPC — it's a plain single-row lookup, and the partial unique
  /// index guarantees at most one active row.
  Future<Season?> fetchCurrentSeason() async {
    final row = await _client
        .from('seasons')
        .select()
        .eq('status', 'active')
        .maybeSingle();
    return row == null ? null : Season.fromJson(row);
  }

  /// The caller's archived past-season results, newest first. Direct table
  /// read like [fetchCurrentSeason] — `season_standings` is world-readable
  /// and only ever written by the server-side rollover.
  Future<List<SeasonStanding>> fetchMyStandings() async {
    final rows = await _client
        .from('season_standings')
        .select()
        .eq('profile_id', _client.auth.currentUser!.id)
        .order('season_id', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SeasonStanding.fromJson)
        .toList();
  }
}
