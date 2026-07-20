import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/auth_controller.dart';
import '../theme/app_palette.dart';
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
          GoogleAuthButton(
            onPressed: auth.signInWithGoogle,
            label: l10n.signInWithGoogle,
          ),
          const SizedBox(height: 12),
          AppleAuthButton(
            onPressed: auth.signInWithApple,
            label: l10n.signInWithApple,
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

/// Shared full-width scaffold so the provider buttons keep identical height,
/// radius and typography — the branding guidelines both ask that third-party
/// sign-in options sit at visual parity.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.border,
    required this.logo,
    required this.label,
  });

  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final BorderSide? border;
  final Widget logo;
  final String label;

  // Height and radius are shared across providers; SF Pro (iOS) / Roboto
  // (Android) come from the platform default font — deliberately not Mulmaru,
  // since both providers mandate their own system typeface.
  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDims.buttonRadius),
          side: border ?? BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              logo,
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Google-branded auth button, reused for both sign-in and account linking —
/// [label] carries the action wording. Per Google's branding guidelines:
/// white/dark neutral fill with a 1px border and the unaltered 4-colour "G".
/// https://developers.google.com/identity/branding-guidelines
class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    return _ProviderButton(
      onPressed: onPressed,
      background: isDark ? const Color(0xFF131314) : const Color(0xFFFFFFFF),
      foreground: isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
      border: BorderSide(
        color: isDark ? const Color(0xFF8E918F) : const Color(0xFF747775),
      ),
      // The "G" is never recoloured, so no colorFilter.
      logo: SvgPicture.asset('assets/images/google_logo.svg',
          width: 20, height: 20),
      label: label,
    );
  }
}

/// Apple-branded auth button, reused for both sign-in and account linking —
/// [label] carries the action wording. Per Apple's HIG: solid black on light
/// grounds, white on dark grounds, with the monochrome Apple mark.
/// https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
class AppleAuthButton extends StatelessWidget {
  const AppleAuthButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final fg = isDark ? Colors.black : Colors.white;
    return _ProviderButton(
      onPressed: onPressed,
      background: isDark ? Colors.white : Colors.black,
      foreground: fg,
      border: null,
      logo: SvgPicture.asset(
        'assets/images/apple_logo.svg',
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
      ),
      label: label,
    );
  }
}
