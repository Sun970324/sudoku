import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The app's chunky rounded card. Light mode gets a white face with a soft
/// violet shadow; dark mode swaps the (invisible-on-dark) shadow for a
/// lifted surface plus a tinted border glow.
class PopCard extends StatelessWidget {
  const PopCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// Optional accent: tints the border glow (dark) and adds a whisper of
  /// the color to the face (light).
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final surface = AppPalette.cardSurface(isDark);
    final tint = this.tint;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint == null || isDark
            ? surface
            : Color.alphaBlend(tint.withValues(alpha: 0.04), surface),
        borderRadius: BorderRadius.circular(AppDims.cardRadius),
        border: isDark
            ? Border.all(
                color: (tint ?? Colors.white).withValues(alpha: 0.25),
                width: 1.5,
              )
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppPalette.cardShadow(isDark),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
  }
}
