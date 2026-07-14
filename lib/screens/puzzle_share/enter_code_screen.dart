import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/puzzle_share_service.dart';

class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _service = PuzzleShareService();
  final _textCodeController = TextEditingController();
  String? _errorMessage;

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
      setState(() => _errorMessage = l10n.invalidTextCodeError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.enterCodeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCodeController,
                  decoration: InputDecoration(hintText: l10n.enterTextCodeHint),
                ),
              ),
              FilledButton(
                onPressed: _loadTextCode,
                child: Text(l10n.loadButton),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
