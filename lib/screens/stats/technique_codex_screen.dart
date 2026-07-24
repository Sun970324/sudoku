import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../models/hint.dart';
import '../../services/generation/human_solver.dart';
import '../../services/storage_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pop_card.dart';

/// The technique codex (free for everyone): every solving technique the app
/// knows, grouped by [TechniqueCategory] (type), with how often each has
/// appeared in puzzles the player solved — fed by
/// StorageService.recordTechniqueCounts on solo wins. Each row carries a
/// difficulty badge (the secondary axis); undiscovered techniques stay dimmed
/// until first encountered.
class TechniqueCodexScreen extends StatefulWidget {
  const TechniqueCodexScreen({super.key});

  @override
  State<TechniqueCodexScreen> createState() => _TechniqueCodexScreenState();
}

class _TechniqueCodexScreenState extends State<TechniqueCodexScreen> {
  late final Future<Map<HintTechnique, ({int uses, int puzzles})>> _codex =
      StorageService().loadTechniqueCodex();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(
        leading: const PixelBackButton(),
        title: Text(l10n.codexTitle),
      ),
      body: FutureBuilder<Map<HintTechnique, ({int uses, int puzzles})>>(
        future: _codex,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final codex = snapshot.data!;
          final isDark = AppPalette.isDark(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PopCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  l10n.codexProgress(
                      codex.length, humanSolverTechniqueOrder.length),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 18),
                ),
              ),
              for (final category in TechniqueCategory.values)
                ..._categorySection(context, l10n, isDark, category, codex),
            ],
          );
        },
      ),
    );
  }

  /// One category's card (header + technique rows), or nothing if none of its
  /// members are in the codex's tracked set ([humanSolverTechniqueOrder]).
  List<Widget> _categorySection(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    TechniqueCategory category,
    Map<HintTechnique, ({int uses, int puzzles})> codex,
  ) {
    final techniques = techniquesInCategory(category)
        .where(humanSolverTechniqueOrder.contains)
        .toList();
    if (techniques.isEmpty) return const [];
    final accent =
        AppPalette.difficultyColor(categoryDifficulty(category), isDark);
    return [
      const SizedBox(height: 16),
      PopCard(
        tint: accent,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.label(context),
              style: TextStyle(
                  fontFamily: 'Mulmaru', fontSize: 17, color: accent),
            ),
            const SizedBox(height: 8),
            for (final technique in techniques)
              _TechniqueRow(
                technique: technique,
                stats: codex[technique],
                isDark: isDark,
              ),
          ],
        ),
      ),
    ];
  }
}

class _TechniqueRow extends StatelessWidget {
  const _TechniqueRow({
    required this.technique,
    required this.stats,
    required this.isDark,
  });

  final HintTechnique technique;

  /// Null until the technique first appears in a solved puzzle.
  final ({int uses, int puzzles})? stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final discovered = stats != null;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Category is the grouping axis now, so difficulty rides along per row: the
    // check + tier pill are coloured by this technique's own tier.
    final tier = techniqueDifficulty[technique]!;
    final tierColor = AppPalette.difficultyColor(tier, isDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            discovered ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: discovered ? tierColor : muted.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              technique.label(context),
              style: discovered
                  ? null
                  : TextStyle(color: muted.withValues(alpha: 0.55)),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: discovered ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tier.label(context),
              style: TextStyle(
                fontSize: 11,
                color: tierColor.withValues(alpha: discovered ? 1 : 0.55),
              ),
            ),
          ),
          Text(
            discovered
                ? l10n.codexUsage(stats!.uses, stats!.puzzles)
                : l10n.codexUndiscovered,
            style: TextStyle(
              fontSize: 12,
              color: discovered ? muted : muted.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
