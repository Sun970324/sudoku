import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// Confetti burst over a result screen. Plays once on mount and is
/// duration-bound (no loop), so `pumpAndSettle` in tests still terminates;
/// [play] exists so tests (or a lost race) can disable it outright.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.child,
    this.play = true,
    this.big = false,
  });

  final Widget child;
  final bool play;

  /// A bigger burst for standout results (perfect clear, race win).
  final bool big;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late final ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        ConfettiController(duration: const Duration(milliseconds: 1200));
    if (widget.play) _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.06,
              // Capped particle counts so low-end devices don't stutter.
              numberOfParticles: widget.big ? 40 : 25,
              maxBlastForce: 24,
              minBlastForce: 8,
              gravity: 0.25,
              colors: const [
                Color(0xFF6E56FF),
                Color(0xFFFF6B6B),
                Color(0xFF14B8A6),
                Color(0xFFFFD24A),
                Color(0xFF7DB8FF),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
