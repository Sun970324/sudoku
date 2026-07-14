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

  /// A plain (non-private) channel keyed by raceId — the id is an
  /// unguessable uuid, and nothing broadcast on it (opponent's live
  /// filledCount/mistakes, ready presence) is authoritative, so this is an
  /// accepted MVP trade-off rather than setting up Realtime Authorization
  /// for private channels.
  RealtimeChannel raceChannel(String raceId) => _client.channel('race:$raceId');

  void leaveChannel(RealtimeChannel channel) => _client.removeChannel(channel);
}
