import 'dart:async';

import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../models/hint.dart';
import '../models/sudoku_grid.dart';
import '../models/sudoku_puzzle.dart';
import '../services/hint_engine.dart';
import '../services/generation/sudoku_generator.dart';

enum GameStatus { playing, won, gameOver }

class _Move {
  _Move.value(this.row, this.col, this.previousValue, this.previousNotes);

  _Move.notesOnly(this.previousNotes)
      : row = null,
        col = null,
        previousValue = null;

  /// Null for a notes-only move (e.g. an eliminate-type hint) — undo then
  /// restores the notes snapshot without touching the board.
  final int? row;
  final int? col;
  final int? previousValue;

  /// A full snapshot of the notes grid taken right before this move, so
  /// undo can restore not just the digit but every note it touched —
  /// including peer cells whose candidates were auto-cleared.
  final List<List<Set<int>>> previousNotes;
}

class GameController extends ChangeNotifier {
  GameController({SudokuGenerator? generator, HintEngine? hintEngine})
      : _generator = generator ?? SudokuGenerator(),
        _hintEngine = hintEngine ?? HintEngine();

  static const maxMistakes = 3;

  final SudokuGenerator _generator;
  final HintEngine _hintEngine;

  late SudokuPuzzle _puzzle;
  late List<List<int>> _board;
  late List<List<Set<int>>> _notes;
  final List<_Move> _history = [];

  /// Cache backing [remainingCount], one entry per digit (index = digit-1).
  /// Kept in sync by [_recomputeRemainingCounts] wherever [_board] changes.
  final List<int> _remainingCounts = List.filled(9, 9);

  int? selectedRow;
  int? selectedCol;
  int mistakes = 0;

  /// Elapsed play time, ticked once per second by [tick]. Exposed via its
  /// own [ValueNotifier] (rather than folded into this class's main
  /// [notifyListeners] channel) so a UI element showing just the clock can
  /// rebuild every second without dragging along every other listener
  /// (the board grid, number pads, controls row) that doesn't care about
  /// the tick.
  final ValueNotifier<int> elapsedSecondsNotifier = ValueNotifier<int>(0);
  int get elapsedSeconds => elapsedSecondsNotifier.value;

  int hintsUsed = 0;
  bool isNoteMode = true;
  GameStatus status = GameStatus.playing;

  /// The hint currently being shown to the player, if any. Transient UI
  /// state only — never persisted in [GameSnapshot], same as [selectedRow].
  Hint? _activeHint;
  Hint? get activeHint => _activeHint;

  /// Cells that briefly flash red because the player just tried to note a
  /// digit that's already confirmed elsewhere in the same row/column/box.
  /// Transient UI state only — never persisted, auto-clears via [_conflictFlashTimer].
  Set<HintCell> _conflictFlashCells = {};
  Set<HintCell> get conflictFlashCells => _conflictFlashCells;
  Timer? _conflictFlashTimer;

  SudokuPuzzle get puzzle => _puzzle;
  Difficulty get difficulty => _puzzle.difficulty;
  bool get canUndo => _history.isNotEmpty;

  /// Starts a new game for [difficulty]. If [puzzle] is supplied (e.g. from
  /// [PuzzleQueueManager]'s pre-generated queue) it's used directly instead
  /// of calling [SudokuGenerator.generate], which can otherwise block the
  /// UI thread for up to ~70s depending on tier.
  void startNewGame(Difficulty difficulty, {SudokuPuzzle? puzzle}) {
    _puzzle = puzzle ?? _generator.generate(difficulty);
    _board = _puzzle.puzzle.toJson();
    _notes = _emptyNotes();
    _recomputeRemainingCounts();
    _resetRoundState();
  }

  void resumeFrom(GameSnapshot snapshot) {
    _puzzle = snapshot.puzzle;
    _board = snapshot.board.map((row) => List<int>.from(row)).toList();
    _notes = snapshot.notes
        .map((row) => row.map((cell) => cell.toSet()).toList())
        .toList();
    _recomputeRemainingCounts();
    mistakes = snapshot.mistakes;
    elapsedSecondsNotifier.value = snapshot.elapsedSeconds;
    hintsUsed = snapshot.hintsUsed;
    selectedRow = null;
    selectedCol = null;
    isNoteMode = true;
    status = GameStatus.playing;
    _history.clear();
    notifyListeners();
  }

  GameSnapshot toSnapshot() => GameSnapshot(
        puzzle: _puzzle,
        board: boardSnapshot,
        notes: _notes
            .map((row) => row.map((cell) => cell.toList()..sort()).toList())
            .toList(),
        mistakes: mistakes,
        elapsedSeconds: elapsedSeconds,
        hintsUsed: hintsUsed,
      );

  static List<List<Set<int>>> _emptyNotes() =>
      List.generate(9, (_) => List.generate(9, (_) => <int>{}));

  List<List<Set<int>>> _cloneNotes() => _notes
      .map((row) => row.map((cell) => Set<int>.from(cell)).toList())
      .toList();

  void _resetRoundState() {
    selectedRow = null;
    selectedCol = null;
    mistakes = 0;
    elapsedSecondsNotifier.value = 0;
    hintsUsed = 0;
    isNoteMode = true;
    status = GameStatus.playing;
    _history.clear();
    notifyListeners();
  }

  int valueAt(int row, int col) => _board[row][col];

  Set<int> notesAt(int row, int col) => _notes[row][col];

  void toggleNoteMode() {
    isNoteMode = !isNoteMode;
    notifyListeners();
  }

  /// Toggles [value] as a pencil-mark candidate in the selected cell. Only
  /// applies to empty, non-fixed cells — notes have no meaning once a cell
  /// holds a committed value (the digit is shown instead of its notes).
  void toggleNote(int value) {
    if (status != GameStatus.playing) return;
    final row = selectedRow;
    final col = selectedCol;
    if (row == null || col == null) return;
    if (isFixed(row, col) || _board[row][col] != 0) return;

    final notes = _notes[row][col];
    if (notes.contains(value)) {
      // Removing an existing note is always allowed, no validity check.
      _activeHint = null;
      _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
      notes.remove(value);
      notifyListeners();
      return;
    }

    if (!SudokuGrid(_board).isValidPlacement(row, col, value)) {
      _flashConflictCells(row, col, value);
      return;
    }

    _activeHint = null;
    _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
    notes.add(value);
    notifyListeners();
  }

  /// Briefly highlights every cell in (row, col)'s row/column/box that
  /// already holds [value] — the reason a note for [value] was rejected.
  void _flashConflictCells(int row, int col, int value) {
    final conflicts = <HintCell>{};
    for (final p in SudokuGrid.peersOf(row, col)) {
      if (_board[p[0]][p[1]] == value) conflicts.add(HintCell(p[0], p[1]));
    }
    _conflictFlashCells = conflicts;
    notifyListeners();
    _conflictFlashTimer?.cancel();
    _conflictFlashTimer = Timer(const Duration(milliseconds: 500), () {
      _conflictFlashCells = {};
      notifyListeners();
    });
  }

  bool isFixed(int row, int col) => _puzzle.isFixed(row, col);

  bool isWrong(int row, int col) {
    final value = _board[row][col];
    return value != 0 && value != _puzzle.solutionValue(row, col);
  }

  /// Whether any cell on the board currently holds an uncorrected wrong
  /// value. Candidate computation ([SudokuGrid.candidatesAt], used by both
  /// [HintEngine] and [_findHintWithRepair]) treats every placed digit as
  /// confirmed truth — a wrong one left in place poisons row/column/box
  /// exclusion for everything downstream, so a hint computed while this is
  /// true can't be trusted no matter how complete the notes are.
  bool get hasUnresolvedMistake {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (isWrong(r, c)) return true;
      }
    }
    return false;
  }

  List<List<int>> get boardSnapshot =>
      _board.map((row) => List<int>.from(row)).toList();

  /// Selection is allowed on any cell, including fixed givens, so the player
  /// can tap them to see same-number highlighting. Editing a fixed cell's
  /// value is still blocked separately (see inputValue/toggleNote). Tapping
  /// the already-selected cell again deselects it instead.
  void selectCell(int row, int col) {
    _activeHint = null;
    _conflictFlashTimer?.cancel();
    _conflictFlashCells = {};
    if (selectedRow == row && selectedCol == col) {
      selectedRow = null;
      selectedCol = null;
    } else {
      selectedRow = row;
      selectedCol = col;
    }
    notifyListeners();
  }

  /// Sets the selected cell directly to (row, col), without [selectCell]'s
  /// toggle-off behavior for re-selecting the same cell — used while
  /// drag-selecting across the grid, where the finger sweeping back over
  /// its starting cell must not deselect it. No-op if (row, col) is already
  /// selected, avoiding a redundant rebuild while the finger lingers within
  /// one cell.
  void selectCellForDrag(int row, int col) {
    if (selectedRow == row && selectedCol == col) return;
    _activeHint = null;
    _conflictFlashTimer?.cancel();
    _conflictFlashCells = {};
    selectedRow = row;
    selectedCol = col;
    notifyListeners();
  }

  /// The digit occupying the selected cell, or null if nothing is selected
  /// or the selected cell is empty. Used to highlight every other cell that
  /// shares this value.
  int? get selectedValue {
    final row = selectedRow;
    final col = selectedCol;
    if (row == null || col == null) return null;
    final value = _board[row][col];
    return value == 0 ? null : value;
  }

  void inputValue(int value) {
    if (status != GameStatus.playing) return;
    final row = selectedRow;
    final col = selectedCol;
    if (row == null || col == null) return;
    if (isFixed(row, col)) return;

    _activeHint = null;
    _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
    _board[row][col] = value;
    _notes[row][col].clear();
    if (value != 0 && value == _puzzle.solutionValue(row, col)) {
      _removeNoteFromPeers(row, col, value);
    }

    if (value != 0 && value != _puzzle.solutionValue(row, col)) {
      mistakes++;
      if (mistakes >= maxMistakes) {
        status = GameStatus.gameOver;
      }
    } else if (_isBoardComplete()) {
      status = GameStatus.won;
    }
    _recomputeRemainingCounts();
    notifyListeners();
  }

  /// Whether pressing erase right now would actually change anything —
  /// false when nothing is selected, the cell is a given, the cell already
  /// holds the confirmed-correct digit (locked once correct, just like a
  /// given), or the cell is already fully empty (no value, no notes).
  bool get canErase {
    final row = selectedRow;
    final col = selectedCol;
    if (row == null || col == null) return false;
    if (isFixed(row, col)) return false;
    final value = _board[row][col];
    if (value != 0) return value != _puzzle.solutionValue(row, col);
    return _notes[row][col].isNotEmpty;
  }

  /// No-op (and doesn't touch [_history]) when [canErase] is false — e.g.
  /// pressing erase again on an already-cleared cell, or on a cell with
  /// nothing to erase in the first place.
  void eraseSelected() {
    if (!canErase) return;
    inputValue(0);
  }

  void undo() {
    if (_history.isEmpty) return;
    final move = _history.removeLast();
    if (move.row != null) {
      _board[move.row!][move.col!] = move.previousValue!;
    }
    _notes = move.previousNotes;
    _activeHint = null;
    if (status == GameStatus.gameOver) status = GameStatus.playing;
    _recomputeRemainingCounts();
    notifyListeners();
  }

  /// Computes the next logical hint from the current board and the
  /// player's own current notes ([_notes]) — reveal-type techniques (Full
  /// House, Naked/Hidden Single) still only ever look at confirmed board
  /// digits, but eliminate-type techniques (Intersection Pointing/Claiming,
  /// X-Wing) reason directly over [_notes], so a hint reflects what the
  /// player has actually narrowed down. Applying such a hint edits [_notes]
  /// (see [_applyEliminateHint]), so the very next call naturally sees the
  /// update and won't rediscover the same elimination. Stores the result as
  /// the active hint for grid highlighting and returns it. Returns null if
  /// no known technique currently applies, or if [hasUnresolvedMistake] —
  /// no amount of note-repair can be trusted while a wrong value on the
  /// board is corrupting candidate computation itself.
  ///
  /// May itself edit [_notes] (see [_findHintWithRepair]) if some cell was
  /// missing its solution digit — pushes an undoable history entry when
  /// that happens, same as any other note-changing action. When the
  /// returned hint is eliminate-type (the kind that actually reasons over
  /// [_notes] — see [HintEngine.findHint]) and a repair occurred, prepends
  /// a note about it to the hint's explanation so the player knows their
  /// notes were corrected; reveal-type hints never depend on notes, so
  /// their explanation is left alone even if some unrelated cell got
  /// repaired along the way.
  Hint? requestHint({AppLocalizations? l10n}) {
    if (status != GameStatus.playing) return null;
    if (hasUnresolvedMistake) return null;
    final notesBefore = _cloneNotes();
    var (hint, repaired) = _findHintWithRepair(boardSnapshot, _notes, l10n);
    if (repaired) {
      _history.add(_Move.notesOnly(notesBefore));
      if (hint != null && hint.type == HintType.eliminate) {
        hint = hint.withExplanation(
          (l10n ?? lookupAppLocalizations(const Locale('ko')))
              .noteRepairNotice(hint.explanation),
        );
      }
    }
    _activeHint = hint;
    notifyListeners();
    return hint;
  }

  /// Whether [requestHint] would actually return a hint right now — lets
  /// callers (e.g. gating a rewarded ad) check availability up front
  /// without mutating [activeHint]/[_notes]/triggering a rebuild the way
  /// [requestHint] itself does. Runs the same repair-and-retry search as
  /// [requestHint] but against a throwaway clone of [_notes], so a stale
  /// candidate that would otherwise get silently repaired doesn't change
  /// the answer here. Also false whenever [hasUnresolvedMistake] is true,
  /// matching [requestHint]'s own refusal.
  bool get hasAvailableHint =>
      status == GameStatus.playing &&
      !hasUnresolvedMistake &&
      _findHintWithRepair(boardSnapshot, _cloneNotes()).$1 != null;

  /// Finds the next hint the same way [requestHint] does, but first makes
  /// sure every empty cell's notes still contain that cell's true solution
  /// digit — the one candidate a *correctly* applied technique, however
  /// advanced, can never eliminate (doing so would mean proving the actual
  /// answer isn't the answer). A cell that's merely narrower than the raw
  /// row/column/box candidate set because the player validly reasoned
  /// past basic exclusion (e.g. a correctly applied Naked Pair or
  /// Pointing) is left completely untouched — only cells actually missing
  /// their solution digit (never checked off, or lost somehow) count as
  /// broken. This matters because an eliminate-type technique (Naked/
  /// Hidden Pair, Pointing, X-Wing, ...) builds its pattern by scanning
  /// for cells with a *specific* candidate count or content; a cell the
  /// player left completely unnoted doesn't just look "narrower", it can
  /// be invisible to that scan entirely — never appearing anywhere in the
  /// returned [Hint] — so checking only the cells a hint happens to
  /// reference can miss this. A single full-board pass is always enough:
  /// broken cells get reset to the safe (if unrefined) [SudokuGrid.
  /// candidatesAt] baseline, which is guaranteed to include the solution
  /// digit as long as [hasUnresolvedMistake] is false (checked by
  /// [requestHint] before this ever runs).
  (Hint?, bool) _findHintWithRepair(
    List<List<int>> board,
    List<List<Set<int>>> notes, [
    AppLocalizations? l10n,
  ]) {
    final grid = SudokuGrid(board);
    var repairedAny = false;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board[r][c] != 0) continue;
        final solutionDigit = _puzzle.solutionValue(r, c);
        if (!notes[r][c].contains(solutionDigit)) {
          notes[r][c] = grid.candidatesAt(r, c);
          repairedAny = true;
        }
      }
    }
    final hint = _hintEngine.findHint(board, notes, l10n);
    return (hint, repairedAny);
  }

  /// Discards the active hint without applying it.
  void dismissHint() {
    if (_activeHint == null) return;
    _activeHint = null;
    notifyListeners();
  }

  /// Applies the active hint: fills the deduced cell (reveal techniques) or
  /// strips the justified candidates from notes (eliminate techniques).
  /// No-op if there is no active hint.
  void applyHint() {
    final hint = _activeHint;
    if (hint == null || status != GameStatus.playing) return;

    if (hint.type == HintType.reveal) {
      _applyRevealHint(hint);
    } else {
      _applyEliminateHint(hint);
    }
    _activeHint = null;
    hintsUsed++;
    notifyListeners();
  }

  void _applyRevealHint(Hint hint) {
    final row = hint.row!;
    final col = hint.col!;
    final value = hint.value!;
    _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
    _board[row][col] = value;
    // Same minimal-touch behavior as a normal inputValue placement: clear
    // this cell's own notes and drop the newly-placed digit from row/col/
    // box peers' notes — not a full-board recompute, which would blanket
    // every other still-blank cell with pencil marks the player never
    // asked for (same principle as _applyEliminateHint).
    _notes[row][col].clear();
    _removeNoteFromPeers(row, col, value);
    selectedRow = row;
    selectedCol = col;
    if (_isBoardComplete()) status = GameStatus.won;
    _recomputeRemainingCounts();
  }

  /// Removes the hint's justified digits directly from the notes of the
  /// cells named in [Hint.eliminations] — a no-op wherever the player
  /// hadn't noted that digit in the first place. Deliberately touches only
  /// those specific cells, not the whole board: a full recompute would
  /// blanket every other still-blank cell with pencil marks the player
  /// never asked for.
  void _applyEliminateHint(Hint hint) {
    _history.add(_Move.notesOnly(_cloneNotes()));
    for (final elimination in hint.eliminations) {
      _notes[elimination.row][elimination.col].remove(elimination.digit);
    }
  }

  /// Whether [autoFillNotes] would actually do anything right now.
  /// Independent of hint availability — auto-fill and hints are separate
  /// features, this only checks that the game is still in progress.
  bool get canAutoFillNotes => status == GameStatus.playing;

  /// Overwrites every empty cell's notes with its true candidate set,
  /// computed fresh from the confirmed board digits — regardless of
  /// whatever the player had (or hadn't) noted there before. Filled cells
  /// are left with no notes, same as everywhere else in this class. No-op
  /// when [canAutoFillNotes] is false (game not in progress).
  void autoFillNotes() {
    if (!canAutoFillNotes) return;
    _activeHint = null;
    _history.add(_Move.notesOnly(_cloneNotes()));
    _recomputeAllNotes();
    notifyListeners();
  }

  void _recomputeAllNotes() {
    final grid = SudokuGrid(_board);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        _notes[r][c] = grid.candidatesAt(r, c);
      }
    }
  }

  /// Clears the mistake count and resumes play after game-over. Callers are
  /// responsible for gating this behind a rewarded ad (see AdService, M4).
  void reviveAfterAd() {
    if (status != GameStatus.gameOver) return;
    mistakes = 2;
    status = GameStatus.playing;
    notifyListeners();
  }

  void tick() {
    if (status != GameStatus.playing) return;
    elapsedSecondsNotifier.value++;
  }

  /// How many more cells still need [digit] correctly placed before it's
  /// fully used up (a digit appears exactly 9 times in a solved grid).
  /// Only cells matching the solution count — a wrong entry doesn't use up
  /// the digit it was mistakenly placed as. Backed by [_remainingCounts],
  /// which every [_board]-mutating method keeps up to date via
  /// [_recomputeRemainingCounts] — this avoids re-scanning all 81 cells for
  /// each of the 9 digits on every call (e.g. from [NumberPadWidget]'s
  /// build, which queries all 9 digits per rebuild).
  int remainingCount(int digit) => _remainingCounts[digit - 1];

  /// Recomputes [_remainingCounts] for all 9 digits in a single 81-cell
  /// pass. Call after any change to [_board]'s contents.
  void _recomputeRemainingCounts() {
    final placed = List.filled(9, 0);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final value = _board[r][c];
        if (value != 0 && value == _puzzle.solutionValue(r, c)) {
          placed[value - 1]++;
        }
      }
    }
    for (var i = 0; i < 9; i++) {
      _remainingCounts[i] = 9 - placed[i];
    }
  }

  /// Removes [value] as a pencil-mark candidate from every other cell in the
  /// same row, column, and 3x3 box as (row, col) — those cells can no longer
  /// hold [value] once it's been placed here.
  void _removeNoteFromPeers(int row, int col, int value) {
    for (final p in SudokuGrid.peersOf(row, col)) {
      _notes[p[0]][p[1]].remove(value);
    }
  }

  bool _isBoardComplete() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (_board[r][c] != _puzzle.solutionValue(r, c)) return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _conflictFlashTimer?.cancel();
    elapsedSecondsNotifier.dispose();
    super.dispose();
  }
}
