import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';

void main() {
  test('techniqueCategory is total over every implemented technique', () {
    // techniqueBaseScore is the app's canonical technique roster; every entry
    // must have a category, or the codex/practice grouping would silently drop
    // it.
    for (final technique in techniqueBaseScore.keys) {
      expect(techniqueCategory.containsKey(technique), isTrue,
          reason: '$technique has no TechniqueCategory');
    }
    // ...and no stray entries for non-techniques.
    expect(techniqueCategory.length, techniqueBaseScore.length);
  });

  test('every category has at least one member', () {
    final populated = techniqueCategory.values.toSet();
    for (final category in TechniqueCategory.values) {
      expect(populated, contains(category),
          reason: '$category has no techniques');
    }
  });

  test('categoryDifficulty returns the hardest member tier', () {
    // Singles top out at Easy (hidden single); ALS reaches Expert.
    expect(categoryDifficulty(TechniqueCategory.singles), Difficulty.easy);
    expect(categoryDifficulty(TechniqueCategory.intersections),
        Difficulty.easy);
    expect(categoryDifficulty(TechniqueCategory.almostLockedSets),
        Difficulty.expert);
  });

  test('declaration order is non-decreasing in hardest-member difficulty '
      '(so a category ceiling never precedes an easier one)', () {
    var prev = -1;
    for (final category in TechniqueCategory.values) {
      final rank = categoryDifficulty(category).index;
      expect(rank, greaterThanOrEqualTo(prev),
          reason: '$category (tier rank $rank) breaks ascending order');
      prev = rank;
    }
  });
}
