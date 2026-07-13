// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '스도쿠';

  @override
  String get homeButton => '홈으로';

  @override
  String get closeAction => '닫기';

  @override
  String get applyAction => '적용하기';

  @override
  String get continueAction => '계속하기';

  @override
  String get continueGame => '이어하기';

  @override
  String get startGame => '시작하기';

  @override
  String get viewStats => '기록 보기';

  @override
  String get themeSectionTitle => '테마';

  @override
  String get followSystemTheme => '시스템 설정 따르기';

  @override
  String get lightTheme => '라이트 모드';

  @override
  String get darkTheme => '다크 모드';

  @override
  String get hapticsLabel => '진동';

  @override
  String get soundLabel => '효과음';

  @override
  String get languageSectionTitle => '언어';

  @override
  String get followSystemLanguage => '시스템 설정 따르기';

  @override
  String get koreanLanguage => '한국어';

  @override
  String get englishLanguage => 'English';

  @override
  String mistakesLabel(int current, int max) {
    return '실수: $current/$max';
  }

  @override
  String get exitDialogTitle => '게임을 종료할까요?';

  @override
  String get restartAction => '다시 시작';

  @override
  String get endGameAction => '게임 끝내기';

  @override
  String get gameOverTitle => '실수 3회';

  @override
  String get gameOverContent => '광고를 보고 계속하시겠어요?';

  @override
  String get giveUpAction => '포기하고 나가기';

  @override
  String get noHintAvailable => '지금은 사용할 수 있는 힌트가 없어요.';

  @override
  String get clearWrongFirst => '오답을 먼저 지워주세요.';

  @override
  String get adNotLoaded => '광고를 아직 불러오지 못했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get resultTitle => '결과';

  @override
  String get perfectClearBadge => '노미스 완료! Perfect Clear';

  @override
  String mistakesAndHints(int mistakes, int hints) {
    return '실수 $mistakes회 · 힌트 사용 $hints회';
  }

  @override
  String get personalBestTitle => '개인 최고기록';

  @override
  String get firstClear => '이 난이도 첫 클리어예요!';

  @override
  String newBest(String time) {
    return '🏆 개인 최고기록 경신! (이전 $time)';
  }

  @override
  String currentBest(String time) {
    return '개인 최고기록: $time';
  }

  @override
  String get comparisonTitle => '글로벌 유저 비교';

  @override
  String topPercent(int percent) {
    return '상위 $percent%';
  }

  @override
  String get mockDataDisclaimer => '* 실제 유저 데이터가 아닌 예시입니다.';

  @override
  String get techniquesUsedTitle => '사용된 기법';

  @override
  String get highestTechniqueLabel => '최고 난이도 기법:';

  @override
  String techniqueUsageCount(int count) {
    return '$count회';
  }

  @override
  String get statsTitle => '기록';

  @override
  String playedWonLabel(int played, int won) {
    return '플레이 $played회 · 승리 $won회';
  }

  @override
  String bestTimeSuffix(String time) {
    return ' · 최고기록 $time';
  }

  @override
  String get undoLabel => '실행취소';

  @override
  String get eraseLabel => '지우기';

  @override
  String get noteLabel => '메모';

  @override
  String get autoFillLabel => '자동메모';

  @override
  String get hintLabel => '힌트';

  @override
  String get difficultyBeginner => '초보자';

  @override
  String get difficultyEasy => '쉬움';

  @override
  String get difficultyMedium => '보통';

  @override
  String get difficultyHard => '어려움';

  @override
  String get difficultyMaster => '마스터';

  @override
  String get difficultyExpert => '익스퍼트';

  @override
  String get techniqueFullHouse => '풀 하우스';

  @override
  String get techniqueNakedSingle => '네이키드 싱글';

  @override
  String get techniqueHiddenSingle => '히든 싱글';

  @override
  String get techniqueNakedPair => '네이키드 페어';

  @override
  String get techniqueNakedTriple => '네이키드 트리플';

  @override
  String get techniqueNakedQuad => '네이키드 쿼드';

  @override
  String get techniqueHiddenPair => '히든 페어';

  @override
  String get techniqueHiddenTriple => '히든 트리플';

  @override
  String get techniqueHiddenQuad => '히든 쿼드';

  @override
  String get techniqueIntersectionPointing => '교차로(포인팅)';

  @override
  String get techniqueIntersectionClaiming => '교차로(클레이밍)';

  @override
  String get techniqueXWing => 'X-윙';

  @override
  String get techniqueSimpleColoring => '심플 컬러링';

  @override
  String get techniqueXYWing => 'XY-윙';

  @override
  String get techniqueSwordfish => '스워드피쉬';

  @override
  String get techniqueFinnedXWing => '핀드 X-윙';

  @override
  String get techniqueSashimiXWing => '사시미 X-윙';

  @override
  String get techniqueBugPlusOne => 'BUG+1';

  @override
  String get techniqueXYChain => 'XY-사슬';

  @override
  String get techniqueJellyfish => '젤리피쉬';

  @override
  String get techniqueUniqueRectangleType1 => '유일사각형 Type 1';

  @override
  String get techniqueUniqueRectangleType2 => '유일사각형 Type 2';

  @override
  String get techniqueUniqueRectangleType3 => '유일사각형 Type 3';

  @override
  String get techniqueUniqueRectangleType4 => '유일사각형 Type 4';

  @override
  String unitRow(int row) {
    return '$row행';
  }

  @override
  String unitCol(int col) {
    return '$col열';
  }

  @override
  String unitCell(int row, int col) {
    return '$row행$col열';
  }

  @override
  String unitBox(int index, int r1, int r2, int c1, int c2) {
    return '박스 $index ($r1~$r2행, $c1~$c2열)';
  }

  @override
  String get wordRows => '행';

  @override
  String get wordColumns => '열';

  @override
  String explanationFullHouse(String unitDesc, int value) {
    return '$unitDesc에 빈 칸이 이 칸 하나만 남았어요. 1~9 중 아직 없는 숫자는 $value뿐이라 자동으로 정해집니다.';
  }

  @override
  String explanationNakedSingle(int row, int col, int value) {
    return '$row행 $col열은 후보 숫자가 $value 하나뿐이에요. 같은 행·열·박스에 나머지 숫자가 모두 있어서 $value만 남았습니다.';
  }

  @override
  String explanationHiddenSingle(String unitDesc, int value, int row, int col) {
    return '$unitDesc에서 숫자 $value번이 들어갈 수 있는 빈 칸은 $row행 $col열 하나뿐이에요.';
  }

  @override
  String explanationNakedSubset(
      String unitDesc, String cellsDesc, String digitsDesc, int size) {
    return '$unitDesc에서 $cellsDesc의 후보를 모두 합치면 $digitsDesc($size개)뿐이에요. 따라서 같은 구역 안 다른 칸에서는 $digitsDesc번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationHiddenSubset(
      String unitDesc, String digitsDesc, String cellsDesc) {
    return '$unitDesc에서 숫자 $digitsDesc번은 오직 $cellsDesc에만 들어갈 수 있어요. 이 칸들에서는 $digitsDesc 외의 다른 후보를 모두 지울 수 있습니다.';
  }

  @override
  String explanationPointing(String boxDesc, int digit, String lineDesc) {
    return '$boxDesc 안에서 숫자 $digit번은 $lineDesc 위에만 있어요. 그래서 $lineDesc의 나머지 칸(박스 밖)에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationClaiming(String lineDesc, int digit, String boxDesc) {
    return '$lineDesc에서 숫자 $digit번은 $boxDesc 안에만 있어요. 그래서 같은 박스의 나머지 칸(이 $lineDesc 밖)에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationXWing(
      int digit, String linesDesc, String crossDesc, String crossUnitName) {
    return '숫자 $digit번은 $linesDesc에서 각각 $crossDesc 두 곳에만 들어갈 수 있어요. 네 칸이 사각형을 이루므로, 두 $crossUnitName의 다른 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationFish(int digit, String linesDesc, String crossDesc,
      String crossUnitName, int size) {
    return '숫자 $digit번은 $linesDesc에서 합쳐서 $crossDesc $size곳에만 들어갈 수 있어요. 그래서 이 $crossUnitName들의 다른 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationFinnedFish(
      String mainLineDesc, int digit, String finLineDesc, String finsDesc) {
    return '$mainLineDesc은 숫자 $digit의 후보가 두 곳뿐인 정석 X-윙 모양이에요. $finLineDesc에는 그 외에 $finsDesc(핀)에도 후보가 있어서 온전한 X-윙은 아니지만, 핀을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationSimpleColoringRule1(int digit, String cellA, String cellB) {
    return '숫자 $digit의 후보를 사슬로 연결해보면 같은 그룹으로 묶인 $cellA와 $cellB가 서로 같은 행·열·박스에 있어요. 둘 다 $digit번이 될 수는 없으므로 이 그룹 전체가 $digit일 수 없습니다. 그래서 이 그룹의 칸들에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationSimpleColoringRule2(int digit, String cellsDesc) {
    return '숫자 $digit의 후보 사슬($cellsDesc)은 두 그룹으로 나뉘어 서로 반대 상태를 가져요. 이 두 그룹을 모두 보고 있는 칸은 어느 그룹이 참이든 $digit번이 될 수 없으므로, 그 칸에서 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationXYWing(String pivotDesc, int x, int y, String w1Desc,
      int sharedDigitW1, int z, String w2Desc, int otherPivotDigit) {
    return '피벗 칸 $pivotDesc의 후보는 $x, $y 두 개예요. 날개 칸 $w1Desc는 $sharedDigitW1 아니면 $z, $w2Desc는 $otherPivotDigit 아니면 $z예요. 피벗이 $sharedDigitW1이면 $w1Desc가, 피벗이 $otherPivotDigit이면 $w2Desc가 $z가 되므로, 어느 쪽이든 두 날개를 모두 보는 칸에서는 $z를 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationXYChain(String chainDesc, int z) {
    return '$chainDesc 순서로 이어지는 칸들은 후보가 둘씩뿐이라, 사슬 한쪽 끝이 $z가 아니면 반대쪽 끝이 $z가 될 수밖에 없어요. 그래서 사슬 양쪽 끝을 모두 보는 칸에서는 $z를 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationBugPlusOne(int row, int col, int value) {
    return '$row행 $col열을 제외한 나머지 빈 칸이 모두 후보 숫자 2개씩만 남았어요. 이 칸이 $value가 아니라면 스도쿠 전체가 완전한 BUG(Bi-Value Universal Grave) 패턴이 되어버려서 정답이 하나로 정해지지 않아요. 그래서 이 칸은 $value로 확정됩니다.';
  }

  @override
  String explanationUniqueRectangleType1(String cellsDesc, int a, int b) {
    return '$cellsDesc은 유일사각형(2행 2열, 박스 2개)을 이루는데, 그중 세 칸이 후보 $a, $b뿐이에요. 나머지 한 칸도 이 둘뿐이라면 퍼즐 해가 두 개가 되어버리므로, 그 칸에서는 $a, $b를 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationUniqueRectangleType2(
      String cellA, String cellB, int a, int b, int c) {
    return '$cellA과 $cellB은 후보가 $a, $b, $c 세 개씩이에요. 둘 다 $a, $b뿐이라면 퍼즐 해가 두 개가 되므로, 둘 중 하나는 반드시 $c여야 해요. 그래서 두 칸을 모두 보는 다른 칸에서는 $c를 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationUniqueRectangleType3(
      String cellA, String cellB, String digitsDesc) {
    return '$cellA과 $cellB의 추가 후보를 하나로 합쳐서 보면, 다른 칸들과 함께 $digitsDesc만 남는 조합을 이뤄요. 그래서 같은 구역의 나머지 칸에서는 $digitsDesc번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationUniqueRectangleType4(
      String cellA, String cellB, int lockedDigit, int otherDigit) {
    return '$cellA과 $cellB이 있는 줄에서 숫자 $lockedDigit번은 이 두 칸에만 들어갈 수 있어요. 그러면 $otherDigit번이 두 칸에 그대로 남아있을 경우 퍼즐 해가 두 개가 되므로, 두 칸 모두에서 $otherDigit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String noteRepairNotice(String explanation) {
    return '후보수가 정확하게 입력되어야 합니다. $explanation';
  }
}
