import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_palette.dart';

/// Looping "searching" indicator: two violet rings expanding and fading
/// around a steady core dot. Replaces the bare CircularProgressIndicator on
/// the matchmaking/friend-room waiting screens.
///
/// This loops forever — keep it OFF any screen covered by a `pumpAndSettle`
/// widget test (home/game); the waiting screens have none.
class PulseRing extends StatelessWidget {
  const PulseRing({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.primaryGradient(AppPalette.isDark(context)).last;

    Widget ring(int delayMs) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(0.4, 0.4),
              end: const Offset(1.0, 1.0),
              delay: delayMs.ms,
              duration: 1400.ms,
              curve: Curves.easeOut,
            )
            .fadeOut(delay: delayMs.ms, duration: 1400.ms);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(0),
          ring(700),
          Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}
