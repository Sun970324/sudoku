import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/hint.dart';
import '../../models/sudoku_puzzle.dart';
import '../../services/technique_queue_manager.dart';
import '../../state/premium_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pop_card.dart';
import '../game_screen.dart';
import '../premium/premium_lock_screen.dart';

/// Learning mode: pick a technique *category* (HoDoKu-style) to drill on a
/// board built to feature it, then walk through it step by step via the game's
/// "이 기법 보기" action. Singles/Intersections are free; the rest are a premium
/// perk. The codex ([TechniqueCodexScreen]) stays the separate progress view.
class TechniquePracticeScreen extends StatefulWidget {
  const TechniquePracticeScreen({super.key});

  @override
  State<TechniquePracticeScreen> createState() =>
      _TechniquePracticeScreenState();
}

class _TechniquePracticeScreenState extends State<TechniquePracticeScreen> {
  /// The category currently mining/loading a board — its row shows a spinner
  /// and further taps are ignored until it resolves.
  TechniqueCategory? _loadingCategory;

  /// The two easiest categories are the free taster; the rest are premium.
  static const _freeCategories = {
    TechniqueCategory.singles,
    TechniqueCategory.intersections,
  };

  @override
  void initState() {
    super.initState();
    // Pre-mine a board for every empty category in the background, so tapping
    // one is instant instead of waiting on a live mine.
    TechniqueQueueManager.instance.warmUp();
  }

  static bool _isFree(TechniqueCategory category) =>
      _freeCategories.contains(category);

  Future<void> _startPractice(TechniqueCategory category) async {
    if (_loadingCategory != null) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_isFree(category) && !PremiumController.instance.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PremiumLockScreen(description: l10n.practicePremiumBody),
        ),
      );
      return;
    }
    setState(() => _loadingCategory = category);
    SudokuPuzzle? puzzle;
    try {
      puzzle = await TechniqueQueueManager.instance.take(category);
    } catch (_) {
      // A mining failure must not leave the row spinning forever.
      puzzle = null;
    }
    if (!mounted) return;
    setState(() => _loadingCategory = null);
    if (puzzle == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.practiceNoBoard)));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen.newGame(
          difficulty: categoryDifficulty(category),
          puzzle: puzzle,
          practiceTechniques: techniquesInCategory(category).toSet(),
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
            for (final category in TechniqueCategory.values)
              _CategoryCard(
                category: category,
                accent: AppPalette.difficultyColor(
                    categoryDifficulty(category), isDark),
                locked:
                    !_isFree(category) && !PremiumController.instance.isPremium,
                loading: _loadingCategory == category,
                onTap: () => _startPractice(category),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.accent,
    required this.locked,
    required this.loading,
    required this.onTap,
  });

  final TechniqueCategory category;
  final Color accent;
  final bool locked;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // The member techniques inside the category, so the learner sees what a
    // category drills (e.g. Basic Fish → X-Wing · Swordfish · Jellyfish).
    final members = techniquesInCategory(category)
        .map((t) => t.label(context))
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PopCard(
        tint: accent,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: loading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label(context),
                        style: TextStyle(
                            fontFamily: 'Mulmaru',
                            fontSize: 17,
                            color: accent),
                      ),
                      const SizedBox(height: 6),
                      Text(members,
                          style: TextStyle(fontSize: 13, color: muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (locked)
                  Icon(Icons.lock_outline, size: 18, color: muted)
                else
                  Icon(Icons.play_arrow_rounded, size: 22, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
