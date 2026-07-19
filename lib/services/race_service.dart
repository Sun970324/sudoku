import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/difficulty.dart';
import '../models/race.dart';
import '../models/sudoku_puzzle.dart';

class RaceService {
  RaceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get selfId => _client.auth.currentUser!.id;

  /// Registers for a race at [difficulty]. Returns the matched race's id if
  /// an opponent was already waiting (caller becomes player_b), or null if
  /// the caller was enqueued instead and must wait — see [watchForMatch].
  Future<String?> enqueue(Difficulty difficulty) async {
    final result = await _client
        .rpc('enqueue_for_race', params: {'p_difficulty': difficulty.name});
    return result as String?;
  }

  Future<void> cancelQueue() async {
    await _client.from('matchmaking_queue').delete().eq('profile_id', selfId);
  }

  /// Creates (or replaces) the caller's private room and returns its 6-char
  /// join code. The friend's join is detected via [watchForMatch] — joining
  /// creates a `races` row with the creator as player_a, exactly like ranked
  /// matchmaking's waiting side.
  Future<String> createPrivateRoom(Difficulty difficulty) async {
    final result = await _client.rpc('create_private_room',
        params: {'p_difficulty': difficulty.name});
    return result as String;
  }

  /// Joins the room for [code] and returns the created race's id. Throws a
  /// [PostgrestException] for an unknown, expired, or self-owned code.
  Future<String> joinPrivateRoom(String code) async {
    final result =
        await _client.rpc('join_private_room', params: {'p_code': code});
    return result as String;
  }

  /// Cancels the caller's open room; also aborts a private race a joiner
  /// created in the same instant, so that joiner's client exits cleanly.
  Future<void> cancelPrivateRoom() async {
    await _client.rpc('cancel_private_room');
  }

  /// Streams the caller's active (not finished/aborted) race, if any — the
  /// *waiting* side of a match always ends up as player_a (see
  /// enqueue_for_race), so this is how a waiting client learns it's been
  /// matched. `.stream()` only supports a single column filter, so terminal
  /// statuses are filtered out here rather than server-side.
  Stream<Race?> watchForMatch() {
    return _client
        .from('races')
        .stream(primaryKey: ['id'])
        .eq('player_a', selfId)
        .order('created_at', ascending: false)
        .map((rows) {
      for (final row in rows) {
        if (row['status'] != 'finished' && row['status'] != 'aborted') {
          return Race.fromJson(row);
        }
      }
      return null;
    });
  }

  Stream<Race?> watchRace(String raceId) {
    return _client
        .from('races')
        .stream(primaryKey: ['id'])
        .eq('id', raceId)
        .map((rows) => rows.isEmpty ? null : Race.fromJson(rows.first));
  }

  /// One-shot equivalent of [watchForMatch] — used as a polling fallback
  /// alongside the realtime stream, since a dropped/missed Postgres Changes
  /// event (e.g. from backgrounding or a network switch) would otherwise
  /// leave the waiting side stuck indefinitely with no other signal.
  Future<Race?> fetchActiveMatch() async {
    final rows = await _client
        .from('races')
        .select()
        .or('player_a.eq.$selfId,player_b.eq.$selfId')
        .order('created_at', ascending: false)
        .limit(5);
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      if (map['status'] != 'finished' && map['status'] != 'aborted') {
        return Race.fromJson(map);
      }
    }
    return null;
  }

  /// One-shot equivalent of [watchRace] — see [fetchActiveMatch].
  Future<Race?> fetchRace(String raceId) async {
    final row =
        await _client.from('races').select().eq('id', raceId).maybeSingle();
    return row == null ? null : Race.fromJson(row);
  }

  Future<void> markPuzzleReady({
    required String raceId,
    required SudokuPuzzle puzzle,
  }) async {
    await _client.rpc('mark_puzzle_ready', params: {
      'p_race_id': raceId,
      'p_puzzle': puzzle.puzzle.toJson(),
      'p_solution': puzzle.solution.toJson(),
      'p_fixed_mask': puzzle.fixedMask,
    });
  }

  Future<void> startRace(String raceId) async {
    await _client.rpc('start_race', params: {'p_race_id': raceId});
  }

  /// Returns true only if this submission won the race — false means either
  /// the board was wrong (caller should keep playing) or the race was
  /// already decided by the opponent.
  Future<bool> submitFinish(String raceId, List<List<int>> board) async {
    final result = await _client.rpc('submit_race_finish',
        params: {'p_race_id': raceId, 'p_board': board});
    return result as bool;
  }

  Future<void> abortRace(String raceId) async {
    await _client.rpc('abort_race', params: {'p_race_id': raceId});
  }

  /// Refreshes the caller's own liveness marker so the opponent can't claim
  /// a disconnect win against them. Sent periodically while racing.
  Future<void> heartbeat(String raceId) async {
    await _client.rpc('race_heartbeat', params: {'p_race_id': raceId});
  }

  /// Claims the win when the opponent's heartbeat has gone stale. Returns
  /// true only if the server agreed the opponent is genuinely gone and the
  /// race was still in progress — false means keep playing (opponent is
  /// still live, or the race was already decided).
  Future<bool> claimDisconnectWin(String raceId) async {
    final result = await _client
        .rpc('claim_disconnect_win', params: {'p_race_id': raceId});
    return result as bool;
  }

  /// The caller's finished races, most recent first. RLS already limits
  /// `races` rows to ones naming the caller as a player, so no extra
  /// filter is needed beyond status — the embedded profile selects use the
  /// FK constraint names to disambiguate player_a vs player_b, since both
  /// point at the same `profiles` table. Excludes any race decided before
  /// the rating-delta columns existed (0007) — apply_race_result always
  /// sets both sides' columns together, so a null player_a delta means the
  /// whole row predates that migration.
  Future<List<RaceHistoryEntry>> fetchHistory() async {
    final rows = await _client
        .from('races')
        .select(
            '*, player_a_profile:profiles!races_player_a_fkey(username), player_b_profile:profiles!races_player_b_fkey(username)')
        .eq('status', 'finished')
        .not('player_a_rating_delta', 'is', null)
        .order('finished_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => RaceHistoryEntry.fromJson(row, selfId))
        .toList();
  }

  /// A plain (non-private) channel keyed by raceId — the id is an
  /// unguessable uuid, and nothing broadcast on it (opponent's live
  /// filledCount/mistakes, ready presence) is authoritative, so this is an
  /// accepted MVP trade-off rather than setting up Realtime Authorization
  /// for private channels.
  RealtimeChannel raceChannel(String raceId) => _client.channel('race:$raceId');

  void leaveChannel(RealtimeChannel channel) => _client.removeChannel(channel);
}
