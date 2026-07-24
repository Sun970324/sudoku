import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../models/favorite_puzzle.dart';
import '../../models/tier.dart';
import '../../services/storage_service.dart';
import '../../state/premium_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pixel_back_button.dart';
import '../../widgets/pixel_icon.dart';
import '../../widgets/pop_card.dart';
import '../game_screen.dart';
import '../premium/premium_lock_screen.dart';

/// The player's saved puzzles (premium-only). Tapping one starts it fresh; the
/// star removes it. Free users see the upsell instead of the list.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final StorageService _storage = StorageService();
  late Future<List<FavoritePuzzle>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = _storage.loadFavorites();
  }

  void _reload() => setState(() => _favorites = _storage.loadFavorites());

  Future<void> _remove(FavoritePuzzle favorite) async {
    await _storage.removeFavorite(favorite.puzzle);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(
        leading: const PixelBackButton(),
        title: Text(l10n.favoritesTitle),
      ),
      body: AnimatedBuilder(
        animation: PremiumController.instance,
        builder: (context, _) {
          if (!PremiumController.instance.isPremium) {
            return PremiumLockView(description: l10n.favoritePremiumBody);
          }
          return FutureBuilder<List<FavoritePuzzle>>(
            future: _favorites,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final favorites = snapshot.data!;
              if (favorites.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.favoritesEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favorites.length,
                itemBuilder: (context, i) => _FavoriteCard(
                  favorite: favorites[i],
                  onRemove: () => _remove(favorites[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.favorite, required this.onRemove});

  final FavoritePuzzle favorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final accent = AppPalette.difficultyColor(favorite.puzzle.difficulty, isDark);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMd(locale).format(favorite.savedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PopCard(
        tint: accent,
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDims.cardRadius),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GameScreen.newGame(
                  difficulty: favorite.puzzle.difficulty,
                  puzzle: favorite.puzzle,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          favorite.puzzle.difficulty.label(context),
                          style: TextStyle(
                              fontFamily: 'Mulmaru', fontSize: 17, color: accent),
                        ),
                        Text(date,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(PixelIcons.star,
                        color: AppPalette.tierColor(Tier.gold, isDark)),
                    onPressed: onRemove,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
