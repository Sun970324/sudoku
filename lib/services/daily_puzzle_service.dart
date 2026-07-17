import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily.dart';
import '../models/sudoku_puzzle.dart';

class DailyPuzzleService {
  DailyPuzzleService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get selfId => _client.auth.currentUser!.id;

  /// Today's shared puzzle, or null if nobody has seeded it yet — "today"
  /// is decided entirely server-side (Asia/Seoul), never by this device's
  /// clock.
  Future<DailyPuzzle?> fetchTodayPuzzle() async {
    final result = await _client.rpc('get_daily_puzzle');
    if (result == null) return null;
    return DailyPuzzle.fromJson((result as Map).cast<String, dynamic>());
  }

  /// Uploads [puzzle] as today's puzzle and returns the canonical winning
  /// row — first writer wins, so this may be a concurrent client's puzzle
  /// rather than the one just uploaded. Always play the returned one.
  Future<DailyPuzzle> createTodayPuzzle(SudokuPuzzle puzzle) async {
    final result = await _client.rpc('create_daily_puzzle', params: {
      'p_puzzle': puzzle.puzzle.toJson(),
      'p_solution': puzzle.solution.toJson(),
      'p_fixed_mask': puzzle.fixedMask,
    });
    return DailyPuzzle.fromJson((result as Map).cast<String, dynamic>());
  }

  /// True only if this call recorded the caller's first completion today —
  /// false for a wrong board, no puzzle today (e.g. finished just past the
  /// KST midnight boundary), or an already-recorded completion.
  Future<bool> submitResult({
    required List<List<int>> board,
    required int elapsedSeconds,
    required int mistakes,
    required int hintsUsed,
  }) async {
    final result = await _client.rpc('submit_daily_result', params: {
      'p_board': board,
      'p_elapsed_seconds': elapsedSeconds,
      'p_mistakes': mistakes,
      'p_hints_used': hintsUsed,
    });
    return result as bool;
  }

  Future<DailyLeaderboard> fetchLeaderboard() async {
    final result = await _client.rpc('get_daily_leaderboard');
    return DailyLeaderboard.fromJson((result as Map).cast<String, dynamic>());
  }
}
