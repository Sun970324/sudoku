import 'package:flutter/material.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fasterThanPercent =
        estimateFasterThanPercent(difficulty, elapsedSeconds);
    final sortedTechniques = difficultyResult.techniqueCounts.entries.toList()
      ..sort((a, b) => humanSolverTechniqueOrder
          .indexOf(a.key)
          .compareTo(humanSolverTechniqueOrder.indexOf(b.key)));

    return Scaffold(
      appBar: AppBar(title: const Text('결과')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(difficulty.label,
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
                  const Chip(
                    avatar: Icon(Icons.star, size: 18, color: Colors.amber),
                    label: Text('노미스 완료! Perfect Clear'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('실수 $mistakes회 · 힌트 사용 $hintsUsed회'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('개인 최고기록',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (previousBestSeconds == null)
                    const Text('이 난이도 첫 클리어예요!')
                  else if (isNewBest)
                    Text(
                        '🏆 개인 최고기록 경신! (이전 ${_formatTime(previousBestSeconds!)})')
                  else
                    Text('개인 최고기록: ${_formatTime(previousBestSeconds!)}'),
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
                  Text('글로벌 유저 비교',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '상위 ${100 - fasterThanPercent}%',
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
                    '* 실제 유저 데이터가 아닌 예시입니다.',
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
                  Text('사용된 기법',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (difficultyResult.highestTechnique != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          const Text('최고 난이도 기법:'),
                          Chip(
                            label: Text(
                              '${difficultyResult.highestTechnique!.label} (${difficultyResult.highestDifficulty.label})',
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
                          Expanded(child: Text(entry.key.label)),
                          Text('${entry.value}회'),
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
            child: const Text('홈으로'),
          ),
        ],
      ),
    );
  }
}
