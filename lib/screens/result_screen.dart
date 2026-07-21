import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/hint.dart';
import '../models/sudoku_puzzle.dart';
import '../services/generation/difficulty_evaluator.dart';
import '../services/generation/human_solver.dart';
import '../services/percentile_estimator.dart';
import '../theme/app_palette.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/favorite_button.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/pixel_back_button.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/pop_button.dart';
import '../widgets/pop_card.dart';
import '../widgets/puzzle_share_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shown right after a puzzle is completed, replacing the old plain "완료!"
/// dialog. Takes only already-computed primitive/value-type data (plus the
/// completed [puzzle], for the share dialog) — no [GameController]
/// reference — so it stays valid even after the game screen that produced
/// it is disposed.
class ResultScreen extends StatelessWidget {
  ResultScreen({
    super.key,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsUsed,
    required this.difficultyResult,
    required this.isNewBest,
    required this.previousBestSeconds,
    required this.puzzle,
  }) : _flavorIndex = Random().nextInt(_perfectFlavorCount);

  final Difficulty difficulty;
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
  final DifficultyResult difficultyResult;
  final bool isNewBest;
  final int? previousBestSeconds;
  final SudokuPuzzle puzzle;

  /// Number of random flavor lines shown on a perfect clear — must match the
  /// perfectClearFlavor1..N keys in the arb files.
  static const int _perfectFlavorCount = 10;

  /// Picked once at construction (one per completed game) so the phrase stays
  /// stable across rebuilds instead of reshuffling on every repaint.
  final int _flavorIndex;

  List<String> _perfectFlavors(AppLocalizations l10n) => [
        l10n.perfectClearFlavor1,
        l10n.perfectClearFlavor2,
        l10n.perfectClearFlavor3,
        l10n.perfectClearFlavor4,
        l10n.perfectClearFlavor5,
        l10n.perfectClearFlavor6,
        l10n.perfectClearFlavor7,
        l10n.perfectClearFlavor8,
        l10n.perfectClearFlavor9,
        l10n.perfectClearFlavor10,
      ];

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static Color _difficultyColor(Difficulty d, bool isDark) =>
      AppPalette.difficultyColor(d, isDark);

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

    final accent = AppPalette.difficultyColor(difficulty, isDark);
    final isPerfect = mistakes == 0 && hintsUsed == 0;
    final perfectFlavor =
        isPerfect ? _perfectFlavors(l10n)[_flavorIndex] : null;
    return GradientScaffold(
      appBar: AppBar(
        leading: const PixelBackButton(),
        title: Text(l10n.resultTitle),
        actions: [
          FavoriteButton(puzzle: puzzle),
          IconButton(
            icon: const Icon(PixelIcons.share),
            onPressed: () => showPuzzleShareDialog(context, puzzle: puzzle),
          ),
        ],
      ),
      body: CelebrationOverlay(
        big: isPerfect,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      difficulty.label(context),
                      style: TextStyle(
                          fontFamily: 'Mulmaru', fontSize: 16, color: accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(elapsedSeconds),
                    style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 56),
                  ).animate().scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.elasticOut,
                      duration: 600.ms),
                  if (isPerfect) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFFD24A),
                          Color(0xFFFFA726),
                        ]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PixelIcons.star,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  perfectFlavor!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontFamily: 'Mulmaru',
                                      color: Colors.white,
                                      fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.perfectClearBadge,
                            style: TextStyle(
                              fontFamily: 'Mulmaru',
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ).animate().scale(
                        begin: const Offset(0.6, 0.6),
                        delay: 250.ms,
                        curve: Curves.elasticOut,
                        duration: 600.ms),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            PopCard(
              child: Text(l10n.mistakesAndHints(mistakes, hintsUsed)),
            ),
            const SizedBox(height: 12),
            PopCard(
              tint: const Color(0xFF6E56FF),
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
            const SizedBox(height: 12),
            PopCard(
              tint: const Color(0xFF2563EB),
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
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fasterThanPercent / 100,
                      minHeight: 10,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.15),
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
            const SizedBox(height: 12),
            PopCard(
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
                              difficultyResult.highestTechnique!.label(context),
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
            const SizedBox(height: 20),
            PopButton(
              onPressed: () => Navigator.pop(context),
              label: l10n.homeButton,
              expanded: true,
            ),
          ]
              .animate(interval: 60.ms)
              .fadeIn(duration: 250.ms)
              .slideY(begin: 0.08, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}
