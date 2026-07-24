import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/tier.dart';
import '../../state/premium_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pixel_icon.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';

/// Which billing plan the user has highlighted on the premium page. Display
/// only for now — the mock purchase ignores it; real IAP maps each to its
/// store product.
enum _PremiumPlan { lifetime, monthly }

/// The premium intro & pricing page, shown wherever a premium-only feature is
/// gated: full feature rundown, plan cards, and the purchase CTA (mock while
/// billing isn't wired — debug builds activate the mock entitlement, release
/// builds explain purchases aren't live yet). [description] is the
/// feature-specific hook (replay, favorites, ...) so each entry point opens in
/// context. Used inline as a body ([PremiumLockView]) or as a full page
/// ([PremiumLockScreen]).
class PremiumLockView extends StatefulWidget {
  const PremiumLockView({
    super.key,
    required this.description,
    this.popOnPurchase = false,
  });

  final String description;

  /// Pop the enclosing route once the (mock) purchase activates — used by the
  /// pushed [PremiumLockScreen], which has nothing else to show once premium
  /// is on. Inline bodies (replay list / favorites) leave this false: their
  /// screens listen to [PremiumController] and swap to the unlocked content
  /// in place.
  final bool popOnPurchase;

  @override
  State<PremiumLockView> createState() => _PremiumLockViewState();
}

class _PremiumLockViewState extends State<PremiumLockView> {
  _PremiumPlan _plan = _PremiumPlan.lifetime;

  Future<void> _onPurchasePressed() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (kDebugMode) {
      // Mock purchase: flips the same entitlement the debug settings toggle
      // uses. Real IAP replaces this with PurchaseService.buy(plan).
      await PremiumController.instance.setMockPremium(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.premiumMockDone)));
      if (widget.popOnPurchase && mounted) Navigator.pop(context);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.premiumComingSoon)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    final gold = AppPalette.tierColor(Tier.gold, isDark);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(PixelIcons.star, size: 56, color: gold),
        const SizedBox(height: 16),
        Text(
          l10n.premiumIntroTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        PopCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _BenefitRow(
                icon: PixelIcons.lightbulb,
                title: l10n.premiumBenefitAssistTitle,
                description: l10n.premiumBenefitAssistBody,
              ),
              _BenefitRow(
                icon: PixelIcons.play,
                title: l10n.premiumBenefitReplayTitle,
                description: l10n.premiumBenefitReplayBody,
              ),
              _BenefitRow(
                icon: PixelIcons.star,
                title: l10n.premiumBenefitFavoriteTitle,
                description: l10n.premiumBenefitFavoriteBody,
              ),
              _BenefitRow(
                icon: PixelIcons.magicWand,
                title: l10n.premiumBenefitThemeTitle,
                description: l10n.premiumBenefitThemeBody,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                name: l10n.premiumPlanLifetime,
                price: l10n.premiumPlanLifetimePrice,
                detail: l10n.premiumPlanLifetimeDetail,
                selected: _plan == _PremiumPlan.lifetime,
                accent: gold,
                onTap: () => setState(() => _plan = _PremiumPlan.lifetime),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                name: l10n.premiumPlanMonthly,
                price: l10n.premiumPlanMonthlyPrice,
                detail: l10n.premiumPlanMonthlyDetail,
                selected: _plan == _PremiumPlan.monthly,
                accent: gold,
                onTap: () => setState(() => _plan = _PremiumPlan.monthly),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PopButton(
          onPressed: _onPurchasePressed,
          label: l10n.premiumCtaStart,
          icon: PixelIcons.star,
          expanded: true,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.premiumComingSoon,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(fontFamily: 'Mulmaru', fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.detail,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String name;
  final String price;
  final String detail;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDims.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.cardSurface(AppPalette.isDark(context)),
          borderRadius: BorderRadius.circular(AppDims.cardRadius),
          border: Border.all(
            color: selected ? accent : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(name, style: const TextStyle(fontFamily: 'Mulmaru')),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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
      body: PremiumLockView(description: description, popOnPurchase: true),
    );
  }
}
