import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
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
                  title: Text(difficulty.label),
                  subtitle: Text(
                    '플레이 ${entry.played}회 · 승리 ${entry.won}회'
                    '${bestTime != null ? ' · 최고기록 ${_formatTime(bestTime)}' : ''}',
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
