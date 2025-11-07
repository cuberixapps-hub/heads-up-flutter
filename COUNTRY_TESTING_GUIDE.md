# Country-Based Deck Filtering - Testing Guide

## Overview
This guide helps you test the automatic country-based deck filtering system in the Heads Up game.

## Prerequisites
1. Firebase Firestore with decks uploaded (with country fields)
2. Admin portal running to manage decks
3. Flutter app running on device/simulator

## Test Scenarios

### 1. Testing Different Countries on iOS Simulator

```bash
# Change simulator language/region:
# Settings > General > Language & Region > Region
# Select different regions to test:
- United States (US)
- India (IN)
- Japan (JP)
- Brazil (BR)
- United Kingdom (GB)
- Mexico (MX)
```

### 2. Testing Different Countries on Android Emulator

```bash
# Change emulator language/region:
# Settings > System > Languages & input > Languages
# Add different languages and regions to test
```

### 3. Testing in Code (Development)

You can temporarily override the country detection in `lib/services/location_service.dart`:

```dart
static Future<String> detectUserCountry() async {
  // For testing, return a specific country:
  return 'IN'; // Test India
  // return 'JP'; // Test Japan
  // return 'BR'; // Test Brazil
  // etc.
}
```

## Upload Test Data to Firebase

### Using Admin Portal

1. Navigate to http://localhost:5173 (admin portal)
2. Click "Create Deck"
3. Fill in the form:
   - **Name**: Test deck name
   - **Country**: Select target country
   - **Priority**: 0 for high priority, higher numbers for lower priority
   - **Tags**: Add relevant tags
   - **Active**: Check to make visible to users
4. Add at least 5 cards
5. Save the deck

### Sample Decks to Create

#### Universal Decks (visible to all countries)
- **Viral TikTok Trends** (Country: UNIVERSAL)
- **Netflix Originals** (Country: UNIVERSAL)
- **Gaming Icons** (Country: UNIVERSAL)

#### India-Specific Decks
- **Bollywood Superstars** (Country: IN)
- **Cricket Legends** (Country: IN)
- **Indian Street Food** (Country: IN)

#### Japan-Specific Decks
- **Anime Characters** (Country: JP)
- **Manga Titles** (Country: JP)
- **J-Pop Artists** (Country: JP)

#### US-Specific Decks
- **NFL Players** (Country: US)
- **American Fast Food** (Country: US)
- **US Presidents** (Country: US)

## Expected Behavior

### US User
- ✅ Sees: Universal decks + US-specific decks
- ❌ Doesn't see: India, Japan, Brazil, etc. specific decks

### India User
- ✅ Sees: Universal decks + India-specific decks
- ❌ Doesn't see: US, Japan, Brazil, etc. specific decks

### Search Behavior
- When searching, users can find decks from ALL countries
- Default browsing only shows user's country + universal

### Error States
- No internet: Shows error screen with retry button
- No decks available: Shows empty state message

## Debugging

### Check Detected Country
Add this to `home_screen_v2.dart` build method:
```dart
print('User country: ${deckProvider.userCountryCode}');
```

### Check Firebase Query
In `deck_firebase_service.dart`, log the query:
```dart
print('Querying decks for country: $countryCode');
```

### Verify Deck Data in Firestore
1. Go to Firebase Console
2. Navigate to Firestore Database
3. Check `decks` collection
4. Verify each deck has:
   - `country` field (string)
   - `isActive` field (boolean)
   - `priority` field (number)
   - `tags` field (array)

## Testing Checklist

- [ ] App detects correct country on launch
- [ ] Only relevant decks appear in browse mode
- [ ] Universal decks always appear
- [ ] Search works across all countries
- [ ] Offline state shows error message
- [ ] Admin portal can create/edit decks with country
- [ ] Decks sort by priority correctly
- [ ] Inactive decks don't appear in app
- [ ] Tags are searchable
- [ ] No local deck data is used

## Common Issues

1. **All decks showing**: Check if country field exists in Firestore
2. **No decks showing**: Verify isActive=true and country matches
3. **Wrong country detected**: Check device locale settings
4. **Firebase timeout**: Increase timeout in deck_provider.dart

## Performance Testing

1. Test with 100+ decks
2. Test with slow internet (Network Link Conditioner)
3. Test offline → online transition
4. Test with different priorities
