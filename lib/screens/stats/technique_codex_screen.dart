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
/// knows, grouped by difficulty tier, with how often each has appeared in
/// puzzles the player solved — fed by StorageService.recordTechniqueCounts on
/// solo wins. Undiscovered techniques stay dimmed until first encountered.
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
              for (final tier in Difficulty.values)
                ..._tierSection(context, l10n, isDark, tier, codex),
            ],
          );
        },
      ),
    );
  }

  /// One tier's card (header + technique rows), or nothing if no technique
  /// maps to [tier].
  List<Widget> _tierSection(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    Difficulty tier,
    Map<HintTechnique, ({int uses, int puzzles})> codex,
  ) {
    final techniques = humanSolverTechniqueOrder
        .where((t) => techniqueDifficulty[t] == tier)
        .toList();
    if (techniques.isEmpty) return const [];
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
            const SizedBox(height: 8),
            for (final technique in techniques)
              _TechniqueRow(
                technique: technique,
                stats: codex[technique],
                accent: accent,
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
    required this.accent,
  });

  final HintTechnique technique;

  /// Null until the technique first appears in a solved puzzle.
  final ({int uses, int puzzles})? stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final discovered = stats != null;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            discovered ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: discovered ? accent : muted.withValues(alpha: 0.4),
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
