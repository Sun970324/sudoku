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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6E56FF),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF6F5FF),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFFF6F5FF),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Color(0xFF241B4B),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6E56FF),
              foregroundColor: Colors.white,
              elevation: 5,
              shadowColor: const Color(0xFF6E56FF).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF9D8CFF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0D0B1E),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFF0D0B1E),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Color(0xFFF0EEFF),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
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
