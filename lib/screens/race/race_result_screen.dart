import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final won = controller.isWinner;
    final opponentUsername = controller.opponentProfile?.username;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.raceResultTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 64,
              color: won ? Colors.amber : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(won ? l10n.raceWon : l10n.raceLost,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(_formatTime(controller.game.elapsedSeconds)),
            if (opponentUsername != null) ...[
              const SizedBox(height: 8),
              Text(l10n.raceOpponentLabel(opponentUsername)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.homeButton),
            ),
          ],
        ),
      ),
    );
  }
}
