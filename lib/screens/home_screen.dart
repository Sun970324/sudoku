import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../models/game_snapshot.dart';
import '../services/haptic_service.dart';
import '../services/puzzle_queue_manager.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../state/settings_controller.dart';
import 'game_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.puzzleQueue,
  });

  final SettingsController settings;
  final PuzzleQueueManager puzzleQueue;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  GameSnapshot? _savedGame;

  @override
  void initState() {
    super.initState();
    _loadSavedGame();
  }

  Future<void> _loadSavedGame() async {
    final snapshot = await _storage.loadInProgressGame();
    if (!mounted) return;
    setState(() => _savedGame = snapshot);
  }

  Future<void> _openGame(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadSavedGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스도쿠'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/icon_black.png'
                  : 'assets/images/app_icon.png',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 32),
            if (_savedGame != null) ...[
              ElevatedButton(
                onPressed: () =>
                    _openGame(GameScreen.resume(resumeSnapshot: _savedGame!)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('이어하기', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: () => _showDifficultyPicker(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text('새 게임', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _openGame(const StatsScreen()),
              child: const Text('기록 보기'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDifficultyPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: Difficulty.values.map((difficulty) {
            return ListTile(
              title: Text(difficulty.label),
              onTap: () {
                Navigator.pop(sheetContext);
                final puzzle = widget.puzzleQueue.take(difficulty);
                _openGame(
                  GameScreen.newGame(difficulty: difficulty, puzzle: puzzle),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child:
                    Text('테마', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              RadioGroup<ThemeMode>(
                groupValue: widget.settings.themeMode,
                onChanged: (mode) => widget.settings.setThemeMode(mode!),
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text('시스템 설정 따르기'),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('라이트 모드'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('다크 모드'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('진동'),
                value: widget.settings.hapticsEnabled,
                onChanged: (v) {
                  widget.settings.setHapticsEnabled(v);
                  if (v) HapticService.selection();
                },
              ),
              SwitchListTile(
                title: const Text('효과음'),
                value: widget.settings.soundEnabled,
                onChanged: (v) {
                  widget.settings.setSoundEnabled(v);
                  if (v) SoundService.click();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
