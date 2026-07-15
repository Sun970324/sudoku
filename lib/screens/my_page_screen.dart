import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/tier.dart';
import '../models/user_profile.dart';
import '../state/auth_controller.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _usernameController = TextEditingController();
  bool _editingUsername = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myPageTitle)),
      body: AnimatedBuilder(
        animation: widget.auth,
        builder: (context, _) {
          final profile = widget.auth.profile;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.auth.errorMessage != null) ...[
                Text(
                  l10n.errorOccurred(widget.auth.errorMessage!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              if (profile == null)
                _SignInSection(auth: widget.auth)
              else
                _ProfileSection(
                  auth: widget.auth,
                  profile: profile,
                  editing: _editingUsername,
                  usernameController: _usernameController,
                  onEditPressed: () {
                    _usernameController.text = profile.username;
                    setState(() => _editingUsername = true);
                  },
                  onSavePressed: () async {
                    await widget.auth.updateUsername(_usernameController.text);
                    if (!mounted) return;
                    setState(() => _editingUsername = false);
                  },
                  onCancelPressed: () =>
                      setState(() => _editingUsername = false),
                ),
              if (widget.auth.isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SignInSection extends StatelessWidget {
  const _SignInSection({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.signInPromptTitle, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: auth.signInWithGoogle,
          child: Text(l10n.signInWithGoogle),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: auth.signInWithApple,
          child: Text(l10n.signInWithApple),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: auth.signInAnonymously,
          child: Text(l10n.signInAsGuest),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.auth,
    required this.profile,
    required this.editing,
    required this.usernameController,
    required this.onEditPressed,
    required this.onSavePressed,
    required this.onCancelPressed,
  });

  final AuthController auth;
  final UserProfile profile;
  final bool editing;
  final TextEditingController usernameController;
  final VoidCallback onEditPressed;
  final VoidCallback onSavePressed;
  final VoidCallback onCancelPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (editing)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: usernameController,
                  autofocus: true,
                  maxLength: 20,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: onSavePressed,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancelPressed,
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(profile.username,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEditPressed,
              ),
            ],
          ),
        const SizedBox(height: 8),
        Center(
          child: Chip(
            label: Text(profile.tier.label(context)),
            backgroundColor: profile.tier
                .color(Theme.of(context).brightness == Brightness.dark)
                .withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: profile.tier
                  .color(Theme.of(context).brightness == Brightness.dark),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.ratingAndRecord(profile.rating, profile.wins, profile.losses),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.winRateLabel(profile.wins + profile.losses == 0
              ? 0
              : profile.wins * 100 ~/ (profile.wins + profile.losses)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (auth.isAnonymous) ...[
          Text(l10n.linkAccountPrompt, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: auth.linkGoogle,
            child: Text(l10n.linkGoogleAction),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: auth.linkApple,
            child: Text(l10n.linkAppleAction),
          ),
          const SizedBox(height: 24),
        ],
        OutlinedButton(
          onPressed: auth.signOut,
          child: Text(l10n.signOutAction),
        ),
      ],
    );
  }
}
