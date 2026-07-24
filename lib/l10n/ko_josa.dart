/// Resolves the Korean particle markers used in `app_ko.arb` hint strings.
///
/// A template can't know whether an interpolated value ends in a final
/// consonant (받침) — "3" reads 삼 and takes 은/이/을, "2" reads 이 and takes
/// 는/가/를 — so the Korean strings write the composite marker instead
/// ("{digit}이(가) 들어갈...") and every hint text is passed through
/// [applyKoJosa] right before display. The marker is replaced by the correct
/// particle for the character in front of it:
///
///  * Hangul syllables by their actual 받침 (행 → 은, 자리 → 는), with the
///    ㄹ-받침 exception for (으)로 (열로, not 열으로);
///  * digits by the 받침 of their Sino-Korean reading (1 일, 2 이, 3 삼, ...);
///  * a parenthetical aside is skipped entirely — a particle attaches to the
///    word before the parenthesis, so "박스 3 (1~3행, 1~3열)이(가)" is judged
///    by the 3, not by 열 or ")".
///
/// English strings contain no markers and pass through unchanged.
String applyKoJosa(String text) =>
    text.replaceAllMapped(_markerPattern, (match) {
      final marker = match.group(0)!;
      final (withJong, withoutJong) = _markers[marker]!;
      final (hasJong, isRieul) = _finalConsonantBefore(text, match.start);
      if (marker == '(으)로' && isRieul) return withoutJong;
      return hasJong ? withJong : withoutJong;
    });

/// Composite marker -> (받침 form, 받침-less form). Longer markers first in
/// the pattern so `(이)라면` never half-matches as `(이)면`.
const _markers = <String, (String, String)>{
  '은(는)': ('은', '는'),
  '이(가)': ('이', '가'),
  '을(를)': ('을', '를'),
  '과(와)': ('과', '와'),
  '(으)로': ('으로', '로'),
  '(이)라면': ('이라면', '라면'),
  '(이)어야': ('이어야', '여야'),
  '(이)에요': ('이에요', '예요'),
  '(이)거나': ('이거나', '거나'),
  '(이)면': ('이면', '면'),
};

final _markerPattern = RegExp(
  (_markers.keys.toList()..sort((a, b) => b.length - a.length))
      .map(RegExp.escape)
      .join('|'),
);

/// Final consonant of the Sino-Korean reading of each digit — whether it has
/// one, and whether that one is ㄹ (which drops the 으 of (으)로).
const _digitFinals = <String, (bool, bool)>{
  '0': (true, false), // 영
  '1': (true, true), // 일
  '2': (false, false), // 이
  '3': (true, false), // 삼
  '4': (false, false), // 사
  '5': (false, false), // 오
  '6': (true, false), // 육
  '7': (true, true), // 칠
  '8': (true, true), // 팔
  '9': (false, false), // 구
};

/// `(has final consonant, that consonant is ㄹ)` for the last "sounding"
/// character before [index] — quotes are skipped, and a parenthesized aside
/// is skipped as a whole (back to before its matching opener).
(bool, bool) _finalConsonantBefore(String text, int index) {
  var i = index - 1;
  while (i >= 0) {
    final ch = text[i];
    if ('\'"”’'.contains(ch)) {
      i--;
    } else if (ch == ')') {
      var depth = 1;
      i--;
      while (i >= 0 && depth > 0) {
        if (text[i] == ')') depth++;
        if (text[i] == '(') depth--;
        i--;
      }
    } else if (ch == ' ') {
      // Only the space padding an aside ("박스 3 (...)"), reached after
      // skipping one — a marker never follows a bare space otherwise.
      i--;
    } else {
      break;
    }
  }
  if (i < 0) return (false, false);
  final ch = text[i];
  final code = ch.codeUnitAt(0);
  if (code >= 0xAC00 && code <= 0xD7A3) {
    final jong = (code - 0xAC00) % 28;
    return (jong != 0, jong == 8);
  }
  return _digitFinals[ch] ?? (false, false);
}
