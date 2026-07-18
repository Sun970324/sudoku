import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/auth_controller.dart';
import 'pop_button.dart';

/// The sign-in gate shown by features that need an account (guest included)
/// before proceeding — matchmaking, the daily puzzle. [title] carries the
/// feature-specific pitch line; the three sign-in buttons are shared.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.auth, required this.title});

  final AuthController auth;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          PopButton(
            onPressed: auth.signInWithGoogle,
            label: l10n.signInWithGoogle,
            expanded: true,
          ),
          const SizedBox(height: 16),
          PopButton(
            onPressed: auth.signInWithApple,
            label: l10n.signInWithApple,
            expanded: true,
          ),
          const SizedBox(height: 16),
          PopButton(
            onPressed: auth.signInAnonymously,
            label: l10n.signInAsGuest,
            variant: PopButtonVariant.outline,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
