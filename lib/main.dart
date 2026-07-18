import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'l10n/generated/app_localizations.dart';
import 'models/game_snapshot.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/puzzle_queue_manager.dart';
import 'services/storage_service.dart';
import 'state/auth_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.assertConfigured();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  AdService.instance.initialize();
  final settings = SettingsController();
  await settings.load();
  final puzzleQueue = PuzzleQueueManager();
  await puzzleQueue.loadFromDisk();
  puzzleQueue.warmUp();
  final resumeSnapshot = await StorageService().loadInProgressGame();
  final auth = AuthController();
  runApp(SudokuApp(
    settings: settings,
    puzzleQueue: puzzleQueue,
    auth: auth,
    resumeSnapshot: resumeSnapshot,
  ));
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({
    super.key,
    required this.settings,
    required this.puzzleQueue,
    required this.auth,
    this.resumeSnapshot,
  });

  final SettingsController settings;
  final PuzzleQueueManager puzzleQueue;
  final AuthController auth;

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
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode,
        home: HomeScreen(
          settings: settings,
          puzzleQueue: puzzleQueue,
          auth: auth,
          initialResumeSnapshot: resumeSnapshot,
        ),
      ),
    );
  }
}
