import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sudoku'**
  String get appTitle;

  /// No description provided for @homeButton.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeButton;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

  /// No description provided for @applyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyAction;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startGame;

  /// No description provided for @raceButton.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get raceButton;

  /// No description provided for @themeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSectionTitle;

  /// No description provided for @followSystemTheme.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkTheme;

  /// No description provided for @hapticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get hapticsLabel;

  /// No description provided for @soundLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundLabel;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// No description provided for @followSystemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystemLanguage;

  /// No description provided for @koreanLanguage.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get koreanLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @mistakesLabel.
  ///
  /// In en, this message translates to:
  /// **'Mistakes: {current}/{max}'**
  String mistakesLabel(int current, int max);

  /// No description provided for @exitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'End the game?'**
  String get exitDialogTitle;

  /// No description provided for @restartAction.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restartAction;

  /// No description provided for @endGameAction.
  ///
  /// In en, this message translates to:
  /// **'End Game'**
  String get endGameAction;

  /// No description provided for @gameOverTitle.
  ///
  /// In en, this message translates to:
  /// **'3 Mistakes'**
  String get gameOverTitle;

  /// No description provided for @gameOverContent.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to continue?'**
  String get gameOverContent;

  /// No description provided for @giveUpAction.
  ///
  /// In en, this message translates to:
  /// **'Give Up and Exit'**
  String get giveUpAction;

  /// No description provided for @noHintAvailable.
  ///
  /// In en, this message translates to:
  /// **'No hint is available right now.'**
  String get noHintAvailable;

  /// No description provided for @clearWrongFirst.
  ///
  /// In en, this message translates to:
  /// **'Please clear the wrong answer first.'**
  String get clearWrongFirst;

  /// No description provided for @adNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'The ad hasn\'t loaded yet. Please try again in a moment.'**
  String get adNotLoaded;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get resultTitle;

  /// No description provided for @perfectClearBadge.
  ///
  /// In en, this message translates to:
  /// **'No Mistakes! Perfect Clear'**
  String get perfectClearBadge;

  /// No description provided for @mistakesAndHints.
  ///
  /// In en, this message translates to:
  /// **'Mistakes: {mistakes} · Hints used: {hints}'**
  String mistakesAndHints(int mistakes, int hints);

  /// No description provided for @personalBestTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Best'**
  String get personalBestTitle;

  /// No description provided for @firstClear.
  ///
  /// In en, this message translates to:
  /// **'First clear for this difficulty!'**
  String get firstClear;

  /// No description provided for @newBest.
  ///
  /// In en, this message translates to:
  /// **'🏆 New personal best! (Previous: {time})'**
  String newBest(String time);

  /// No description provided for @currentBest.
  ///
  /// In en, this message translates to:
  /// **'Personal best: {time}'**
  String currentBest(String time);

  /// No description provided for @comparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Global Player Comparison'**
  String get comparisonTitle;

  /// No description provided for @topPercent.
  ///
  /// In en, this message translates to:
  /// **'Top {percent}%'**
  String topPercent(int percent);

  /// No description provided for @mockDataDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'* This is sample data, not real user data.'**
  String get mockDataDisclaimer;

  /// No description provided for @techniquesUsedTitle.
  ///
  /// In en, this message translates to:
  /// **'Techniques Used'**
  String get techniquesUsedTitle;

  /// No description provided for @highestTechniqueLabel.
  ///
  /// In en, this message translates to:
  /// **'Hardest technique:'**
  String get highestTechniqueLabel;

  /// No description provided for @techniqueUsageCount.
  ///
  /// In en, this message translates to:
  /// **'×{count}'**
  String techniqueUsageCount(int count);

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsTitle;

  /// No description provided for @playedWonLabel.
  ///
  /// In en, this message translates to:
  /// **'Played {played} · Won {won}'**
  String playedWonLabel(int played, int won);

  /// No description provided for @bestTimeSuffix.
  ///
  /// In en, this message translates to:
  /// **' · Best {time}'**
  String bestTimeSuffix(String time);

  /// No description provided for @raceHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Race History'**
  String get raceHistoryTitle;

  /// No description provided for @raceHistoryResultWon.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get raceHistoryResultWon;

  /// No description provided for @raceHistoryResultLost.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get raceHistoryResultLost;

  /// No description provided for @raceHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No races yet.'**
  String get raceHistoryEmpty;

  /// No description provided for @undoLabel.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoLabel;

  /// No description provided for @eraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get eraseLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get noteLabel;

  /// No description provided for @autoFillLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto Notes'**
  String get autoFillLabel;

  /// No description provided for @hintLabel.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hintLabel;

  /// No description provided for @difficultyBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get difficultyBeginner;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @difficultyMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get difficultyMaster;

  /// No description provided for @difficultyExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get difficultyExpert;

  /// No description provided for @techniqueFullHouse.
  ///
  /// In en, this message translates to:
  /// **'Full House'**
  String get techniqueFullHouse;

  /// No description provided for @techniqueNakedSingle.
  ///
  /// In en, this message translates to:
  /// **'Naked Single'**
  String get techniqueNakedSingle;

  /// No description provided for @techniqueHiddenSingle.
  ///
  /// In en, this message translates to:
  /// **'Hidden Single'**
  String get techniqueHiddenSingle;

  /// No description provided for @techniqueNakedPair.
  ///
  /// In en, this message translates to:
  /// **'Naked Pair'**
  String get techniqueNakedPair;

  /// No description provided for @techniqueNakedTriple.
  ///
  /// In en, this message translates to:
  /// **'Naked Triple'**
  String get techniqueNakedTriple;

  /// No description provided for @techniqueNakedQuad.
  ///
  /// In en, this message translates to:
  /// **'Naked Quad'**
  String get techniqueNakedQuad;

  /// No description provided for @techniqueHiddenPair.
  ///
  /// In en, this message translates to:
  /// **'Hidden Pair'**
  String get techniqueHiddenPair;

  /// No description provided for @techniqueHiddenTriple.
  ///
  /// In en, this message translates to:
  /// **'Hidden Triple'**
  String get techniqueHiddenTriple;

  /// No description provided for @techniqueHiddenQuad.
  ///
  /// In en, this message translates to:
  /// **'Hidden Quad'**
  String get techniqueHiddenQuad;

  /// No description provided for @techniqueIntersectionPointing.
  ///
  /// In en, this message translates to:
  /// **'Intersection (Pointing)'**
  String get techniqueIntersectionPointing;

  /// No description provided for @techniqueIntersectionClaiming.
  ///
  /// In en, this message translates to:
  /// **'Intersection (Claiming)'**
  String get techniqueIntersectionClaiming;

  /// No description provided for @techniqueXWing.
  ///
  /// In en, this message translates to:
  /// **'X-Wing'**
  String get techniqueXWing;

  /// No description provided for @techniqueSimpleColoring.
  ///
  /// In en, this message translates to:
  /// **'Simple Coloring'**
  String get techniqueSimpleColoring;

  /// No description provided for @techniqueXYWing.
  ///
  /// In en, this message translates to:
  /// **'XY-Wing'**
  String get techniqueXYWing;

  /// No description provided for @techniqueSwordfish.
  ///
  /// In en, this message translates to:
  /// **'Swordfish'**
  String get techniqueSwordfish;

  /// No description provided for @techniqueFinnedXWing.
  ///
  /// In en, this message translates to:
  /// **'Finned X-Wing'**
  String get techniqueFinnedXWing;

  /// No description provided for @techniqueSashimiXWing.
  ///
  /// In en, this message translates to:
  /// **'Sashimi X-Wing'**
  String get techniqueSashimiXWing;

  /// No description provided for @techniqueBugPlusOne.
  ///
  /// In en, this message translates to:
  /// **'BUG+1'**
  String get techniqueBugPlusOne;

  /// No description provided for @techniqueXYChain.
  ///
  /// In en, this message translates to:
  /// **'XY-Chain'**
  String get techniqueXYChain;

  /// No description provided for @techniqueJellyfish.
  ///
  /// In en, this message translates to:
  /// **'Jellyfish'**
  String get techniqueJellyfish;

  /// No description provided for @techniqueUniqueRectangleType1.
  ///
  /// In en, this message translates to:
  /// **'Unique Rectangle Type 1'**
  String get techniqueUniqueRectangleType1;

  /// No description provided for @techniqueUniqueRectangleType2.
  ///
  /// In en, this message translates to:
  /// **'Unique Rectangle Type 2'**
  String get techniqueUniqueRectangleType2;

  /// No description provided for @techniqueUniqueRectangleType3.
  ///
  /// In en, this message translates to:
  /// **'Unique Rectangle Type 3'**
  String get techniqueUniqueRectangleType3;

  /// No description provided for @techniqueUniqueRectangleType4.
  ///
  /// In en, this message translates to:
  /// **'Unique Rectangle Type 4'**
  String get techniqueUniqueRectangleType4;

  /// No description provided for @unitRow.
  ///
  /// In en, this message translates to:
  /// **'Row {row}'**
  String unitRow(int row);

  /// No description provided for @unitCol.
  ///
  /// In en, this message translates to:
  /// **'Column {col}'**
  String unitCol(int col);

  /// No description provided for @unitCell.
  ///
  /// In en, this message translates to:
  /// **'R{row}C{col}'**
  String unitCell(int row, int col);

  /// No description provided for @unitBox.
  ///
  /// In en, this message translates to:
  /// **'Box {index} (rows {r1}-{r2}, columns {c1}-{c2})'**
  String unitBox(int index, int r1, int r2, int c1, int c2);

  /// No description provided for @wordRows.
  ///
  /// In en, this message translates to:
  /// **'rows'**
  String get wordRows;

  /// No description provided for @wordColumns.
  ///
  /// In en, this message translates to:
  /// **'columns'**
  String get wordColumns;

  /// No description provided for @explanationFullHouse.
  ///
  /// In en, this message translates to:
  /// **'{unitDesc} has only one empty cell left. Since {value} is the only digit from 1-9 missing, it\'s automatically filled in.'**
  String explanationFullHouse(String unitDesc, int value);

  /// No description provided for @explanationNakedSingle.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, Column {col} has only one candidate: {value}. Every other digit already appears in its row, column, or box, leaving only {value}.'**
  String explanationNakedSingle(int row, int col, int value);

  /// No description provided for @explanationHiddenSingle.
  ///
  /// In en, this message translates to:
  /// **'In {unitDesc}, the only empty cell where {value} can go is Row {row}, Column {col}.'**
  String explanationHiddenSingle(String unitDesc, int value, int row, int col);

  /// No description provided for @explanationNakedSubset.
  ///
  /// In en, this message translates to:
  /// **'In {unitDesc}, the combined candidates of {cellsDesc} are only {digitsDesc} ({size} digits). So {digitsDesc} can be removed from every other cell in that unit.'**
  String explanationNakedSubset(
      String unitDesc, String cellsDesc, String digitsDesc, int size);

  /// No description provided for @explanationHiddenSubset.
  ///
  /// In en, this message translates to:
  /// **'In {unitDesc}, digits {digitsDesc} can only go in {cellsDesc}. Every other candidate can be removed from those cells.'**
  String explanationHiddenSubset(
      String unitDesc, String digitsDesc, String cellsDesc);

  /// No description provided for @explanationPointing.
  ///
  /// In en, this message translates to:
  /// **'Within {boxDesc}, digit {digit} only appears along {lineDesc}. So {digit} can be removed from the rest of {lineDesc} (outside the box).'**
  String explanationPointing(String boxDesc, int digit, String lineDesc);

  /// No description provided for @explanationClaiming.
  ///
  /// In en, this message translates to:
  /// **'Within {lineDesc}, digit {digit} only appears in {boxDesc}. So {digit} can be removed from the rest of that box (outside {lineDesc}).'**
  String explanationClaiming(String lineDesc, int digit, String boxDesc);

  /// No description provided for @explanationXWing.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} can only go in {crossDesc} within {linesDesc}. Since these four cells form a rectangle, {digit} can be removed from the rest of those two {crossUnitName}.'**
  String explanationXWing(
      int digit, String linesDesc, String crossDesc, String crossUnitName);

  /// No description provided for @explanationFish.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} can only go in {crossDesc} ({size} cells total) combined across {linesDesc}. So {digit} can be removed from the rest of those {crossUnitName}.'**
  String explanationFish(int digit, String linesDesc, String crossDesc,
      String crossUnitName, int size);

  /// No description provided for @explanationFinnedFish.
  ///
  /// In en, this message translates to:
  /// **'{mainLineDesc} forms a clean X-Wing shape with only two candidate cells for digit {digit}. {finLineDesc} also has extra candidates at {finsDesc} (fins), so it\'s not a pure X-Wing — but cells that see every fin can still have {digit} removed from their candidates.'**
  String explanationFinnedFish(
      String mainLineDesc, int digit, String finLineDesc, String finsDesc);

  /// No description provided for @explanationSimpleColoringRule1.
  ///
  /// In en, this message translates to:
  /// **'Chaining digit {digit}\'s candidates, {cellA} and {cellB} — both in the same color group — share a row, column, or box. Since they can\'t both be {digit}, this whole group can\'t be {digit}. So {digit} can be removed from this group\'s cells.'**
  String explanationSimpleColoringRule1(int digit, String cellA, String cellB);

  /// No description provided for @explanationSimpleColoringRule2.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit}\'s candidate chain ({cellsDesc}) splits into two groups with opposite states. Any cell that sees both groups can\'t be {digit} regardless of which group is true, so {digit} can be removed from its candidates there.'**
  String explanationSimpleColoringRule2(int digit, String cellsDesc);

  /// No description provided for @explanationXYWing.
  ///
  /// In en, this message translates to:
  /// **'Pivot cell {pivotDesc} has candidates {x} and {y}. Wing cell {w1Desc} is either {sharedDigitW1} or {z}; wing cell {w2Desc} is either {otherPivotDigit} or {z}. If the pivot is {sharedDigitW1}, {w1Desc} becomes {z}; if it\'s {otherPivotDigit}, {w2Desc} becomes {z}. Either way, cells that see both wings can have {z} removed from their candidates.'**
  String explanationXYWing(String pivotDesc, int x, int y, String w1Desc,
      int sharedDigitW1, int z, String w2Desc, int otherPivotDigit);

  /// No description provided for @explanationXYChain.
  ///
  /// In en, this message translates to:
  /// **'The cells chained in order {chainDesc} each have only two candidates, so if one end of the chain isn\'t {z}, the other end must be. So {z} can be removed from cells that see both ends of the chain.'**
  String explanationXYChain(String chainDesc, int z);

  /// No description provided for @explanationBugPlusOne.
  ///
  /// In en, this message translates to:
  /// **'Every empty cell except Row {row}, Column {col} already has exactly 2 candidates. If this cell weren\'t {value}, the whole grid would form a complete BUG (Bi-Value Universal Grave) pattern, which would break this puzzle\'s unique solution. So it must be {value}.'**
  String explanationBugPlusOne(int row, int col, int value);

  /// No description provided for @explanationUniqueRectangleType1.
  ///
  /// In en, this message translates to:
  /// **'{cellsDesc} form a Unique Rectangle (2 rows, 2 columns, 2 boxes), and three of these cells have only candidates {a} and {b}. If the last cell also had only those two, the puzzle would have two solutions — so {a} and {b} can be removed from that cell\'s candidates.'**
  String explanationUniqueRectangleType1(String cellsDesc, int a, int b);

  /// No description provided for @explanationUniqueRectangleType2.
  ///
  /// In en, this message translates to:
  /// **'{cellA} and {cellB} each have three candidates: {a}, {b}, and {c}. If both were only {a} and {b}, the puzzle would have two solutions, so one of them must be {c}. So {c} can be removed from any other cell that sees both.'**
  String explanationUniqueRectangleType2(
      String cellA, String cellB, int a, int b, int c);

  /// No description provided for @explanationUniqueRectangleType3.
  ///
  /// In en, this message translates to:
  /// **'Combining the extra candidates of {cellA} and {cellB}, they form a set of only {digitsDesc} together with other cells in that unit. So {digitsDesc} can be removed from the rest of that unit\'s cells.'**
  String explanationUniqueRectangleType3(
      String cellA, String cellB, String digitsDesc);

  /// No description provided for @explanationUniqueRectangleType4.
  ///
  /// In en, this message translates to:
  /// **'In the line containing {cellA} and {cellB}, digit {lockedDigit} can only go in these two cells. If {otherDigit} remained in both, the puzzle would have two solutions — so {otherDigit} can be removed from both cells\' candidates.'**
  String explanationUniqueRectangleType4(
      String cellA, String cellB, int lockedDigit, int otherDigit);

  /// No description provided for @noteRepairNotice.
  ///
  /// In en, this message translates to:
  /// **'Notes needed to be corrected first. {explanation}'**
  String noteRepairNotice(String explanation);

  /// No description provided for @myPageTitle.
  ///
  /// In en, this message translates to:
  /// **'My Page'**
  String get myPageTitle;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {message}'**
  String errorOccurred(String message);

  /// No description provided for @signInPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to race other players'**
  String get signInPromptTitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInWithApple;

  /// No description provided for @signInAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get signInAsGuest;

  /// No description provided for @ratingAndRecord.
  ///
  /// In en, this message translates to:
  /// **'Rating {rating} · {wins}W {losses}L'**
  String ratingAndRecord(int rating, int wins, int losses);

  /// No description provided for @winRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Race win rate {percent}%'**
  String winRateLabel(int percent);

  /// No description provided for @linkAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in as a guest. Link an account to keep your progress.'**
  String get linkAccountPrompt;

  /// No description provided for @linkGoogleAction.
  ///
  /// In en, this message translates to:
  /// **'Link Google Account'**
  String get linkGoogleAction;

  /// No description provided for @linkAppleAction.
  ///
  /// In en, this message translates to:
  /// **'Link Apple Account'**
  String get linkAppleAction;

  /// No description provided for @signOutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutAction;

  /// No description provided for @shareCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Puzzle'**
  String get shareCodeTitle;

  /// No description provided for @enterCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Code'**
  String get enterCodeTitle;

  /// No description provided for @shareCodeTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Text Code'**
  String get shareCodeTextLabel;

  /// No description provided for @invalidTextCodeError.
  ///
  /// In en, this message translates to:
  /// **'That text code isn\'t valid.'**
  String get invalidTextCodeError;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @enterTextCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Paste text code'**
  String get enterTextCodeHint;

  /// No description provided for @loadButton.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get loadButton;

  /// No description provided for @matchmakingTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Opponent'**
  String get matchmakingTitle;

  /// No description provided for @matchmakingSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for an opponent...'**
  String get matchmakingSearching;

  /// No description provided for @matchmakingPreparingPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Preparing puzzle...'**
  String get matchmakingPreparingPuzzle;

  /// No description provided for @matchmakingReadyCheck.
  ///
  /// In en, this message translates to:
  /// **'Checking readiness...'**
  String get matchmakingReadyCheck;

  /// No description provided for @raceAbortConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Give up the race?'**
  String get raceAbortConfirmTitle;

  /// No description provided for @opponentLeftBanner.
  ///
  /// In en, this message translates to:
  /// **'Opponent disconnected'**
  String get opponentLeftBanner;

  /// No description provided for @opponentProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get opponentProgressLabel;

  /// No description provided for @raceResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Race Result'**
  String get raceResultTitle;

  /// No description provided for @raceWon.
  ///
  /// In en, this message translates to:
  /// **'You Won!'**
  String get raceWon;

  /// No description provided for @raceLost.
  ///
  /// In en, this message translates to:
  /// **'You Lost'**
  String get raceLost;

  /// No description provided for @tierBronze.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get tierBronze;

  /// No description provided for @tierSilver.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get tierSilver;

  /// No description provided for @tierGold.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tierGold;

  /// No description provided for @tierPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get tierPlatinum;

  /// No description provided for @tierDiamond.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get tierDiamond;

  /// No description provided for @tierMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get tierMaster;

  /// No description provided for @tierChallenger.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get tierChallenger;

  /// No description provided for @yourRatingChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'You: {oldRating} → {newRating} ({delta})'**
  String yourRatingChangeLabel(int oldRating, int newRating, String delta);

  /// No description provided for @opponentRatingChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{username}: {oldRating} → {newRating} ({delta})'**
  String opponentRatingChangeLabel(
      String username, int oldRating, int newRating, String delta);

  /// No description provided for @homeRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'{tier} · Rating {rating}'**
  String homeRatingLabel(String tier, int rating);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
