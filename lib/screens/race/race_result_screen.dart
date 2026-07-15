import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/hint.dart';
import '../../services/generation/difficulty_evaluator.dart';
import '../../services/generation/human_solver.dart';
import '../../state/race_controller.dart';

/// Terminal screen for a finished race — the last owner in the
/// Matchmaking -> Race -> RaceResult controller hand-off chain, so this is
/// what disposes [controller].
class RaceResultScreen extends StatefulWidget {
  const RaceResultScreen({super.key, required this.controller});

  final RaceController controller;

  @override
  State<RaceResultScreen> createState() => _RaceResultScreenState();
}

class _RaceResultScreenState extends State<RaceResultScreen> {
  DifficultyResult? _difficultyResult;

  @override
  void initState() {
    super.initState();
    final puzzle = widget.controller.puzzle;
    if (puzzle != null) {
      _difficultyResult = DifficultyEvaluator().evaluate(
        HumanSolver().solve(puzzle.puzzle.toJson()),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDelta(int delta) => delta >= 0 ? '+$delta' : '$delta';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;

    // Rating deltas only land once _refreshProfilesAfterFinish resolves
    // (an async round trip after this screen mounts), so this rebuilds via
    // AnimatedBuilder rather than reading controller fields once.
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final won = controller.isWinner;
        final opponentUsername = controller.opponentProfile?.username;
        final selfDelta = controller.selfRatingDelta;
        final opponentDelta = controller.opponentRatingDelta;
        final selfRatingAfter = controller.selfRatingAfter;
        final opponentRatingAfter = controller.opponentRatingAfter;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.raceResultTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                  size: 64,
                  color:
                      won ? Colors.amber : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(won ? l10n.raceWon : l10n.raceLost,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(_formatTime(controller.game.elapsedSeconds)),
                const SizedBox(height: 16),
                if (selfRatingAfter != null && selfDelta != null)
                  Text(l10n.yourRatingChangeLabel(
                    selfRatingAfter - selfDelta,
                    selfRatingAfter,
                    _formatDelta(selfDelta),
                  ))
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                if (opponentUsername != null &&
                    controller.opponentProfile != null &&
                    opponentDelta != null && opponentRatingAfter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.opponentRatingChangeLabel(
                      opponentUsername,
                      opponentRatingAfter - opponentDelta,
                      opponentRatingAfter,
                      _formatDelta(opponentDelta),
                    )),
                  ),
              ],
            )),
            const SizedBox(height: 16),
            if (_difficultyResult != null) _TechniqueCard(result: _difficultyResult!),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.homeButton),
            ),
            ],
          ),
        );
      },
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  const _TechniqueCard({required this.result});

  final DifficultyResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final techniques = result.techniqueCounts.entries.toList()
      ..sort((a, b) => humanSolverTechniqueOrder
          .indexOf(a.key)
          .compareTo(humanSolverTechniqueOrder.indexOf(b.key)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.techniquesUsedTitle,
                style: Theme.of(context).textTheme.titleMedium),
            if (result.highestTechnique != null) ...[
              const SizedBox(height: 8),
              Text('${l10n.highestTechniqueLabel} ${result.highestTechnique!.label(context)}'),
            ],
            ...techniques.map((entry) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(child: Text(entry.key.label(context))),
                    Text(l10n.techniqueUsageCount(entry.value)),
                  ]),
                )),
          ],
        ),
      ),
    );
  }
}
