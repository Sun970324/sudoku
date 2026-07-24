import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../models/game_replay.dart';
import '../../services/storage_service.dart';
import '../../state/premium_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pixel_icon.dart';
import '../../widgets/pop_card.dart';
import '../premium/premium_lock_screen.dart';
import 'replay_player_screen.dart';

/// The most recent finished games available to replay (premium-only). Free
/// users see an upsell in place of the list.
class ReplayListScreen extends StatefulWidget {
  const ReplayListScreen({super.key});

  @override
  State<ReplayListScreen> createState() => _ReplayListScreenState();
}

class _ReplayListScreenState extends State<ReplayListScreen> {
  late Future<List<GameReplay>> _replays;

  @override
  void initState() {
    super.initState();
    _replays = StorageService().loadReplays();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(
          leading: const PixelBackButton(), title: Text(l10n.replayTitle)),
      body: AnimatedBuilder(
        animation: PremiumController.instance,
        builder: (context, _) {
          if (!PremiumController.instance.isPremium) {
            return PremiumLockView(description: l10n.replayPremiumBody);
          }
          return FutureBuilder<List<GameReplay>>(
            future: _replays,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final replays = snapshot.data!;
              if (replays.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.replayEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: replays.length,
                itemBuilder: (context, i) => _ReplayCard(replay: replays[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReplayCard extends StatelessWidget {
  const _ReplayCard({required this.replay});

  final GameReplay replay;

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final accent = AppPalette.difficultyColor(replay.difficulty, isDark);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMd(locale).add_Hm().format(replay.finishedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PopCard(
        tint: accent,
        padding: EdgeInsets.zero,
        // Transparent Material + clipped InkWell so the tap ripple renders on
        // top of the card (a bare ListTile behind PopCard's opaque box warns
        // its ink/background may be invisible) and stays within the corners.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDims.cardRadius),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReplayPlayerScreen(replay: replay),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    replay.won ? PixelIcons.trophy : PixelIcons.sadFace,
                    color: replay.won
                        ? accent
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replay.difficulty.label(context),
                          style: TextStyle(
                              fontFamily: 'Mulmaru',
                              fontSize: 17,
                              color: accent),
                        ),
                        Text(date,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(PixelIcons.timelapse, size: 15),
                  const SizedBox(width: 4),
                  Text(_formatTime(replay.elapsedSeconds)),
                  const SizedBox(width: 12),
                  const Icon(PixelIcons.close, size: 15),
                  const SizedBox(width: 4),
                  Text('${replay.mistakes}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
