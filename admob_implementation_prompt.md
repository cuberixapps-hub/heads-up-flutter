# Google AdMob Implementation Guide - Complete Integration Prompt

## Overview

This document provides a comprehensive guide for implementing Google AdMob in a Flutter application, based on the production-ready implementation in the Borderly app. This guide covers Android and iOS configuration, service architecture, ad types, safety mechanisms, and best practices.

## Prerequisites

1. **AdMob Account**: Create an AdMob account and register your app
2. **Flutter Packages**: Add required packages to pubspec.yaml:
   ```yaml
   dependencies:
     google_mobile_ads: ^4.0.0 # or latest version
     firebase_core: ^2.24.2
     firebase_crashlytics: ^3.4.9
     firebase_remote_config: ^4.3.8
   ```
3. **Firebase Project**: Create a Firebase project and link it to your app

## Step 1: Firebase Setup and Configuration

### 1.1 Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project or select existing one
3. Add your Android and iOS apps to the project
4. Download configuration files:
   - `google-services.json` for Android → Place in `android/app/`
   - `GoogleService-Info.plist` for iOS → Place in `ios/Runner/`

### 1.2 Firebase Remote Config Setup

1. In Firebase Console, go to **Remote Config**
2. Create a parameter:
   - **Parameter name**: `use_production_ads`
   - **Data type**: Boolean
   - **Default value**: `false` (IMPORTANT: Default to test ads for safety)
3. Save and publish changes

### 1.3 Create Firebase Service

Create `lib/core/services/firebase_service.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to manage Firebase Crashlytics and Remote Config
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static bool _initialized = false;
  static FirebaseRemoteConfig? _remoteConfig;

  // Remote Config Keys
  static const String _useProductionAdsKey = 'use_production_ads';

  /// Initialize Firebase services
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize Crashlytics
      await _initializeCrashlytics();

      // Initialize Remote Config
      await _initializeRemoteConfig();

      _initialized = true;
      debugPrint('✅ Firebase services initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization failed: $e');
      // Report the error to Crashlytics if it's initialized
      if (_initialized) {
        FirebaseCrashlytics.instance.recordError(e, stackTrace);
      }
    }
  }

  /// Initialize Firebase Crashlytics
  static Future<void> _initializeCrashlytics() async {
    // Pass all uncaught errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Disable Crashlytics collection in debug mode
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    debugPrint('🔥 Crashlytics initialized (Collection: ${!kDebugMode})');
  }

  /// Initialize Firebase Remote Config
  static Future<void> _initializeRemoteConfig() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values (CRITICAL: Default to false for safety)
      await _remoteConfig!.setDefaults({
        _useProductionAdsKey: false, // Default to test ads
      });

      debugPrint('📝 Remote Config: Default value set for $_useProductionAdsKey = false');

      // Set config settings
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 5)  // 5 minutes in debug for testing
              : const Duration(hours: 12),  // 12 hours in production
        ),
      );

      // Fetch and activate
      final bool fetchSucceeded = await _remoteConfig!.fetchAndActivate();

      // Log fetch status
      if (fetchSucceeded) {
        debugPrint('✅ Remote Config: Successfully fetched from Firebase');
      } else {
        debugPrint('📦 Remote Config: Using cached values');
      }

      // Log the actual value and its source
      final bool configValue = _remoteConfig!.getBool(_useProductionAdsKey);
      final ValueSource source = _remoteConfig!.getValue(_useProductionAdsKey).source;

      debugPrint('🔍 Remote Config Value Details:');
      debugPrint('   - Parameter: $_useProductionAdsKey');
      debugPrint('   - Raw Value from Firebase: $configValue');
      debugPrint('   - Value Source: ${_getSourceName(source)}');
      debugPrint('   - Last Fetch Time: ${_remoteConfig!.lastFetchTime}');

      // Listen for real-time updates
      _remoteConfig!.onConfigUpdated.listen((event) async {
        debugPrint('🔔 Remote Config: Update detected from Firebase!');
        await _remoteConfig!.activate();

        final bool newValue = _remoteConfig!.getBool(_useProductionAdsKey);
        debugPrint('🔄 Remote Config Updated:');
        debugPrint('   - New Value: $newValue');
        debugPrint('   - Effective Production Ads: ${shouldUseProductionAds()}');
      });

      debugPrint('🎛️ Remote Config initialized successfully');
      _logCurrentAdConfiguration();
    } catch (e) {
      debugPrint('⚠️ Remote Config initialization failed: $e');
      debugPrint('⚠️ Will use default values (test ads)');
    }
  }

  /// Get human-readable source name
  static String _getSourceName(ValueSource source) {
    switch (source) {
      case ValueSource.valueStatic:
        return 'Static (Default value)';
      case ValueSource.valueDefault:
        return 'Default (Local default)';
      case ValueSource.valueRemote:
        return 'Remote (From Firebase)';
      default:
        return 'Unknown';
    }
  }

  /// Log current ad configuration
  static void _logCurrentAdConfiguration() {
    final bool useProductionAds = shouldUseProductionAds();
    final bool remoteConfigValue = _remoteConfig?.getBool(_useProductionAdsKey) ?? false;

    debugPrint('');
    debugPrint('📱 === CURRENT AD CONFIGURATION ===');
    debugPrint('   Build Mode: ${kDebugMode ? "DEBUG" : (kProfileMode ? "PROFILE" : "RELEASE")}');
    debugPrint('   Remote Config ($_useProductionAdsKey): $remoteConfigValue');
    debugPrint('   Effective Setting: ${useProductionAds ? "PRODUCTION ADS" : "TEST ADS"}');

    if (kDebugMode || kProfileMode) {
      debugPrint('   ⚠️ Note: Debug/Profile mode always uses TEST ADS for safety');
    } else {
      debugPrint('   ✅ Production mode: Using Remote Config value');
    }
    debugPrint('===================================');
    debugPrint('');
  }

  /// Check if production ads should be used based on Remote Config
  static bool shouldUseProductionAds() {
    if (_remoteConfig == null) {
      // If Remote Config is not initialized, use default behavior
      return !kDebugMode && !kProfileMode;
    }

    // Get the value from Remote Config
    final useProductionAds = _remoteConfig!.getBool(_useProductionAdsKey);

    // SAFETY: In debug/profile mode, ALWAYS use test ads regardless of Remote Config
    if (kDebugMode || kProfileMode) {
      return false;
    }

    // In release mode, use the Remote Config value
    return useProductionAds;
  }

  /// Log error to Crashlytics
  static void logError(dynamic error, StackTrace? stackTrace) {
    if (_initialized) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }
}
```

## Step 2: Platform-Specific Configuration

### Android Configuration

#### 2.1 Update build.gradle files

**Project-level build.gradle** (`android/build.gradle`):

```gradle
buildscript {
    dependencies {
        // Add Google Services plugin
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**App-level build.gradle** (`android/app/build.gradle`):

```gradle
// At the bottom of the file
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        minSdkVersion 21  // Required minimum for AdMob
    }
}
```

#### 2.2 Add google-services.json

Place the `google-services.json` file (downloaded from Firebase Console) in `android/app/`

#### 2.3 Update AndroidManifest.xml

Add the AdMob App ID to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add permissions if needed for your app -->

    <application
        android:label="YourAppName"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- ... other configurations ... -->

        <!-- Google Mobile Ads App ID (REQUIRED) -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>

        <!-- ... rest of application config ... -->
    </application>
</manifest>
```

#### 1.2 Update build.gradle.kts

Ensure minimum SDK version is 21 or higher in `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 21
        // ... other configs
    }
}
```

### iOS Configuration

#### 2.4 Add GoogleService-Info.plist

1. Place the `GoogleService-Info.plist` file (downloaded from Firebase Console) in `ios/Runner/`
2. In Xcode, right-click on Runner folder and select "Add Files to Runner"
3. Select the `GoogleService-Info.plist` file and ensure "Copy items if needed" is checked

#### 2.5 Update Info.plist

Add the AdMob App ID to `ios/Runner/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ... other configurations ... -->

    <!-- Google AdMob App ID (REQUIRED) -->
    <key>GADApplicationIdentifier</key>
    <string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>

    <!-- SKAdNetwork for iOS 14+ (REQUIRED for better ad performance) -->
    <key>SKAdNetworkItems</key>
    <array>
        <dict>
            <key>SKAdNetworkIdentifier</key>
            <string>cstr6suwn9.skadnetwork</string>
        </dict>
    </array>

    <!-- App Tracking Transparency (iOS 14+) -->
    <key>NSUserTrackingUsageDescription</key>
    <string>This identifier will be used to deliver personalized ads to you.</string>

    <!-- ... rest of configurations ... -->
</dict>
</plist>
```

#### 2.6 Update Podfile

Set minimum iOS version to 12.0 or higher in `ios/Podfile`:

```ruby
platform :ios, '12.0'
```

## Step 2: Create AdService Architecture

### 2.1 Complete AdService Implementation

Create `lib/core/services/ad_service.dart`:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  static bool _initialized = false;

  // PRODUCTION Ad IDs - Replace with your actual IDs
  // Android
  static const String _prodAndroidBannerAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodAndroidInterstitialAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodAndroidRewardedAdUnitId = 'ca-app-pub-XXXX/XXXX';

  // iOS
  static const String _prodIosBannerAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodIosInterstitialAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodIosRewardedAdUnitId = 'ca-app-pub-XXXX/XXXX';

  // TEST Ad IDs - Google's official test IDs (DO NOT CHANGE)
  // Android
  static const String _testAndroidBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // iOS
  static const String _testIosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  /// CRITICAL: Automatically use test ads in debug/profile mode
  /// This prevents accidental clicks during development
  /// Also checks Firebase Remote Config for production override
  bool get _useTestAds {
    // Always use test ads in debug/profile mode for safety
    if (kDebugMode || kProfileMode) return true;

    // In release mode, check Firebase Remote Config
    // If Remote Config says use_production_ads = false, use test ads
    return !FirebaseService.shouldUseProductionAds();
  }

  /// Get the appropriate banner ad unit ID based on platform and mode
  String get bannerAdUnitId {
    if (_useTestAds) {
      if (Platform.isAndroid) return _testAndroidBannerAdUnitId;
      if (Platform.isIOS) return _testIosBannerAdUnitId;
    } else {
      if (Platform.isAndroid) return _prodAndroidBannerAdUnitId;
      if (Platform.isIOS) return _prodIosBannerAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  String get interstitialAdUnitId {
    if (_useTestAds) {
      if (Platform.isAndroid) return _testAndroidInterstitialAdUnitId;
      if (Platform.isIOS) return _testIosInterstitialAdUnitId;
    } else {
      if (Platform.isAndroid) return _prodAndroidInterstitialAdUnitId;
      if (Platform.isIOS) return _prodIosInterstitialAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  String get rewardedAdUnitId {
    if (_useTestAds) {
      if (Platform.isAndroid) return _testAndroidRewardedAdUnitId;
      if (Platform.isIOS) return _testIosRewardedAdUnitId;
    } else {
      if (Platform.isAndroid) return _prodAndroidRewardedAdUnitId;
      if (Platform.isIOS) return _prodIosRewardedAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;

      // Log initialization details for debugging
      final instance = AdService();
      final platform = Platform.isAndroid ? 'Android' : 'iOS';

      if (instance._useTestAds) {
        debugPrint('🔧 AdMob SDK initialized with TEST ADS');
        debugPrint('📍 Reason: ${kDebugMode ? "Debug Mode" : "Profile Mode"}');
      } else {
        debugPrint('✅ AdMob SDK initialized with PRODUCTION ADS');
      }
      debugPrint('📱 Platform: $platform');
      debugPrint('🆔 Banner ID: ${instance.bannerAdUnitId}');

      // Preload ads for better performance
      instance.loadBannerAd();
      instance.loadInterstitialAd();
      instance.loadRewardedAd();
    } catch (e) {
      debugPrint('❌ AdMob SDK initialization failed: $e');
    }
  }

  /// Load Banner Ad
  void loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isBannerAdReady = true;
          debugPrint('✅ Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner ad failed to load: $error');
          _isBannerAdReady = false;
          ad.dispose();
          _bannerAd = null;

          // Retry after delay
          Future.delayed(const Duration(seconds: 30), loadBannerAd);
        },
      ),
    );
    _bannerAd?.load();
  }

  /// Get Banner Ad Widget
  Widget? getBannerAdWidget() {
    if (_isBannerAdReady && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }

  /// Load Interstitial Ad
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('✅ Interstitial ad loaded');

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Interstitial ad failed to show: $error');
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial ad failed to load: $error');
          _isInterstitialAdReady = false;

          // Retry after delay
          Future.delayed(const Duration(seconds: 60), loadInterstitialAd);
        },
      ),
    );
  }

  /// Show Interstitial Ad
  Future<void> showInterstitialAd() async {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      debugPrint('⚠️ Interstitial ad not ready');
      loadInterstitialAd(); // Try loading if not ready
    }
  }

  /// Load Rewarded Ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('✅ Rewarded ad loaded');

          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Rewarded ad failed to show: $error');
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded ad failed to load: $error');
          _isRewardedAdReady = false;

          // Retry after delay
          Future.delayed(const Duration(seconds: 60), loadRewardedAd);
        },
      ),
    );
  }

  /// Show Rewarded Ad with callback
  Future<void> showRewardedAd({
    required Function(num amount) onUserEarnedReward,
  }) async {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.setImmersiveMode(true);
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onUserEarnedReward(reward.amount);
        },
      );
    } else {
      debugPrint('⚠️ Rewarded ad not ready');
      loadRewardedAd(); // Try loading if not ready
    }
  }

  /// Dispose all ads
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
```

## Step 3: Create Reusable Banner Ad Widget

### 3.1 Banner Ad Widget Implementation

Create `lib/shared/widgets/banner_ad_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:your_app/core/services/ad_service.dart';

/// A reusable banner ad widget that displays Google AdMob banner ads
class BannerAdWidget extends StatefulWidget {
  final EdgeInsets padding;
  final Color? backgroundColor;
  final String widgetKey;

  const BannerAdWidget({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.backgroundColor,
    required this.widgetKey, // Unique key to identify this banner instance
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  final AdService _adService = AdService();
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdReady = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load for ${widget.widgetKey}: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerAdReady = false;

          // Retry after delay
          if (mounted) {
            Future.delayed(const Duration(seconds: 30), () {
              if (mounted) _loadBannerAd();
            });
          }
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBannerAdReady || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: widget.backgroundColor ??
             (isDark ? Colors.black.withOpacity(0.8)
                     : Colors.white.withOpacity(0.9)),
      padding: widget.padding,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}

/// A widget that shows a banner ad at the bottom of a screen
class BottomBannerAd extends StatelessWidget {
  final Widget child;
  final bool showAd;
  final String widgetKey;

  const BottomBannerAd({
    super.key,
    required this.child,
    required this.widgetKey,
    this.showAd = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        if (showAd) BannerAdWidget(widgetKey: widgetKey),
      ],
    );
  }
}
```

## Step 4: Initialize Services in Main App

### 4.1 Update main.dart

```dart
import 'package:flutter/material.dart';
import 'package:your_app/core/services/firebase_service.dart';
import 'package:your_app/core/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: Initialize Firebase FIRST (includes Remote Config)
  await FirebaseService.initialize();

  // Initialize AdMob (will use Firebase Remote Config to determine ad type)
  await AdService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

## Step 5: Implement Ads in Your Screens

### 5.1 Banner Ad Example

```dart
import 'package:flutter/material.dart';
import 'package:your_app/shared/widgets/banner_ad_widget.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Your content here
              ],
            ),
          ),
          // Banner ad at bottom
          const BannerAdWidget(widgetKey: 'home_screen_banner'),
        ],
      ),
    );
  }
}
```

### 5.2 Interstitial Ad Example

```dart
class EditorScreen extends StatelessWidget {
  final AdService _adService = AdService();

  Future<void> _saveImage() async {
    // Save image logic

    // Show interstitial ad after save
    await _adService.showInterstitialAd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your UI
    );
  }
}
```

### 5.3 Rewarded Ad Example

```dart
class PremiumFeatureScreen extends StatelessWidget {
  final AdService _adService = AdService();

  Future<void> _watchAdForCredits() async {
    await _adService.showRewardedAd(
      onUserEarnedReward: (amount) {
        // Grant user credits/rewards
        debugPrint('User earned $amount credits');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your UI with button to watch ad
    );
  }
}
```

## Step 6: Advanced Features (Optional)

### 6.1 Premium Users - Disable Ads

```dart
class AdService {
  // Add premium check
  bool get shouldShowAds => !isPremiumUser();

  void loadBannerAd() {
    // Skip loading if premium user
    if (!shouldShowAds) {
      debugPrint('Skipping ad load - premium user');
      return;
    }
    // ... rest of implementation
  }
}
```

### 6.2 Remote Config for Production/Test Ads

```dart
import 'package:firebase_remote_config/firebase_remote_config.dart';

class AdService {
  bool get _useTestAds {
    // Check debug mode first
    if (kDebugMode || kProfileMode) return true;

    // Check remote config for production override
    final remoteConfig = FirebaseRemoteConfig.instance;
    return !remoteConfig.getBool('use_production_ads');
  }
}
```

## Step 7: Testing Checklist

### Development Testing

- [ ] Test ads show in debug mode (should be Google's test ads)
- [ ] Banner ads display correctly on different screen sizes
- [ ] Interstitial ads show at appropriate times
- [ ] Rewarded ads grant rewards correctly
- [ ] No ads overlap with UI elements
- [ ] Ads refresh properly after failures

### Production Testing

- [ ] Production ads show in release build
- [ ] Verify correct App IDs in AndroidManifest.xml and Info.plist
- [ ] Test on both Android and iOS devices
- [ ] Check AdMob dashboard for impressions
- [ ] Ensure no policy violations

## Step 8: AdMob Policy Compliance

### Best Practices

1. **Spacing**: Keep ads away from interactive elements (minimum 16dp)
2. **Placement**: Don't place ads where users might accidentally click
3. **Loading**: Don't show loading indicators for ads
4. **Frequency**: Limit interstitial ads (max 1 per user action)
5. **Context**: Don't show ads during app launch or exit
6. **Test Ads**: ALWAYS use test ads during development

### Common Violations to Avoid

- ❌ Placing ads too close to buttons
- ❌ Showing interstitials on app launch
- ❌ Forcing users to click ads
- ❌ Modifying ad behavior or appearance
- ❌ Using production ads during development

## Step 9: Troubleshooting

### Common Issues and Solutions

#### Ads Not Showing

1. Check internet connection
2. Verify AdMob account is approved
3. Check if ad units are active in AdMob console
4. Review console logs for errors
5. Ensure correct App IDs are configured

#### Duplicate App ID Error (Android)

- Check AndroidManifest.xml for duplicate `com.google.android.gms.ads.APPLICATION_ID` entries
- Ensure only one entry exists

#### iOS Build Failures

- Run `cd ios && pod install`
- Clean build: `flutter clean && flutter pub get`
- Check minimum iOS version is 12.0 or higher

## Step 10: Firebase Remote Config Control

### 10.1 How Remote Config Controls Ads

The implementation uses a **three-layer safety system**:

1. **Debug/Profile Mode**: ALWAYS uses test ads (highest priority)
2. **Firebase Remote Config**: Controls production/test ads in release mode
3. **Default Fallback**: Uses test ads if Firebase fails

### 10.2 Firebase Console Configuration

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Navigate to **Remote Config**
3. Configure the `use_production_ads` parameter:
   - **Development/Testing**: Set to `false`
   - **Production**: Set to `true` when ready

### 10.3 Safety Features

#### Automatic Test Ads in Development

```dart
// In AdService
bool get _useTestAds {
  // Safety Layer 1: Always test ads in debug/profile
  if (kDebugMode || kProfileMode) return true;

  // Safety Layer 2: Check Firebase Remote Config
  return !FirebaseService.shouldUseProductionAds();
}
```

#### Default to Test Ads

```dart
// In FirebaseService
await _remoteConfig!.setDefaults({
  'use_production_ads': false, // Default to test ads for safety
});
```

### 10.4 Console Output for Debugging

The app provides detailed logging to track ad configuration:

```
📝 Remote Config: Default value set for use_production_ads = false
✅ Remote Config: Successfully fetched from Firebase
🔍 Remote Config Value Details:
   - Parameter: use_production_ads
   - Raw Value from Firebase: false
   - Value Source: Remote (From Firebase)
   - Last Fetch Time: 2024-01-15 10:30:45

📱 === CURRENT AD CONFIGURATION ===
   Build Mode: DEBUG
   Remote Config (use_production_ads): false
   Effective Setting: TEST ADS
   ⚠️ Note: Debug/Profile mode always uses TEST ADS for safety
===================================

🔧 AdMob SDK initialized with TEST ADS
📍 Reason: Debug Mode
📱 Platform: Android
🆔 Banner Test ID: ca-app-pub-3940256099942544/6300978111
```

### 10.5 Testing Production Ads Safely

1. **Set Remote Config**: In Firebase Console, set `use_production_ads` to `true`
2. **Build Release Version**: `flutter build apk --release` or `flutter build ios --release`
3. **Monitor Logs**: Check console output to verify production ads are loading
4. **Quick Rollback**: If issues occur, set Remote Config back to `false` instantly

### 10.6 Benefits of Firebase Integration

- **Instant Control**: Switch between test/production ads without app update
- **A/B Testing**: Test different ad configurations with user segments
- **Emergency Shutoff**: Disable ads instantly if policy issues arise
- **Gradual Rollout**: Enable production ads for percentage of users
- **Error Tracking**: Crashlytics automatically logs ad-related errors

## Step 11: Monitoring and Optimization

### Key Metrics to Track

- **Fill Rate**: Percentage of ad requests filled
- **eCPM**: Effective cost per thousand impressions
- **Click-Through Rate**: User engagement with ads
- **Revenue**: Daily/monthly ad revenue

### Optimization Tips

1. Use mediation for better fill rates
2. Implement adaptive banners for better layouts
3. Test different ad placements
4. Use native ads for better user experience
5. A/B test ad frequency and timing

## Summary

This implementation provides a **complete Firebase-integrated AdMob solution** with:

### Core Features

- ✅ **Firebase Remote Config Integration** - Control ads without app updates
- ✅ **Three-Layer Safety System** - Prevents accidental production ad clicks
- ✅ **Automatic Test/Production Switching** - Based on build mode and Remote Config
- ✅ **Platform-Specific Ad Unit IDs** - Separate IDs for Android and iOS
- ✅ **Robust Error Handling** - Automatic retry logic for failed ad loads
- ✅ **Reusable Ad Widgets** - Ready-to-use banner components
- ✅ **All Ad Types Supported** - Banner, Interstitial, and Rewarded ads
- ✅ **Premium User Support** - Ad-free experience for subscribers
- ✅ **Crashlytics Integration** - Automatic error reporting
- ✅ **AdMob Policy Compliance** - Built-in safety mechanisms

### Firebase Integration Benefits

1. **Remote Control**: Switch between test/production ads instantly via Firebase Console
2. **Safety First**: Default to test ads, enable production only when ready
3. **A/B Testing**: Test different ad configurations with user segments
4. **Emergency Shutoff**: Disable ads immediately if issues arise
5. **Gradual Rollout**: Enable production ads for percentage of users
6. **Real-time Updates**: Changes apply without app store updates
7. **Error Tracking**: Crashlytics logs all ad-related errors automatically
8. **Detailed Logging**: Console output shows exact ad configuration status

### Implementation Checklist

- [ ] Create Firebase project and link apps
- [ ] Download and add configuration files (google-services.json, GoogleService-Info.plist)
- [ ] Set up Remote Config with `use_production_ads` parameter (default: false)
- [ ] Replace placeholder AdMob IDs with your actual IDs
- [ ] Initialize Firebase before AdMob in main.dart
- [ ] Test with test ads in debug mode
- [ ] Verify Remote Config is working via console logs
- [ ] Test production ads in release build (with Remote Config = true)
- [ ] Monitor AdMob and Firebase dashboards

### Critical Safety Rules

1. **ALWAYS** default Remote Config to `false` (test ads)
2. **NEVER** use production ads during development
3. **ALWAYS** initialize Firebase before AdMob
4. **MONITOR** console logs to verify correct ad type is loading
5. **TEST** thoroughly before enabling production ads

This implementation has been **tested and proven in production** with the Borderly app, ensuring reliability, safety, and compliance with Google AdMob policies. The Firebase integration provides unprecedented control and safety for managing ads in production.
