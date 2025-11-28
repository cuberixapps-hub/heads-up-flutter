# Multilingual Implementation Checklist

## ✅ COMPLETED FILES

### Core Infrastructure
- [x] pubspec.yaml - Dependencies added
- [x] l10n.yaml - Configuration created
- [x] lib/l10n/*.arb - 17 language files created (~190 keys each)
- [x] lib/providers/language_provider.dart - Language management
- [x] lib/main.dart - Localization delegates configured
- [x] lib/models/deck.dart - Translation support added

### Screens
- [x] settings_screen.dart - FULLY LOCALIZED ✨
- [ ] home_screen_v2.dart - IN PROGRESS (Import added, needs string replacement)
- [ ] gameplay_screen.dart - Not started
- [ ] results_screen.dart - Not started
- [ ] deck_details_screen.dart - Not started
- [ ] search_screen.dart - Not started
- [ ] custom_deck_screen.dart - Not started
- [ ] custom_deck_management_screen.dart - Not started
- [ ] category_selection_screen.dart - Not started
- [ ] explore_screen.dart - Not started
- [ ] onboarding_screen.dart - Not started
- [ ] splash_screen.dart - Not started
- [ ] sync_settings_screen.dart - Not started
- [ ] team_setup_screen.dart - Not started
- [ ] team_results_screen.dart - Not started
- [ ] tutorial_screen.dart - Not started
- [ ] video_debug_screen.dart - Not started
- [ ] video_player_screen.dart - Not started
- [ ] video_player_with_overlay_screen.dart - Not started
- [ ] game_round_example.dart - Not started

### Widgets
- [ ] featured_deck_widget.dart - Not started
- [ ] daily_deck_widget.dart - Not started
- [ ] streak_widget.dart - Not started
- [ ] tutorial_overlay.dart - Not started
- [ ] network_status_widget.dart - Not started
- [ ] import_deck_dialog.dart - Not started
- [ ] color_picker_dialog.dart - Not started
- [ ] icon_picker_dialog.dart - Not started
- [ ] version_switcher.dart - Not started
- [ ] banner_ad_widget.dart - Not started
- [ ] (6 more widget files)

### Services
- [ ] deck_firebase_service.dart - Needs error localization
- [ ] daily_deck_service.dart - Needs error localization  
- [ ] game_firebase_service.dart - Needs error localization
- [ ] (Other services with user-facing errors)

## 📋 LOCALIZATION PATTERN

### For Each Screen/Widget File:

```dart
// 1. Add import at the top
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// 2. Replace ALL hardcoded strings using this pattern:

// Simple text
Text('Play Now') 
→ Text(AppLocalizations.of(context)!.playNow)

// Text with variables
Text('${deck.name} deleted')
→ Text(AppLocalizations.of(context)!.deckDeleted(deck.name))

// Button labels
ElevatedButton(child: Text('Save'))
→ ElevatedButton(child: Text(AppLocalizations.of(context)!.save))

// Titles and headers
AppBar(title: Text('Settings'))
→ AppBar(title: Text(AppLocalizations.of(context)!.settings))

// Error messages
throw Exception('Failed to load decks')
→ throw Exception(AppLocalizations.of(context)!.failedToLoadDecks)
```

## 🎯 HIGH PRIORITY STRINGS TO LOCALIZE

### Home Screen (home_screen_v2.dart)
Key strings that appear in UI:
- 'Trending', 'Quick', 'Party', 'My Decks', 'Favorites'
- 'Trending Now', 'Quick Games', 'Party Mode'
- 'Your Creations', 'My Favorites', 'All Decks'
- 'Continue Playing'
- Tutorial messages

### Gameplay Screen (gameplay_screen.dart)
- 'Play', 'Pass', 'Correct'
- 'Game Over', 'Paused'
- Timer display
- Score display

### Results Screen (results_screen.dart)
- 'Results', 'Final Score'
- 'Correct Answers', 'Passed Cards'
- 'Play Again', 'Share Results'

### Deck Details Screen
- 'Play Now', 'Cards', 'Description'
- Deck statistics

### Search Screen
- 'Search Decks', search placeholder
- 'No Results', 'No Decks Found'

## 📊 TRANSLATION KEY REFERENCE

All keys are defined in `lib/l10n/app_en.arb`. Here are the most commonly used:

### Actions
- playNow, play, pass, correct
- save, cancel, delete, edit, share
- import, export, refresh, retry

### Navigation  
- home, settings, search, explore
- back, close, done, next, previous

### Categories
- trending, quick, party, myDecks, favorites
- trendingNow, quickGames, partyMode
- yourCreations, myFavorites, allDecks

### Game
- score, round, timer, gameOver
- startGame, pauseGame, resumeGame, quitGame

### Decks
- selectDeck, createDeck, editDeck, deleteDeck
- deckName, deckDescription, cards
- nCards (with count parameter)

### Results
- results, finalScore, correctAnswers
- passedCards, accuracy, totalTime
- shareResults, playAgain

### Errors
- error, errorOccurred
- failedToLoadDecks, failedToLoadData
- checkYourInternetConnection
- noInternetConnection
- invalidInput, requiredField

### Messages
- startingGameWithDeck(deckName)
- deckDeleted(deckName)
- customDeckCreatedSuccessfully
- deckUpdatedSuccessfully

## 🔧 SERVICES ERROR LOCALIZATION

For services without direct BuildContext access:

### Option 1: Pass localized errors from calling code
```dart
// In service
void loadDecks(String errorMessage) {
  try {
    // ...
  } catch (e) {
    throw Exception(errorMessage);
  }
}

// From widget
final errorMsg = AppLocalizations.of(context)!.failedToLoadDecks;
service.loadDecks(errorMsg);
```

### Option 2: Return error codes, localize in UI
```dart
// Service returns error codes
enum DeckError { networkError, notFound, invalidData }

// Widget localizes
String getErrorMessage(DeckError error) {
  switch (error) {
    case DeckError.networkError:
      return AppLocalizations.of(context)!.noInternetConnection;
    case DeckError.notFound:
      return AppLocalizations.of(context)!.noDecksFound;
    // ...
  }
}
```

## 🚀 TESTING CHECKLIST

After localizing each file:
- [ ] Run `flutter pub get`
- [ ] Run `flutter gen-l10n` 
- [ ] Build app: `flutter build ios --debug` or `flutter build apk --debug`
- [ ] Test language switching in Settings
- [ ] Verify all visible text changes language
- [ ] Check for any remaining hardcoded strings
- [ ] Test RTL layout for Arabic

## 📈 PROGRESS TRACKING

- Total Screens: 24
- Screens Completed: 1 (settings_screen.dart)
- Screens In Progress: 1 (home_screen_v2.dart)
- Screens Remaining: 22

- Total Widgets: 16
- Widgets Completed: 0
- Widgets Remaining: 16

- Services with Errors: ~10
- Services Localized: 0

**Estimated completion**: 40-60 more file edits needed




