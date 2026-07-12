import 'difficulty.dart';
import 'sudoku_grid.dart';

class SudokuPuzzle {
  SudokuPuzzle({
    required this.puzzle,
    required this.solution,
    required this.fixedMask,
    required this.difficulty,
  });

  factory SudokuPuzzle.fromJson(Map<String, dynamic> json) => SudokuPuzzle(
        puzzle: SudokuGrid.fromJson(json['puzzle'] as List<dynamic>),
        solution: SudokuGrid.fromJson(json['solution'] as List<dynamic>),
        fixedMask: (json['fixedMask'] as List<dynamic>)
            .map((row) => (row as List<dynamic>).cast<bool>())
            .toList(),
        difficulty: difficultyFromName(json['difficulty'] as String),
      );

  final SudokuGrid puzzle;
  final SudokuGrid solution;
  final List<List<bool>> fixedMask;
  final Difficulty difficulty;

  bool isFixed(int row, int col) => fixedMask[row][col];

  int solutionValue(int row, int col) => solution.get(row, col);

  Map<String, dynamic> toJson() => {
        'puzzle': puzzle.toJson(),
        'solution': solution.toJson(),
        'fixedMask': fixedMask,
        'difficulty': difficulty.name,
      };
}
