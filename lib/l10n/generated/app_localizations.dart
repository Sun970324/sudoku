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
  /// **'Sudoku League'**
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

  /// No description provided for @hintRevealMoreAction.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get hintRevealMoreAction;

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

  /// No description provided for @tutorialNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutorialNext;

  /// No description provided for @tutorialSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutorialSkip;

  /// No description provided for @tutorialDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tutorialDone;

  /// No description provided for @tutorialReplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Replay tutorial'**
  String get tutorialReplayLabel;

  /// No description provided for @tutorialHomeDifficultyTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a difficulty'**
  String get tutorialHomeDifficultyTitle;

  /// No description provided for @tutorialHomeDifficultyBody.
  ///
  /// In en, this message translates to:
  /// **'Spin this wheel to choose how hard your puzzle will be.'**
  String get tutorialHomeDifficultyBody;

  /// No description provided for @tutorialHomeStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start playing'**
  String get tutorialHomeStartTitle;

  /// No description provided for @tutorialHomeStartBody.
  ///
  /// In en, this message translates to:
  /// **'Tap here to begin a new puzzle at the difficulty you picked.'**
  String get tutorialHomeStartBody;

  /// No description provided for @tutorialHomeIconsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top menu'**
  String get tutorialHomeIconsTitle;

  /// No description provided for @tutorialHomeIconsBody.
  ///
  /// In en, this message translates to:
  /// **'These icons open stats, enter a shared puzzle code, your profile, and settings.'**
  String get tutorialHomeIconsBody;

  /// No description provided for @tutorialHomeRaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get tutorialHomeRaceTitle;

  /// No description provided for @tutorialHomeRaceBody.
  ///
  /// In en, this message translates to:
  /// **'Take on a friend or other players in a real-time sudoku match.'**
  String get tutorialHomeRaceBody;

  /// No description provided for @tutorialHomeDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get tutorialHomeDailyTitle;

  /// No description provided for @tutorialHomeDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Solve today\'s puzzle and check where you rank.'**
  String get tutorialHomeDailyBody;

  /// No description provided for @tutorialGameGridTitle.
  ///
  /// In en, this message translates to:
  /// **'The board'**
  String get tutorialGameGridTitle;

  /// No description provided for @tutorialGameGridBody.
  ///
  /// In en, this message translates to:
  /// **'Tap an empty cell to select it, then choose a number to fill it in.'**
  String get tutorialGameGridBody;

  /// No description provided for @tutorialGameNumbersTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter numbers'**
  String get tutorialGameNumbersTitle;

  /// No description provided for @tutorialGameNumbersBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a number here to place it in the selected cell.'**
  String get tutorialGameNumbersBody;

  /// No description provided for @tutorialGameNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note mode'**
  String get tutorialGameNoteTitle;

  /// No description provided for @tutorialGameNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Turn this on to pencil in small candidate numbers before committing.'**
  String get tutorialGameNoteBody;

  /// No description provided for @tutorialGameHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Need a hand?'**
  String get tutorialGameHintTitle;

  /// No description provided for @tutorialGameHintBody.
  ///
  /// In en, this message translates to:
  /// **'Stuck? Get a hint by watching a short ad — the badge marks ad-gated helpers.'**
  String get tutorialGameHintBody;

  /// No description provided for @tutorialGameMistakesTitle.
  ///
  /// In en, this message translates to:
  /// **'Mistake limit'**
  String get tutorialGameMistakesTitle;

  /// No description provided for @tutorialGameMistakesBody.
  ///
  /// In en, this message translates to:
  /// **'The game ends after 3 mistakes, so place each number carefully.'**
  String get tutorialGameMistakesBody;

  /// No description provided for @tutorialQuickInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick input'**
  String get tutorialQuickInputTitle;

  /// No description provided for @tutorialQuickInputBody.
  ///
  /// In en, this message translates to:
  /// **'Turn this on to pick a number first, then tap cells to fill them fast. Memo digits work the same way.'**
  String get tutorialQuickInputBody;

  /// No description provided for @tutorialRaceProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your standing'**
  String get tutorialRaceProfileTitle;

  /// No description provided for @tutorialRaceProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Your tier, rating, and win-loss record show up here.'**
  String get tutorialRaceProfileBody;

  /// No description provided for @tutorialRaceFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Play a friend'**
  String get tutorialRaceFriendTitle;

  /// No description provided for @tutorialRaceFriendBody.
  ///
  /// In en, this message translates to:
  /// **'Share a room code to race a friend one-on-one.'**
  String get tutorialRaceFriendBody;

  /// No description provided for @tutorialRaceRankedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ranked match'**
  String get tutorialRaceRankedTitle;

  /// No description provided for @tutorialRaceRankedBody.
  ///
  /// In en, this message translates to:
  /// **'Get matched with a similar opponent — your tier sets the difficulty.'**
  String get tutorialRaceRankedBody;

  /// No description provided for @tutorialRaceLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get tutorialRaceLeaderboardTitle;

  /// No description provided for @tutorialRaceLeaderboardBody.
  ///
  /// In en, this message translates to:
  /// **'See how you rank against everyone else.'**
  String get tutorialRaceLeaderboardBody;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startGame;

  /// No description provided for @generatingPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generatingPuzzle;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceTitle;

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

  /// No description provided for @wrongNoteWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Prevent on Wrong Notes'**
  String get wrongNoteWarningLabel;

  /// No description provided for @wrongNoteWarningDescription.
  ///
  /// In en, this message translates to:
  /// **'Blocks notes for a number already placed in the same row, column, or box.'**
  String get wrongNoteWarningDescription;

  /// No description provided for @autoRemoveNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-clear Notes on Confirm'**
  String get autoRemoveNotesLabel;

  /// No description provided for @autoRemoveNotesDescription.
  ///
  /// In en, this message translates to:
  /// **'Placing a number clears matching notes in the same row, column, and box.'**
  String get autoRemoveNotesDescription;

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

  /// No description provided for @hintNoTechniqueWithNotes.
  ///
  /// In en, this message translates to:
  /// **'No technique can be applied with your current notes.'**
  String get hintNoTechniqueWithNotes;

  /// No description provided for @hintAutoGenerateCandidatesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Generate candidate notes automatically and analyze again?'**
  String get hintAutoGenerateCandidatesPrompt;

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
  /// **'Perfect Clear'**
  String get perfectClearBadge;

  /// No description provided for @perfectClearFlavor1.
  ///
  /// In en, this message translates to:
  /// **'Hint? What\'s that? 😎'**
  String get perfectClearFlavor1;

  /// No description provided for @perfectClearFlavor2.
  ///
  /// In en, this message translates to:
  /// **'You didn\'t even give yourself a chance to mess up.'**
  String get perfectClearFlavor2;

  /// No description provided for @perfectClearFlavor3.
  ///
  /// In en, this message translates to:
  /// **'The numbers practically lined themselves up.'**
  String get perfectClearFlavor3;

  /// No description provided for @perfectClearFlavor4.
  ///
  /// In en, this message translates to:
  /// **'Was 9×9 too easy for you?'**
  String get perfectClearFlavor4;

  /// No description provided for @perfectClearFlavor5.
  ///
  /// In en, this message translates to:
  /// **'The puzzle never stood a chance. 🏆'**
  String get perfectClearFlavor5;

  /// No description provided for @perfectClearFlavor6.
  ///
  /// In en, this message translates to:
  /// **'Okay, that\'s almost unfair.'**
  String get perfectClearFlavor6;

  /// No description provided for @perfectClearFlavor7.
  ///
  /// In en, this message translates to:
  /// **'The numbers were on your side today.'**
  String get perfectClearFlavor7;

  /// No description provided for @perfectClearFlavor8.
  ///
  /// In en, this message translates to:
  /// **'9 numbers. 81 cells. 0 mistakes.'**
  String get perfectClearFlavor8;

  /// No description provided for @perfectClearFlavor9.
  ///
  /// In en, this message translates to:
  /// **'The hint button is out of a job today.'**
  String get perfectClearFlavor9;

  /// No description provided for @perfectClearFlavor10.
  ///
  /// In en, this message translates to:
  /// **'Certified Sudoku Master! 👑'**
  String get perfectClearFlavor10;

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

  /// No description provided for @dailyCalendarSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your daily sudoku history.'**
  String get dailyCalendarSignInHint;

  /// No description provided for @dailyCalendarLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your daily history.'**
  String get dailyCalendarLoadError;

  /// No description provided for @dailyCalendarDayDetail.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} · {time} · {mistakes} mistakes'**
  String dailyCalendarDayDetail(int month, int day, String time, int mistakes);

  /// No description provided for @statsCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statsCompletedLabel;

  /// No description provided for @statsPerfectLabel.
  ///
  /// In en, this message translates to:
  /// **'Perfect clears'**
  String get statsPerfectLabel;

  /// No description provided for @statsAverageLabel.
  ///
  /// In en, this message translates to:
  /// **'Average time'**
  String get statsAverageLabel;

  /// No description provided for @statsBestLabel.
  ///
  /// In en, this message translates to:
  /// **'Best time'**
  String get statsBestLabel;

  /// No description provided for @statsNoRecord.
  ///
  /// In en, this message translates to:
  /// **'-'**
  String get statsNoRecord;

  /// No description provided for @statsTopPercentBadge.
  ///
  /// In en, this message translates to:
  /// **'Top {percent}%'**
  String statsTopPercentBadge(int percent);

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

  /// No description provided for @inputModeQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get inputModeQuick;

  /// No description provided for @difficultyBeginner.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get difficultyBeginner;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get difficultyHard;

  /// No description provided for @difficultyMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get difficultyMaster;

  /// No description provided for @difficultyExpert.
  ///
  /// In en, this message translates to:
  /// **'Challenger'**
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

  /// No description provided for @techniqueLockedPair.
  ///
  /// In en, this message translates to:
  /// **'Locked Pair'**
  String get techniqueLockedPair;

  /// No description provided for @techniqueLockedTriple.
  ///
  /// In en, this message translates to:
  /// **'Locked Triple'**
  String get techniqueLockedTriple;

  /// No description provided for @techniqueXWing.
  ///
  /// In en, this message translates to:
  /// **'X-Wing'**
  String get techniqueXWing;

  /// No description provided for @techniqueSkyscraper.
  ///
  /// In en, this message translates to:
  /// **'Skyscraper'**
  String get techniqueSkyscraper;

  /// No description provided for @techniqueTwoStringKite.
  ///
  /// In en, this message translates to:
  /// **'2-String Kite'**
  String get techniqueTwoStringKite;

  /// No description provided for @techniqueTurbotFish.
  ///
  /// In en, this message translates to:
  /// **'Turbot Fish'**
  String get techniqueTurbotFish;

  /// No description provided for @techniqueRemotePair.
  ///
  /// In en, this message translates to:
  /// **'Remote Pair'**
  String get techniqueRemotePair;

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

  /// No description provided for @techniqueXYZWing.
  ///
  /// In en, this message translates to:
  /// **'XYZ-Wing'**
  String get techniqueXYZWing;

  /// No description provided for @techniqueWWing.
  ///
  /// In en, this message translates to:
  /// **'W-Wing'**
  String get techniqueWWing;

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

  /// No description provided for @techniqueFinnedSwordfish.
  ///
  /// In en, this message translates to:
  /// **'Finned Swordfish'**
  String get techniqueFinnedSwordfish;

  /// No description provided for @techniqueFinnedJellyfish.
  ///
  /// In en, this message translates to:
  /// **'Finned Jellyfish'**
  String get techniqueFinnedJellyfish;

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

  /// No description provided for @techniqueXChain.
  ///
  /// In en, this message translates to:
  /// **'X-Chain'**
  String get techniqueXChain;

  /// No description provided for @techniqueAic.
  ///
  /// In en, this message translates to:
  /// **'AIC'**
  String get techniqueAic;

  /// No description provided for @techniqueGroupedXChain.
  ///
  /// In en, this message translates to:
  /// **'Grouped X-Chain'**
  String get techniqueGroupedXChain;

  /// No description provided for @techniqueGroupedAic.
  ///
  /// In en, this message translates to:
  /// **'Grouped AIC'**
  String get techniqueGroupedAic;

  /// No description provided for @techniqueWXYZWing.
  ///
  /// In en, this message translates to:
  /// **'WXYZ-Wing'**
  String get techniqueWXYZWing;

  /// No description provided for @techniqueAlsXZ.
  ///
  /// In en, this message translates to:
  /// **'ALS-XZ'**
  String get techniqueAlsXZ;

  /// No description provided for @techniqueSueDeCoq.
  ///
  /// In en, this message translates to:
  /// **'Sue de Coq'**
  String get techniqueSueDeCoq;

  /// No description provided for @techniqueTripleFirework.
  ///
  /// In en, this message translates to:
  /// **'Triple Firework'**
  String get techniqueTripleFirework;

  /// No description provided for @techniqueAlsAic.
  ///
  /// In en, this message translates to:
  /// **'ALS Chain'**
  String get techniqueAlsAic;

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

  /// No description provided for @explanationSkyscraper.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} forms a Skyscraper: two strong links join so that at least one of {cell1} and {cell2} must be {digit}. Any cell that sees both can have {digit} removed from its candidates.'**
  String explanationSkyscraper(int digit, String cell1, String cell2);

  /// No description provided for @explanationTwoStringKite.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} forms a 2-String Kite joined through a shared box, so at least one of {cell1} and {cell2} must be {digit}. Any cell that sees both can have {digit} removed from its candidates.'**
  String explanationTwoStringKite(int digit, String cell1, String cell2);

  /// No description provided for @explanationTurbotFish.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} forms a Turbot Fish chain, so at least one of {cell1} and {cell2} must be {digit}. Any cell that sees both can have {digit} removed from its candidates.'**
  String explanationTurbotFish(int digit, String cell1, String cell2);

  /// No description provided for @explanationFinnedFish.
  ///
  /// In en, this message translates to:
  /// **'{mainLineDesc} forms a clean X-Wing shape with only two candidate cells for digit {digit}. {finLineDesc} also has extra candidates at {finsDesc} (fins), so it\'s not a pure X-Wing — but cells that see every fin can still have {digit} removed from their candidates.'**
  String explanationFinnedFish(
      String mainLineDesc, int digit, String finLineDesc, String finsDesc);

  /// No description provided for @explanationFinnedFishN.
  ///
  /// In en, this message translates to:
  /// **'{baseLinesDesc} confine digit {digit} to a {size}-line fish shape, except for extra candidates (fins) at {finsDesc}. If every fin is false this is a true fish; otherwise one of the fins is {digit}. Either way, cells that see every fin can have {digit} removed from their candidates.'**
  String explanationFinnedFishN(
      String baseLinesDesc, int digit, int size, String finsDesc);

  /// No description provided for @explanationLockedSubset.
  ///
  /// In en, this message translates to:
  /// **'{cellsDesc} lie where {lineDesc} crosses {boxDesc}, and together their only candidates are {digitsDesc} ({size} digits). Those cells take all {size} digits, so {digitsDesc} can be removed from the rest of {lineDesc} AND the rest of {boxDesc}.'**
  String explanationLockedSubset(String lineDesc, String boxDesc,
      String cellsDesc, String digitsDesc, int size);

  /// No description provided for @explanationRemotePair.
  ///
  /// In en, this message translates to:
  /// **'{chainDesc} all hold only {a} and {b}, and each sees the next, so their values alternate along the chain. The two ends sit an odd number of steps apart, so one is {a} and the other is {b} — meaning any cell seeing both ends can have BOTH {a} and {b} removed.'**
  String explanationRemotePair(String chainDesc, int a, int b);

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

  /// No description provided for @explanationXYZWing.
  ///
  /// In en, this message translates to:
  /// **'The pivot {pivotDesc} has three candidates ({pivotDigits}), and its wings {w1Desc} and {w2Desc} each hold {z} plus one of the others. Whichever digit the pivot takes, {z} ends up on the pivot or one of the wings — so any cell seeing all three can have {z} removed.'**
  String explanationXYZWing(String pivotDesc, String pivotDigits, String w1Desc,
      String w2Desc, int z);

  /// No description provided for @explanationWWing.
  ///
  /// In en, this message translates to:
  /// **'{cell1} and {cell2} both hold only {a} and {b}, and {unitDesc} has just two places for {b} — one seeing each of them. If both were {b}, that unit would have nowhere left for {b}. So at least one of them is {a}, and any cell seeing both can have {a} removed.'**
  String explanationWWing(
      String cell1, String cell2, int a, int b, String unitDesc);

  /// No description provided for @explanationGroupedXChain.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} forms an alternating chain along {chainDesc}, using clusters of neighbouring candidates as single links. The strong links still guarantee at least one end is {digit}, so any cell that sees both ends can have {digit} removed.'**
  String explanationGroupedXChain(String chainDesc, int digit);

  /// No description provided for @explanationGroupedAic.
  ///
  /// In en, this message translates to:
  /// **'The alternating inference chain {chainDesc} uses clusters of neighbouring candidates as single links. At least one of its two ends must be true, so any candidate that conflicts with both ends can be removed.'**
  String explanationGroupedAic(String chainDesc);

  /// No description provided for @explanationWXYZWing.
  ///
  /// In en, this message translates to:
  /// **'{chainDesc}: a WXYZ-Wing — a bivalue cell and a 3-cell Almost Locked Set joined through a shared digit. At least one chain end is true, so any candidate seeing both ends can be removed.'**
  String explanationWXYZWing(String chainDesc);

  /// No description provided for @explanationAlsXZ.
  ///
  /// In en, this message translates to:
  /// **'{chainDesc}: two Almost Locked Sets joined by a restricted common digit. If either set loses it the other locks, so at least one end is true — any candidate seeing both ends can be removed.'**
  String explanationAlsXZ(String chainDesc);

  /// No description provided for @explanationAlsAic.
  ///
  /// In en, this message translates to:
  /// **'The alternating inference chain {chainDesc} uses Almost Locked Sets as links. At least one of its two ends must be true, so any candidate that conflicts with both ends can be removed.'**
  String explanationAlsAic(String chainDesc);

  /// No description provided for @explanationSueDeCoq.
  ///
  /// In en, this message translates to:
  /// **'The crossing cells {cells} interlock exactly with an Almost Locked Set on their line and one in their box. Every involved digit ({digits}) must land inside these three clusters, so matching candidates outside them can be removed.'**
  String explanationSueDeCoq(String cells, String digits);

  /// No description provided for @hintStepSueDeCoqIntro.
  ///
  /// In en, this message translates to:
  /// **'Where the box meets the line, {cells} — {cellCount} cells — together hold {digits}: {digitCount} candidate kinds, at least two more than cells.'**
  String hintStepSueDeCoqIntro(
      String cells, int cellCount, String digits, int digitCount);

  /// No description provided for @hintStepSueDeCoqLine.
  ///
  /// In en, this message translates to:
  /// **'On the same line, {cells} ({cellCount} cells) hold only {digits} — {digitCount} kinds, exactly one more than cells: an Almost Locked Set. On this line those digits fit only here or in the crossing cells.'**
  String hintStepSueDeCoqLine(
      String cells, int cellCount, String digits, int digitCount);

  /// No description provided for @hintStepSueDeCoqBox.
  ///
  /// In en, this message translates to:
  /// **'In the box, {cells} ({cellCount} cells) likewise hold only {digits} — {digitCount} kinds, another Almost Locked Set. Its digits fit only there or in the crossing cells; every digit\'s place adds up exactly.'**
  String hintStepSueDeCoqBox(
      String cells, int cellCount, String digits, int digitCount);

  /// No description provided for @explanationTripleFirework.
  ///
  /// In en, this message translates to:
  /// **'Digits {digits} form fireworks: on both the row and the column they escape the box by just one wing cell each. The box can hold each digit only once, so the cross cell and the two wings ({cells}) must take exactly these three digits — removing their other candidates, and these digits from the box\'s non-cross cells.'**
  String explanationTripleFirework(String digits, String cells);

  /// No description provided for @hintStepFireworkRow.
  ///
  /// In en, this message translates to:
  /// **'On this row, candidates for {digits} sit only in {cells} — outside the box that is just {cell}.'**
  String hintStepFireworkRow(String digits, String cells, String cell);

  /// No description provided for @hintStepFireworkCol.
  ///
  /// In en, this message translates to:
  /// **'Same on this column — {digits} sit only in {cells}, with {cell} the lone escape from the box.'**
  String hintStepFireworkCol(String digits, String cells, String cell);

  /// No description provided for @hintStepFireworkTriple.
  ///
  /// In en, this message translates to:
  /// **'The box can hold {digits} only once each, so for all three to fit, the three cells {cells} must take exactly one apiece.'**
  String hintStepFireworkTriple(String cells, String digits);

  /// No description provided for @explanationXChain.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} forms an alternating chain along {chainDesc}. Because the strong links guarantee at least one end is {digit}, any cell that sees both ends can have {digit} removed.'**
  String explanationXChain(String chainDesc, int digit);

  /// No description provided for @explanationAic.
  ///
  /// In en, this message translates to:
  /// **'The alternating inference chain {chainDesc} forces at least one of its two ends to be true, so any candidate that conflicts with both ends can be removed.'**
  String explanationAic(String chainDesc);

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
  /// **'One of {cellA} and {cellB} must take an extra candidate (if both kept only the rectangle pair, the puzzle would have two solutions). Treating their extra candidates as one virtual cell, they form a set of only {digitsDesc} with other cells in that unit — so {digitsDesc} can be removed from the rest of that unit.'**
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
  /// **'Some cells\' notes didn\'t match the board, so they were corrected first. {explanation}'**
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

  /// No description provided for @tierPromotionRemaining.
  ///
  /// In en, this message translates to:
  /// **'{points} pts to {nextTier}'**
  String tierPromotionRemaining(int points, String nextTier);

  /// No description provided for @tierTopReached.
  ///
  /// In en, this message translates to:
  /// **'Top tier reached'**
  String get tierTopReached;

  /// No description provided for @ratingTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Rating Trend'**
  String get ratingTrendTitle;

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
  /// **'Room code or puzzle code'**
  String get enterTextCodeHint;

  /// No description provided for @roomJoinRequiresSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to join a friend match. You can sign in from the race lobby.'**
  String get roomJoinRequiresSignIn;

  /// No description provided for @loadButton.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get loadButton;

  /// No description provided for @raceLobbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get raceLobbyTitle;

  /// No description provided for @friendMatchButton.
  ///
  /// In en, this message translates to:
  /// **'Play with a Friend'**
  String get friendMatchButton;

  /// No description provided for @rankedMatchButton.
  ///
  /// In en, this message translates to:
  /// **'Ranked Match'**
  String get rankedMatchButton;

  /// No description provided for @leaderboardButton.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get leaderboardButton;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardMyRankLabel.
  ///
  /// In en, this message translates to:
  /// **'Your rank: #{rank} of {total}'**
  String leaderboardMyRankLabel(int rank, int total);

  /// No description provided for @leaderboardMyRankUnranked.
  ///
  /// In en, this message translates to:
  /// **'No ranked record yet'**
  String get leaderboardMyRankUnranked;

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ranked players yet.'**
  String get leaderboardEmpty;

  /// No description provided for @leaderboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the ranking.'**
  String get leaderboardLoadFailed;

  /// No description provided for @seasonName.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String seasonName(int number);

  /// No description provided for @seasonDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'D-{days}'**
  String seasonDaysLeft(int days);

  /// No description provided for @pastSeasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Past Seasons'**
  String get pastSeasonsTitle;

  /// No description provided for @seasonStandingDetail.
  ///
  /// In en, this message translates to:
  /// **'#{rank} · {wins}W {losses}L'**
  String seasonStandingDetail(int rank, int wins, int losses);

  /// No description provided for @placementProgress.
  ///
  /// In en, this message translates to:
  /// **'Placements {played}/{total}'**
  String placementProgress(int played, int total);

  /// No description provided for @seasonEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Season {number} Complete!'**
  String seasonEndedTitle(int number);

  /// No description provided for @seasonEndedNewStart.
  ///
  /// In en, this message translates to:
  /// **'A new season has begun — you restart at rating {rating}!'**
  String seasonEndedNewStart(int rating);

  /// No description provided for @okAction.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okAction;

  /// No description provided for @friendMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Play with a Friend'**
  String get friendMatchTitle;

  /// No description provided for @createRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose difficulty'**
  String get createRoomTitle;

  /// No description provided for @createRoomAction.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoomAction;

  /// No description provided for @joinRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Room'**
  String get joinRoomTitle;

  /// No description provided for @waitingForFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Friend'**
  String get waitingForFriendTitle;

  /// No description provided for @joinRoomAction.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinRoomAction;

  /// No description provided for @roomCodeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Room code'**
  String get roomCodeFieldLabel;

  /// No description provided for @roomCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Room not found or expired.'**
  String get roomCodeInvalid;

  /// No description provided for @roomCodeShareHint.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your friend'**
  String get roomCodeShareHint;

  /// No description provided for @waitingForFriend.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your friend to join...'**
  String get waitingForFriend;

  /// No description provided for @matchmakingElapsed.
  ///
  /// In en, this message translates to:
  /// **'Waiting {time}'**
  String matchmakingElapsed(String time);

  /// No description provided for @friendlyMatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Friendly match · no rating change'**
  String get friendlyMatchLabel;

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

  /// No description provided for @matchmakingTip1.
  ///
  /// In en, this message translates to:
  /// **'Solve today\'s Daily puzzle and check where you rank.'**
  String get matchmakingTip1;

  /// No description provided for @matchmakingTip2.
  ///
  /// In en, this message translates to:
  /// **'Finish a puzzle with no hints and no mistakes for a Perfect Clear.'**
  String get matchmakingTip2;

  /// No description provided for @matchmakingTip3.
  ///
  /// In en, this message translates to:
  /// **'In ranked matches, the puzzle difficulty is set by your tier.'**
  String get matchmakingTip3;

  /// No description provided for @matchmakingTip4.
  ///
  /// In en, this message translates to:
  /// **'Use note mode to pencil in candidate numbers and solve faster.'**
  String get matchmakingTip4;

  /// No description provided for @matchmakingTip5.
  ///
  /// In en, this message translates to:
  /// **'Share a room code to race a friend one-on-one.'**
  String get matchmakingTip5;

  /// No description provided for @matchmakingTip6.
  ///
  /// In en, this message translates to:
  /// **'Win races to raise your rating and climb to a higher tier.'**
  String get matchmakingTip6;

  /// No description provided for @matchmakingTip7.
  ///
  /// In en, this message translates to:
  /// **'Tiers go Bronze > Silver > Gold > Diamond > Master > Challenger. Aim for Challenger.'**
  String get matchmakingTip7;

  /// No description provided for @raceAbortConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Give up the race?'**
  String get raceAbortConfirmTitle;

  /// No description provided for @opponentDisconnectedCountdown.
  ///
  /// In en, this message translates to:
  /// **'Opponent disconnected — you win in {seconds}s'**
  String opponentDisconnectedCountdown(int seconds);

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
  /// **'Bronze'**
  String get tierBronze;

  /// No description provided for @tierSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get tierSilver;

  /// No description provided for @tierGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get tierGold;

  /// No description provided for @tierDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get tierDiamond;

  /// No description provided for @tierMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get tierMaster;

  /// No description provided for @tierChallenger.
  ///
  /// In en, this message translates to:
  /// **'Challenger'**
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

  /// No description provided for @dailyButton.
  ///
  /// In en, this message translates to:
  /// **'Daily Sudoku'**
  String get dailyButton;

  /// No description provided for @dailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Sudoku'**
  String get dailyTitle;

  /// No description provided for @dailyLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing today\'s puzzle...'**
  String get dailyLoading;

  /// No description provided for @dailySignInPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to play the Daily Sudoku'**
  String get dailySignInPromptTitle;

  /// No description provided for @dailyResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Result'**
  String get dailyResultTitle;

  /// No description provided for @dailyMyRankLabel.
  ///
  /// In en, this message translates to:
  /// **'Ranked #{rank} of {total} today'**
  String dailyMyRankLabel(int rank, int total);

  /// No description provided for @dailyLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Top 10'**
  String get dailyLeaderboardTitle;

  /// No description provided for @dailyEmptyLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'No one has finished yet.'**
  String get dailyEmptyLeaderboard;

  /// No description provided for @dailyReplayAction.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get dailyReplayAction;

  /// No description provided for @dailyNotRankedNotice.
  ///
  /// In en, this message translates to:
  /// **'Only your first clear is recorded.'**
  String get dailyNotRankedNotice;

  /// No description provided for @dailySubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit your result.'**
  String get dailySubmitFailed;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @hintStepPrevAction.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get hintStepPrevAction;

  /// No description provided for @hintStepNextAction.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get hintStepNextAction;

  /// No description provided for @hintStepXYWingPivot.
  ///
  /// In en, this message translates to:
  /// **'The pivot {pivot} has only two candidates: {x} and {y}.'**
  String hintStepXYWingPivot(String pivot, int x, int y);

  /// No description provided for @hintStepWingCase.
  ///
  /// In en, this message translates to:
  /// **'If the pivot is {digit}, {wing} loses {digit} — so it must be {z}.'**
  String hintStepWingCase(int digit, String wing, int z);

  /// No description provided for @hintStepXYWingConclusion.
  ///
  /// In en, this message translates to:
  /// **'Either way, one of the two wings is {z}. Any cell that sees both wings can\'t be {z}.'**
  String hintStepXYWingConclusion(int z);

  /// No description provided for @hintStepXYZWingPivot.
  ///
  /// In en, this message translates to:
  /// **'The pivot {pivot} has three candidates: {digits}.'**
  String hintStepXYZWingPivot(String pivot, String digits);

  /// No description provided for @hintStepXYZWingPivotZ.
  ///
  /// In en, this message translates to:
  /// **'And the pivot could be {z} itself — that\'s the third case.'**
  String hintStepXYZWingPivotZ(int z);

  /// No description provided for @hintStepXYZWingConclusion.
  ///
  /// In en, this message translates to:
  /// **'In every case, one of the three cells is {z}. Any cell that sees all three can\'t be {z}.'**
  String hintStepXYZWingConclusion(int z);

  /// No description provided for @hintStepWWingPair.
  ///
  /// In en, this message translates to:
  /// **'{cell1} and {cell2} hold exactly the same pair: {a} and {b}.'**
  String hintStepWWingPair(String cell1, String cell2, int a, int b);

  /// No description provided for @hintStepWWingBridge.
  ///
  /// In en, this message translates to:
  /// **'In {unitDesc}, {b} fits in only two places — and each one sees one of the pair cells.'**
  String hintStepWWingBridge(String unitDesc, int b);

  /// No description provided for @hintStepWWingForced.
  ///
  /// In en, this message translates to:
  /// **'If both those cells were {b}, {unitDesc} would have nowhere left for {b}. So at least one of them is {a}.'**
  String hintStepWWingForced(String unitDesc, int a, int b);

  /// No description provided for @hintStepWWingConclusion.
  ///
  /// In en, this message translates to:
  /// **'Any cell that sees both pair cells can\'t be {a}.'**
  String hintStepWWingConclusion(int a);

  /// No description provided for @hintStepChainStart.
  ///
  /// In en, this message translates to:
  /// **'Start at {cell}: if it isn\'t {z}, it must be {a}.'**
  String hintStepChainStart(String cell, int z, int a);

  /// No description provided for @hintStepChainHop.
  ///
  /// In en, this message translates to:
  /// **'Then {cell} can\'t be {carry}, so it must be {next}.'**
  String hintStepChainHop(String cell, int carry, int next);

  /// No description provided for @hintStepAicStart.
  ///
  /// In en, this message translates to:
  /// **'Start at candidate {digit} in {cell}, and suppose this cell is NOT {digit} —'**
  String hintStepAicStart(String cell, int digit);

  /// No description provided for @hintStepAicStrongUnit.
  ///
  /// In en, this message translates to:
  /// **'then {cell} must be {digit}.'**
  String hintStepAicStrongUnit(String cell, int digit);

  /// No description provided for @hintStepAicStrongCell.
  ///
  /// In en, this message translates to:
  /// **'then the remaining {digit} is forced.'**
  String hintStepAicStrongCell(int digit);

  /// No description provided for @hintStepAicStartGroup.
  ///
  /// In en, this message translates to:
  /// **'Start at the {digit} candidates clustered in {cells}, and suppose NONE of them is {digit} —'**
  String hintStepAicStartGroup(String cells, int digit);

  /// No description provided for @hintStepAicStrongGroup.
  ///
  /// In en, this message translates to:
  /// **'then one of {cells} must be {digit}.'**
  String hintStepAicStrongGroup(String cells, int digit);

  /// No description provided for @hintStepAicWeakUnit.
  ///
  /// In en, this message translates to:
  /// **'Now {cell} can no longer be {digit}.'**
  String hintStepAicWeakUnit(String cell, int digit);

  /// No description provided for @hintStepAicWeakCell.
  ///
  /// In en, this message translates to:
  /// **'Now this cell\'s other candidate {digit} is ruled out.'**
  String hintStepAicWeakCell(int digit);

  /// No description provided for @hintStepAicEitherEnds.
  ///
  /// In en, this message translates to:
  /// **'So there are only two cases: either {startCell} really is {startDigit}, or — as we just followed — {endCell} ends up {endDigit}. Either way, one of the two must be true.'**
  String hintStepAicEitherEnds(
      String startCell, int startDigit, String endCell, int endDigit);

  /// No description provided for @hintStepAicConclusion.
  ///
  /// In en, this message translates to:
  /// **'Any candidate that sees both ends can be removed.'**
  String get hintStepAicConclusion;

  /// No description provided for @hintStepChainConclusion.
  ///
  /// In en, this message translates to:
  /// **'So either the start is {z}, or the end is {z}. Any cell that sees both ends can\'t be {z}.'**
  String hintStepChainConclusion(int z);

  /// No description provided for @hintStepRemotePairIntro.
  ///
  /// In en, this message translates to:
  /// **'Every cell in this chain holds the same pair: {a} and {b}.'**
  String hintStepRemotePairIntro(int a, int b);

  /// No description provided for @hintStepRemotePairAlternate.
  ///
  /// In en, this message translates to:
  /// **'Neighbors see each other, so the values must alternate {a}, {b}, {a}, {b} along the chain.'**
  String hintStepRemotePairAlternate(int a, int b);

  /// No description provided for @hintStepRemotePairEnds.
  ///
  /// In en, this message translates to:
  /// **'The two ends are an odd number of hops apart, so one is {a} and the other is {b} — always.'**
  String hintStepRemotePairEnds(int a, int b);

  /// No description provided for @hintStepRemotePairConclusion.
  ///
  /// In en, this message translates to:
  /// **'Any cell that sees both ends can be neither {a} nor {b}.'**
  String hintStepRemotePairConclusion(int a, int b);

  /// No description provided for @hintStepSingleDigitStrong1.
  ///
  /// In en, this message translates to:
  /// **'{cell1} and {cell2} are the only two spots for {digit} in their unit — one of them must be {digit}.'**
  String hintStepSingleDigitStrong1(int digit, String cell1, String cell2);

  /// No description provided for @hintStepSingleDigitStrong2.
  ///
  /// In en, this message translates to:
  /// **'{cell1} and {cell2} are another only-two-spots pair, and the two middle cells see each other.'**
  String hintStepSingleDigitStrong2(int digit, String cell1, String cell2);

  /// No description provided for @hintStepSingleDigitForced.
  ///
  /// In en, this message translates to:
  /// **'The middle cells can\'t both be {digit}, so at least one of the free ends {cell1} and {cell2} must be {digit}.'**
  String hintStepSingleDigitForced(int digit, String cell1, String cell2);

  /// No description provided for @hintStepSingleDigitConclusion.
  ///
  /// In en, this message translates to:
  /// **'Any cell that sees both free ends can\'t be {digit}.'**
  String hintStepSingleDigitConclusion(int digit);

  /// No description provided for @hintStepColoringChain.
  ///
  /// In en, this message translates to:
  /// **'Cells linked as the only two spots for {digit} form a chain — neighbors are opposites, so they split into two colors.'**
  String hintStepColoringChain(int digit);

  /// No description provided for @hintStepColoringRule1Clash.
  ///
  /// In en, this message translates to:
  /// **'{cell1} and {cell2} share a color AND see each other — a color can\'t hold {digit} twice, so that whole color is wrong.'**
  String hintStepColoringRule1Clash(int digit, String cell1, String cell2);

  /// No description provided for @hintStepColoringRule1Conclusion.
  ///
  /// In en, this message translates to:
  /// **'Every cell of the wrong color loses {digit}.'**
  String hintStepColoringRule1Conclusion(int digit);

  /// No description provided for @hintStepColoringRule2Conclusion.
  ///
  /// In en, this message translates to:
  /// **'One of the two colors must be true. A cell that sees both colors can\'t be {digit} either way.'**
  String hintStepColoringRule2Conclusion(int digit);

  /// No description provided for @hintStepXWingLines.
  ///
  /// In en, this message translates to:
  /// **'Digit {digit} fits in only two spots in each of {linesDesc}.'**
  String hintStepXWingLines(int digit, String linesDesc);

  /// No description provided for @hintStepXWingRect.
  ///
  /// In en, this message translates to:
  /// **'The four spots form a rectangle — however it resolves, {crossDesc} each get exactly one {digit} inside it.'**
  String hintStepXWingRect(int digit, String crossDesc);

  /// No description provided for @hintStepXWingConclusion.
  ///
  /// In en, this message translates to:
  /// **'So the rest of those two {crossUnitName} can\'t hold {digit}.'**
  String hintStepXWingConclusion(int digit, String crossUnitName);

  /// No description provided for @hintStepFullHouseIntro.
  ///
  /// In en, this message translates to:
  /// **'Only one cell in {unitDesc} is still empty.'**
  String hintStepFullHouseIntro(String unitDesc);

  /// No description provided for @hintStepNakedSingleIntro.
  ///
  /// In en, this message translates to:
  /// **'Narrow down {cell}: cross off every digit already placed in its row, column, and box.'**
  String hintStepNakedSingleIntro(String cell);

  /// No description provided for @hintStepHiddenSingleIntro.
  ///
  /// In en, this message translates to:
  /// **'One area has only a single spot left where {digit} can go — the highlighted digits block every other cell.'**
  String hintStepHiddenSingleIntro(int digit);

  /// No description provided for @hintStepBugIntro.
  ///
  /// In en, this message translates to:
  /// **'If every empty cell kept exactly two candidates, the puzzle would end up with two solutions. Exactly one cell holds three — that cell is the way out.'**
  String get hintStepBugIntro;

  /// No description provided for @hintStepNakedSubsetIntro.
  ///
  /// In en, this message translates to:
  /// **'In {unitDesc}, the {count} highlighted cells hold only {digits} between them.'**
  String hintStepNakedSubsetIntro(int count, String digits, String unitDesc);

  /// No description provided for @hintStepHiddenSubsetIntro.
  ///
  /// In en, this message translates to:
  /// **'In {unitDesc}, {digits} can only go in the {count} highlighted cells.'**
  String hintStepHiddenSubsetIntro(int count, String digits, String unitDesc);

  /// No description provided for @hintStepPointingIntro.
  ///
  /// In en, this message translates to:
  /// **'Inside {boxDesc}, every spot for {digit} sits on {lineDesc}.'**
  String hintStepPointingIntro(int digit, String boxDesc, String lineDesc);

  /// No description provided for @hintStepClaimingIntro.
  ///
  /// In en, this message translates to:
  /// **'In {lineDesc}, every spot for {digit} sits inside {boxDesc}.'**
  String hintStepClaimingIntro(int digit, String lineDesc, String boxDesc);

  /// No description provided for @hintStepFishIntro.
  ///
  /// In en, this message translates to:
  /// **'Look at {linesDesc}: the spots where {digit} can go there are pinned to just a few crossing lines.'**
  String hintStepFishIntro(int digit, String linesDesc);

  /// No description provided for @hintStepURIntro.
  ///
  /// In en, this message translates to:
  /// **'The highlighted cells form a rectangle sharing one candidate pair. If all four kept only that pair, the puzzle would have two solutions — which is impossible.'**
  String get hintStepURIntro;

  /// No description provided for @replayTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replayTitle;

  /// No description provided for @replayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No games to replay yet.'**
  String get replayEmpty;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTitle;

  /// No description provided for @premiumIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Sudoku League Premium'**
  String get premiumIntroTitle;

  /// No description provided for @premiumBenefitAssistTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlimited hints & auto-notes'**
  String get premiumBenefitAssistTitle;

  /// No description provided for @premiumBenefitAssistBody.
  ///
  /// In en, this message translates to:
  /// **'Use hints and auto-notes freely — no ads.'**
  String get premiumBenefitAssistBody;

  /// No description provided for @premiumBenefitReplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get premiumBenefitReplayTitle;

  /// No description provided for @premiumBenefitReplayBody.
  ///
  /// In en, this message translates to:
  /// **'Review recent games move by move and resume solving — races included.'**
  String get premiumBenefitReplayBody;

  /// No description provided for @premiumBenefitFavoriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get premiumBenefitFavoriteTitle;

  /// No description provided for @premiumBenefitFavoriteBody.
  ///
  /// In en, this message translates to:
  /// **'Save puzzles you like and solve them again anytime.'**
  String get premiumBenefitFavoriteBody;

  /// No description provided for @premiumBenefitThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'5 theme packs'**
  String get premiumBenefitThemeTitle;

  /// No description provided for @premiumBenefitThemeBody.
  ///
  /// In en, this message translates to:
  /// **'Premium themes that restyle the board and the whole app.'**
  String get premiumBenefitThemeBody;

  /// No description provided for @premiumPlanLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get premiumPlanLifetime;

  /// No description provided for @premiumPlanLifetimePrice.
  ///
  /// In en, this message translates to:
  /// **'\$3.99'**
  String get premiumPlanLifetimePrice;

  /// No description provided for @premiumPlanLifetimeDetail.
  ///
  /// In en, this message translates to:
  /// **'Pay once, yours forever'**
  String get premiumPlanLifetimeDetail;

  /// No description provided for @premiumPlanMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get premiumPlanMonthly;

  /// No description provided for @premiumPlanMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'\$0.99'**
  String get premiumPlanMonthlyPrice;

  /// No description provided for @premiumPlanMonthlyDetail.
  ///
  /// In en, this message translates to:
  /// **'Renews every month'**
  String get premiumPlanMonthlyDetail;

  /// No description provided for @premiumCtaStart.
  ///
  /// In en, this message translates to:
  /// **'Get Premium'**
  String get premiumCtaStart;

  /// No description provided for @premiumMockDone.
  ///
  /// In en, this message translates to:
  /// **'(Mock) Premium activated!'**
  String get premiumMockDone;

  /// No description provided for @premiumComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Purchases will be available at official launch.'**
  String get premiumComingSoon;

  /// No description provided for @replayPremiumBody.
  ///
  /// In en, this message translates to:
  /// **'Replay your recent games move by move and pick up solving again — retrace every entry and note in the exact order you made them.'**
  String get replayPremiumBody;

  /// No description provided for @replayResumeFromHere.
  ///
  /// In en, this message translates to:
  /// **'Solve from here'**
  String get replayResumeFromHere;

  /// No description provided for @raceReplayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No replay saved for this game on this device.'**
  String get raceReplayUnavailable;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritePremiumBody.
  ///
  /// In en, this message translates to:
  /// **'Save puzzles to your favorites and replay them fresh whenever you like.'**
  String get favoritePremiumBody;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved puzzles yet.'**
  String get favoritesEmpty;

  /// No description provided for @favoriteSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to favorites.'**
  String get favoriteSaved;

  /// No description provided for @favoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites.'**
  String get favoriteRemoved;

  /// No description provided for @favoriteFull.
  ///
  /// In en, this message translates to:
  /// **'Favorites are full (max {count}).'**
  String favoriteFull(int count);

  /// No description provided for @themePackSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Pack'**
  String get themePackSectionTitle;

  /// No description provided for @themePackClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get themePackClassic;

  /// No description provided for @themePackMidnightNeon.
  ///
  /// In en, this message translates to:
  /// **'Midnight Neon'**
  String get themePackMidnightNeon;

  /// No description provided for @themePackSepiaPaper.
  ///
  /// In en, this message translates to:
  /// **'Sepia Paper'**
  String get themePackSepiaPaper;

  /// No description provided for @themePackMonochrome.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get themePackMonochrome;

  /// No description provided for @themePackForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get themePackForest;

  /// No description provided for @themePackOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get themePackOcean;

  /// No description provided for @themePremiumBody.
  ///
  /// In en, this message translates to:
  /// **'Restyle the board and the whole app with premium theme packs — five distinct looks to choose from.'**
  String get themePremiumBody;

  /// No description provided for @codexTitle.
  ///
  /// In en, this message translates to:
  /// **'Technique Codex'**
  String get codexTitle;

  /// No description provided for @codexProgress.
  ///
  /// In en, this message translates to:
  /// **'Discovered {met} / {total}'**
  String codexProgress(int met, int total);

  /// No description provided for @codexUsage.
  ///
  /// In en, this message translates to:
  /// **'{uses}× · {puzzles} puzzles'**
  String codexUsage(int uses, int puzzles);

  /// No description provided for @codexUndiscovered.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get codexUndiscovered;
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
