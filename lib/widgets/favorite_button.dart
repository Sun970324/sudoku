import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/sudoku_puzzle.dart';
import '../models/tier.dart';
import '../screens/premium/premium_lock_screen.dart';
import '../services/storage_service.dart';
import '../state/premium_controller.dart';
import '../theme/app_palette.dart';
import 'pixel_icon.dart';

/// A star toggle that saves/removes [puzzle] from favorites (premium-only).
/// Free users tapping it land on the upsell page instead. Reused in the game
/// AppBar and the result screen — both hold the played puzzle.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.puzzle,
    this.onPause,
    this.onResume,
  });

  final SudokuPuzzle puzzle;

  /// Bracket the free-user upsell navigation: [onPause] fires before pushing
  /// the lock screen, [onResume] once it's popped — so the game screen can
  /// halt its timer while the upsell is up. No-ops where unset (e.g. the
  /// result screen, which has no running clock).
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final StorageService _storage = StorageService();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final saved = await _storage.isFavorite(widget.puzzle);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _onPressed() async {
    final l10n = AppLocalizations.of(context)!;
    if (!PremiumController.instance.isPremium) {
      widget.onPause?.call();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PremiumLockScreen(description: l10n.favoritePremiumBody),
        ),
      );
      widget.onResume?.call();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (_saved) {
      await _storage.removeFavorite(widget.puzzle);
      if (!mounted) return;
      setState(() => _saved = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.favoriteRemoved)));
    } else {
      final ok = await _storage.saveFavorite(widget.puzzle);
      if (!mounted) return;
      if (ok) {
        setState(() => _saved = true);
        messenger.showSnackBar(SnackBar(content: Text(l10n.favoriteSaved)));
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.favoriteFull(StorageService.maxFavorites))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppPalette.tierColor(Tier.gold, AppPalette.isDark(context));
    return IconButton(
      icon: Icon(
        PixelIcons.star,
        color: _saved ? gold : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: AppLocalizations.of(context)!.favoritesTitle,
      onPressed: _onPressed,
    );
  }
}
