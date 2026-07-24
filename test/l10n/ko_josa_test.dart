import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/l10n/ko_josa.dart';

void main() {
  test('digits pick the particle of their Sino-Korean reading', () {
    // 3 삼 (받침) / 2 이 (모음).
    expect(applyKoJosa('3은(는)'), '3은');
    expect(applyKoJosa('2은(는)'), '2는');
    expect(applyKoJosa('4이(가) 됩니다'), '4가 됩니다');
    expect(applyKoJosa('6이(가) 됩니다'), '6이 됩니다');
    expect(applyKoJosa('9을(를) 지울'), '9를 지울');
    expect(applyKoJosa('8을(를) 지울'), '8을 지울');
    expect(applyKoJosa('5과(와) 7'), '5와 7');
    expect(applyKoJosa('3과(와) 7'), '3과 7');
  });

  test('(으)로 keeps 로 after ㄹ-final digits (1, 7, 8)', () {
    expect(applyKoJosa('1(으)로'), '1로');
    expect(applyKoJosa('7(으)로'), '7로');
    expect(applyKoJosa('3(으)로'), '3으로');
    expect(applyKoJosa('2(으)로'), '2로');
  });

  test('copula-style markers', () {
    expect(applyKoJosa('피벗이 4(이)라면'), '피벗이 4라면');
    expect(applyKoJosa('피벗이 3(이)라면'), '피벗이 3이라면');
    expect(applyKoJosa('한쪽이 2(이)면'), '한쪽이 2면');
    expect(applyKoJosa('한쪽이 6(이)면'), '한쪽이 6이면');
    expect(applyKoJosa('끝이 5(이)에요'), '끝이 5예요');
    expect(applyKoJosa('끝이 3(이)에요'), '끝이 3이에요');
    expect(applyKoJosa('4(이)거나'), '4거나');
    expect(applyKoJosa('반드시 2(이)어야'), '반드시 2여야');
    expect(applyKoJosa('반드시 3(이)어야'), '반드시 3이어야');
  });

  test('Hangul finals: 행/열 take the 받침 forms, ㄹ still gets 로', () {
    expect(applyKoJosa('4행은(는)'), '4행은');
    expect(applyKoJosa('5열을(를) 보세요'), '5열을 보세요');
    expect(applyKoJosa('3행4열이(가) 서로'), '3행4열이 서로');
    expect(applyKoJosa('사슬(으)로'), '사슬로');
  });

  test('a parenthetical aside is skipped — the particle follows the word '
      'before it', () {
    expect(applyKoJosa('박스 3 (1~3행, 1~3열)이(가) 겹치는'), '박스 3 (1~3행, 1~3열)이 겹치는');
    expect(applyKoJosa('박스 2 (1~3행, 4~6열)이(가) 겹치는'), '박스 2 (1~3행, 4~6열)가 겹치는');
  });

  test('multiple markers resolve independently; text without markers is '
      'untouched', () {
    expect(
      applyKoJosa('피벗이 4(이)라면 3행7열에서 4이(가) 빠져요 — 그럼 그 칸은 8이(가) 됩니다.'),
      '피벗이 4라면 3행7열에서 4가 빠져요 — 그럼 그 칸은 8이 됩니다.',
    );
    const english = 'If the pivot is 4, r3c7 loses 4 — so it must be 8.';
    expect(applyKoJosa(english), english);
    const plain = '숫자 3은 여기 못 옵니다.';
    expect(applyKoJosa(plain), plain);
  });

  test('a marker with nothing before it falls back to the vowel form', () {
    expect(applyKoJosa('은(는)'), '는');
  });
}
