import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/game_replay.dart';
import '../models/game_snapshot.dart';
import '../models/hint.dart';
import '../models/sudoku_grid.dart';
import '../models/sudoku_puzzle.dart';
import '../services/hint_engine.dart';
import '../services/hint_step_builder.dart';
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

/// How [GameController] runs its hint searches: [Isolate.run] in the app
/// (the full technique sweep is far too slow for the UI thread when it comes
/// up empty — only then does it reach the expensive DFS tail of XY-Chain /
/// Remote Pair), and an inline runner in tests, which keeps fake engines'
/// hint instances identical (an isolate returns a copy) and avoids real
/// isolates inside the fake-async test zone.
typedef HintSearchRunner = Future<R> Function<R>(
    FutureOr<R> Function() computation);

class GameController extends ChangeNotifier {
  GameController({
    SudokuGenerator? generator,
    HintEngine? hintEngine,
    HintSearchRunner? searchRunner,
  })  : _generator = generator ?? SudokuGenerator(),
        _hintEngine = hintEngine ?? HintEngine(),
        _runSearch = searchRunner ?? Isolate.run;

  static const maxMistakes = 3;

  /// Settings-driven gates, pushed by [SettingsController] — see
  /// [toggleNote] and [inputValue].
  static bool wrongNoteWarningEnabled = true;
  static bool autoRemoveNotesEnabled = true;

  /// Remembered default for [quickInputMode], pushed by [SettingsController]
  /// so a new game inherits the player's last-used input mode.
  static bool quickInputDefault = false;

  final SudokuGenerator _generator;
  final HintEngine _hintEngine;
  final HintSearchRunner _runSearch;

  late SudokuPuzzle _puzzle;
  late List<List<int>> _board;
  late List<List<Set<int>>> _notes;
  final List<_Move> _history = [];

  /// The forward move log for replay (see [GameReplay]) — one entry recorded
  /// alongside every [_history] push and popped in lockstep on [undo], so it
  /// stays exactly the sequence that produced the current board. Carried
  /// through save/resume via [GameSnapshot.events].
  final List<GameEvent> _eventLog = [];

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

  /// Quick-input (digit-first) state. When [quickInputMode] is on, the number
  /// pad selects [activeDigit] instead of placing into a cell, and tapping
  /// cells places [activeDigit] (see [selectActiveDigit] and
  /// SudokuGridWidget). Both are transient UI state — never persisted in a
  /// snapshot; the mode's remembered default is [quickInputDefault].
  bool quickInputMode = quickInputDefault;
  int? activeDigit;

  /// Whether [activeDigit] was picked from the notes pad (so cell taps write
  /// it as a pencil mark) rather than the value pad. Independent of
  /// [isNoteMode]: that only governs whether the notes pad is shown at all —
  /// picking a quick-input digit never toggles it.
  bool activeDigitIsNote = false;

  GameStatus status = GameStatus.playing;

  /// The hint currently being shown to the player, if any. Transient UI
  /// state only — never persisted in [GameSnapshot], same as [selectedRow].
  Hint? _activeHint;
  Hint? get activeHint => _activeHint;

  /// How much of [activeHint] has been revealed so far: 0 = the technique's
  /// name only, 1 = name plus [Hint.mainInfo], 2 = the full explanation and
  /// the board visualisation. Always reset to 0 alongside [_activeHint] —
  /// assign through [_setActiveHint] rather than the field so a new hint can
  /// never inherit the previous one's stage.
  int _hintStage = 0;
  int get hintStage => _hintStage;

  /// The hint the board should actually draw — [activeHint] only once the
  /// player has reached the final stage. The earlier stages deliberately
  /// show nothing on the grid: naming the technique is only a nudge if it
  /// doesn't also point at the cells.
  Hint? get visualizedHint => _hintStage >= 2 ? _activeHint : null;

  /// The only place [_activeHint] is assigned, so every path that shows or
  /// drops a hint resets [_hintStage] with it. Does not notify — callers
  /// already do, and several set a hint mid-way through a larger mutation.
  /// [steps] is the hint's walkthrough, kept beside the hint rather than on
  /// it so [_activeHint] stays the exact instance the engine returned
  /// (several callers and tests rely on that identity); only the two
  /// request* entry points pass one — every hint-clearing path leaves the
  /// default empty list.
  void _setActiveHint(Hint? hint, [List<HintStep> steps = const []]) {
    _activeHint = hint;
    _activeHintSteps = steps;
    _hintStage = 0;
    _hintStepIndex = 0;
  }

  /// Advances the progressive reveal one step, up to the final stage. No-op
  /// with no active hint. Notifies so the board picks up the stage-2
  /// visualisation.
  void advanceHintStage() {
    if (_activeHint == null || _hintStage >= 2) return;
    _hintStage++;
    notifyListeners();
  }

  /// The active hint's step-by-step walkthrough (see [buildHintSteps]) and
  /// which of its steps the player is on. Only meaningful once [hintStage]
  /// reaches 2 (the sheet's step pager isn't shown before that); reset
  /// alongside the hint itself in [_setActiveHint].
  List<HintStep> _activeHintSteps = const [];
  List<HintStep> get hintSteps => _activeHintSteps;
  int _hintStepIndex = 0;
  int get hintStepIndex => _hintStepIndex;

  /// The walkthrough step the board should draw right now, or null when
  /// there's nothing step-wise to restrict — no visualized hint yet, or a
  /// hint without step support — in which case the board draws the full
  /// visualization as always.
  HintStep? get currentHintStep {
    if (visualizedHint == null || _activeHintSteps.isEmpty) return null;
    return _activeHintSteps[
        _hintStepIndex.clamp(0, _activeHintSteps.length - 1)];
  }

  /// Steps the walkthrough forward/backward. No-ops at the ends and when
  /// the active hint has no steps, so the sheet can call these unguarded.
  void nextHintStep() => setHintStep(_hintStepIndex + 1);

  void prevHintStep() => setHintStep(_hintStepIndex - 1);

  /// Jumps the walkthrough to [index] (clamped) — how the hint sheet's
  /// swipeable step pager syncs its page changes back here.
  void setHintStep(int index) {
    if (_activeHintSteps.isEmpty) return;
    final clamped = index.clamp(0, _activeHintSteps.length - 1);
    if (clamped == _hintStepIndex) return;
    _hintStepIndex = clamped;
    notifyListeners();
  }

  /// Cells that briefly flash red because the player just tried to note a
  /// digit that's already confirmed elsewhere in the same row/column/box.
  /// Transient UI state only — never persisted, auto-clears via [_conflictFlashTimer].
  Set<HintCell> _conflictFlashCells = {};
  Set<HintCell> get conflictFlashCells => _conflictFlashCells;
  Timer? _conflictFlashTimer;

  SudokuPuzzle get puzzle => _puzzle;
  Difficulty get difficulty => _puzzle.difficulty;
  bool get canUndo => status == GameStatus.playing && _history.isNotEmpty;

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
    quickInputMode = quickInputDefault;
    activeDigit = null;
    activeDigitIsNote = false;
    status = GameStatus.playing;
    _history.clear();
    // Restore the move log so a game resumed across an app kill still finishes
    // with a complete replay rooted at the pristine puzzle.
    _eventLog
      ..clear()
      ..addAll(snapshot.events);
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
        events: List.of(_eventLog),
      );

  /// Packages the recorded move log and result into a [GameReplay] for storage
  /// (see StorageService.saveReplay). [raceId] tags a race replay; null is a
  /// solo game.
  GameReplay toReplay({required bool won, String? raceId}) => GameReplay(
        puzzle: _puzzle,
        events: List.of(_eventLog),
        autoRemoveNotes: autoRemoveNotesEnabled,
        won: won,
        elapsedSeconds: elapsedSeconds,
        mistakes: mistakes,
        hintsUsed: hintsUsed,
        finishedAt: DateTime.now(),
        raceId: raceId,
      );

  static List<List<Set<int>>> _emptyNotes() =>
      List.generate(9, (_) => List.generate(9, (_) => <int>{}));

  List<List<Set<int>>> _cloneNotes() => _notes
      .map((row) => row.map((cell) => Set<int>.from(cell)).toList())
      .toList();

  /// The recorded move log so far (read-only) — see [_eventLog], [toReplay].
  List<GameEvent> get eventLog => List.unmodifiable(_eventLog);

  /// Records one forward move, stamped with the current elapsed time. Called
  /// alongside every [_history] push so undo can pop the two in lockstep.
  void _recordEvent(GameEvent event) => _eventLog.add(event);

  /// The cells whose notes [repaired] differs from the current [_notes] — the
  /// ones the hint engine's candidate repair touched — so a replay can reset
  /// exactly those to their true candidates (see [ReplayEventType.repair]).
  List<List<int>> _repairedCells(List<List<Set<int>>> repaired) {
    final cells = <List<int>>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final before = _notes[r][c];
        final after = repaired[r][c];
        if (before.length != after.length || !before.containsAll(after)) {
          cells.add([r, c]);
        }
      }
    }
    return cells;
  }

  void _resetRoundState() {
    selectedRow = null;
    selectedCol = null;
    mistakes = 0;
    elapsedSecondsNotifier.value = 0;
    hintsUsed = 0;
    isNoteMode = true;
    quickInputMode = quickInputDefault;
    activeDigit = null;
    activeDigitIsNote = false;
    status = GameStatus.playing;
    _history.clear();
    _eventLog.clear();
    notifyListeners();
  }

  int valueAt(int row, int col) => _board[row][col];

  Set<int> notesAt(int row, int col) => _notes[row][col];

  void toggleNoteMode() {
    isNoteMode = !isNoteMode;
    // Hiding the notes pad drops a quick-input digit that was pinned to it,
    // so nothing stays active without a visible pad to show it.
    if (!isNoteMode && activeDigitIsNote) {
      activeDigit = null;
      activeDigitIsNote = false;
    }
    notifyListeners();
  }

  /// Switches between cell-first and digit-first (quick) input. Clears
  /// [activeDigit] both ways so a digit picked in quick mode can't leak
  /// into a later re-entry, and also updates [quickInputDefault] so the
  /// choice carries over to the next game (persisted by the caller via
  /// SettingsController).
  void setQuickInputMode(bool enabled) {
    if (enabled == quickInputMode) return;
    quickInputMode = enabled;
    quickInputDefault = enabled;
    activeDigit = null;
    activeDigitIsNote = false;
    notifyListeners();
  }

  /// Picks [value] as the digit that cell taps will place while in quick
  /// input mode, and whether taps write it as a committed value ([asNote]
  /// false, from the value pad) or a pencil mark ([asNote] true, from the
  /// notes pad) — recorded in [activeDigitIsNote]. [isNoteMode] (notes-pad
  /// visibility) is deliberately left untouched; the two are independent.
  /// Only ever one digit is active: picking on either pad replaces whatever
  /// the other held. Re-tapping the digit already active on the same pad
  /// clears it back to plain selection. Also drops any showing hint, matching
  /// [selectCell]'s behavior for the equivalent cell-first interaction.
  void selectActiveDigit(int value, {required bool asNote}) {
    _setActiveHint(null);
    if (activeDigit == value && activeDigitIsNote == asNote) {
      activeDigit = null;
    } else {
      activeDigit = value;
      activeDigitIsNote = asNote;
    }
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
      _setActiveHint(null);
      _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
      _recordEvent(GameEvent.note(row, col, value, elapsedSeconds));
      notes.remove(value);
      notifyListeners();
      return;
    }

    if (wrongNoteWarningEnabled &&
        !SudokuGrid(_board).isValidPlacement(row, col, value)) {
      _flashConflictCells(row, col, value);
      return;
    }

    _setActiveHint(null);
    _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
    _recordEvent(GameEvent.note(row, col, value, elapsedSeconds));
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
    _setActiveHint(null);
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
    _setActiveHint(null);
    _conflictFlashTimer?.cancel();
    _conflictFlashCells = {};
    selectedRow = row;
    selectedCol = col;
    notifyListeners();
  }

  /// The digit occupying the selected cell, or null if nothing is selected
  /// or the selected cell is empty. Used to highlight every other cell that
  /// shares this value. In quick input mode the [activeDigit] takes over:
  /// the pad-picked digit highlights its placements without any cell being
  /// selected, showing where it can still go.
  int? get selectedValue {
    if (quickInputMode && activeDigit != null) return activeDigit;
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

    _setActiveHint(null);
    _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
    _recordEvent(GameEvent.place(row, col, value, elapsedSeconds));
    _board[row][col] = value;
    _notes[row][col].clear();
    if (autoRemoveNotesEnabled &&
        value != 0 &&
        value == _puzzle.solutionValue(row, col)) {
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
    if (status != GameStatus.playing) return;
    if (_history.isEmpty) return;
    final move = _history.removeLast();
    if (_eventLog.isNotEmpty) _eventLog.removeLast();
    if (move.row != null) {
      _board[move.row!][move.col!] = move.previousValue!;
    }
    _notes = move.previousNotes;
    _setActiveHint(null);
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
  Future<Hint?> requestHint({AppLocalizations? l10n}) async =>
      applyPreparedHint(await prepareRepairedHint(l10n: l10n), l10n: l10n);

  /// Runs [requestHint]'s repaired-notes search on a background isolate and
  /// returns the result WITHOUT committing anything — no notes edit, no
  /// history entry, no active hint. Lets the UI hold a completed search
  /// while it asks the player to consent to auto-corrected candidates (see
  /// `GameScreen._showAutoCandidatePrompt`), then commit via
  /// [applyPreparedHint] — instead of searching once for the offer and
  /// again on consent. Returns [PreparedHint.none] when a hint request
  /// would be refused outright (not playing, or an unresolved mistake).
  Future<PreparedHint> prepareRepairedHint({AppLocalizations? l10n}) async {
    if (status != GameStatus.playing) return PreparedHint.none;
    if (hasUnresolvedMistake) return PreparedHint.none;
    final board = boardSnapshot;
    // A clone, not [_notes] itself: the repair pass mutates the grid it's
    // given, and with an inline [HintSearchRunner] (tests) there is no
    // isolate message-copy to protect the live notes. Nothing may change
    // until [applyPreparedHint] commits.
    final notes = _cloneNotes();
    final solution = _puzzle.solution.toJson();
    final engine = _hintEngine;
    final resolvedL10n = l10n ?? lookupAppLocalizations(const Locale('ko'));
    final (hint, repairedNotes, repairedAny) = await _runSearch(() =>
        searchHintInBackground(
            engine, board, notes, solution, true, resolvedL10n));
    return PreparedHint._(hint, repairedNotes, repairedAny);
  }

  /// Commits a [prepareRepairedHint] result: applies the repaired notes
  /// (with an undoable history entry and the note-repair notice on an
  /// eliminate hint's explanation, exactly as the old synchronous
  /// [requestHint] did) and sets the active hint. The caller must not have
  /// let the board or notes change since the prepare — the only gap in the
  /// app is while the modal auto-candidates dialog is up, which blocks all
  /// board input. No-op returning null for [PreparedHint.none].
  Hint? applyPreparedHint(PreparedHint prepared, {AppLocalizations? l10n}) {
    if (!prepared._searched) return null;
    if (status != GameStatus.playing) return null;
    var hint = prepared.hint;
    if (prepared._repairedAny) {
      final repairedNotes = prepared._repairedNotes!;
      _history.add(_Move.notesOnly(_cloneNotes()));
      _recordEvent(GameEvent.repair(_repairedCells(repairedNotes), elapsedSeconds));
      _notes = repairedNotes;
      if (hint != null && hint.type == HintType.eliminate) {
        hint = hint.withExplanation(
          (l10n ?? lookupAppLocalizations(const Locale('ko')))
              .noteRepairNotice(hint.explanation),
        );
      }
    }
    _setActiveHint(hint, _stepsFor(hint, l10n));
    notifyListeners();
    return hint;
  }

  /// The step-by-step walkthrough for a hint about to be displayed (see
  /// [buildHintSteps]) — only the two request* entry points build one;
  /// generation and availability checks never show a hint, so they skip the
  /// work. Resolves a missing [l10n] to Korean the same way the engine does
  /// for [Hint.explanation].
  List<HintStep> _stepsFor(Hint? hint, AppLocalizations? l10n) => hint == null
      ? const []
      : buildHintSteps(
          hint, l10n ?? lookupAppLocalizations(const Locale('ko')));

  /// Stage 1 of the two-step hint flow (see `GameScreen._onHintPressed`):
  /// analyzes using ONLY the board's confirmed digits and the player's own
  /// notes as they stand — deliberately WITHOUT [_findHintWithRepair]'s
  /// auto-fill of missing candidates. Returns null (and clears [activeHint])
  /// when the player's current notes don't enable any known technique; the UI
  /// then offers to auto-generate candidates and retry via [requestHint]
  /// (stage 2). Reveal-type techniques still read the board directly, so a
  /// Naked/Hidden Single is found regardless of notes — only eliminate-type
  /// techniques depend on what the player has actually pencilled in. Never
  /// edits [_notes], so unlike [requestHint] it pushes no history entry.
  Future<Hint?> requestHintFromNotes({AppLocalizations? l10n}) async {
    if (status != GameStatus.playing) return null;
    if (hasUnresolvedMistake) return null;
    final board = boardSnapshot;
    final notes = _notes;
    final engine = _hintEngine;
    final resolvedL10n = l10n ?? lookupAppLocalizations(const Locale('ko'));
    var hint =
        await _runSearch(() => engine.findHint(board, notes, resolvedL10n));
    // Safety net: a notes-only search trusts the player's pencil marks as a
    // COMPLETE candidate set. If they understate a cell (omit a digit the
    // cell actually needs), an otherwise-sound eliminate technique can
    // "prove" something the real solution violates — e.g. a Naked Pair {1,3}
    // that removes 1 from a cell whose true answer is 1. Never surface a hint
    // that contradicts the solution: drop it so the UI offers auto-generated
    // candidates instead (stage 2's [_findHintWithRepair] restores the
    // every-cell-contains-its-solution-digit invariant that makes sound
    // eliminations provably solution-safe, which this stage deliberately
    // skips). Reveal hints read the board, not the notes, so they can't hit
    // this — but the check is cheap and covers them too.
    if (hint != null && !_agreesWithSolution(hint)) hint = null;
    _setActiveHint(hint, _stepsFor(hint, l10n));
    notifyListeners();
    return hint;
  }

  /// Debug-only: force-shows an X-Chain / AIC hint on the current board,
  /// bypassing the ordered [findHint] (which would surface an easier
  /// technique first) — the only way to see an AIC hint live, since it's
  /// last in [hintTechniqueOrder] and rarely reached. Returns null when the
  /// current notes hold no such chain. Sets it as the active hint + steps
  /// exactly like [requestHintFromNotes] so the hint sheet drives normally.
  Future<Hint?> debugRequestAicHint({AppLocalizations? l10n}) async {
    if (status != GameStatus.playing) return null;
    final board = boardSnapshot;
    final notes = _notes;
    final engine = _hintEngine;
    final resolvedL10n = l10n ?? lookupAppLocalizations(const Locale('ko'));
    // Grouped X-Chain before Grouped AIC: the general grouped search finds a
    // chain whenever the single-digit one does, so the reverse order would
    // make the groupedXChain label unreachable from this debug entry.
    var hint = await _runSearch(() =>
        engine.findAic(board, notes, resolvedL10n) ??
        engine.findXChain(board, notes, resolvedL10n) ??
        engine.findGroupedXChain(board, notes, resolvedL10n) ??
        engine.findGroupedAic(board, notes, resolvedL10n));
    if (hint != null && !_agreesWithSolution(hint)) hint = null;
    _setActiveHint(hint, _stepsFor(hint, l10n));
    notifyListeners();
    return hint;
  }

  /// Whether [hint]'s conclusion matches the actual solution: no eliminated
  /// candidate is a cell's true answer, and a revealed value is the true
  /// answer. Used to reject a notes-only hint built on faulty player notes
  /// (see [requestHintFromNotes]).
  bool _agreesWithSolution(Hint hint) {
    if (hint.type == HintType.reveal) {
      return hint.value == _puzzle.solutionValue(hint.row!, hint.col!);
    }
    for (final e in hint.eliminations) {
      if (e.digit == _puzzle.solutionValue(e.row, e.col)) return false;
    }
    return true;
  }

  /// Whether [requestHint] would actually return a hint right now — checks
  /// availability up front without mutating [activeHint]/[_notes] or
  /// triggering a rebuild the way [requestHint] itself does. Also false
  /// whenever [hasUnresolvedMistake] is true, matching [requestHint]'s own
  /// refusal.
  Future<bool> hasAvailableHint() async =>
      (await prepareRepairedHint()).hint != null;

  /// Discards the active hint without applying it.
  void dismissHint() {
    if (_activeHint == null) return;
    _setActiveHint(null);
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
    _setActiveHint(null);
    hintsUsed++;
    notifyListeners();
  }

  void _applyRevealHint(Hint hint) {
    final row = hint.row!;
    final col = hint.col!;
    final value = hint.value!;
    _history.add(_Move.value(row, col, _board[row][col], _cloneNotes()));
    _recordEvent(GameEvent.place(row, col, value, elapsedSeconds));
    _board[row][col] = value;
    // Same minimal-touch behavior as a normal inputValue placement: clear
    // this cell's own notes and drop the newly-placed digit from row/col/
    // box peers' notes — not a full-board recompute, which would blanket
    // every other still-blank cell with pencil marks the player never
    // asked for (same principle as _applyEliminateHint).
    _notes[row][col].clear();
    if (autoRemoveNotesEnabled) _removeNoteFromPeers(row, col, value);
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
    _recordEvent(GameEvent.eliminate(
        [for (final e in hint.eliminations) [e.row, e.col, e.digit]],
        elapsedSeconds));
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
    _setActiveHint(null);
    _history.add(_Move.notesOnly(_cloneNotes()));
    _recordEvent(GameEvent.fillNotes(elapsedSeconds));
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

/// A repaired-notes hint search that finished on the background isolate but
/// hasn't been committed — see [GameController.prepareRepairedHint] /
/// [GameController.applyPreparedHint]. [none] marks a request that was
/// refused before searching (not playing, unresolved mistake): applying it
/// is a no-op, matching the old synchronous requestHint's early return.
class PreparedHint {
  const PreparedHint._(this.hint, this._repairedNotes, this._repairedAny)
      : _searched = true;

  const PreparedHint._none()
      : hint = null,
        _repairedNotes = null,
        _repairedAny = false,
        _searched = false;

  static const none = PreparedHint._none();

  final Hint? hint;
  final List<List<Set<int>>>? _repairedNotes;
  final bool _repairedAny;
  final bool _searched;
}

/// The hint search [GameController] hands to its [HintSearchRunner] — a
/// top-level function over plain data, so the [Isolate.run] closure captures
/// only sendable values and never the controller itself.
///
/// With [repair], first makes sure every empty cell's notes still contain
/// that cell's true solution digit — the one candidate a *correctly* applied
/// technique, however advanced, can never eliminate (doing so would mean
/// proving the actual answer isn't the answer). A cell that's merely
/// narrower than the raw row/column/box candidate set because the player
/// validly reasoned past basic exclusion (e.g. a correctly applied Naked
/// Pair or Pointing) is left completely untouched — only cells actually
/// missing their solution digit (never checked off, or lost somehow) count
/// as broken. This matters because an eliminate-type technique (Naked/
/// Hidden Pair, Pointing, X-Wing, ...) builds its pattern by scanning for
/// cells with a *specific* candidate count or content; a cell the player
/// left completely unnoted doesn't just look "narrower", it can be
/// invisible to that scan entirely — never appearing anywhere in the
/// returned [Hint] — so checking only the cells a hint happens to reference
/// can miss this. A single full-board pass is always enough: broken cells
/// get reset to the safe (if unrefined) [SudokuGrid.candidatesAt] baseline,
/// which is guaranteed to include the solution digit as long as
/// [GameController.hasUnresolvedMistake] was false when the request was
/// made.
///
/// Mutates and returns [notes] — on the isolate that's its own message
/// copy; the caller's grid is never touched until [GameController.
/// applyPreparedHint] commits the returned one.
@visibleForTesting
(Hint?, List<List<Set<int>>>, bool) searchHintInBackground(
  HintEngine engine,
  List<List<int>> board,
  List<List<Set<int>>> notes,
  List<List<int>> solution,
  bool repair,
  AppLocalizations l10n,
) {
  var repairedAny = false;
  if (repair) {
    final grid = SudokuGrid(board);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board[r][c] != 0) continue;
        if (!notes[r][c].contains(solution[r][c])) {
          notes[r][c] = grid.candidatesAt(r, c);
          repairedAny = true;
        }
      }
    }
  }
  final hint = engine.findHint(board, notes, l10n);
  return (hint, notes, repairedAny);
}
