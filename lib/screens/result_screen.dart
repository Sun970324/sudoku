import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/hint.dart';
import '../services/generation/difficulty_evaluator.dart';
import '../services/generation/human_solver.dart';
import '../services/percentile_estimator.dart';

/// Shown right after a puzzle is completed, replacing the old plain "완료!"
/// dialog. Takes only already-computed primitive/value-type data (no
/// [GameController] reference) so it stays valid even after the game screen
/// that produced it is disposed.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsUsed,
    required this.difficultyResult,
    required this.isNewBest,
    required this.previousBestSeconds,
  });

  final Difficulty difficulty;
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
  final DifficultyResult difficultyResult;
  final bool isNewBest;
  final int? previousBestSeconds;

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static Color _difficultyColor(Difficulty d, bool isDark) {
    switch (d) {
      case Difficulty.beginner:
        return isDark ? Colors.green.shade300 : Colors.green.shade700;
      case Difficulty.easy:
        return isDark ? Colors.teal.shade300 : Colors.teal.shade700;
      case Difficulty.medium:
        return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      case Difficulty.hard:
        return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
      case Difficulty.master:
        return isDark ? Colors.deepOrange.shade300 : Colors.deepOrange.shade700;
      case Difficulty.expert:
        return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fasterThanPercent =
        estimateFasterThanPercent(difficulty, elapsedSeconds);
    final sortedTechniques = difficultyResult.techniqueCounts.entries.toList()
      ..sort((a, b) => humanSolverTechniqueOrder
          .indexOf(a.key)
          .compareTo(humanSolverTechniqueOrder.indexOf(b.key)));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(difficulty.label(context),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  _formatTime(elapsedSeconds),
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (mistakes == 0) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.star,
                        size: 18, color: Colors.amber),
                    label: Text(l10n.perfectClearBadge),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.mistakesAndHints(mistakes, hintsUsed)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.personalBestTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (previousBestSeconds == null)
                    Text(l10n.firstClear)
                  else if (isNewBest)
                    Text(l10n.newBest(_formatTime(previousBestSeconds!)))
                  else
                    Text(l10n.currentBest(_formatTime(previousBestSeconds!))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.comparisonTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    l10n.topPercent(100 - fasterThanPercent),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fasterThanPercent / 100,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.mockDataDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.techniquesUsedTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (difficultyResult.highestTechnique != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(l10n.highestTechniqueLabel),
                          Chip(
                            label: Text(
                              difficultyResult.highestTechnique!
                                  .label(context),
                            ),
                            backgroundColor: _difficultyColor(
                                    difficultyResult.highestDifficulty, isDark)
                                .withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _difficultyColor(
                                  difficultyResult.highestDifficulty, isDark),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...sortedTechniques.map((entry) {
                    final tier = techniqueDifficulty[entry.key]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _difficultyColor(tier, isDark),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.key.label(context))),
                          Text(l10n.techniqueUsageCount(entry.value)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.homeButton),
          ),
        ],
      ),
    );
  }
}
