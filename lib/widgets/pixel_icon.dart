import 'package:flutter/widgets.dart';

/// Pixel-art icon set backed by the Pixel Icon Library font (HackerNoon,
/// CC BY 4.0 — https://pixeliconlibrary.com). Each entry is an [IconData]
/// pointing at a glyph in the bundled `PixelIcon` font, so they render through
/// the standard [Icon] widget just like `Icons.*`.
///
/// Names mirror the app's semantic use; the comment on each line records the
/// source glyph (`hn hn-<name>`, solid variant) it maps to.
abstract final class PixelIcons {
  static const _family = 'PixelIcon';

  static const barChart = IconData(0xf283, fontFamily: _family); // chart-line
  static const qrCode = IconData(0xf2c7, fontFamily: _family); // grid
  static const person = IconData(0xf33a, fontFamily: _family); // user
  static const settings = IconData(0xf294, fontFamily: _family); // cog
  static const gameController = IconData(0xf142, fontFamily: _family); // gaming
  static const calendar = IconData(0xf27c, fontFamily: _family); // calendar-alt
  static const star = IconData(0xf31f, fontFamily: _family); // star
  static const share = IconData(0xf311, fontFamily: _family); // share
  static const trophy = IconData(0xf330, fontFamily: _family); // trophy
  static const sadFace = IconData(0xf2b8, fontFamily: _family); // face-sad
  static const group = IconData(0xf33c, fontFamily: _family); // users
  static const medal = IconData(0xf29f, fontFamily: _family); // crown
  static const leaderboard =
      IconData(0xf2ea, fontFamily: _family); // numbered-list
  static const edit = IconData(0xf2a7, fontFamily: _family); // edit
  static const editNote = IconData(0xf2e9, fontFamily: _family); // notebook
  static const pause = IconData(0xf2f2, fontFamily: _family); // pause
  static const play = IconData(0xf2fd, fontFamily: _family); // play
  static const ad = IconData(0xf24b, fontFamily: _family); // ad
  static const refresh = IconData(0xf308, fontFamily: _family); // refresh
  static const lightbulb = IconData(0xf2d8, fontFamily: _family); // lightbulb
  static const copy = IconData(0xf29d, fontFamily: _family); // copy
  static const undo =
      IconData(0xf25b, fontFamily: _family); // arrow-circle-left
  static const backspace = IconData(0xf278, fontFamily: _family); // broom
  static const magicWand = IconData(0xf31b, fontFamily: _family); // sparkles
  static const shield =
      IconData(0xf13e, fontFamily: _family); // cybersecurity
  static const document = IconData(0xf26d, fontFamily: _family); // book
  static const timelapse = IconData(0xf28d, fontFamily: _family); // clock
  static const checkCircle =
      IconData(0xf286, fontFamily: _family); // check-circle
  static const arrowBack = IconData(0xf25f, fontFamily: _family); // arrow-left
  static const check = IconData(0xf288, fontFamily: _family); // check
  static const close = IconData(0xf32a, fontFamily: _family); // times
  static const chevronLeft = IconData(0xf252, fontFamily: _family); // angle-left
  static const chevronRight =
      IconData(0xf253, fontFamily: _family); // angle-right
  static const creativeCommons =
      IconData(0xf10c, fontFamily: _family); // creative-commons
}
