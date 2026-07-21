// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sudoku League';

  @override
  String get homeButton => 'Home';

  @override
  String get closeAction => 'Close';

  @override
  String get applyAction => 'Apply';

  @override
  String get hintRevealMoreAction => 'Show more';

  @override
  String get continueAction => 'Continue';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialDone => 'Got it';

  @override
  String get tutorialReplayLabel => 'Replay tutorial';

  @override
  String get tutorialHomeDifficultyTitle => 'Pick a difficulty';

  @override
  String get tutorialHomeDifficultyBody =>
      'Spin this wheel to choose how hard your puzzle will be.';

  @override
  String get tutorialHomeStartTitle => 'Start playing';

  @override
  String get tutorialHomeStartBody =>
      'Tap here to begin a new puzzle at the difficulty you picked.';

  @override
  String get tutorialHomeIconsTitle => 'Top menu';

  @override
  String get tutorialHomeIconsBody =>
      'These icons open stats, enter a shared puzzle code, your profile, and settings.';

  @override
  String get tutorialHomeRaceTitle => 'Race';

  @override
  String get tutorialHomeRaceBody =>
      'Take on a friend or other players in a real-time sudoku match.';

  @override
  String get tutorialHomeDailyTitle => 'Daily';

  @override
  String get tutorialHomeDailyBody =>
      'Solve today\'s puzzle and check where you rank.';

  @override
  String get tutorialGameGridTitle => 'The board';

  @override
  String get tutorialGameGridBody =>
      'Tap an empty cell to select it, then choose a number to fill it in.';

  @override
  String get tutorialGameNumbersTitle => 'Enter numbers';

  @override
  String get tutorialGameNumbersBody =>
      'Tap a number here to place it in the selected cell.';

  @override
  String get tutorialGameNoteTitle => 'Note mode';

  @override
  String get tutorialGameNoteBody =>
      'Turn this on to pencil in small candidate numbers before committing.';

  @override
  String get tutorialGameHintTitle => 'Need a hand?';

  @override
  String get tutorialGameHintBody =>
      'Stuck? Get a hint by watching a short ad — the badge marks ad-gated helpers.';

  @override
  String get tutorialGameMistakesTitle => 'Mistake limit';

  @override
  String get tutorialGameMistakesBody =>
      'The game ends after 3 mistakes, so place each number carefully.';

  @override
  String get tutorialQuickInputTitle => 'Quick input';

  @override
  String get tutorialQuickInputBody =>
      'Turn this on to pick a number first, then tap cells to fill them fast. Memo digits work the same way.';

  @override
  String get tutorialRaceProfileTitle => 'Your standing';

  @override
  String get tutorialRaceProfileBody =>
      'Your tier, rating, and win-loss record show up here.';

  @override
  String get tutorialRaceFriendTitle => 'Play a friend';

  @override
  String get tutorialRaceFriendBody =>
      'Share a room code to race a friend one-on-one.';

  @override
  String get tutorialRaceRankedTitle => 'Ranked match';

  @override
  String get tutorialRaceRankedBody =>
      'Get matched with a similar opponent — your tier sets the difficulty.';

  @override
  String get tutorialRaceLeaderboardTitle => 'Leaderboard';

  @override
  String get tutorialRaceLeaderboardBody =>
      'See how you rank against everyone else.';

  @override
  String get startGame => 'Start';

  @override
  String get generatingPuzzle => 'Generating...';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get termsOfServiceTitle => 'Terms of Service';

  @override
  String get raceButton => 'Race';

  @override
  String get themeSectionTitle => 'Theme';

  @override
  String get followSystemTheme => 'Follow System';

  @override
  String get lightTheme => 'Light Mode';

  @override
  String get darkTheme => 'Dark Mode';

  @override
  String get hapticsLabel => 'Vibration';

  @override
  String get soundLabel => 'Sound Effects';

  @override
  String get wrongNoteWarningLabel => 'Prevent on Wrong Notes';

  @override
  String get wrongNoteWarningDescription =>
      'Blocks notes for a number already placed in the same row, column, or box.';

  @override
  String get autoRemoveNotesLabel => 'Auto-clear Notes on Confirm';

  @override
  String get autoRemoveNotesDescription =>
      'Placing a number clears matching notes in the same row, column, and box.';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get followSystemLanguage => 'Follow System';

  @override
  String get koreanLanguage => '한국어';

  @override
  String get englishLanguage => 'English';

  @override
  String mistakesLabel(int current, int max) {
    return 'Mistakes: $current/$max';
  }

  @override
  String get exitDialogTitle => 'End the game?';

  @override
  String get restartAction => 'Restart';

  @override
  String get endGameAction => 'End Game';

  @override
  String get gameOverTitle => '3 Mistakes';

  @override
  String get gameOverContent => 'Watch an ad to continue?';

  @override
  String get giveUpAction => 'Give Up and Exit';

  @override
  String get noHintAvailable => 'No hint is available right now.';

  @override
  String get clearWrongFirst => 'Please clear the wrong answer first.';

  @override
  String get hintNoTechniqueWithNotes =>
      'No technique can be applied with your current notes.';

  @override
  String get hintAutoGenerateCandidatesPrompt =>
      'Generate candidate notes automatically and analyze again?';

  @override
  String get adNotLoaded =>
      'The ad hasn\'t loaded yet. Please try again in a moment.';

  @override
  String get resultTitle => 'Result';

  @override
  String get perfectClearBadge => 'Perfect Clear';

  @override
  String get perfectClearFlavor1 => 'Hint? What\'s that? 😎';

  @override
  String get perfectClearFlavor2 =>
      'You didn\'t even give yourself a chance to mess up.';

  @override
  String get perfectClearFlavor3 =>
      'The numbers practically lined themselves up.';

  @override
  String get perfectClearFlavor4 => 'Was 9×9 too easy for you?';

  @override
  String get perfectClearFlavor5 => 'The puzzle never stood a chance. 🏆';

  @override
  String get perfectClearFlavor6 => 'Okay, that\'s almost unfair.';

  @override
  String get perfectClearFlavor7 => 'The numbers were on your side today.';

  @override
  String get perfectClearFlavor8 => '9 numbers. 81 cells. 0 mistakes.';

  @override
  String get perfectClearFlavor9 => 'The hint button is out of a job today.';

  @override
  String get perfectClearFlavor10 => 'Certified Sudoku Master! 👑';

  @override
  String mistakesAndHints(int mistakes, int hints) {
    return 'Mistakes: $mistakes · Hints used: $hints';
  }

  @override
  String get personalBestTitle => 'Personal Best';

  @override
  String get firstClear => 'First clear for this difficulty!';

  @override
  String newBest(String time) {
    return '🏆 New personal best! (Previous: $time)';
  }

  @override
  String currentBest(String time) {
    return 'Personal best: $time';
  }

  @override
  String get comparisonTitle => 'Global Player Comparison';

  @override
  String topPercent(int percent) {
    return 'Top $percent%';
  }

  @override
  String get mockDataDisclaimer => '* This is sample data, not real user data.';

  @override
  String get techniquesUsedTitle => 'Techniques Used';

  @override
  String get highestTechniqueLabel => 'Hardest technique:';

  @override
  String techniqueUsageCount(int count) {
    return '×$count';
  }

  @override
  String get statsTitle => 'Stats';

  @override
  String get dailyCalendarSignInHint =>
      'Sign in to see your daily sudoku history.';

  @override
  String get dailyCalendarLoadError => 'Couldn\'t load your daily history.';

  @override
  String dailyCalendarDayDetail(int month, int day, String time, int mistakes) {
    return '$month/$day · $time · $mistakes mistakes';
  }

  @override
  String get statsCompletedLabel => 'Completed';

  @override
  String get statsPerfectLabel => 'Perfect clears';

  @override
  String get statsAverageLabel => 'Average time';

  @override
  String get statsBestLabel => 'Best time';

  @override
  String get statsNoRecord => '-';

  @override
  String statsTopPercentBadge(int percent) {
    return 'Top $percent%';
  }

  @override
  String playedWonLabel(int played, int won) {
    return 'Played $played · Won $won';
  }

  @override
  String bestTimeSuffix(String time) {
    return ' · Best $time';
  }

  @override
  String get raceHistoryTitle => 'Race History';

  @override
  String get raceHistoryResultWon => 'Win';

  @override
  String get raceHistoryResultLost => 'Loss';

  @override
  String get raceHistoryEmpty => 'No races yet.';

  @override
  String get undoLabel => 'Undo';

  @override
  String get eraseLabel => 'Erase';

  @override
  String get noteLabel => 'Notes';

  @override
  String get autoFillLabel => 'Auto Notes';

  @override
  String get hintLabel => 'Hint';

  @override
  String get inputModeQuick => 'Quick';

  @override
  String get difficultyBeginner => 'Bronze';

  @override
  String get difficultyEasy => 'Silver';

  @override
  String get difficultyMedium => 'Gold';

  @override
  String get difficultyHard => 'Diamond';

  @override
  String get difficultyMaster => 'Master';

  @override
  String get difficultyExpert => 'Challenger';

  @override
  String get techniqueFullHouse => 'Full House';

  @override
  String get techniqueNakedSingle => 'Naked Single';

  @override
  String get techniqueHiddenSingle => 'Hidden Single';

  @override
  String get techniqueNakedPair => 'Naked Pair';

  @override
  String get techniqueNakedTriple => 'Naked Triple';

  @override
  String get techniqueNakedQuad => 'Naked Quad';

  @override
  String get techniqueHiddenPair => 'Hidden Pair';

  @override
  String get techniqueHiddenTriple => 'Hidden Triple';

  @override
  String get techniqueHiddenQuad => 'Hidden Quad';

  @override
  String get techniqueIntersectionPointing => 'Intersection (Pointing)';

  @override
  String get techniqueIntersectionClaiming => 'Intersection (Claiming)';

  @override
  String get techniqueLockedPair => 'Locked Pair';

  @override
  String get techniqueLockedTriple => 'Locked Triple';

  @override
  String get techniqueXWing => 'X-Wing';

  @override
  String get techniqueSkyscraper => 'Skyscraper';

  @override
  String get techniqueTwoStringKite => '2-String Kite';

  @override
  String get techniqueTurbotFish => 'Turbot Fish';

  @override
  String get techniqueRemotePair => 'Remote Pair';

  @override
  String get techniqueSimpleColoring => 'Simple Coloring';

  @override
  String get techniqueXYWing => 'XY-Wing';

  @override
  String get techniqueXYZWing => 'XYZ-Wing';

  @override
  String get techniqueWWing => 'W-Wing';

  @override
  String get techniqueSwordfish => 'Swordfish';

  @override
  String get techniqueFinnedXWing => 'Finned X-Wing';

  @override
  String get techniqueSashimiXWing => 'Sashimi X-Wing';

  @override
  String get techniqueBugPlusOne => 'BUG+1';

  @override
  String get techniqueXYChain => 'XY-Chain';

  @override
  String get techniqueJellyfish => 'Jellyfish';

  @override
  String get techniqueFinnedSwordfish => 'Finned Swordfish';

  @override
  String get techniqueFinnedJellyfish => 'Finned Jellyfish';

  @override
  String get techniqueUniqueRectangleType1 => 'Unique Rectangle Type 1';

  @override
  String get techniqueUniqueRectangleType2 => 'Unique Rectangle Type 2';

  @override
  String get techniqueUniqueRectangleType3 => 'Unique Rectangle Type 3';

  @override
  String get techniqueUniqueRectangleType4 => 'Unique Rectangle Type 4';

  @override
  String unitRow(int row) {
    return 'Row $row';
  }

  @override
  String unitCol(int col) {
    return 'Column $col';
  }

  @override
  String unitCell(int row, int col) {
    return 'R${row}C$col';
  }

  @override
  String unitBox(int index, int r1, int r2, int c1, int c2) {
    return 'Box $index (rows $r1-$r2, columns $c1-$c2)';
  }

  @override
  String get wordRows => 'rows';

  @override
  String get wordColumns => 'columns';

  @override
  String explanationFullHouse(String unitDesc, int value) {
    return '$unitDesc has only one empty cell left. Since $value is the only digit from 1-9 missing, it\'s automatically filled in.';
  }

  @override
  String explanationNakedSingle(int row, int col, int value) {
    return 'Row $row, Column $col has only one candidate: $value. Every other digit already appears in its row, column, or box, leaving only $value.';
  }

  @override
  String explanationHiddenSingle(String unitDesc, int value, int row, int col) {
    return 'In $unitDesc, the only empty cell where $value can go is Row $row, Column $col.';
  }

  @override
  String explanationNakedSubset(
      String unitDesc, String cellsDesc, String digitsDesc, int size) {
    return 'In $unitDesc, the combined candidates of $cellsDesc are only $digitsDesc ($size digits). So $digitsDesc can be removed from every other cell in that unit.';
  }

  @override
  String explanationHiddenSubset(
      String unitDesc, String digitsDesc, String cellsDesc) {
    return 'In $unitDesc, digits $digitsDesc can only go in $cellsDesc. Every other candidate can be removed from those cells.';
  }

  @override
  String explanationPointing(String boxDesc, int digit, String lineDesc) {
    return 'Within $boxDesc, digit $digit only appears along $lineDesc. So $digit can be removed from the rest of $lineDesc (outside the box).';
  }

  @override
  String explanationClaiming(String lineDesc, int digit, String boxDesc) {
    return 'Within $lineDesc, digit $digit only appears in $boxDesc. So $digit can be removed from the rest of that box (outside $lineDesc).';
  }

  @override
  String explanationXWing(
      int digit, String linesDesc, String crossDesc, String crossUnitName) {
    return 'Digit $digit can only go in $crossDesc within $linesDesc. Since these four cells form a rectangle, $digit can be removed from the rest of those two $crossUnitName.';
  }

  @override
  String explanationFish(int digit, String linesDesc, String crossDesc,
      String crossUnitName, int size) {
    return 'Digit $digit can only go in $crossDesc ($size cells total) combined across $linesDesc. So $digit can be removed from the rest of those $crossUnitName.';
  }

  @override
  String explanationSkyscraper(int digit, String cell1, String cell2) {
    return 'Digit $digit forms a Skyscraper: two strong links join so that at least one of $cell1 and $cell2 must be $digit. Any cell that sees both can have $digit removed from its candidates.';
  }

  @override
  String explanationTwoStringKite(int digit, String cell1, String cell2) {
    return 'Digit $digit forms a 2-String Kite joined through a shared box, so at least one of $cell1 and $cell2 must be $digit. Any cell that sees both can have $digit removed from its candidates.';
  }

  @override
  String explanationTurbotFish(int digit, String cell1, String cell2) {
    return 'Digit $digit forms a Turbot Fish chain, so at least one of $cell1 and $cell2 must be $digit. Any cell that sees both can have $digit removed from its candidates.';
  }

  @override
  String explanationFinnedFish(
      String mainLineDesc, int digit, String finLineDesc, String finsDesc) {
    return '$mainLineDesc forms a clean X-Wing shape with only two candidate cells for digit $digit. $finLineDesc also has extra candidates at $finsDesc (fins), so it\'s not a pure X-Wing — but cells that see every fin can still have $digit removed from their candidates.';
  }

  @override
  String explanationFinnedFishN(
      String baseLinesDesc, int digit, int size, String finsDesc) {
    return '$baseLinesDesc confine digit $digit to a $size-line fish shape, except for extra candidates (fins) at $finsDesc. If every fin is false this is a true fish; otherwise one of the fins is $digit. Either way, cells that see every fin can have $digit removed from their candidates.';
  }

  @override
  String explanationLockedSubset(String lineDesc, String boxDesc,
      String cellsDesc, String digitsDesc, int size) {
    return '$cellsDesc lie where $lineDesc crosses $boxDesc, and together their only candidates are $digitsDesc ($size digits). Those cells take all $size digits, so $digitsDesc can be removed from the rest of $lineDesc AND the rest of $boxDesc.';
  }

  @override
  String explanationRemotePair(String chainDesc, int a, int b) {
    return '$chainDesc all hold only $a and $b, and each sees the next, so their values alternate along the chain. The two ends sit an odd number of steps apart, so one is $a and the other is $b — meaning any cell seeing both ends can have BOTH $a and $b removed.';
  }

  @override
  String explanationSimpleColoringRule1(int digit, String cellA, String cellB) {
    return 'Chaining digit $digit\'s candidates, $cellA and $cellB — both in the same color group — share a row, column, or box. Since they can\'t both be $digit, this whole group can\'t be $digit. So $digit can be removed from this group\'s cells.';
  }

  @override
  String explanationSimpleColoringRule2(int digit, String cellsDesc) {
    return 'Digit $digit\'s candidate chain ($cellsDesc) splits into two groups with opposite states. Any cell that sees both groups can\'t be $digit regardless of which group is true, so $digit can be removed from its candidates there.';
  }

  @override
  String explanationXYWing(String pivotDesc, int x, int y, String w1Desc,
      int sharedDigitW1, int z, String w2Desc, int otherPivotDigit) {
    return 'Pivot cell $pivotDesc has candidates $x and $y. Wing cell $w1Desc is either $sharedDigitW1 or $z; wing cell $w2Desc is either $otherPivotDigit or $z. If the pivot is $sharedDigitW1, $w1Desc becomes $z; if it\'s $otherPivotDigit, $w2Desc becomes $z. Either way, cells that see both wings can have $z removed from their candidates.';
  }

  @override
  String explanationXYZWing(String pivotDesc, String pivotDigits, String w1Desc,
      String w2Desc, int z) {
    return 'The pivot $pivotDesc has three candidates ($pivotDigits), and its wings $w1Desc and $w2Desc each hold $z plus one of the others. Whichever digit the pivot takes, $z ends up on the pivot or one of the wings — so any cell seeing all three can have $z removed.';
  }

  @override
  String explanationWWing(
      String cell1, String cell2, int a, int b, String unitDesc) {
    return '$cell1 and $cell2 both hold only $a and $b, and $unitDesc has just two places for $b — one seeing each of them. If both were $b, that unit would have nowhere left for $b. So at least one of them is $a, and any cell seeing both can have $a removed.';
  }

  @override
  String explanationXYChain(String chainDesc, int z) {
    return 'The cells chained in order $chainDesc each have only two candidates, so if one end of the chain isn\'t $z, the other end must be. So $z can be removed from cells that see both ends of the chain.';
  }

  @override
  String explanationBugPlusOne(int row, int col, int value) {
    return 'Every empty cell except Row $row, Column $col already has exactly 2 candidates. If this cell weren\'t $value, the whole grid would form a complete BUG (Bi-Value Universal Grave) pattern, which would break this puzzle\'s unique solution. So it must be $value.';
  }

  @override
  String explanationUniqueRectangleType1(String cellsDesc, int a, int b) {
    return '$cellsDesc form a Unique Rectangle (2 rows, 2 columns, 2 boxes), and three of these cells have only candidates $a and $b. If the last cell also had only those two, the puzzle would have two solutions — so $a and $b can be removed from that cell\'s candidates.';
  }

  @override
  String explanationUniqueRectangleType2(
      String cellA, String cellB, int a, int b, int c) {
    return '$cellA and $cellB each have three candidates: $a, $b, and $c. If both were only $a and $b, the puzzle would have two solutions, so one of them must be $c. So $c can be removed from any other cell that sees both.';
  }

  @override
  String explanationUniqueRectangleType3(
      String cellA, String cellB, String digitsDesc) {
    return 'One of $cellA and $cellB must take an extra candidate (if both kept only the rectangle pair, the puzzle would have two solutions). Treating their extra candidates as one virtual cell, they form a set of only $digitsDesc with other cells in that unit — so $digitsDesc can be removed from the rest of that unit.';
  }

  @override
  String explanationUniqueRectangleType4(
      String cellA, String cellB, int lockedDigit, int otherDigit) {
    return 'In the line containing $cellA and $cellB, digit $lockedDigit can only go in these two cells. If $otherDigit remained in both, the puzzle would have two solutions — so $otherDigit can be removed from both cells\' candidates.';
  }

  @override
  String noteRepairNotice(String explanation) {
    return 'Some cells\' notes didn\'t match the board, so they were corrected first. $explanation';
  }

  @override
  String get myPageTitle => 'My Page';

  @override
  String errorOccurred(String message) {
    return 'An error occurred: $message';
  }

  @override
  String get signInPromptTitle => 'Sign in to race other players';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get signInAsGuest => 'Continue as Guest';

  @override
  String ratingAndRecord(int rating, int wins, int losses) {
    return 'Rating $rating · ${wins}W ${losses}L';
  }

  @override
  String winRateLabel(int percent) {
    return 'Race win rate $percent%';
  }

  @override
  String tierPromotionRemaining(int points, String nextTier) {
    return '$points pts to $nextTier';
  }

  @override
  String get tierTopReached => 'Top tier reached';

  @override
  String get ratingTrendTitle => 'Rating Trend';

  @override
  String get linkAccountPrompt =>
      'You\'re signed in as a guest. Link an account to keep your progress.';

  @override
  String get linkGoogleAction => 'Link Google Account';

  @override
  String get linkAppleAction => 'Link Apple Account';

  @override
  String get signOutAction => 'Sign Out';

  @override
  String get shareCodeTitle => 'Share Puzzle';

  @override
  String get enterCodeTitle => 'Enter Code';

  @override
  String get shareCodeTextLabel => 'Text Code';

  @override
  String get invalidTextCodeError => 'That text code isn\'t valid.';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get enterTextCodeHint => 'Room code or puzzle code';

  @override
  String get roomJoinRequiresSignIn =>
      'Sign in to join a friend match. You can sign in from the race lobby.';

  @override
  String get loadButton => 'Enter';

  @override
  String get raceLobbyTitle => 'Race';

  @override
  String get friendMatchButton => 'Play with a Friend';

  @override
  String get rankedMatchButton => 'Ranked Match';

  @override
  String get leaderboardButton => 'Ranking';

  @override
  String get leaderboardTitle => 'Ranking';

  @override
  String leaderboardMyRankLabel(int rank, int total) {
    return 'Your rank: #$rank of $total';
  }

  @override
  String get leaderboardMyRankUnranked => 'No ranked record yet';

  @override
  String get leaderboardEmpty => 'No ranked players yet.';

  @override
  String get leaderboardLoadFailed => 'Couldn\'t load the ranking.';

  @override
  String seasonName(int number) {
    return 'Season $number';
  }

  @override
  String seasonDaysLeft(int days) {
    return 'D-$days';
  }

  @override
  String get pastSeasonsTitle => 'Past Seasons';

  @override
  String seasonStandingDetail(int rank, int wins, int losses) {
    return '#$rank · ${wins}W ${losses}L';
  }

  @override
  String placementProgress(int played, int total) {
    return 'Placements $played/$total';
  }

  @override
  String seasonEndedTitle(int number) {
    return 'Season $number Complete!';
  }

  @override
  String seasonEndedNewStart(int rating) {
    return 'A new season has begun — you restart at rating $rating!';
  }

  @override
  String get okAction => 'OK';

  @override
  String get friendMatchTitle => 'Play with a Friend';

  @override
  String get createRoomTitle => 'Choose difficulty';

  @override
  String get createRoomAction => 'Create Room';

  @override
  String get joinRoomTitle => 'Join Room';

  @override
  String get waitingForFriendTitle => 'Waiting for Friend';

  @override
  String get joinRoomAction => 'Join';

  @override
  String get roomCodeFieldLabel => 'Room code';

  @override
  String get roomCodeInvalid => 'Room not found or expired.';

  @override
  String get roomCodeShareHint => 'Share this code with your friend';

  @override
  String get waitingForFriend => 'Waiting for your friend to join...';

  @override
  String matchmakingElapsed(String time) {
    return 'Waiting $time';
  }

  @override
  String get friendlyMatchLabel => 'Friendly match · no rating change';

  @override
  String get matchmakingTitle => 'Find Opponent';

  @override
  String get matchmakingSearching => 'Searching for an opponent...';

  @override
  String get matchmakingPreparingPuzzle => 'Preparing puzzle...';

  @override
  String get matchmakingReadyCheck => 'Checking readiness...';

  @override
  String get matchmakingTip1 =>
      'Solve today\'s Daily puzzle and check where you rank.';

  @override
  String get matchmakingTip2 =>
      'Finish a puzzle with no hints and no mistakes for a Perfect Clear.';

  @override
  String get matchmakingTip3 =>
      'In ranked matches, the puzzle difficulty is set by your tier.';

  @override
  String get matchmakingTip4 =>
      'Use note mode to pencil in candidate numbers and solve faster.';

  @override
  String get matchmakingTip5 =>
      'Share a room code to race a friend one-on-one.';

  @override
  String get matchmakingTip6 =>
      'Win races to raise your rating and climb to a higher tier.';

  @override
  String get matchmakingTip7 =>
      'Tiers go Bronze > Silver > Gold > Diamond > Master > Challenger. Aim for Challenger.';

  @override
  String get raceAbortConfirmTitle => 'Give up the race?';

  @override
  String opponentDisconnectedCountdown(int seconds) {
    return 'Opponent disconnected — you win in ${seconds}s';
  }

  @override
  String get opponentProgressLabel => 'Opponent';

  @override
  String get raceResultTitle => 'Race Result';

  @override
  String get raceWon => 'You Won!';

  @override
  String get raceLost => 'You Lost';

  @override
  String get tierBronze => 'Bronze';

  @override
  String get tierSilver => 'Silver';

  @override
  String get tierGold => 'Gold';

  @override
  String get tierDiamond => 'Diamond';

  @override
  String get tierMaster => 'Master';

  @override
  String get tierChallenger => 'Challenger';

  @override
  String yourRatingChangeLabel(int oldRating, int newRating, String delta) {
    return 'You: $oldRating → $newRating ($delta)';
  }

  @override
  String opponentRatingChangeLabel(
      String username, int oldRating, int newRating, String delta) {
    return '$username: $oldRating → $newRating ($delta)';
  }

  @override
  String homeRatingLabel(String tier, int rating) {
    return '$tier · Rating $rating';
  }

  @override
  String get dailyButton => 'Daily Sudoku';

  @override
  String get dailyTitle => 'Daily Sudoku';

  @override
  String get dailyLoading => 'Preparing today\'s puzzle...';

  @override
  String get dailySignInPromptTitle => 'Sign in to play the Daily Sudoku';

  @override
  String get dailyResultTitle => 'Today\'s Result';

  @override
  String dailyMyRankLabel(int rank, int total) {
    return 'Ranked #$rank of $total today';
  }

  @override
  String get dailyLeaderboardTitle => 'Top 10';

  @override
  String get dailyEmptyLeaderboard => 'No one has finished yet.';

  @override
  String get dailyReplayAction => 'Play Again';

  @override
  String get dailyNotRankedNotice => 'Only your first clear is recorded.';

  @override
  String get dailySubmitFailed => 'Couldn\'t submit your result.';

  @override
  String get retryAction => 'Retry';

  @override
  String get hintStepPrevAction => 'Back';

  @override
  String get hintStepNextAction => 'Next';

  @override
  String hintStepXYWingPivot(String pivot, int x, int y) {
    return 'The pivot $pivot has only two candidates: $x and $y.';
  }

  @override
  String hintStepWingCase(int digit, String wing, int z) {
    return 'If the pivot is $digit, $wing loses $digit — so it must be $z.';
  }

  @override
  String hintStepXYWingConclusion(int z) {
    return 'Either way, one of the two wings is $z. Any cell that sees both wings can\'t be $z.';
  }

  @override
  String hintStepXYZWingPivot(String pivot, String digits) {
    return 'The pivot $pivot has three candidates: $digits.';
  }

  @override
  String hintStepXYZWingPivotZ(int z) {
    return 'And the pivot could be $z itself — that\'s the third case.';
  }

  @override
  String hintStepXYZWingConclusion(int z) {
    return 'In every case, one of the three cells is $z. Any cell that sees all three can\'t be $z.';
  }

  @override
  String hintStepWWingPair(String cell1, String cell2, int a, int b) {
    return '$cell1 and $cell2 hold exactly the same pair: $a and $b.';
  }

  @override
  String hintStepWWingBridge(String unitDesc, int b) {
    return 'In $unitDesc, $b fits in only two places — and each one sees one of the pair cells.';
  }

  @override
  String hintStepWWingForced(int a, int b) {
    return 'If both pair cells were $b, that unit would have nowhere left for $b. So at least one of them is $a.';
  }

  @override
  String hintStepWWingConclusion(int a) {
    return 'Any cell that sees both pair cells can\'t be $a.';
  }

  @override
  String hintStepChainStart(String cell, int z, int a) {
    return 'Start at $cell: if it isn\'t $z, it must be $a.';
  }

  @override
  String hintStepChainHop(String cell, int carry, int next) {
    return 'Then $cell can\'t be $carry, so it must be $next.';
  }

  @override
  String hintStepChainConclusion(int z) {
    return 'So either the start is $z, or the end is $z. Any cell that sees both ends can\'t be $z.';
  }

  @override
  String hintStepRemotePairIntro(int a, int b) {
    return 'Every cell in this chain holds the same pair: $a and $b.';
  }

  @override
  String hintStepRemotePairAlternate(int a, int b) {
    return 'Neighbors see each other, so the values must alternate $a, $b, $a, $b along the chain.';
  }

  @override
  String hintStepRemotePairEnds(int a, int b) {
    return 'The two ends are an odd number of hops apart, so one is $a and the other is $b — always.';
  }

  @override
  String hintStepRemotePairConclusion(int a, int b) {
    return 'Any cell that sees both ends can be neither $a nor $b.';
  }

  @override
  String hintStepSingleDigitStrong1(int digit, String cell1, String cell2) {
    return '$cell1 and $cell2 are the only two spots for $digit in their unit — one of them must be $digit.';
  }

  @override
  String hintStepSingleDigitStrong2(int digit, String cell1, String cell2) {
    return '$cell1 and $cell2 are another only-two-spots pair, and the two middle cells see each other.';
  }

  @override
  String hintStepSingleDigitForced(int digit, String cell1, String cell2) {
    return 'The middle cells can\'t both be $digit, so at least one of the free ends $cell1 and $cell2 must be $digit.';
  }

  @override
  String hintStepSingleDigitConclusion(int digit) {
    return 'Any cell that sees both free ends can\'t be $digit.';
  }

  @override
  String hintStepColoringChain(int digit) {
    return 'Cells linked as the only two spots for $digit form a chain — neighbors are opposites, so they split into two colors.';
  }

  @override
  String hintStepColoringRule1Clash(int digit, String cell1, String cell2) {
    return '$cell1 and $cell2 share a color AND see each other — a color can\'t hold $digit twice, so that whole color is wrong.';
  }

  @override
  String hintStepColoringRule1Conclusion(int digit) {
    return 'Every cell of the wrong color loses $digit.';
  }

  @override
  String hintStepColoringRule2Conclusion(int digit) {
    return 'One of the two colors must be true. A cell that sees both colors can\'t be $digit either way.';
  }

  @override
  String hintStepXWingLines(int digit, String linesDesc) {
    return 'Digit $digit fits in only two spots in each of $linesDesc.';
  }

  @override
  String hintStepXWingRect(int digit, String crossDesc) {
    return 'The four spots form a rectangle — however it resolves, $crossDesc each get exactly one $digit inside it.';
  }

  @override
  String hintStepXWingConclusion(int digit, String crossUnitName) {
    return 'So the rest of those two $crossUnitName can\'t hold $digit.';
  }

  @override
  String hintStepFullHouseIntro(String unitDesc) {
    return 'Only one cell in $unitDesc is still empty.';
  }

  @override
  String hintStepNakedSingleIntro(String cell) {
    return 'Narrow down $cell: cross off every digit already placed in its row, column, and box.';
  }

  @override
  String hintStepHiddenSingleIntro(int digit) {
    return 'One area has only a single spot left where $digit can go — the highlighted digits block every other cell.';
  }

  @override
  String get hintStepBugIntro =>
      'If every empty cell kept exactly two candidates, the puzzle would end up with two solutions. Exactly one cell holds three — that cell is the way out.';

  @override
  String hintStepNakedSubsetIntro(int count, String digits, String unitDesc) {
    return 'In $unitDesc, the $count highlighted cells hold only $digits between them.';
  }

  @override
  String hintStepHiddenSubsetIntro(int count, String digits, String unitDesc) {
    return 'In $unitDesc, $digits can only go in the $count highlighted cells.';
  }

  @override
  String hintStepPointingIntro(int digit, String boxDesc, String lineDesc) {
    return 'Inside $boxDesc, every spot for $digit sits on $lineDesc.';
  }

  @override
  String hintStepClaimingIntro(int digit, String lineDesc, String boxDesc) {
    return 'In $lineDesc, every spot for $digit sits inside $boxDesc.';
  }

  @override
  String hintStepFishIntro(int digit, String linesDesc) {
    return 'Look at $linesDesc: the spots where $digit can go there are pinned to just a few crossing lines.';
  }

  @override
  String get hintStepURIntro =>
      'The highlighted cells form a rectangle sharing one candidate pair. If all four kept only that pair, the puzzle would have two solutions — which is impossible.';

  @override
  String get replayTitle => 'Replay';

  @override
  String get replayEmpty => 'No games to replay yet.';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumLockTitle => 'Premium feature';

  @override
  String get replayPremiumBody =>
      'Replay your recent games move by move and pick up solving again — retrace every entry and note in the exact order you made them.';

  @override
  String get replayResumeFromHere => 'Solve from here';

  @override
  String get raceReplayUnavailable =>
      'No replay saved for this game on this device.';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritePremiumBody =>
      'Save puzzles to your favorites and replay them fresh whenever you like.';

  @override
  String get favoritesEmpty => 'No saved puzzles yet.';

  @override
  String get favoriteSaved => 'Saved to favorites.';

  @override
  String get favoriteRemoved => 'Removed from favorites.';

  @override
  String favoriteFull(int count) {
    return 'Favorites are full (max $count).';
  }

  @override
  String get themePackSectionTitle => 'Theme Pack';

  @override
  String get themePackClassic => 'Classic';

  @override
  String get themePackMidnightNeon => 'Midnight Neon';

  @override
  String get themePackSepiaPaper => 'Sepia Paper';

  @override
  String get themePackMonochrome => 'Monochrome';

  @override
  String get themePackForest => 'Forest';

  @override
  String get themePackOcean => 'Ocean';

  @override
  String get themePremiumBody =>
      'Restyle the board and the whole app with premium theme packs — five distinct looks to choose from.';

  @override
  String get codexTitle => 'Technique Codex';

  @override
  String codexProgress(int met, int total) {
    return 'Discovered $met / $total';
  }

  @override
  String codexUsage(int uses, int puzzles) {
    return '$uses× · $puzzles puzzles';
  }

  @override
  String get codexUndiscovered => 'Not yet';
}
