import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/puzzle_queue_manager.dart';
import '../../services/puzzle_share_service.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';
import '../race/friend_room_screen.dart';

/// One input for both kinds of code a player might receive: a 6-char friend
/// room code (joins a private race) or a longer puzzle share code (loads the
/// puzzle to play solo). They can't collide — a room code is exactly 6 chars
/// from a fixed uppercase alphabet, a share code is a much longer base62
/// string — so which one was pasted is detected automatically.
class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({
    super.key,
    required this.auth,
    required this.puzzleQueue,
  });

  final AuthController auth;
  final PuzzleQueueManager puzzleQueue;

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _service = PuzzleShareService();
  final _textCodeController = TextEditingController();
  String? _errorMessage;

  /// Bumped on every failed decode so the error shake replays each time.
  int _errorShakeTick = 0;

  /// A friend room code: exactly 6 chars from the room-code alphabet
  /// (0/O/1/I/L excluded — see create_private_room). Matched case-
  /// insensitively since codes are stored uppercase server-side.
  static final _roomCodePattern = RegExp(r'^[2-9A-HJKMNP-Z]{6}$');

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _errorShakeTick++;
    });
  }

  void _submit() {
    setState(() => _errorMessage = null);
    final raw = _textCodeController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (_roomCodePattern.hasMatch(raw.toUpperCase())) {
      if (!widget.auth.isSignedIn) {
        _showError(l10n.roomJoinRequiresSignIn);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FriendRoomScreen.join(
            puzzleQueue: widget.puzzleQueue,
            code: raw.toUpperCase(),
          ),
        ),
      );
      return;
    }

    // Not a room code — treat as a puzzle share code. Case is significant
    // here (base62), so decode the raw trimmed text, not the uppercased one.
    try {
      final puzzle = _service.decodeText(raw);
      Navigator.pop(context, puzzle);
    } on PuzzleShareException {
      _showError(l10n.invalidTextCodeError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientScaffold(
      appBar: AppBar(title: Text(l10n.enterCodeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PopCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Animate(
                  key: ValueKey(_errorShakeTick),
                  effects: _errorShakeTick == 0
                      ? const []
                      : [const ShakeEffect(hz: 5, duration: Duration(milliseconds: 350))],
                  child: TextField(
                    controller: _textCodeController,
                    decoration: InputDecoration(
                      hintText: l10n.enterTextCodeHint,
                      hintStyle: const TextStyle(fontFamily: 'Mulmaru'),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDims.fieldRadius),
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                PopButton(
                  onPressed: _submit,
                  label: l10n.loadButton,
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
