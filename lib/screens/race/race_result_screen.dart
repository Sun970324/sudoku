import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/hint.dart';
import '../../services/generation/difficulty_evaluator.dart';
import '../../services/generation/human_solver.dart';
import '../../state/race_controller.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';

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

        return GradientScaffold(
          appBar: AppBar(title: Text(l10n.raceResultTitle)),
          body: CelebrationOverlay(
            play: won,
            big: won,
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: won
                        ? const LinearGradient(colors: [
                            Color(0xFFFFD24A),
                            Color(0xFFFFA726),
                          ])
                        : LinearGradient(colors: [
                            Colors.indigo.shade300,
                            Colors.indigo.shade500,
                          ]),
                  ),
                  child: Icon(
                    won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                    size: 52,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .scale(
                        begin: const Offset(0.5, 0.5),
                        curve: Curves.elasticOut,
                        duration: 700.ms),
                const SizedBox(height: 16),
                Text(won ? l10n.raceWon : l10n.raceLost,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  _formatTime(controller.game.elapsedSeconds),
                  style: const TextStyle(fontFamily: 'Jua', fontSize: 24),
                ),
                const SizedBox(height: 16),
                // A friendly match never writes rating columns, so the
                // ranked branches below would spin forever waiting for a
                // delta that never comes (or show a bogus "+0" via the
                // profile-diff fallback).
                if (controller.isPrivate)
                  Text(l10n.friendlyMatchLabel)
                else if (selfRatingAfter != null && selfDelta != null)
                  PopCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    child: Column(
                      children: [
                        Text(l10n.yourRatingChangeLabel(
                          selfRatingAfter - selfDelta,
                          selfRatingAfter,
                          _formatDelta(selfDelta),
                        )),
                        const SizedBox(height: 4),
                        Text(
                          _formatDelta(selfDelta),
                          style: TextStyle(
                            fontFamily: 'Jua',
                            fontSize: 28,
                            color: selfDelta >= 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                if (!controller.isPrivate &&
                    opponentUsername != null &&
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
            PopButton(
              onPressed: () => Navigator.pop(context),
              label: l10n.homeButton,
              expanded: true,
            ),
            ],
          ),
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
    return PopCard(
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
    );
  }
}
