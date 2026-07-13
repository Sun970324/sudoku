import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/difficulty.dart';
import '../models/stats.dart';
import '../services/storage_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StorageService _storage = StorageService();
  late Future<Stats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _storage.getStats();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
            children: Difficulty.values.map((difficulty) {
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
            }).toList(),
          );
        },
      ),
    );
  }
}
