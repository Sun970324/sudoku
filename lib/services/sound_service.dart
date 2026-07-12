import 'package:audioplayers/audioplayers.dart';

/// Centralized sound effects, mirroring [HapticService]'s static
/// enable-gated pattern. Each sound gets its own [AudioPlayer] instance so
/// rapid, independent triggers (e.g. a click right after a wrong-answer
/// buzz) don't interrupt one another.
class SoundService {
  SoundService._();

  static bool enabled = true;

  static final AudioPlayer _clickPlayer = AudioPlayer();
  static final AudioPlayer _correctPlayer = AudioPlayer();
  static final AudioPlayer _wrongPlayer = AudioPlayer();

  /// Cell selection / note toggled on or off.
  static Future<void> click() => _play(_clickPlayer, 'sounds/click.ogg');

  /// Correct digit entered.
  static Future<void> correct() => _play(_correctPlayer, 'sounds/correct.ogg');

  /// Wrong digit entered, or a note was blocked by a conflict. The source
  /// clip is mastered noticeably louder than click/correct, which are
  /// already playing at max volume (1.0) — so this is toned down to match
  /// perceived loudness instead, since the others can't go any higher.
  static Future<void> wrong() =>
      _play(_wrongPlayer, 'sounds/wrong.ogg', volume: 0.3);

  static Future<void> _play(
    AudioPlayer player,
    String assetPath, {
    double volume = 1.0,
  }) async {
    if (!enabled) return;
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Missing asset / platform issue — a silent miss beats crashing the game.
    }
  }
}
