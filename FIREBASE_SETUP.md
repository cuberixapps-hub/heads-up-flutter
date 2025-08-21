# Firebase Setup Guide for Heads Up Game

This guide will help you complete the Firebase integration for your Heads Up game application.

## Prerequisites

1. **Flutter SDK** installed and configured
2. **Firebase CLI** installed (`npm install -g firebase-tools`)
3. **FlutterFire CLI** installed (`dart pub global activate flutterfire_cli`)
4. A **Google/Firebase account**

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name (e.g., "heads-up-game")
4. Enable/Disable Google Analytics (recommended: Enable)
5. Click "Create project"

## Step 2: Configure Firebase using FlutterFire CLI

Run the following command in your project root:

```bash
cd "/Users/chandangadhavi11/Documents/Cuberix/Games/Heads Up"
flutterfire configure
```

This command will:
- List your Firebase projects
- Let you select the project you just created
- Ask which platforms to support (select Android and iOS)
- Generate the `firebase_options.dart` file automatically
- Configure Android and iOS apps in Firebase

## Step 3: Android Configuration

### 3.1 Download google-services.json

1. In Firebase Console, go to Project Settings
2. Under "Your apps", find your Android app
3. Download `google-services.json`
4. Place it in `android/app/` directory

### 3.2 Update Android Build Files

The FlutterFire CLI should handle most of this, but verify:

**android/build.gradle:**
```gradle
buildscript {
    dependencies {
        // Add this line if not present
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**android/app/build.gradle:**
```gradle
// Add at the bottom of the file
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        minSdkVersion 21  // Firebase requires minimum SDK 21
        multiDexEnabled true  // Add this if you get dex errors
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

## Step 4: iOS Configuration

### 4.1 Download GoogleService-Info.plist

1. In Firebase Console, go to Project Settings
2. Under "Your apps", find your iOS app
3. Download `GoogleService-Info.plist`
4. Open your iOS project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
5. Drag `GoogleService-Info.plist` into the Runner folder in Xcode
6. Make sure "Copy items if needed" is checked
7. Select "Runner" as the target

### 4.2 Update iOS Minimum Version

In `ios/Podfile`, ensure minimum iOS version is set:
```ruby
platform :ios, '12.0'
```

### 4.3 Install iOS Dependencies

```bash
cd ios
pod install
cd ..
```

## Step 5: Initialize Firestore Database

1. Go to Firebase Console
2. Navigate to "Firestore Database" in the sidebar
3. Click "Create database"
4. Choose "Start in test mode" for development (configure security rules later)
5. Select your preferred location
6. Click "Enable"

## Step 6: Set Up Firestore Security Rules

For production, update your Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read access to default decks for all users
    match /defaultDecks/{deck} {
      allow read: if true;
      allow write: if false; // Only admin can write
    }
    
    // User-specific data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Custom decks subcollection
      match /customDecks/{deck} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Game sessions subcollection
      match /gameSessions/{session} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Global leaderboard
    match /globalLeaderboard/{entry} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == entry;
    }
    
    // Deck-specific leaderboards
    match /deckLeaderboards/{deckId}/scores/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 7: Enable Authentication

1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Enable the following sign-in methods:
   - **Anonymous** (for guest users)
   - **Email/Password** (optional, for registered users)
   - **Google Sign-In** (optional)

## Step 8: Run the Application

1. Get Flutter packages:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

## Step 9: Initialize Default Decks (First Run Only)

The app will automatically initialize default decks in Firestore on first run. Check the Firebase Console to verify the data is created.

## Troubleshooting

### Common Issues and Solutions

1. **Build errors after adding Firebase:**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter run
   ```

2. **Android: Dex limit exceeded:**
   - Ensure `multiDexEnabled true` is in `android/app/build.gradle`
   - Clean and rebuild the project

3. **iOS: CocoaPods issues:**
   ```bash
   cd ios
   pod deintegrate
   pod install
   cd ..
   ```

4. **Firebase initialization error:**
   - Verify `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in correct locations
   - Ensure Firebase project is properly configured

## Production Checklist

Before releasing to production:

- [ ] Update Firestore security rules (don't use test mode)
- [ ] Enable App Check for additional security
- [ ] Configure Firebase Analytics events
- [ ] Set up Firebase Crashlytics for error reporting
- [ ] Configure Firebase Performance Monitoring
- [ ] Set up proper authentication flow (not just anonymous)
- [ ] Enable Firebase Cloud Messaging for notifications (optional)
- [ ] Configure backup and recovery policies
- [ ] Set up monitoring and alerts

## Additional Features to Consider

1. **User Profiles**: Implement full user authentication with profiles
2. **Social Features**: Add friends, challenges, and multiplayer modes
3. **Cloud Functions**: Implement server-side logic for complex operations
4. **Remote Config**: Manage game settings remotely
5. **In-App Messaging**: Send targeted messages to users
6. **A/B Testing**: Test different features with Firebase A/B Testing

## Support

For issues specific to:
- **Flutter**: Check [Flutter documentation](https://flutter.dev/docs)
- **Firebase**: Check [Firebase documentation](https://firebase.google.com/docs)
- **FlutterFire**: Check [FlutterFire documentation](https://firebase.flutter.dev/)
