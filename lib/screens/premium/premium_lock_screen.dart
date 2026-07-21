import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/tier.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pixel_icon.dart';

/// The premium upsell shown where a premium-only feature is gated.
/// [description] is the feature-specific pitch (replay, favorites, ...) so each
/// entry point reads in context. Used inline as a body ([PremiumLockView]) or
/// as a full page ([PremiumLockScreen]).
class PremiumLockView extends StatelessWidget {
  const PremiumLockView({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = AppPalette.tierColor(Tier.gold, AppPalette.isDark(context));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PixelIcons.star, size: 56, color: color),
            const SizedBox(height: 20),
            Text(
              l10n.premiumLockTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumLockScreen extends StatelessWidget {
  const PremiumLockScreen({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(
          leading: const PixelBackButton(), title: Text(l10n.premiumTitle)),
      body: PremiumLockView(description: description),
    );
  }
}
