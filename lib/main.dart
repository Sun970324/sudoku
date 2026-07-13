import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'models/game_snapshot.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/puzzle_queue_manager.dart';
import 'services/storage_service.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AdService.instance.initialize();
  final settings = SettingsController();
  await settings.load();
  final puzzleQueue = PuzzleQueueManager();
  await puzzleQueue.loadFromDisk();
  puzzleQueue.warmUp();
  final resumeSnapshot = await StorageService().loadInProgressGame();
  runApp(SudokuApp(
    settings: settings,
    puzzleQueue: puzzleQueue,
    resumeSnapshot: resumeSnapshot,
  ));
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({
    super.key,
    required this.settings,
    required this.puzzleQueue,
    this.resumeSnapshot,
  });

  final SettingsController settings;
  final PuzzleQueueManager puzzleQueue;

  /// A game already in progress at app launch — when non-null, [HomeScreen]
  /// pushes straight into that game right after its first frame, so the
  /// user still lands on the game screen immediately, but with [HomeScreen]
  /// underneath it in the navigator stack (so back/"게임 끝내기" have
  /// somewhere to go).
  final GameSnapshot? resumeSnapshot;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: settings.localeOverride,
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
        home: HomeScreen(
          settings: settings,
          puzzleQueue: puzzleQueue,
          initialResumeSnapshot: resumeSnapshot,
        ),
      ),
    );
  }
}
