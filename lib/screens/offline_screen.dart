import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/connectivity_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/pixel_back_button.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/pop_button.dart';
import '../widgets/pop_card.dart';

/// Guards a server-only action: returns true (proceed) when online, otherwise
/// routes to the [OfflineScreen] and returns false so the caller aborts.
/// The connectivity check is the interface-level pre-empt; a request that
/// still fails on a flaky link is handled at the call site (failure fallback).
Future<bool> ensureOnline(BuildContext context) async {
  if (ConnectivityService.instance.isOnline) return true;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const OfflineScreen()),
  );
  return false;
}

/// Full-screen "no internet" notice reached when a server-only action is
/// attempted offline. Reassures the player by listing what still works without
/// a connection, and offers a retry that returns them once they reconnect.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    return GradientScaffold(
      appBar: AppBar(leading: const PixelBackButton()),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 64, color: primary.withValues(alpha: 0.7)),
                const SizedBox(height: 20),
                Text(
                  l10n.offlineTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Mulmaru', fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.offlineBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                PopCard(
                  tint: primary,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.offlineAvailableTitle,
                        style: TextStyle(
                            fontFamily: 'Mulmaru', fontSize: 16, color: primary),
                      ),
                      const SizedBox(height: 12),
                      _AvailableRow(
                          icon: PixelIcons.gameController,
                          text: l10n.offlineAvailablePlay),
                      _AvailableRow(
                          icon: PixelIcons.refresh,
                          text: l10n.offlineAvailableResume),
                      _AvailableRow(
                          icon: PixelIcons.barChart,
                          text: l10n.offlineAvailableStats),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PopButton(
                  onPressed: () {
                    if (ConnectivityService.instance.isOnline) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.offlineStillDisconnected)),
                      );
                    }
                  },
                  label: l10n.offlineRetry,
                  icon: PixelIcons.refresh,
                  expanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailableRow extends StatelessWidget {
  const _AvailableRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
