import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/tier.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pixel_icon.dart';

/// The premium upsell shown where a premium-only feature is gated — used inline
/// as a body ([PremiumLockView]) or as a full page ([PremiumLockScreen]).
class PremiumLockView extends StatelessWidget {
  const PremiumLockView({super.key});

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
              l10n.replayPremiumTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.replayPremiumBody,
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
  const PremiumLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(
          leading: const PixelBackButton(), title: Text(l10n.replayTitle)),
      body: const PremiumLockView(),
    );
  }
}
