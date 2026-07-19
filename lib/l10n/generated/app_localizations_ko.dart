// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '스도쿠 리그';

  @override
  String get homeButton => '홈으로';

  @override
  String get closeAction => '닫기';

  @override
  String get applyAction => '적용하기';

  @override
  String get hintRevealMoreAction => '더 보기';

  @override
  String get continueAction => '계속하기';

  @override
  String get cancelAction => '취소';

  @override
  String get startGame => '시작하기';

  @override
  String get generatingPuzzle => '생성 중...';

  @override
  String get privacyPolicyTitle => '개인정보처리방침';

  @override
  String get termsOfServiceTitle => '이용약관';

  @override
  String get raceButton => '대결하기';

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
  String get wrongNoteWarningLabel => '틀린 메모 경고';

  @override
  String get autoRemoveNotesLabel => '숫자 확정 시 자동 메모 제거';

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
  String get hintNoTechniqueWithNotes => '현재 메모만으로는 적용할 수 있는 기술이 없습니다.';

  @override
  String get hintAutoGenerateCandidatesPrompt => '후보수를 자동으로 생성해서 다시 분석할까요?';

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
  String get dailyCalendarSignInHint => '로그인하면 데일리 스도쿠 기록이 표시됩니다.';

  @override
  String get dailyCalendarLoadError => '데일리 기록을 불러오지 못했어요.';

  @override
  String dailyCalendarDayDetail(int month, int day, String time, int mistakes) {
    return '$month월 $day일 · $time · 실수 $mistakes';
  }

  @override
  String get statsCompletedLabel => '완료 횟수';

  @override
  String get statsPerfectLabel => '퍼펙트 횟수';

  @override
  String get statsAverageLabel => '평균 기록';

  @override
  String get statsBestLabel => '최고 기록';

  @override
  String get statsNoRecord => '-';

  @override
  String statsTopPercentBadge(int percent) {
    return '상위 $percent%';
  }

  @override
  String playedWonLabel(int played, int won) {
    return '플레이 $played회 · 승리 $won회';
  }

  @override
  String bestTimeSuffix(String time) {
    return ' · 최고기록 $time';
  }

  @override
  String get raceHistoryTitle => '대결 기록';

  @override
  String get raceHistoryResultWon => '승리';

  @override
  String get raceHistoryResultLost => '패배';

  @override
  String get raceHistoryEmpty => '아직 대결 기록이 없어요.';

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
  String get difficultyBeginner => '브론즈';

  @override
  String get difficultyEasy => '실버';

  @override
  String get difficultyMedium => '골드';

  @override
  String get difficultyHard => '다이아몬드';

  @override
  String get difficultyMaster => '마스터';

  @override
  String get difficultyExpert => '챌린저';

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
  String get techniqueLockedPair => '락드 페어';

  @override
  String get techniqueLockedTriple => '락드 트리플';

  @override
  String get techniqueXWing => 'X-윙';

  @override
  String get techniqueSkyscraper => '스카이스크래퍼';

  @override
  String get techniqueTwoStringKite => '2-스트링 카이트';

  @override
  String get techniqueTurbotFish => '터봇 피시';

  @override
  String get techniqueRemotePair => '리모트 페어';

  @override
  String get techniqueSimpleColoring => '심플 컬러링';

  @override
  String get techniqueXYWing => 'XY-윙';

  @override
  String get techniqueXYZWing => 'XYZ-윙';

  @override
  String get techniqueWWing => 'W-윙';

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
  String get techniqueFinnedSwordfish => '핀드 스워드피쉬';

  @override
  String get techniqueFinnedJellyfish => '핀드 젤리피쉬';

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
  String explanationSkyscraper(int digit, String cell1, String cell2) {
    return '숫자 $digit번이 스카이스크래퍼를 이뤄요. 두 강한 연결이 이어져 $cell1과 $cell2 중 적어도 한 칸은 $digit번이어야 해요. 그래서 두 칸을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationTwoStringKite(int digit, String cell1, String cell2) {
    return '숫자 $digit번이 한 박스를 통해 2-스트링 카이트를 이뤄서, $cell1과 $cell2 중 적어도 한 칸은 $digit번이어야 해요. 그래서 두 칸을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationTurbotFish(int digit, String cell1, String cell2) {
    return '숫자 $digit번이 터봇 피시 사슬을 이뤄서, $cell1과 $cell2 중 적어도 한 칸은 $digit번이어야 해요. 그래서 두 칸을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationFinnedFish(
      String mainLineDesc, int digit, String finLineDesc, String finsDesc) {
    return '$mainLineDesc은 숫자 $digit의 후보가 두 곳뿐인 정석 X-윙 모양이에요. $finLineDesc에는 그 외에 $finsDesc(핀)에도 후보가 있어서 온전한 X-윙은 아니지만, 핀을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationFinnedFishN(
      String baseLinesDesc, int digit, int size, String finsDesc) {
    return '$baseLinesDesc에서 숫자 $digit번이 $size줄 피시 모양을 이루는데, $finsDesc(핀)에 후보가 더 있어요. 핀이 모두 거짓이면 온전한 피시가 되고, 아니면 핀 중 하나가 $digit번이에요. 어느 쪽이든 핀을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationLockedSubset(String lineDesc, String boxDesc,
      String cellsDesc, String digitsDesc, int size) {
    return '$cellsDesc은 $lineDesc과 $boxDesc이 겹치는 자리에 있고, 이 칸들의 후보를 모두 합치면 $digitsDesc($size개)뿐이에요. 이 칸들이 $size개 숫자를 모두 가져가므로, $lineDesc의 나머지 칸과 $boxDesc의 나머지 칸 양쪽에서 $digitsDesc번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationRemotePair(String chainDesc, int a, int b) {
    return '$chainDesc은 모두 후보가 $a, $b 두 개뿐이고 서로 이어져 있어서 값이 번갈아 정해져요. 사슬의 양 끝은 홀수 칸 떨어져 있으므로 한쪽이 $a면 다른 쪽은 반드시 $b입니다. 그래서 양 끝을 모두 보는 칸에서는 $a번과 $b번을 모두 후보에서 지울 수 있습니다.';
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
  String explanationXYZWing(String pivotDesc, String pivotDigits, String w1Desc,
      String w2Desc, int z) {
    return '피벗 칸 $pivotDesc의 후보는 $pivotDigits 세 개이고, 날개 칸 $w1Desc와 $w2Desc는 각각 $z번과 나머지 하나를 갖고 있어요. 피벗이 어느 숫자가 되든 $z번은 피벗이나 날개 중 한 곳에 들어가므로, 세 칸을 모두 보는 칸에서는 $z번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationWWing(
      String cell1, String cell2, int a, int b, String unitDesc) {
    return '$cell1과 $cell2는 후보가 똑같이 $a, $b 두 개뿐이고, $unitDesc에는 $b번이 들어갈 자리가 두 곳뿐인데 그 두 곳이 각각 두 칸을 하나씩 보고 있어요. 만약 두 칸이 모두 $b번이면 $unitDesc에 $b번이 들어갈 자리가 없어집니다. 따라서 둘 중 적어도 하나는 $a번이고, 두 칸을 모두 보는 칸에서는 $a번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationXYChain(String chainDesc, int z) {
    return '$chainDesc 순서로 이어지는 칸들은 후보가 둘씩뿐이라, 사슬 한쪽 끝이 $z번이 아니면 반대쪽 끝이 $z번이 될 수밖에 없어요. 그래서 사슬 양쪽 끝을 모두 보는 칸에서는 $z번을 후보에서 지울 수 있습니다.';
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

  @override
  String get myPageTitle => '마이페이지';

  @override
  String errorOccurred(String message) {
    return '오류가 발생했습니다: $message';
  }

  @override
  String get signInPromptTitle => '로그인하고 다른 플레이어와 대결해보세요';

  @override
  String get signInWithGoogle => 'Google로 로그인';

  @override
  String get signInWithApple => 'Apple로 로그인';

  @override
  String get signInAsGuest => '게스트로 시작';

  @override
  String ratingAndRecord(int rating, int wins, int losses) {
    return '레이팅 $rating · $wins승 $losses패';
  }

  @override
  String winRateLabel(int percent) {
    return '대결 승률 $percent%';
  }

  @override
  String tierPromotionRemaining(int points, String nextTier) {
    return '$nextTier 승급까지 $points점';
  }

  @override
  String get tierTopReached => '최고 티어예요';

  @override
  String get linkAccountPrompt => '게스트 계정으로 로그인 중입니다. 계정을 연동하면 기록이 유지됩니다.';

  @override
  String get linkGoogleAction => 'Google 계정 연동';

  @override
  String get linkAppleAction => 'Apple 계정 연동';

  @override
  String get signOutAction => '로그아웃';

  @override
  String get shareCodeTitle => '퍼즐 공유';

  @override
  String get enterCodeTitle => '코드 입력';

  @override
  String get shareCodeTextLabel => '텍스트 코드';

  @override
  String get invalidTextCodeError => '유효하지 않은 텍스트 코드예요.';

  @override
  String get copiedToClipboard => '클립보드에 복사했어요';

  @override
  String get enterTextCodeHint => '방 코드 또는 퍼즐 코드';

  @override
  String get roomJoinRequiresSignIn => '친구 대결 참가는 로그인이 필요해요. 대결 로비에서 로그인해 주세요.';

  @override
  String get loadButton => '입장하기';

  @override
  String get raceLobbyTitle => '대결';

  @override
  String get friendMatchButton => '친구와 대결하기';

  @override
  String get rankedMatchButton => '랭크대전';

  @override
  String get leaderboardButton => '랭킹';

  @override
  String get leaderboardTitle => '랭킹';

  @override
  String leaderboardMyRankLabel(int rank, int total) {
    return '내 순위 $rank위 / $total명';
  }

  @override
  String get leaderboardMyRankUnranked => '아직 랭크 기록이 없어요';

  @override
  String get leaderboardEmpty => '아직 랭크된 플레이어가 없어요.';

  @override
  String get leaderboardLoadFailed => '랭킹을 불러오지 못했어요.';

  @override
  String get friendMatchTitle => '친구와 대결하기';

  @override
  String get createRoomTitle => '난이도 선택';

  @override
  String get createRoomAction => '방 만들기';

  @override
  String get joinRoomTitle => '방 참가';

  @override
  String get joinRoomAction => '참가하기';

  @override
  String get roomCodeFieldLabel => '방 코드';

  @override
  String get roomCodeInvalid => '방을 찾을 수 없거나 만료되었어요.';

  @override
  String get roomCodeShareHint => '이 코드를 친구에게 공유하세요';

  @override
  String get waitingForFriend => '친구가 참가하길 기다리는 중...';

  @override
  String matchmakingElapsed(String time) {
    return '대기 시간 $time';
  }

  @override
  String get friendlyMatchLabel => '친선전 · 레이팅 변동 없음';

  @override
  String get matchmakingTitle => '대결 상대 찾기';

  @override
  String get matchmakingSearching => '상대를 찾는 중...';

  @override
  String get matchmakingPreparingPuzzle => '퍼즐 준비 중...';

  @override
  String get matchmakingReadyCheck => '상대 확인 중...';

  @override
  String get raceAbortConfirmTitle => '레이스를 포기할까요?';

  @override
  String get opponentLeftBanner => '상대방 연결이 끊겼어요';

  @override
  String get opponentProgressLabel => '상대방';

  @override
  String get raceResultTitle => '레이스 결과';

  @override
  String get raceWon => '승리!';

  @override
  String get raceLost => '패배';

  @override
  String get tierBronze => '브론즈';

  @override
  String get tierSilver => '실버';

  @override
  String get tierGold => '골드';

  @override
  String get tierDiamond => '다이아몬드';

  @override
  String get tierMaster => '마스터';

  @override
  String get tierChallenger => '챌린저';

  @override
  String yourRatingChangeLabel(int oldRating, int newRating, String delta) {
    return '나: $oldRating → $newRating ($delta)';
  }

  @override
  String opponentRatingChangeLabel(
      String username, int oldRating, int newRating, String delta) {
    return '$username: $oldRating → $newRating ($delta)';
  }

  @override
  String homeRatingLabel(String tier, int rating) {
    return '$tier · 레이팅 $rating';
  }

  @override
  String get dailyButton => '오늘의 스도쿠';

  @override
  String get dailyTitle => '오늘의 스도쿠';

  @override
  String get dailyLoading => '오늘의 퍼즐 준비 중...';

  @override
  String get dailySignInPromptTitle => '로그인하고 오늘의 스도쿠에 도전해보세요';

  @override
  String get dailyResultTitle => '오늘의 결과';

  @override
  String dailyMyRankLabel(int rank, int total) {
    return '오늘 $rank등 / $total명';
  }

  @override
  String get dailyLeaderboardTitle => 'TOP 10';

  @override
  String get dailyEmptyLeaderboard => '아직 완료한 사람이 없어요.';

  @override
  String get dailyReplayAction => '다시 풀기';

  @override
  String get dailyNotRankedNotice => '기록은 첫 완료 기준이에요.';

  @override
  String get dailySubmitFailed => '기록 전송에 실패했어요.';

  @override
  String get retryAction => '다시 시도';
}
