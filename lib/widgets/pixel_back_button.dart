import 'package:flutter/material.dart';

import 'pixel_icon.dart';

/// App-styled replacement for Flutter's default [BackButton] — same
/// [Navigator.maybePop] behavior and tooltip, but with the pixel-art arrow
/// glyph instead of the platform-default icon.
class PixelBackButton extends StatelessWidget {
  const PixelBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(PixelIcons.arrowBack),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.maybePop(context),
    );
  }
}
