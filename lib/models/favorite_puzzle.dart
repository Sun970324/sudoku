import 'sudoku_puzzle.dart';

/// A puzzle the player saved to favorites to replay fresh later — see
/// StorageService's favorites methods and FavoritesScreen.
class FavoritePuzzle {
  FavoritePuzzle({required this.puzzle, required this.savedAt});

  final SudokuPuzzle puzzle;
  final DateTime savedAt;

  factory FavoritePuzzle.fromJson(Map<String, dynamic> json) => FavoritePuzzle(
        puzzle: SudokuPuzzle.fromJson(json['puzzle'] as Map<String, dynamic>),
        savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
      );

  Map<String, dynamic> toJson() => {
        'puzzle': puzzle.toJson(),
        'savedAt': savedAt.millisecondsSinceEpoch,
      };
}
