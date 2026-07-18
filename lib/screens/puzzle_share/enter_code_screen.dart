import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/puzzle_share_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/pop_button.dart';
import '../../widgets/pop_card.dart';

class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _service = PuzzleShareService();
  final _textCodeController = TextEditingController();
  String? _errorMessage;

  /// Bumped on every failed decode so the error shake replays each time.
  int _errorShakeTick = 0;

  @override
  void dispose() {
    _textCodeController.dispose();
    super.dispose();
  }

  void _loadTextCode() {
    setState(() => _errorMessage = null);
    try {
      final puzzle = _service.decodeText(_textCodeController.text.trim());
      Navigator.pop(context, puzzle);
    } on PuzzleShareException {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.invalidTextCodeError;
        _errorShakeTick++;
      });
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
                  onPressed: _loadTextCode,
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
