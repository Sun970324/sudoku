import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/puzzle_queue_manager.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AdService.instance.initialize();
  final settings = SettingsController();
  await settings.load();
  final puzzleQueue = PuzzleQueueManager();
  await puzzleQueue.loadFromDisk();
  puzzleQueue.warmUp();
  runApp(SudokuApp(settings: settings, puzzleQueue: puzzleQueue));
}

class SudokuApp extends StatelessWidget {
  const SudokuApp(
      {super.key, required this.settings, required this.puzzleQueue});

  final SettingsController settings;
  final PuzzleQueueManager puzzleQueue;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        title: '스도쿠',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: settings.themeMode,
        home: HomeScreen(settings: settings, puzzleQueue: puzzleQueue),
      ),
    );
  }
}
