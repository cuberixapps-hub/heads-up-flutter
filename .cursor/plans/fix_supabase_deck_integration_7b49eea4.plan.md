---
name: Fix Supabase Deck Integration
overview: Fix `deck_provider.dart` to use Supabase instead of Firebase for all deck operations. The file currently uses `DeckSupabaseService` for some operations but still falls back to `DeckFirebaseService` for background refresh and real-time listeners.
todos:
  - id: fix-background-refresh
    content: Replace _deckFirebaseService with _deckService in _refreshDecksInBackground()
    status: completed
  - id: fix-realtime-listeners
    content: Replace _deckFirebaseService with _deckService in _setupRealtimeListeners()
    status: completed
  - id: remove-firebase-import
    content: Remove DeckFirebaseService import and instance variable
    status: completed
isProject: false
---

# Fix Supabase Integration in DeckProvider

## Problem

The `[lib/providers/deck_provider.dart](lib/providers/deck_provider.dart)` file is partially migrated - it uses Firebase for:

- Background deck refresh (line 159)
- Real-time deck streaming (lines 212-226)

## Changes Required

### 1. Update `_refreshDecksInBackground()` method (lines 152-199)

Replace Firebase call with Supabase:

```dart
// BEFORE (line 159):
final freshDecks = await _deckFirebaseService.refreshDecksByCountry(_userCountryCode)

// AFTER:
final freshDecks = await _deckService.refreshDecksByCountry(_userCountryCode)
```

### 2. Update `_setupRealtimeListeners()` method (lines 201-230)

Replace Firebase streaming with Supabase:

```dart
// BEFORE (line 212):
final subscription = _deckFirebaseService.streamDecksByCountry(_userCountryCode)

// AFTER:
final subscription = _deckService.streamDecksByCountry(_userCountryCode)
```

### 3. Remove unused Firebase deck service

Since Firebase is no longer needed for deck content, remove:

- Line 6: Remove import `'../services/deck_firebase_service.dart'`
- Line 19: Remove `final DeckFirebaseService _deckFirebaseService = DeckFirebaseService();`

## Files to Modify

| File | Change |

|------|--------|

| `[lib/providers/deck_provider.dart](lib/providers/deck_provider.dart)` | Replace Firebase with Supabase for background refresh and streaming |

## No Changes Needed

These files are already correctly using Supabase:

- `[lib/services/supabase_service.dart](lib/services/supabase_service.dart)`
- `[lib/services/deck_supabase_service.dart](lib/services/deck_supabase_service.dart)`
- `[lib/services/daily_deck_service.dart](lib/services/daily_deck_service.dart)`
- `[lib/main.dart](lib/main.dart)`
- `[lib/models/deck.dart](lib/models/deck.dart)`
- `[lib/models/daily_deck.dart](lib/models/daily_deck.dart)`
