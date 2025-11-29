import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('pt'),
    Locale('ru'),
    Locale('th'),
    Locale('tr'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Heads Up!'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @customizeYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Customize your experience'**
  String get customizeYourExperience;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @addAll.
  ///
  /// In en, this message translates to:
  /// **'Add All'**
  String get addAll;

  /// No description provided for @watchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch Ad'**
  String get watchAd;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @testRecording.
  ///
  /// In en, this message translates to:
  /// **'Test Recording'**
  String get testRecording;

  /// No description provided for @playVideo.
  ///
  /// In en, this message translates to:
  /// **'Play Video'**
  String get playVideo;

  /// No description provided for @playNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get playNow;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get pass;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @round.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get round;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get gameOver;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGame;

  /// No description provided for @pauseGame.
  ///
  /// In en, this message translates to:
  /// **'Pause Game'**
  String get pauseGame;

  /// No description provided for @resumeGame.
  ///
  /// In en, this message translates to:
  /// **'Resume Game'**
  String get resumeGame;

  /// No description provided for @quitGame.
  ///
  /// In en, this message translates to:
  /// **'Quit Game'**
  String get quitGame;

  /// No description provided for @recalibrate.
  ///
  /// In en, this message translates to:
  /// **'Recalibrate'**
  String get recalibrate;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @trendingNow.
  ///
  /// In en, this message translates to:
  /// **'Trending Now'**
  String get trendingNow;

  /// No description provided for @quick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get quick;

  /// No description provided for @quickGames.
  ///
  /// In en, this message translates to:
  /// **'Quick Games'**
  String get quickGames;

  /// No description provided for @party.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get party;

  /// No description provided for @partyMode.
  ///
  /// In en, this message translates to:
  /// **'Party Mode'**
  String get partyMode;

  /// No description provided for @myDecks.
  ///
  /// In en, this message translates to:
  /// **'My Decks'**
  String get myDecks;

  /// No description provided for @yourCreations.
  ///
  /// In en, this message translates to:
  /// **'Your Creations'**
  String get yourCreations;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @myFavorites.
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get myFavorites;

  /// No description provided for @allDecks.
  ///
  /// In en, this message translates to:
  /// **'All Decks'**
  String get allDecks;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @selectDeck.
  ///
  /// In en, this message translates to:
  /// **'Select Deck'**
  String get selectDeck;

  /// No description provided for @createDeck.
  ///
  /// In en, this message translates to:
  /// **'Create Deck'**
  String get createDeck;

  /// No description provided for @editDeck.
  ///
  /// In en, this message translates to:
  /// **'Edit Deck'**
  String get editDeck;

  /// No description provided for @deleteDeck.
  ///
  /// In en, this message translates to:
  /// **'Delete Deck'**
  String get deleteDeck;

  /// No description provided for @customDecks.
  ///
  /// In en, this message translates to:
  /// **'Custom Decks'**
  String get customDecks;

  /// No description provided for @deckName.
  ///
  /// In en, this message translates to:
  /// **'Deck Name'**
  String get deckName;

  /// No description provided for @deckDescription.
  ///
  /// In en, this message translates to:
  /// **'Deck Description'**
  String get deckDescription;

  /// No description provided for @deckCategory.
  ///
  /// In en, this message translates to:
  /// **'Deck Category'**
  String get deckCategory;

  /// No description provided for @deckColor.
  ///
  /// In en, this message translates to:
  /// **'Deck Color'**
  String get deckColor;

  /// No description provided for @deckIcon.
  ///
  /// In en, this message translates to:
  /// **'Deck Icon'**
  String get deckIcon;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cards;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get addCard;

  /// No description provided for @nCards.
  ///
  /// In en, this message translates to:
  /// **'{count} Cards'**
  String nCards(int count);

  /// No description provided for @shareDeck.
  ///
  /// In en, this message translates to:
  /// **'Share Deck'**
  String get shareDeck;

  /// No description provided for @importDeck.
  ///
  /// In en, this message translates to:
  /// **'Import Deck'**
  String get importDeck;

  /// No description provided for @exportDeck.
  ///
  /// In en, this message translates to:
  /// **'Export Deck'**
  String get exportDeck;

  /// No description provided for @createYourFirstDeck.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Deck'**
  String get createYourFirstDeck;

  /// No description provided for @searchDecks.
  ///
  /// In en, this message translates to:
  /// **'Search Decks'**
  String get searchDecks;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search for decks...'**
  String get searchPlaceholder;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get noResults;

  /// No description provided for @noDecksFound.
  ///
  /// In en, this message translates to:
  /// **'No Decks Found'**
  String get noDecksFound;

  /// No description provided for @dailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge'**
  String get dailyChallenge;

  /// No description provided for @dailyDeck.
  ///
  /// In en, this message translates to:
  /// **'Daily Deck'**
  String get dailyDeck;

  /// No description provided for @todaysChallenge.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Challenge'**
  String get todaysChallenge;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get currentStreak;

  /// No description provided for @weeklyProgress.
  ///
  /// In en, this message translates to:
  /// **'Weekly Progress'**
  String get weeklyProgress;

  /// No description provided for @milestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get milestone;

  /// No description provided for @nextMilestone.
  ///
  /// In en, this message translates to:
  /// **'Next Milestone'**
  String get nextMilestone;

  /// No description provided for @completeDailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Complete Daily Challenge'**
  String get completeDailyChallenge;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @finalScore.
  ///
  /// In en, this message translates to:
  /// **'Final Score'**
  String get finalScore;

  /// No description provided for @correctAnswers.
  ///
  /// In en, this message translates to:
  /// **'Correct Answers'**
  String get correctAnswers;

  /// No description provided for @passedCards.
  ///
  /// In en, this message translates to:
  /// **'Passed Cards'**
  String get passedCards;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get totalTime;

  /// No description provided for @bestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best Streak'**
  String get bestStreak;

  /// No description provided for @shareResults.
  ///
  /// In en, this message translates to:
  /// **'Share Results'**
  String get shareResults;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// No description provided for @noGameData.
  ///
  /// In en, this message translates to:
  /// **'No game data'**
  String get noGameData;

  /// No description provided for @noGameDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No game data available'**
  String get noGameDataAvailable;

  /// No description provided for @gameSettings.
  ///
  /// In en, this message translates to:
  /// **'Game Settings'**
  String get gameSettings;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundEffects;

  /// No description provided for @playSoundsDuringGameplay.
  ///
  /// In en, this message translates to:
  /// **'Play sounds during gameplay'**
  String get playSoundsDuringGameplay;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get hapticFeedback;

  /// No description provided for @subtleTouchFeedback.
  ///
  /// In en, this message translates to:
  /// **'Subtle touch feedback'**
  String get subtleTouchFeedback;

  /// No description provided for @roundDuration.
  ///
  /// In en, this message translates to:
  /// **'Round Duration'**
  String get roundDuration;

  /// No description provided for @timePerRoundInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Time per round in seconds'**
  String get timePerRoundInSeconds;

  /// No description provided for @kidFriendlyMode.
  ///
  /// In en, this message translates to:
  /// **'Kid-Friendly Mode'**
  String get kidFriendlyMode;

  /// No description provided for @filterInappropriateContent.
  ///
  /// In en, this message translates to:
  /// **'Filter inappropriate content'**
  String get filterInappropriateContent;

  /// No description provided for @showWordsAfterPass.
  ///
  /// In en, this message translates to:
  /// **'Show Words After Pass'**
  String get showWordsAfterPass;

  /// No description provided for @displayPassedWordsAfterRound.
  ///
  /// In en, this message translates to:
  /// **'Display passed words after round'**
  String get displayPassedWordsAfterRound;

  /// No description provided for @recordReactions.
  ///
  /// In en, this message translates to:
  /// **'Record Reactions'**
  String get recordReactions;

  /// No description provided for @captureFunMoments.
  ///
  /// In en, this message translates to:
  /// **'Capture fun moments'**
  String get captureFunMoments;

  /// No description provided for @gameplayControls.
  ///
  /// In en, this message translates to:
  /// **'Gameplay Controls'**
  String get gameplayControls;

  /// No description provided for @manualControls.
  ///
  /// In en, this message translates to:
  /// **'Manual Controls'**
  String get manualControls;

  /// No description provided for @useButtonsInsteadOfTilt.
  ///
  /// In en, this message translates to:
  /// **'Use buttons instead of tilt'**
  String get useButtonsInsteadOfTilt;

  /// No description provided for @landscapeMode.
  ///
  /// In en, this message translates to:
  /// **'Landscape Mode'**
  String get landscapeMode;

  /// No description provided for @playInHorizontalOrientation.
  ///
  /// In en, this message translates to:
  /// **'Play in horizontal orientation'**
  String get playInHorizontalOrientation;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @receiveGameReminders.
  ///
  /// In en, this message translates to:
  /// **'Receive game reminders'**
  String get receiveGameReminders;

  /// No description provided for @showTutorials.
  ///
  /// In en, this message translates to:
  /// **'Show Tutorials'**
  String get showTutorials;

  /// No description provided for @displayHelpfulHints.
  ///
  /// In en, this message translates to:
  /// **'Display helpful hints'**
  String get displayHelpfulHints;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @appAppearance.
  ///
  /// In en, this message translates to:
  /// **'App Appearance'**
  String get appAppearance;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @rateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// No description provided for @welcomeToHeadsUp.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Heads Up!'**
  String get welcomeToHeadsUp;

  /// No description provided for @tutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get tutorial;

  /// No description provided for @tutorialStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Heads Up!'**
  String get tutorialStep1Title;

  /// No description provided for @tutorialStep1Description.
  ///
  /// In en, this message translates to:
  /// **'This is your featured deck. Swipe left or right to explore different decks, or tap to see details.'**
  String get tutorialStep1Description;

  /// No description provided for @tutorialStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Browse Categories'**
  String get tutorialStep2Title;

  /// No description provided for @tutorialStep2Description.
  ///
  /// In en, this message translates to:
  /// **'Explore different categories or search for specific decks using these chips.'**
  String get tutorialStep2Description;

  /// No description provided for @tutorialStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge'**
  String get tutorialStep3Title;

  /// No description provided for @tutorialStep3Description.
  ///
  /// In en, this message translates to:
  /// **'Complete a new challenge every day to maintain your streak!'**
  String get tutorialStep3Description;

  /// No description provided for @tutorialStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Continue Playing'**
  String get tutorialStep4Title;

  /// No description provided for @tutorialStep4Description.
  ///
  /// In en, this message translates to:
  /// **'Your recent games appear here for quick access.'**
  String get tutorialStep4Description;

  /// No description provided for @teams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teams;

  /// No description provided for @teamSetup.
  ///
  /// In en, this message translates to:
  /// **'Team Setup'**
  String get teamSetup;

  /// No description provided for @teamName.
  ///
  /// In en, this message translates to:
  /// **'Team Name'**
  String get teamName;

  /// No description provided for @enterTeamName.
  ///
  /// In en, this message translates to:
  /// **'Enter team name'**
  String get enterTeamName;

  /// No description provided for @teamResults.
  ///
  /// In en, this message translates to:
  /// **'Team Results'**
  String get teamResults;

  /// No description provided for @pleaseEnterNamesForAllTeams.
  ///
  /// In en, this message translates to:
  /// **'Please enter names for all teams'**
  String get pleaseEnterNamesForAllTeams;

  /// No description provided for @teamNamesMustBeUnique.
  ///
  /// In en, this message translates to:
  /// **'Team names must be unique'**
  String get teamNamesMustBeUnique;

  /// No description provided for @videoDebug.
  ///
  /// In en, this message translates to:
  /// **'Video Debug'**
  String get videoDebug;

  /// No description provided for @saveReactionOnly.
  ///
  /// In en, this message translates to:
  /// **'Save Reaction Only'**
  String get saveReactionOnly;

  /// No description provided for @shareReactionVideo.
  ///
  /// In en, this message translates to:
  /// **'Share Reaction Video'**
  String get shareReactionVideo;

  /// No description provided for @shareWithGameOverlay.
  ///
  /// In en, this message translates to:
  /// **'Share with Game Overlay'**
  String get shareWithGameOverlay;

  /// No description provided for @videoWithOverlaySaved.
  ///
  /// In en, this message translates to:
  /// **'Video with overlay saved to gallery!'**
  String get videoWithOverlaySaved;

  /// No description provided for @startingGameWithDeck.
  ///
  /// In en, this message translates to:
  /// **'Starting game with {deckName}!'**
  String startingGameWithDeck(String deckName);

  /// No description provided for @switchedToMode.
  ///
  /// In en, this message translates to:
  /// **'Switched to {modeName} mode'**
  String switchedToMode(String modeName);

  /// No description provided for @customDeckCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Custom deck created successfully!'**
  String get customDeckCreatedSuccessfully;

  /// No description provided for @deckUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Deck updated successfully!'**
  String get deckUpdatedSuccessfully;

  /// No description provided for @deckDeleted.
  ///
  /// In en, this message translates to:
  /// **'{deckName} deleted'**
  String deckDeleted(String deckName);

  /// No description provided for @areYouSureDeleteDeck.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{deckName}\"?'**
  String areYouSureDeleteDeck(String deckName);

  /// No description provided for @adIntegrationComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ad integration coming soon!'**
  String get adIntegrationComingSoon;

  /// No description provided for @inAppPurchasesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'In-app purchases coming soon!'**
  String get inAppPurchasesComingSoon;

  /// No description provided for @noCustomDecksYet.
  ///
  /// In en, this message translates to:
  /// **'No Custom Decks Yet'**
  String get noCustomDecksYet;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No Favorites Yet'**
  String get noFavoritesYet;

  /// No description provided for @continuePlayingTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue Playing'**
  String get continuePlayingTitle;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @failedToLoadDecks.
  ///
  /// In en, this message translates to:
  /// **'Failed to load decks'**
  String get failedToLoadDecks;

  /// No description provided for @checkYourInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection'**
  String get checkYourInternetConnection;

  /// No description provided for @failedToLoadData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get failedToLoadData;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @tryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get tryAgainLater;

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get invalidInput;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @deckNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Deck name is required'**
  String get deckNameRequired;

  /// No description provided for @atLeastOneCardRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one card is required'**
  String get atLeastOneCardRequired;

  /// No description provided for @atLeastCardsRequired.
  ///
  /// In en, this message translates to:
  /// **'At least {count} cards are required'**
  String atLeastCardsRequired(int count);

  /// No description provided for @errorLoadingDailyDeck.
  ///
  /// In en, this message translates to:
  /// **'Error loading daily deck'**
  String get errorLoadingDailyDeck;

  /// No description provided for @errorLoadingStreakData.
  ///
  /// In en, this message translates to:
  /// **'Error loading streak data'**
  String get errorLoadingStreakData;

  /// No description provided for @failedToSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get failedToSaveSettings;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get cannotBeUndone;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @syncSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get syncSettings;

  /// No description provided for @syncMode.
  ///
  /// In en, this message translates to:
  /// **'Sync Mode'**
  String get syncMode;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get lastSync;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @featuredDecks.
  ///
  /// In en, this message translates to:
  /// **'Featured Decks'**
  String get featuredDecks;

  /// No description provided for @featuredDeck.
  ///
  /// In en, this message translates to:
  /// **'Featured Deck'**
  String get featuredDeck;

  /// No description provided for @partyFavorites.
  ///
  /// In en, this message translates to:
  /// **'Party Favorites'**
  String get partyFavorites;

  /// No description provided for @unlockMoreFun.
  ///
  /// In en, this message translates to:
  /// **'Unlock More Fun'**
  String get unlockMoreFun;

  /// No description provided for @noDecksAvailable.
  ///
  /// In en, this message translates to:
  /// **'No decks available'**
  String get noDecksAvailable;

  /// No description provided for @unableToLoadDecks.
  ///
  /// In en, this message translates to:
  /// **'Unable to Load Decks'**
  String get unableToLoadDecks;

  /// No description provided for @checkInternetAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection and try again'**
  String get checkInternetAndRetry;

  /// No description provided for @helloUser.
  ///
  /// In en, this message translates to:
  /// **'Hello!'**
  String get helloUser;

  /// No description provided for @whatWouldYouLikeToPlayToday.
  ///
  /// In en, this message translates to:
  /// **'What would you like to play today?'**
  String get whatWouldYouLikeToPlayToday;

  /// No description provided for @tapStarToAddFavorites.
  ///
  /// In en, this message translates to:
  /// **'Tap the star icon on any deck to add it to your favorites for quick access anytime!'**
  String get tapStarToAddFavorites;

  /// No description provided for @quickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quickAccess;

  /// No description provided for @trackFavorites.
  ///
  /// In en, this message translates to:
  /// **'Track Favorites'**
  String get trackFavorites;

  /// No description provided for @createCustomDeckPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Your Own'**
  String get createCustomDeckPromptTitle;

  /// No description provided for @createCustomDeckPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make custom decks with your own words and categories!'**
  String get createCustomDeckPromptSubtitle;

  /// No description provided for @unlockNow.
  ///
  /// In en, this message translates to:
  /// **'Unlock Now'**
  String get unlockNow;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @newBadge.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newBadge;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'DAY'**
  String get day;

  /// No description provided for @startYourStreakToday.
  ///
  /// In en, this message translates to:
  /// **'Start your streak today!'**
  String get startYourStreakToday;

  /// No description provided for @gamesWon.
  ///
  /// In en, this message translates to:
  /// **'Games Won'**
  String get gamesWon;

  /// No description provided for @winStreak.
  ///
  /// In en, this message translates to:
  /// **'Win Streak'**
  String get winStreak;

  /// No description provided for @playersMet.
  ///
  /// In en, this message translates to:
  /// **'Players Met'**
  String get playersMet;

  /// No description provided for @avgScore.
  ///
  /// In en, this message translates to:
  /// **'Avg Score'**
  String get avgScore;

  /// No description provided for @quickSetup.
  ///
  /// In en, this message translates to:
  /// **'Quick Setup'**
  String get quickSetup;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @gettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get gettingStarted;

  /// No description provided for @daysToGo.
  ///
  /// In en, this message translates to:
  /// **'{count} days to go'**
  String daysToGo(int count);

  /// No description provided for @weekWarrior.
  ///
  /// In en, this message translates to:
  /// **'Week Warrior'**
  String get weekWarrior;

  /// No description provided for @consistentPlayer.
  ///
  /// In en, this message translates to:
  /// **'Consistent Player'**
  String get consistentPlayer;

  /// No description provided for @monthlyMaster.
  ///
  /// In en, this message translates to:
  /// **'Monthly Master'**
  String get monthlyMaster;

  /// No description provided for @dedicatedGamer.
  ///
  /// In en, this message translates to:
  /// **'Dedicated Gamer'**
  String get dedicatedGamer;

  /// No description provided for @centuryClub.
  ///
  /// In en, this message translates to:
  /// **'Century Club'**
  String get centuryClub;

  /// No description provided for @premiumUnlockComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Premium unlock coming soon!'**
  String get premiumUnlockComingSoon;

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{day} other{days}}'**
  String dayCount(int count);

  /// No description provided for @searchForDecks.
  ///
  /// In en, this message translates to:
  /// **'Search for decks'**
  String get searchForDecks;

  /// No description provided for @trendingSearches.
  ///
  /// In en, this message translates to:
  /// **'Trending Searches'**
  String get trendingSearches;

  /// No description provided for @popularCategoriesRightNow.
  ///
  /// In en, this message translates to:
  /// **'Popular categories right now'**
  String get popularCategoriesRightNow;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearches;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @tryAdjustingYourSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search'**
  String get tryAdjustingYourSearch;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @gaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get gaming;

  /// No description provided for @world.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get world;

  /// No description provided for @romance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get romance;

  /// No description provided for @craftSomethingUnique.
  ///
  /// In en, this message translates to:
  /// **'Craft something unique'**
  String get craftSomethingUnique;

  /// No description provided for @refineAndPerfect.
  ///
  /// In en, this message translates to:
  /// **'Refine and perfect'**
  String get refineAndPerfect;

  /// No description provided for @deckInformation.
  ///
  /// In en, this message translates to:
  /// **'Deck Information'**
  String get deckInformation;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @enterUniqueName.
  ///
  /// In en, this message translates to:
  /// **'Enter a unique name'**
  String get enterUniqueName;

  /// No description provided for @tellUsAboutYourDeck.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your deck'**
  String get tellUsAboutYourDeck;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @customization.
  ///
  /// In en, this message translates to:
  /// **'Customization'**
  String get customization;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @moreNeeded.
  ///
  /// In en, this message translates to:
  /// **'{count} more needed'**
  String moreNeeded(int count);

  /// No description provided for @addACard.
  ///
  /// In en, this message translates to:
  /// **'Add a card...'**
  String get addACard;

  /// No description provided for @aiSuggestions.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestions'**
  String get aiSuggestions;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get discardChanges;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get unsavedChangesMessage;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @pleaseAddCards.
  ///
  /// In en, this message translates to:
  /// **'Please add at least {count} cards to your deck'**
  String pleaseAddCards(int count);

  /// No description provided for @deckNeedsCards.
  ///
  /// In en, this message translates to:
  /// **'A deck needs at least {count} cards to play'**
  String deckNeedsCards(int count);

  /// No description provided for @failedToSaveDeck.
  ///
  /// In en, this message translates to:
  /// **'Failed to save deck. Please try again.'**
  String get failedToSaveDeck;

  /// No description provided for @enterDeckNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter a deck name first'**
  String get enterDeckNameFirst;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @pleaseEnterDeckName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a deck name'**
  String get pleaseEnterDeckName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'ko',
    'nl',
    'pt',
    'ru',
    'th',
    'tr',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
