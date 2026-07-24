import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../models/hint.dart';
import '../../models/sudoku_puzzle.dart';
import '../../services/generation/technique_board_miner.dart';
import '../../services/technique_queue_manager.dart';
import '../../state/premium_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pop_card.dart';
import '../game_screen.dart';
import '../premium/premium_lock_screen.dart';

/// Learning mode: pick a technique to drill on a board built to feature it,
/// then walk through it step by step via the game's "이 기법 보기" action.
/// beginner/easy items are free; the rest are a premium perk. The codex
/// ([TechniqueCodexScreen]) stays the separate progress view.
class TechniquePracticeScreen extends StatefulWidget {
  const TechniquePracticeScreen({super.key});

  @override
  State<TechniquePracticeScreen> createState() =>
      _TechniquePracticeScreenState();
}

class _TechniquePracticeScreenState extends State<TechniquePracticeScreen> {
  /// The item currently mining/loading a board — its row shows a spinner and
  /// further taps are ignored until it resolves.
  String? _loadingItemId;

  @override
  void initState() {
    super.initState();
    // Pre-mine a board for every empty item in the background, so tapping one
    // is instant instead of waiting on a live mine.
    TechniqueQueueManager.instance.warmUp();
  }

  /// An item's tier is its hardest member technique (matching how
  /// [mineTechniqueBoard] tags the board it mines).
  static Difficulty _tierOf(PracticeItem item) => Difficulty.values[
      item.techniques.map((t) => techniqueDifficulty[t]!.index).reduce(max)];

  /// beginner/easy items are the free taster; medium and up are premium.
  static bool _isFree(PracticeItem item) =>
      _tierOf(item).index <= Difficulty.easy.index;

  Future<void> _startPractice(PracticeItem item) async {
    if (_loadingItemId != null) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_isFree(item) && !PremiumController.instance.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PremiumLockScreen(description: l10n.practicePremiumBody),
        ),
      );
      return;
    }
    setState(() => _loadingItemId = item.id);
    SudokuPuzzle? puzzle;
    try {
      puzzle = await TechniqueQueueManager.instance.take(item.id);
    } catch (_) {
      // A mining failure must not leave the row spinning forever.
      puzzle = null;
    }
    if (!mounted) return;
    setState(() => _loadingItemId = null);
    if (puzzle == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.practiceNoBoard)));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen.newGame(
          difficulty: _tierOf(item),
          puzzle: puzzle,
          practiceTechniques: item.techniques,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    return GradientScaffold(
      appBar: AppBar(
        leading: const PixelBackButton(),
        title: Text(l10n.practiceTitle),
      ),
      body: AnimatedBuilder(
        animation: PremiumController.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PopCard(
              padding: const EdgeInsets.all(20),
              child: Text(
                l10n.practiceIntro,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 15),
              ),
            ),
            for (final tier in Difficulty.values)
              ..._tierSection(context, l10n, isDark, tier),
          ],
        ),
      ),
    );
  }

  /// One tier's card (header + practice-item rows), or nothing if no item maps
  /// to [tier].
  List<Widget> _tierSection(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    Difficulty tier,
  ) {
    final items =
        TechniqueQueueManager.items.where((it) => _tierOf(it) == tier).toList();
    if (items.isEmpty) return const [];
    final accent = AppPalette.difficultyColor(tier, isDark);
    return [
      const SizedBox(height: 16),
      PopCard(
        tint: accent,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tier.label(context),
              style: TextStyle(
                  fontFamily: 'Mulmaru', fontSize: 17, color: accent),
            ),
            const SizedBox(height: 4),
            for (final item in items)
              _PracticeRow(
                item: item,
                accent: accent,
                locked:
                    !_isFree(item) && !PremiumController.instance.isPremium,
                loading: _loadingItemId == item.id,
                onTap: () => _startPractice(item),
              ),
          ],
        ),
      ),
    ];
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.item,
    required this.accent,
    required this.locked,
    required this.loading,
    required this.onTap,
  });

  final PracticeItem item;
  final Color accent;
  final bool locked;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Group items (e.g. Swordfish · Jellyfish) list every member technique;
    // a single-technique item is just its own label.
    final name = item.techniques.map((t) => t.label(context)).join(' · ');
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(name)),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (locked)
              Icon(Icons.lock_outline, size: 16, color: muted)
            else
              Icon(Icons.play_arrow_rounded, size: 20, color: accent),
          ],
        ),
      ),
    );
  }
}
