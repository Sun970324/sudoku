import 'difficulty.dart';
import 'sudoku_grid.dart';
import 'sudoku_puzzle.dart';

/// The kind of a recorded [GameEvent] — the minimal set of primitive board
/// mutations that reproduce every move [GameController] makes:
/// * [place] — set a cell's value (0 = erase); also how a revealed hint lands.
/// * [note] — toggle a pencil-mark candidate in a cell.
/// * [eliminate] — strip specific candidates (an eliminate-type hint).
/// * [fillNotes] — recompute every cell's candidates (auto-memo).
/// * [repair] — reset listed cells' notes to their true candidates (the hint
///   engine's missing-candidate repair before a search).
enum ReplayEventType { place, note, eliminate, fillNotes, repair }

/// One recorded move in a [GameReplay]. Serialized with short keys because a
/// game holds hundreds of these; the mapping is `t`=type, `r`/`c`=row/col,
/// `v`=value, `k`=cells, `e`=elapsed seconds.
class GameEvent {
  const GameEvent.place(this.row, this.col, this.value, this.elapsed)
      : type = ReplayEventType.place,
        cells = null;

  const GameEvent.note(this.row, this.col, this.value, this.elapsed)
      : type = ReplayEventType.note,
        cells = null;

  const GameEvent.eliminate(this.cells, this.elapsed)
      : type = ReplayEventType.eliminate,
        row = null,
        col = null,
        value = null;

  const GameEvent.fillNotes(this.elapsed)
      : type = ReplayEventType.fillNotes,
        row = null,
        col = null,
        value = null,
        cells = null;

  const GameEvent.repair(this.cells, this.elapsed)
      : type = ReplayEventType.repair,
        row = null,
        col = null,
        value = null;

  final ReplayEventType type;

  /// Single-cell target (place/note). Null for the multi-cell types.
  final int? row;
  final int? col;
  final int? value;

  /// Multi-cell payload: eliminate stores `[row, col, digit]` per entry,
  /// repair stores `[row, col]`. Null for the single-cell types.
  final List<List<int>>? cells;

  /// Elapsed play seconds when this move was made — drives the replay's clock.
  final int elapsed;

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final type = ReplayEventType.values[json['t'] as int];
    final elapsed = json['e'] as int;
    switch (type) {
      case ReplayEventType.place:
        return GameEvent.place(
            json['r'] as int, json['c'] as int, json['v'] as int, elapsed);
      case ReplayEventType.note:
        return GameEvent.note(
            json['r'] as int, json['c'] as int, json['v'] as int, elapsed);
      case ReplayEventType.eliminate:
        return GameEvent.eliminate(_cellsFromJson(json['k']), elapsed);
      case ReplayEventType.repair:
        return GameEvent.repair(_cellsFromJson(json['k']), elapsed);
      case ReplayEventType.fillNotes:
        return GameEvent.fillNotes(elapsed);
    }
  }

  Map<String, dynamic> toJson() => {
        't': type.index,
        if (row != null) 'r': row,
        if (col != null) 'c': col,
        if (value != null) 'v': value,
        if (cells != null) 'k': cells,
        'e': elapsed,
      };

  static List<List<int>> _cellsFromJson(dynamic raw) => (raw as List<dynamic>)
      .map((cell) => (cell as List<dynamic>).cast<int>())
      .toList();
}

/// A finished game's full move history plus its result, kept so the player can
/// replay it move-by-move (and resume solving from any point). Rooted at the
/// pristine [puzzle]: applying [events] in order reproduces the exact board
/// and notes the player ended with — see [reconstructReplay].
class GameReplay {
  GameReplay({
    required this.puzzle,
    required this.events,
    required this.autoRemoveNotes,
    required this.won,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsUsed,
    required this.finishedAt,
    this.raceId,
  });

  final SudokuPuzzle puzzle;
  final List<GameEvent> events;

  /// The auto-remove-notes setting in force during play — reconstruction needs
  /// it to reproduce (or not) the peer-note clearing a correct placement did.
  final bool autoRemoveNotes;

  final bool won;
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
  final DateTime finishedAt;

  /// Set for a race replay (keyed to its race id), null for a solo game — lets
  /// race replays (Phase 4) reuse this shape without a storage migration.
  final String? raceId;

  Difficulty get difficulty => puzzle.difficulty;

  factory GameReplay.fromJson(Map<String, dynamic> json) => GameReplay(
        puzzle: SudokuPuzzle.fromJson(json['puzzle'] as Map<String, dynamic>),
        events: (json['events'] as List<dynamic>)
            .map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        autoRemoveNotes: json['autoRemoveNotes'] as bool,
        won: json['won'] as bool,
        elapsedSeconds: json['elapsedSeconds'] as int,
        mistakes: json['mistakes'] as int,
        hintsUsed: json['hintsUsed'] as int,
        finishedAt:
            DateTime.fromMillisecondsSinceEpoch(json['finishedAt'] as int),
        raceId: json['raceId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'puzzle': puzzle.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'autoRemoveNotes': autoRemoveNotes,
        'won': won,
        'elapsedSeconds': elapsedSeconds,
        'mistakes': mistakes,
        'hintsUsed': hintsUsed,
        'finishedAt': finishedAt.millisecondsSinceEpoch,
        if (raceId != null) 'raceId': raceId,
      };
}

/// Rebuilds the (board, notes) state after applying the first [upTo] events of
/// [replay] (0 = pristine puzzle, `events.length` = final state). Performs the
/// same primitive mutations [GameController] does — including the peer-note
/// clearing a correct placement triggers — so a reconstructed state is exactly
/// what the player had at that point. Used to render a replay step and to hand
/// a mid-replay position back to the controller to keep solving.
(List<List<int>> board, List<List<Set<int>>> notes) reconstructReplay(
    GameReplay replay, int upTo) {
  final board = replay.puzzle.puzzle.toJson(); // fresh mutable copy
  final notes = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  final solution = replay.puzzle.solution;
  final count = upTo.clamp(0, replay.events.length);

  for (var i = 0; i < count; i++) {
    final event = replay.events[i];
    switch (event.type) {
      case ReplayEventType.place:
        final r = event.row!, c = event.col!, v = event.value!;
        board[r][c] = v;
        notes[r][c].clear();
        if (replay.autoRemoveNotes && v != 0 && v == solution.get(r, c)) {
          for (final p in SudokuGrid.peersOf(r, c)) {
            notes[p[0]][p[1]].remove(v);
          }
        }
      case ReplayEventType.note:
        final cellNotes = notes[event.row!][event.col!];
        if (!cellNotes.add(event.value!)) cellNotes.remove(event.value!);
      case ReplayEventType.eliminate:
        for (final cell in event.cells!) {
          notes[cell[0]][cell[1]].remove(cell[2]);
        }
      case ReplayEventType.repair:
        // A fresh grid, exactly as the controller computes candidates — its
        // incremental masks don't handle a digit appearing twice in a unit.
        final grid = SudokuGrid(board);
        for (final cell in event.cells!) {
          notes[cell[0]][cell[1]] = grid.candidatesAt(cell[0], cell[1]);
        }
      case ReplayEventType.fillNotes:
        final grid = SudokuGrid(board);
        for (var r = 0; r < 9; r++) {
          for (var c = 0; c < 9; c++) {
            notes[r][c] = grid.candidatesAt(r, c);
          }
        }
    }
  }
  return (board, notes);
}
