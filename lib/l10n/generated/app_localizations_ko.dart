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
  String get tutorialNext => '다음';

  @override
  String get tutorialSkip => '건너뛰기';

  @override
  String get tutorialDone => '확인';

  @override
  String get tutorialReplayLabel => '튜토리얼 다시 보기';

  @override
  String get tutorialHomeDifficultyTitle => '난이도 고르기';

  @override
  String get tutorialHomeDifficultyBody => '이 휠을 돌려 퍼즐의 난이도를 골라요.';

  @override
  String get tutorialHomeStartTitle => '게임 시작';

  @override
  String get tutorialHomeStartBody => '여기를 누르면 고른 난이도로 새 퍼즐이 시작돼요.';

  @override
  String get tutorialHomeIconsTitle => '상단 메뉴';

  @override
  String get tutorialHomeIconsBody =>
      '이 아이콘들로 통계, 공유 퍼즐 코드 입력, 내 프로필, 설정을 열 수 있어요.';

  @override
  String get tutorialHomeRaceTitle => '대결하기';

  @override
  String get tutorialHomeRaceBody => '친구나 다른 플레이어와 실시간으로 스도쿠 대결을 해보세요.';

  @override
  String get tutorialHomeDailyTitle => '오늘의 스도쿠';

  @override
  String get tutorialHomeDailyBody => '매일 주어지는 오늘의 스도쿠를 풀고 순위를 확인해 보세요.';

  @override
  String get tutorialGameGridTitle => '게임판';

  @override
  String get tutorialGameGridBody => '빈 칸을 눌러 선택한 뒤, 숫자를 골라 채워 넣어요.';

  @override
  String get tutorialGameNumbersTitle => '숫자 입력';

  @override
  String get tutorialGameNumbersBody => '여기서 숫자를 누르면 선택한 칸에 입력돼요.';

  @override
  String get tutorialGameNoteTitle => '메모 모드';

  @override
  String get tutorialGameNoteBody => '메모를 켜면 확정하기 전에 후보 숫자를 작게 적어둘 수 있어요.';

  @override
  String get tutorialGameHintTitle => '도움이 필요하면';

  @override
  String get tutorialGameHintBody =>
      '막히면 짧은 광고를 보고 힌트를 받을 수 있어요. 배지는 광고가 필요한 기능을 뜻해요.';

  @override
  String get tutorialGameMistakesTitle => '실수 제한';

  @override
  String get tutorialGameMistakesBody => '실수가 3번 쌓이면 게임이 끝나요. 한 칸씩 신중하게 입력해요.';

  @override
  String get tutorialQuickInputTitle => '빠른 입력';

  @override
  String get tutorialQuickInputBody =>
      '이 버튼을 켜면 숫자를 먼저 고른 뒤 여러 칸을 눌러 빠르게 채울 수 있어요. 메모 숫자도 같은 방식으로 입력돼요.';

  @override
  String get tutorialRaceProfileTitle => '내 정보';

  @override
  String get tutorialRaceProfileBody => '티어와 레이팅, 전적을 여기서 확인할 수 있어요.';

  @override
  String get tutorialRaceFriendTitle => '친구와 대결';

  @override
  String get tutorialRaceFriendBody => '방 코드를 공유해 친구와 1:1로 겨뤄요.';

  @override
  String get tutorialRaceRankedTitle => '랭크 대전';

  @override
  String get tutorialRaceRankedBody =>
      '실력이 비슷한 상대와 자동으로 매칭돼요. 티어에 따라 난이도가 정해져요.';

  @override
  String get tutorialRaceLeaderboardTitle => '리더보드';

  @override
  String get tutorialRaceLeaderboardBody => '전체 순위에서 내 위치를 확인할 수 있어요.';

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
  String get followSystemTheme => '시스템 설정';

  @override
  String get lightTheme => '라이트 모드';

  @override
  String get darkTheme => '다크 모드';

  @override
  String get hapticsLabel => '진동';

  @override
  String get soundLabel => '효과음';

  @override
  String get wrongNoteWarningLabel => '틀린 메모 방지';

  @override
  String get wrongNoteWarningDescription =>
      '같은 줄·칸·박스에 이미 있는 숫자는 메모할 수 없게 막아요.';

  @override
  String get autoRemoveNotesLabel => '숫자 확정 시 자동 메모 제거';

  @override
  String get autoRemoveNotesDescription =>
      '숫자를 입력하면 같은 줄·칸·박스에 있는 해당 숫자 메모를 자동으로 지워요.';

  @override
  String get languageSectionTitle => '언어';

  @override
  String get followSystemLanguage => '시스템 설정';

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
  String get perfectClearBadge => 'Perfect Clear';

  @override
  String get perfectClearFlavor1 => '힌트? 그게 뭐죠? 😎';

  @override
  String get perfectClearFlavor2 => '실수할 틈도 안 주셨네요.';

  @override
  String get perfectClearFlavor3 => '숫자들이 알아서 줄을 섰네요.';

  @override
  String get perfectClearFlavor4 => '9×9가 너무 작았나요?';

  @override
  String get perfectClearFlavor5 => '퍼즐이 졌습니다. 🏆';

  @override
  String get perfectClearFlavor6 => '이건 좀 반칙인데요?';

  @override
  String get perfectClearFlavor7 => '오늘은 숫자들이 당신 편이네요.';

  @override
  String get perfectClearFlavor8 => '9개의 숫자, 81개의 칸, 0개의 실수.';

  @override
  String get perfectClearFlavor9 => '힌트 버튼이 오늘도 한가하네요.';

  @override
  String get perfectClearFlavor10 => '스도쿠 장인 인정! 👑';

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
  String get inputModeQuick => '빠른입력';

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
  String get techniqueXChain => 'X-사슬';

  @override
  String get techniqueAic => 'AIC 사슬';

  @override
  String get techniqueGroupedXChain => '그룹 X-사슬';

  @override
  String get techniqueGroupedAic => '그룹 AIC 사슬';

  @override
  String get techniqueWXYZWing => 'WXYZ-윙';

  @override
  String get techniqueAlsXZ => 'ALS-XZ';

  @override
  String get techniqueSueDeCoq => '수 드 코크';

  @override
  String get techniqueTripleFirework => '트리플 파이어워크';

  @override
  String get techniqueAlsAic => 'ALS 사슬';

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
    return '$cellsDesc은 $lineDesc과 $boxDesc이(가) 겹치는 자리에 있고, 이 칸들의 후보를 모두 합치면 $digitsDesc($size개)뿐이에요. 이 칸들이 $size개 숫자를 모두 가져가므로, $lineDesc의 나머지 칸과 $boxDesc의 나머지 칸 양쪽에서 $digitsDesc번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationRemotePair(String chainDesc, int a, int b) {
    return '$chainDesc은 모두 후보가 $a, $b 두 개뿐이고 서로 이어져 있어서 값이 번갈아 정해져요. 사슬의 양 끝은 홀수 칸 떨어져 있으므로 한쪽이 $a(이)면 다른 쪽은 반드시 $b입니다. 그래서 양 끝을 모두 보는 칸에서는 $a번과 $b번을 모두 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationSimpleColoringRule1(int digit, String cellA, String cellB) {
    return '숫자 $digit의 후보를 사슬로 연결해보면 같은 그룹으로 묶인 $cellA과(와) $cellB이(가) 서로 같은 행·열·박스에 있어요. 둘 다 $digit번이 될 수는 없으므로 이 그룹 전체가 $digit일 수 없습니다. 그래서 이 그룹의 칸들에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationSimpleColoringRule2(int digit, String cellsDesc) {
    return '숫자 $digit의 후보 사슬($cellsDesc)은 두 그룹으로 나뉘어 서로 반대 상태를 가져요. 이 두 그룹을 모두 보고 있는 칸은 어느 그룹이 참이든 $digit번이 될 수 없으므로, 그 칸에서 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationXYWing(String pivotDesc, int x, int y, String w1Desc,
      int sharedDigitW1, int z, String w2Desc, int otherPivotDigit) {
    return '피벗 칸 $pivotDesc의 후보는 $x, $y 두 개예요. 날개 칸 $w1Desc은(는) $sharedDigitW1 아니면 $z, $w2Desc은(는) $otherPivotDigit 아니면 $z(이)에요. 피벗이 $sharedDigitW1(이)면 $w1Desc이(가), 피벗이 $otherPivotDigit(이)면 $w2Desc이(가) $z이(가) 되므로, 어느 쪽이든 두 날개를 모두 보는 칸에서는 $z을(를) 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationXYZWing(String pivotDesc, String pivotDigits, String w1Desc,
      String w2Desc, int z) {
    return '피벗 칸 $pivotDesc의 후보는 $pivotDigits 세 개이고, 날개 칸 $w1Desc과 $w2Desc은 각각 $z번과 나머지 하나를 갖고 있어요. 피벗이 어느 숫자가 되든 $z번은 피벗이나 날개 중 한 곳에 들어가므로, 세 칸을 모두 보는 칸에서는 $z번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationWWing(
      String cell1, String cell2, int a, int b, String unitDesc) {
    return '$cell1과(와) $cell2은(는) 후보가 똑같이 $a, $b 두 개뿐이고, $unitDesc에는 $b번이 들어갈 자리가 두 곳뿐인데 그 두 곳이 각각 두 칸을 하나씩 보고 있어요. 만약 두 칸이 모두 $b번이면 $unitDesc에 $b번이 들어갈 자리가 없어집니다. 따라서 둘 중 적어도 하나는 $a번이고, 두 칸을 모두 보는 칸에서는 $a번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationGroupedXChain(String chainDesc, int digit) {
    return '숫자 $digit번이 $chainDesc를 따라 교대 사슬을 이뤄요. 이 사슬은 나란히 놓인 후보 몇 개를 하나의 묶음 고리로 사용해요. 강한 연결이 양 끝 중 하나는 반드시 $digit임을 보장하므로, 두 끝을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationGroupedAic(String chainDesc) {
    return '$chainDesc 교차 추론 사슬은 나란히 놓인 후보 몇 개를 하나의 묶음 고리로 사용해요. 양 끝 중 적어도 하나는 참이 되도록 강제하므로, 양 끝과 모두 충돌하는 후보를 지울 수 있습니다.';
  }

  @override
  String explanationWXYZWing(String chainDesc) {
    return '$chainDesc: 후보가 두 개뿐인 칸과 세 칸짜리 거의-잠긴 집합(ALS)이 공유 숫자로 이어진 WXYZ-윙이에요. 사슬의 양 끝 중 적어도 하나는 참이므로, 양 끝을 모두 보는 후보는 지울 수 있습니다.';
  }

  @override
  String explanationAlsXZ(String chainDesc) {
    return '$chainDesc: 두 거의-잠긴 집합(ALS)이 제한 공통 숫자로 이어졌어요. 한쪽에서 그 숫자가 빠지면 다른 쪽 집합이 잠기므로 양 끝 중 적어도 하나는 참 — 양 끝을 모두 보는 후보는 지울 수 있습니다.';
  }

  @override
  String explanationAlsAic(String chainDesc) {
    return '$chainDesc 교차 추론 사슬은 거의-잠긴 집합(ALS)을 고리로 사용해요. 양 끝 중 적어도 하나는 참이 되므로, 양 끝과 모두 충돌하는 후보를 지울 수 있습니다.';
  }

  @override
  String explanationSueDeCoq(String cells, String digits) {
    return '교차 칸 $cells의 후보가 같은 줄의 거의-잠긴 집합, 같은 상자의 거의-잠긴 집합과 정확히 맞물려요. 관련 숫자($digits)가 전부 이 세 무리 안에서만 자리를 잡을 수 있으므로, 무리 밖의 같은 숫자 후보는 지울 수 있습니다.';
  }

  @override
  String hintStepSueDeCoqIntro(
      String cells, int cellCount, String digits, int digitCount) {
    return '상자와 줄이 만나는 $cells, 이 $cellCount칸의 후보를 모으면 $digits — 총 $digitCount종류예요. 칸 수보다 후보 종류가 두 개 이상 많죠.';
  }

  @override
  String hintStepSueDeCoqLine(
      String cells, int cellCount, String digits, int digitCount) {
    return '같은 줄의 $cells은 $cellCount칸에 후보가 $digits — $digitCount종류로 딱 하나 많은 거의-잠긴 집합이에요. 이 숫자들은 줄에서 여기 아니면 교차 칸에만 들어갈 수 있어요.';
  }

  @override
  String hintStepSueDeCoqBox(
      String cells, int cellCount, String digits, int digitCount) {
    return '같은 상자의 $cells도 $cellCount칸에 후보가 $digits — $digitCount종류뿐인 거의-잠긴 집합이에요. 이 숫자들도 상자에서 여기 아니면 교차 칸뿐 — 숫자마다 자리가 꼭 맞아떨어집니다.';
  }

  @override
  String explanationTripleFirework(String digits, String cells) {
    return '숫자 $digits가 행과 열 모두에서 상자 밖으로는 날개 한 칸씩만 삐져나가는 불꽃 모양이에요. 상자는 각 숫자를 한 번만 담을 수 있으니 교차 칸과 두 날개($cells)가 정확히 이 세 숫자로 채워져야 해요. 그래서 세 칸의 다른 후보와, 상자 안 비교차 칸의 이 숫자들을 지울 수 있습니다.';
  }

  @override
  String hintStepFireworkRow(String digits, String cells, String cell) {
    return '이 행에서 $digits의 후보는 $cells에만 있어요 — 상자 밖으로는 $cell 한 칸뿐이죠.';
  }

  @override
  String hintStepFireworkCol(String digits, String cells, String cell) {
    return '이 열에서도 $digits의 후보는 $cells에만 있어요 — 상자 밖은 $cell 하나예요.';
  }

  @override
  String hintStepFireworkTriple(String cells, String digits) {
    return '상자에 $digits 세 숫자는 각각 한 번씩만 들어갈 수 있어요. 전부 들어가려면 $cells 세 칸이 정확히 하나씩 나눠 가져야 해요.';
  }

  @override
  String explanationXChain(String chainDesc, int digit) {
    return '숫자 $digit번이 $chainDesc를 따라 교대 사슬을 이뤄요. 강한 연결이 양 끝 중 하나는 반드시 $digit임을 보장하므로, 두 끝을 모두 보는 칸에서는 $digit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationAic(String chainDesc) {
    return '$chainDesc 교차 추론 사슬은 양 끝 중 적어도 하나가 참이 되도록 강제해요. 그래서 양 끝과 모두 충돌하는 후보를 지울 수 있습니다.';
  }

  @override
  String explanationXYChain(String chainDesc, int z) {
    return '$chainDesc 순서로 이어지는 칸들은 후보가 둘씩뿐이라, 사슬 한쪽 끝이 $z번이 아니면 반대쪽 끝이 $z번이 될 수밖에 없어요. 그래서 사슬 양쪽 끝을 모두 보는 칸에서는 $z번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationBugPlusOne(int row, int col, int value) {
    return '$row행 $col열을 제외한 나머지 빈 칸이 모두 후보 숫자 2개씩만 남았어요. 이 칸이 $value이(가) 아니라면 스도쿠 전체가 완전한 BUG(Bi-Value Universal Grave) 패턴이 되어버려서 정답이 하나로 정해지지 않아요. 그래서 이 칸은 $value(으)로 확정됩니다.';
  }

  @override
  String explanationUniqueRectangleType1(String cellsDesc, int a, int b) {
    return '$cellsDesc은 유일사각형(2행 2열, 박스 2개)을 이루는데, 그중 세 칸이 후보 $a, $b뿐이에요. 나머지 한 칸도 이 둘뿐이라면 퍼즐 해가 두 개가 되어버리므로, 그 칸에서는 $a, $b을(를) 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationUniqueRectangleType2(
      String cellA, String cellB, int a, int b, int c) {
    return '$cellA과 $cellB은 후보가 $a, $b, $c 세 개씩이에요. 둘 다 $a, $b뿐이라면 퍼즐 해가 두 개가 되므로, 둘 중 하나는 반드시 $c(이)어야 해요. 그래서 두 칸을 모두 보는 다른 칸에서는 $c을(를) 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationUniqueRectangleType3(
      String cellA, String cellB, String digitsDesc) {
    return '$cellA과 $cellB 중 하나는 반드시 추가 후보 쪽이어야 해요(둘 다 사각형 쌍만 남으면 해가 두 개가 되니까요). 두 칸의 추가 후보를 한 칸처럼 합쳐서 보면 같은 구역의 다른 칸들과 함께 후보 $digitsDesc을(를) 나눠 갖는 묶음이 되므로, 그 구역의 나머지 칸에서는 $digitsDesc번을 후보에서 지울 수 있습니다.';
  }

  @override
  String explanationUniqueRectangleType4(
      String cellA, String cellB, int lockedDigit, int otherDigit) {
    return '$cellA과 $cellB이 있는 줄에서 숫자 $lockedDigit번은 이 두 칸에만 들어갈 수 있어요. 그러면 $otherDigit번이 두 칸에 그대로 남아있을 경우 퍼즐 해가 두 개가 되므로, 두 칸 모두에서 $otherDigit번을 후보에서 지울 수 있습니다.';
  }

  @override
  String noteRepairNotice(String explanation) {
    return '일부 칸의 후보 메모가 실제와 달라 먼저 자동으로 보정했어요. $explanation';
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
  String get signInWithGoogle => 'Google 계정으로 로그인';

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
  String get ratingTrendTitle => '레이팅 추이';

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
  String seasonName(int number) {
    return '시즌 $number';
  }

  @override
  String seasonDaysLeft(int days) {
    return 'D-$days';
  }

  @override
  String get pastSeasonsTitle => '지난 시즌 기록';

  @override
  String seasonStandingDetail(int rank, int wins, int losses) {
    return '$rank위 · $wins승 $losses패';
  }

  @override
  String placementProgress(int played, int total) {
    return '배치 $played/$total';
  }

  @override
  String seasonEndedTitle(int number) {
    return '시즌 $number 종료!';
  }

  @override
  String seasonEndedNewStart(int rating) {
    return '새 시즌이 시작됐어요. 레이팅 $rating에서 다시 출발해요!';
  }

  @override
  String get okAction => '확인';

  @override
  String get friendMatchTitle => '친구와 대결하기';

  @override
  String get createRoomTitle => '난이도 선택';

  @override
  String get createRoomAction => '방 만들기';

  @override
  String get joinRoomTitle => '방 참가';

  @override
  String get waitingForFriendTitle => '친구 대기 중';

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
  String get matchmakingTip1 => '오늘의 스도쿠를 풀고 순위를 확인해보세요.';

  @override
  String get matchmakingTip2 => '힌트와 실수 없이 스도쿠를 완료하면 Perfect Clear가 됩니다.';

  @override
  String get matchmakingTip3 => '랭크 대전의 스도쿠 난이도는 티어에 따라 정해집니다.';

  @override
  String get matchmakingTip4 => '메모 기능으로 후보 숫자를 적어두면 더 쉽게 풀 수 있어요.';

  @override
  String get matchmakingTip5 => '방 코드를 공유하면 친구와 1:1로 대결할 수 있어요.';

  @override
  String get matchmakingTip6 => '대결에서 이기면 레이팅이 올라 더 높은 티어로 승급해요.';

  @override
  String get matchmakingTip7 =>
      '티어는 브론즈 > 실버 > 골드 > 다이아몬드 > 마스터 > 챌린저가 있습니다. 챌린저까지 도전해보세요.';

  @override
  String get raceAbortConfirmTitle => '레이스를 포기할까요?';

  @override
  String opponentDisconnectedCountdown(int seconds) {
    return '상대방 연결 끊김 — $seconds초 후 승리 처리';
  }

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

  @override
  String get hintStepPrevAction => '이전';

  @override
  String get hintStepNextAction => '다음';

  @override
  String hintStepXYWingPivot(String pivot, int x, int y) {
    return '피벗 $pivot의 후보는 $x과(와) $y 둘뿐이에요.';
  }

  @override
  String hintStepWingCase(int digit, String wing, int z) {
    return '피벗이 $digit(이)라면 $wing에서 $digit이(가) 빠져요 — 그럼 그 칸은 $z이(가) 됩니다.';
  }

  @override
  String hintStepXYWingConclusion(int z) {
    return '어느 쪽이든 두 날개 중 하나는 반드시 $z. 두 날개를 모두 보는 칸은 $z이(가) 될 수 없어요.';
  }

  @override
  String hintStepXYZWingPivot(String pivot, String digits) {
    return '피벗 $pivot의 후보는 $digits 셋이에요.';
  }

  @override
  String hintStepXYZWingPivotZ(int z) {
    return '피벗이 $z인 경우도 있어요 — 그땐 피벗 자신이 $z입니다.';
  }

  @override
  String hintStepXYZWingConclusion(int z) {
    return '어떤 경우든 세 칸 중 하나는 반드시 $z. 세 칸을 모두 보는 칸은 $z이(가) 될 수 없어요.';
  }

  @override
  String hintStepWWingPair(String cell1, String cell2, int a, int b) {
    return '$cell1과(와) $cell2은(는) 후보가 $a, $b(으)로 똑같은 쌍이에요.';
  }

  @override
  String hintStepWWingBridge(String unitDesc, int b) {
    return '$unitDesc에서 $b이(가) 들어갈 곳은 두 곳뿐인데, 그 두 곳이 각각 쌍 칸을 하나씩 보고 있어요.';
  }

  @override
  String hintStepWWingForced(int a, int b) {
    return '쌍 두 칸이 모두 $b(이)라면 그 줄엔 $b이(가) 들어갈 곳이 없어져요. 그래서 적어도 하나는 $a입니다.';
  }

  @override
  String hintStepWWingConclusion(int a) {
    return '두 쌍 칸을 모두 보는 칸은 $a이(가) 될 수 없어요.';
  }

  @override
  String hintStepChainStart(String cell, int z, int a) {
    return '$cell에서 시작해요. 이 칸이 $z이(가) 아니라면 남는 후보는 $a뿐이에요.';
  }

  @override
  String hintStepChainHop(String cell, int carry, int next) {
    return '그러면 $cell은(는) $carry이(가) 될 수 없으니 $next이(가) 됩니다.';
  }

  @override
  String hintStepAicStart(String cell, int digit) {
    return '$cell의 후보 $digit번에서 출발해요. 만약 이 칸이 $digit번이 아니라면 —';
  }

  @override
  String hintStepAicStrongUnit(String cell, int digit) {
    return '$cell은 반드시 $digit번이 돼요.';
  }

  @override
  String hintStepAicStrongCell(int digit) {
    return '남은 후보 $digit번이 확정돼요.';
  }

  @override
  String hintStepAicStartGroup(String cells, int digit) {
    return '$cells 묶음의 후보 $digit번에서 출발해요. 만약 이 묶음 어디에도 $digit번이 없다면 —';
  }

  @override
  String hintStepAicStrongGroup(String cells, int digit) {
    return '$cells 묶음 중 하나는 반드시 $digit번이 돼요.';
  }

  @override
  String hintStepAicWeakUnit(String cell, int digit) {
    return '그러면 $cell은 $digit번이 될 수 없어요.';
  }

  @override
  String hintStepAicWeakCell(int digit) {
    return '그러면 이 칸의 다른 후보 $digit번은 지워져요.';
  }

  @override
  String hintStepAicEitherEnds(
      String startCell, int startDigit, String endCell, int endDigit) {
    return '정리하면 경우는 딱 둘이에요. $startCell이 정말 $startDigit번이거나, 아니라면 방금 본 흐름대로 $endCell이 $endDigit번이 되거나 — 어느 쪽이든 둘 중 하나는 반드시 맞아요.';
  }

  @override
  String get hintStepAicConclusion => '양 끝을 모두 보는 후보는 지울 수 있어요.';

  @override
  String hintStepChainConclusion(int z) {
    return '따라서 시작 칸이 $z(이)거나 끝 칸이 $z(이)에요. 양 끝을 모두 보는 칸은 $z이(가) 될 수 없습니다.';
  }

  @override
  String hintStepRemotePairIntro(int a, int b) {
    return '이 사슬의 칸들은 후보가 모두 $a, $b(으)로 똑같아요.';
  }

  @override
  String hintStepRemotePairAlternate(int a, int b) {
    return '이웃한 칸끼리 서로 보므로 값은 $a, $b, $a, $b… 번갈아 갈 수밖에 없어요.';
  }

  @override
  String hintStepRemotePairEnds(int a, int b) {
    return '양 끝은 홀수 번 떨어져 있어서 항상 서로 달라요 — 하나는 $a, 다른 하나는 $b입니다.';
  }

  @override
  String hintStepRemotePairConclusion(int a, int b) {
    return '양 끝을 모두 보는 칸은 $a도 $b도 될 수 없어요.';
  }

  @override
  String hintStepSingleDigitStrong1(int digit, String cell1, String cell2) {
    return '$cell1과(와) $cell2은(는) 그 줄에서 $digit이(가) 들어갈 수 있는 단 두 곳이에요 — 둘 중 하나는 반드시 $digit입니다.';
  }

  @override
  String hintStepSingleDigitStrong2(int digit, String cell1, String cell2) {
    return '$cell1과(와) $cell2도 단 두 곳 쌍이에요. 그리고 두 쌍의 가운데 칸끼리는 서로 봅니다.';
  }

  @override
  String hintStepSingleDigitForced(int digit, String cell1, String cell2) {
    return '가운데 두 칸이 동시에 $digit일 수는 없어요. 그래서 끝 칸 $cell1과(와) $cell2 중 적어도 하나는 $digit입니다.';
  }

  @override
  String hintStepSingleDigitConclusion(int digit) {
    return '두 끝 칸을 모두 보는 칸은 $digit이(가) 될 수 없어요.';
  }

  @override
  String hintStepColoringChain(int digit) {
    return '$digit이(가) 딱 두 곳에만 들어가는 줄로 이어진 사슬이에요. 이웃은 서로 반대라 두 색으로 나뉩니다.';
  }

  @override
  String hintStepColoringRule1Clash(int digit, String cell1, String cell2) {
    return '같은 색인 $cell1과(와) $cell2이(가) 서로 보고 있어요. 한 색이 $digit을(를) 두 번 가질 수는 없으니 이 색 전체가 틀렸습니다.';
  }

  @override
  String hintStepColoringRule1Conclusion(int digit) {
    return '틀린 색의 모든 칸에서 $digit을(를) 지울 수 있어요.';
  }

  @override
  String hintStepColoringRule2Conclusion(int digit) {
    return '두 색 중 하나는 반드시 참이에요. 양쪽 색을 모두 보는 칸은 어느 쪽이든 $digit이(가) 될 수 없습니다.';
  }

  @override
  String hintStepXWingLines(int digit, String linesDesc) {
    return '숫자 $digit은(는) $linesDesc에서 각각 딱 두 곳에만 들어갈 수 있어요.';
  }

  @override
  String hintStepXWingRect(int digit, String crossDesc) {
    return '네 곳이 직사각형을 이뤄요. 어떻게 놓이든 $crossDesc에는 그 안에서 $digit이(가) 하나씩 들어갑니다.';
  }

  @override
  String hintStepXWingConclusion(int digit, String crossUnitName) {
    return '그래서 그 두 $crossUnitName의 나머지 칸에는 $digit이(가) 올 수 없어요.';
  }

  @override
  String hintStepFullHouseIntro(String unitDesc) {
    return '$unitDesc에는 빈 칸이 딱 하나 남았어요.';
  }

  @override
  String hintStepNakedSingleIntro(String cell) {
    return '$cell의 후보를 좁혀 볼게요 — 같은 행·열·박스에 이미 놓인 숫자를 하나씩 지워 보세요.';
  }

  @override
  String hintStepHiddenSingleIntro(int digit) {
    return '숫자 $digit이(가) 들어갈 수 있는 자리가 한 칸뿐인 구역이 있어요. 강조된 숫자들이 다른 칸을 모두 막고 있거든요.';
  }

  @override
  String get hintStepBugIntro =>
      '빈 칸의 후보가 전부 2개씩이면 정답이 두 개가 되어 버려요. 후보가 3개인 칸이 딱 하나 있는데, 그 칸이 열쇠예요.';

  @override
  String hintStepNakedSubsetIntro(int count, String digits, String unitDesc) {
    return '$unitDesc의 강조된 $count칸에는 후보가 $digits밖에 없어요.';
  }

  @override
  String hintStepHiddenSubsetIntro(int count, String digits, String unitDesc) {
    return '$unitDesc에서 $digits이(가) 들어갈 수 있는 곳은 강조된 $count칸뿐이에요.';
  }

  @override
  String hintStepPointingIntro(int digit, String boxDesc, String lineDesc) {
    return '$boxDesc 안에서 숫자 $digit이(가) 들어갈 자리는 전부 $lineDesc 위에 있어요.';
  }

  @override
  String hintStepClaimingIntro(int digit, String lineDesc, String boxDesc) {
    return '$lineDesc에서 숫자 $digit이(가) 들어갈 자리는 전부 $boxDesc 안에 있어요.';
  }

  @override
  String hintStepFishIntro(int digit, String linesDesc) {
    return '$linesDesc을(를) 보세요 — 숫자 $digit이(가) 들어갈 자리가 몇 개의 교차선에 몰려 있어요.';
  }

  @override
  String get hintStepURIntro =>
      '강조된 칸들이 같은 후보 쌍을 공유하는 직사각형을 이뤄요. 네 칸 모두 그 두 후보만 남으면 정답이 두 개가 되어 버립니다 — 그럴 수는 없죠.';

  @override
  String get replayTitle => '리플레이';

  @override
  String get replayEmpty => '아직 리플레이할 기록이 없어요.';

  @override
  String get premiumTitle => '프리미엄';

  @override
  String get premiumIntroTitle => '스도쿠 리그 프리미엄';

  @override
  String get premiumBenefitAssistTitle => '무제한 힌트·자동메모';

  @override
  String get premiumBenefitAssistBody => '광고 없이 힌트와 자동메모를 마음껏 사용해요.';

  @override
  String get premiumBenefitReplayTitle => '리플레이';

  @override
  String get premiumBenefitReplayBody =>
      '최근 게임을 한 수씩 되돌려 보고 이어서 풀어요 — 대전 리플레이 포함.';

  @override
  String get premiumBenefitFavoriteTitle => '즐겨찾기';

  @override
  String get premiumBenefitFavoriteBody => '마음에 드는 퍼즐을 저장해두고 언제든 다시 풀어요.';

  @override
  String get premiumBenefitThemeTitle => '테마 팩 5종';

  @override
  String get premiumBenefitThemeBody => '보드와 앱 전체의 분위기를 바꾸는 프리미엄 테마.';

  @override
  String get premiumPlanLifetime => '평생 이용권';

  @override
  String get premiumPlanLifetimePrice => '₩5,500';

  @override
  String get premiumPlanLifetimeDetail => '한 번 결제로 평생 이용';

  @override
  String get premiumPlanMonthly => '월 구독';

  @override
  String get premiumPlanMonthlyPrice => '₩1,100';

  @override
  String get premiumPlanMonthlyDetail => '매월 자동 갱신';

  @override
  String get premiumCtaStart => '프리미엄 시작하기';

  @override
  String get premiumMockDone => '(목업) 프리미엄이 활성화됐어요!';

  @override
  String get premiumComingSoon => '결제는 정식 출시 시 제공돼요.';

  @override
  String get replayPremiumBody =>
      '최근 게임을 한 수씩 복기하고 다시 풀어보세요 — 입력·메모한 순서를 그대로 되돌려 봅니다.';

  @override
  String get replayResumeFromHere => '여기서부터 풀기';

  @override
  String get raceReplayUnavailable => '이 기기에 저장된 리플레이 기록이 없어요.';

  @override
  String get favoritesTitle => '즐겨찾기';

  @override
  String get favoritePremiumBody => '마음에 드는 스도쿠를 즐겨찾기에 저장해두고 원할 때 새로 풀어보세요.';

  @override
  String get favoritesEmpty => '저장한 스도쿠가 없어요.';

  @override
  String get favoriteSaved => '즐겨찾기에 저장했어요.';

  @override
  String get favoriteRemoved => '즐겨찾기에서 제거했어요.';

  @override
  String favoriteFull(int count) {
    return '즐겨찾기가 가득 찼어요 (최대 $count개).';
  }

  @override
  String get themePackSectionTitle => '테마 팩';

  @override
  String get themePackClassic => '클래식';

  @override
  String get themePackMidnightNeon => '미드나잇 네온';

  @override
  String get themePackSepiaPaper => '세피아 페이퍼';

  @override
  String get themePackMonochrome => '모노크롬';

  @override
  String get themePackForest => '포레스트';

  @override
  String get themePackOcean => '오션';

  @override
  String get themePremiumBody =>
      '프리미엄 테마 팩으로 보드와 앱 전체의 분위기를 바꿔보세요 — 5가지 스타일 중에서 고를 수 있어요.';

  @override
  String get codexTitle => '기법 도감';

  @override
  String codexProgress(int met, int total) {
    return '발견한 기법 $met / $total';
  }

  @override
  String codexUsage(int uses, int puzzles) {
    return '$uses회 · $puzzles판';
  }

  @override
  String get codexUndiscovered => '미발견';
}
