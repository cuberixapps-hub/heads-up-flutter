# Fix Firestore Index and Populate Data

## 🔧 Quick Fix for the Index Issue

### Step 1: Create the Firestore Index

The error you're seeing is because Firestore needs a composite index for our query. 

1. **Click this link** (from your error message):
   ```
   https://console.firebase.google.com/v1/r/project/heads-up-game-48f14/firestore/indexes?create_composite=ClFwcm9qZWN0cy9oZWFkcy11cC1nYW1lLTQ4ZjE0L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9kZWNrcy9pbmRleGVzL18QARoLCgdjb3VudHJ5EAEaDAoIaXNBY3RpdmUQARoMCghwcmlvcml0eRABGgwKCF9fbmFtZV9fEAE
   ```

2. It will automatically create the required index with fields:
   - country (Ascending)
   - isActive (Ascending) 
   - priority (Ascending)
   - __name__ (Ascending)

3. Wait 1-2 minutes for the index to build

### Step 2: Temporary Fix (Already Applied)

I've already simplified the query to avoid the index requirement initially:
- Changed from complex query to simpler `whereIn` query
- Client-side filtering for `isActive` and sorting by `priority`

## 📊 Populate Sample Data

### Option 1: Using Admin Portal (Easiest)

1. Run your admin portal:
   ```bash
   cd admin-portal
   npm run dev
   ```

2. Navigate to http://localhost:5173

3. Click "Create Deck" and add decks with:
   - **Country**: Select from dropdown (UNIVERSAL, IN, JP, US, etc.)
   - **Priority**: 0 for high priority
   - **Active**: Check the box
   - **Tags**: Add relevant tags
   - Add at least 5 cards per deck

### Option 2: Using the Dart Script

1. Run the population script:
   ```bash
   flutter run lib/scripts/populate_firebase_decks.dart
   ```

   This will add 14 sample decks:
   - 3 Universal decks
   - 4 India decks 
   - 2 USA decks
   - 2 Japan decks
   - 1 Korea deck
   - 1 Trending deck

### Option 3: Manual Firebase Console

1. Go to Firebase Console > Firestore Database
2. Click on `decks` collection
3. Add documents with this structure:

```json
{
  "name": "Bollywood Superstars",
  "description": "Iconic Bollywood actors",
  "country": "IN",
  "tags": ["bollywood", "movies", "india"],
  "priority": 1,
  "isActive": true,
  "isPremium": false,
  "iconCodePoint": 61448,
  "iconFontFamily": "FontAwesomeSolid",
  "colorValue": 4294944051,
  "cards": [
    "Shah Rukh Khan",
    "Salman Khan",
    "Aamir Khan",
    "Amitabh Bachchan",
    "Deepika Padukone"
  ],
  "createdAt": <Server Timestamp>,
  "updatedAt": <Server Timestamp>
}
```

## 🧪 Testing the Implementation

1. **Test with India locale**:
   - Your device is already set to India (`en_IN`)
   - You should see Universal + India decks

2. **Test other countries**:
   - Change device locale in Settings > Language & Region
   - Or temporarily modify `location_service.dart`:
   ```dart
   return 'US'; // Test USA
   return 'JP'; // Test Japan
   ```

3. **Expected Results**:
   - India users: See Bollywood, Cricket, Indian Food decks
   - US users: See NFL, Fast Food decks
   - All users: See Universal decks (TikTok, Netflix, Gaming)

## 📝 Sample Decks by Country

### Universal (All Users See These)
- Viral TikTok Trends
- Netflix Originals  
- Gaming Icons

### India 🇮🇳
- Bollywood Superstars
- Cricket Legends
- Indian Street Food
- Indian Web Series (Premium)

### USA 🇺🇸
- NFL Stars
- American Fast Food

### Japan 🇯🇵
- Anime Characters (Premium)
- Japanese Food

### Korea 🇰🇷
- K-Pop Groups (Premium)

### Trending 🔥
- Trending 2025

## 🚨 Troubleshooting

If decks still don't appear:

1. **Check Firestore**:
   - Verify decks exist in Firebase Console
   - Check `country` field matches expected values
   - Ensure `isActive: true`

2. **Check Detection**:
   ```dart
   print('User country: ${deckProvider.userCountryCode}');
   ```

3. **Force Refresh**:
   - Pull down to refresh in app
   - Clear app data and restart

4. **Create Index** (if not done):
   - Go to Firestore > Indexes
   - Create composite index for: country, isActive, priority
