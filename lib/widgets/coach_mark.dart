import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_palette.dart';
import 'pop_card.dart';

// Re-exported so callers can position steps without importing the package.
export 'package:tutorial_coach_mark/tutorial_coach_mark.dart'
    show ContentAlign, ShapeLightFocus;

/// One step of a first-entry coach-mark: spotlights the widget behind
/// [targetKey] and shows a titled explanation card next to it.
class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.shape = ShapeLightFocus.RRect,
    this.align = ContentAlign.bottom,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final ShapeLightFocus shape;

  /// Where the explanation card sits relative to the highlighted target.
  final ContentAlign align;
}

/// Runs a spotlight walkthrough over real UI elements. Shared by every
/// first-entry tutorial (home / game / race) so they look and behave the
/// same. [onDone] fires once, whether the user finishes or skips — the
/// caller uses it to persist the "seen" flag. [onSkip], when given, fires
/// *instead of* [onDone] on skip, so a caller can distinguish "skipped" from
/// "finished" (e.g. to also suppress a chained follow-up tutorial).
void showCoachMark(
  BuildContext context, {
  required List<CoachMarkStep> steps,
  VoidCallback? onDone,
  VoidCallback? onSkip,
}) {
  final l10n = AppLocalizations.of(context)!;
  var done = false;
  void finish({bool skipped = false}) {
    if (done) return;
    done = true;
    if (skipped && onSkip != null) {
      onSkip();
    } else {
      onDone?.call();
    }
  }

  final targets = [
    for (var i = 0; i < steps.length; i++)
      TargetFocus(
        identify: 'step_$i',
        keyTarget: steps[i].targetKey,
        shape: steps[i].shape,
        radius: 12,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: steps[i].align,
            builder: (context, controller) => _CoachCard(
              l10n: l10n,
              title: steps[i].title,
              body: steps[i].body,
              isLast: i == steps.length - 1,
              onNext: controller.next,
              onSkip: controller.skip,
            ),
          ),
        ],
      ),
  ];

  TutorialCoachMark(
    targets: targets,
    hideSkip: true,
    colorShadow: Colors.black,
    opacityShadow: 0.82,
    onFinish: finish,
    onSkip: () {
      finish(skipped: true);
      return true;
    },
  ).show(context: context);
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.l10n,
    required this.title,
    required this.body,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final AppLocalizations l10n;
  final String title;
  final String body;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: PopCard(
        tint: primary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Mulmaru',
                fontSize: 18,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppPalette.isDark(context)
                    ? Colors.white70
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isLast)
                  TextButton(
                    onPressed: onSkip,
                    child: Text(l10n.tutorialSkip),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: onNext,
                  child: Text(isLast ? l10n.tutorialDone : l10n.tutorialNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
