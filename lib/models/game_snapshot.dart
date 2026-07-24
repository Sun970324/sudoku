import 'game_replay.dart';
import 'sudoku_puzzle.dart';

class GameSnapshot {
  GameSnapshot({
    required this.puzzle,
    required this.board,
    required this.notes,
    required this.mistakes,
    required this.elapsedSeconds,
    required this.hintsUsed,
    this.events = const [],
  });

  factory GameSnapshot.fromJson(Map<String, dynamic> json) => GameSnapshot(
        puzzle: SudokuPuzzle.fromJson(json['puzzle'] as Map<String, dynamic>),
        board: (json['board'] as List<dynamic>)
            .map((row) => (row as List<dynamic>).cast<int>())
            .toList(),
        notes: (json['notes'] as List<dynamic>)
            .map((row) => (row as List<dynamic>)
                .map((cell) => (cell as List<dynamic>).cast<int>())
                .toList())
            .toList(),
        mistakes: json['mistakes'] as int,
        elapsedSeconds: json['elapsedSeconds'] as int,
        hintsUsed: json['hintsUsed'] as int,
        // Absent in snapshots saved before replay recording existed — an empty
        // log just means that resumed game can't produce a complete replay.
        events: (json['events'] as List<dynamic>?)
                ?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  final SudokuPuzzle puzzle;
  final List<List<int>> board;
  final List<List<List<int>>> notes;
  final int mistakes;
  final int elapsedSeconds;
  final int hintsUsed;

  /// The recorded move log so far, carried through a save/resume so a game
  /// interrupted by an app kill still yields a complete [GameReplay] on finish.
  final List<GameEvent> events;

  Map<String, dynamic> toJson() => {
        'puzzle': puzzle.toJson(),
        'board': board,
        'notes': notes,
        'mistakes': mistakes,
        'elapsedSeconds': elapsedSeconds,
        'hintsUsed': hintsUsed,
        'events': events.map((e) => e.toJson()).toList(),
      };
}
