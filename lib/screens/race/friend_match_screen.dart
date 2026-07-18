import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/difficulty.dart';
import '../../models/tier.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';
import 'friend_room_screen.dart';

/// The friend-match branch point: create a room (pick a difficulty, get a
/// code) or join one (enter a friend's code). Reached only through
/// RaceLobbyScreen, so a signed-in user can be assumed.
class FriendMatchScreen extends StatefulWidget {
  const FriendMatchScreen({
    super.key,
    required this.auth,
    required this.puzzleQueue,
  });

  final AuthController auth;
  final PuzzleQueueManager puzzleQueue;

  @override
  State<FriendMatchScreen> createState() => _FriendMatchScreenState();
}

class _FriendMatchScreenState extends State<FriendMatchScreen> {
  static const _codeLength = 6;

  late Difficulty _difficulty;
  final _codeController = TextEditingController();
  bool _codeComplete = false;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.auth.profile?.tier.raceDifficulty ?? Difficulty.medium;
    _codeController.addListener(() {
      final complete = _codeController.text.length == _codeLength;
      if (complete != _codeComplete) setState(() => _codeComplete = complete);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _createRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendRoomScreen.host(
          puzzleQueue: widget.puzzleQueue,
          difficulty: _difficulty,
        ),
      ),
    );
  }

  void _joinRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendRoomScreen.join(
          puzzleQueue: widget.puzzleQueue,
          code: _codeController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    return GradientScaffold(
      appBar: AppBar(title: Text(l10n.friendMatchTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PopCard(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.createRoomTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in Difficulty.values)
                        ChoiceChip(
                          label: Text(d.label(context)),
                          selected: _difficulty == d,
                          onSelected: (_) => setState(() => _difficulty = d),
                          selectedColor: AppPalette.difficultyColor(d, isDark)
                              .withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: _difficulty == d
                                ? AppPalette.difficultyColor(d, isDark)
                                : null,
                            fontWeight: _difficulty == d
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: const StadiumBorder(),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PopButton(
                    onPressed: _createRoom,
                    label: l10n.createRoomAction,
                    expanded: true,
                  ),
                ],
              ),
          ),
          const SizedBox(height: 16),
          PopCard(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.joinRoomTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: l10n.roomCodeFieldLabel,
                      counterText: '',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDims.fieldRadius),
                      ),
                    ),
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: _codeLength,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 24,
                        letterSpacing: 8),
                    inputFormatters: [
                      // Codes are stored uppercase server-side; normalizing
                      // here too keeps what the player sees identical to
                      // what gets sent.
                      FilteringTextInputFormatter.allow(
                          RegExp('[a-zA-Z0-9]')),
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                            text: newValue.text.toUpperCase()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PopButton(
                    onPressed: _codeComplete ? _joinRoom : null,
                    label: l10n.joinRoomAction,
                    variant: PopButtonVariant.secondary,
                    color: AppPalette.dailyTeal,
                    expanded: true,
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }
}
