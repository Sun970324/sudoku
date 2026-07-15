import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/race.dart';
import '../models/stats.dart';
import '../services/race_service.dart';
import '../services/storage_service.dart';
import '../state/auth_controller.dart';
import 'game_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StorageService _storage = StorageService();
  late Future<Stats> _statsFuture;
  Future<List<RaceHistoryEntry>>? _raceHistoryFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _storage.getStats();
    if (widget.auth.isSignedIn) {
      _raceHistoryFuture = RaceService().fetchHistory();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildRaceHistoryTile(RaceHistoryEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final delta = entry.ratingDelta;
    final deltaColor = delta >= 0 ? Colors.green : Colors.red;
    final deltaText = delta >= 0 ? '+$delta' : '$delta';
    final resultLabel =
        entry.won ? l10n.raceHistoryResultWon : l10n.raceHistoryResultLost;
    final baseStyle = TextStyle(
      fontSize: 13,
      color: DefaultTextStyle.of(context).style.color,
    );
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen.newGame(
              difficulty: entry.puzzle.difficulty,
              puzzle: entry.puzzle,
            ),
          ),
        ),
        leading: Icon(
          entry.won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
          color:
              entry.won ? Colors.amber : Theme.of(context).colorScheme.outline,
        ),
        title: Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(text:
                  '($resultLabel) ${_formatDate(entry.finishedAt)} vs ${entry.opponentUsername} ${entry.ratingAfter} ('),
              TextSpan(
                text: deltaText,
                style: baseStyle.copyWith(
                    color: deltaColor, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ')'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: FutureBuilder<Stats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...Difficulty.values.map((difficulty) {
                final entry = stats.byDifficulty[difficulty]!;
                final bestTime = entry.bestTimeSeconds;
                return Card(
                  child: ListTile(
                    title: Text(difficulty.label(context)),
                    subtitle: Text(
                      l10n.playedWonLabel(entry.played, entry.won) +
                          (bestTime != null
                              ? l10n.bestTimeSuffix(_formatTime(bestTime))
                              : ''),
                    ),
                  ),
                );
              }),
              if (_raceHistoryFuture != null) ...[
                const SizedBox(height: 16),
                Text(l10n.raceHistoryTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<List<RaceHistoryEntry>>(
                  future: _raceHistoryFuture,
                  builder: (context, raceSnapshot) {
                    if (!raceSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final history = raceSnapshot.data!;
                    if (history.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(l10n.raceHistoryEmpty),
                      );
                    }
                    return Column(
                      children: history.map(_buildRaceHistoryTile).toList(),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
