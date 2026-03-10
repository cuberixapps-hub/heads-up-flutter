import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import '../config/environment.dart';
import '../firebase_options.dart';
import 'version_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  late FirebaseAnalytics _analytics;
  late FirebaseCrashlytics _crashlytics;
  late FirebaseRemoteConfig _remoteConfig;

  static bool _initialized = false;
  static bool _remoteConfigReady = false;

  // Remote Config Keys
  static const String _useProductionAdsKey = 'use_production_ads';

  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;
  FirebaseAnalytics get analytics => _analytics;
  FirebaseCrashlytics get crashlytics => _crashlytics;
  FirebaseRemoteConfig get remoteConfig => _remoteConfig;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Initialize Firebase and auto-create guest user
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Firebase.initializeApp is already called in main.dart (for early Crashlytics),
      // but this is safe to call again — it returns the existing instance.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Enable Firestore offline persistence
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024, // 100MB cache limit (was unlimited)
      );

      // Crashlytics error handlers are configured in main.dart before runApp()

      _initialized = true;
      debugPrint('✅ Firebase core initialized successfully');

      // Initialize Remote Config in background (don't block startup)
      _initializeRemoteConfig().catchError((e) {
        debugPrint('⚠️ Remote Config init failed: $e');
      });

      // Auto-create guest user in background (don't block startup)
      _initializeUserInBackground();
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      rethrow;
    }
  }
  
  /// Initialize user authentication in background
  Future<void> _initializeUserInBackground() async {
    try {
      if (_auth.currentUser == null) {
        // Create guest user with timeout
        await _createGuestUser().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('⚠️ Guest user creation timeout - will retry later');
          },
        );
      } else {
        // Update last seen (don't await - fire and forget)
        updateUserLastSeen();
      }
    } catch (e) {
      debugPrint('⚠️ Background user init failed: $e');
    }
  }

  // Create guest user automatically
  Future<void> _createGuestUser() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      if (userCredential.user != null) {
        await createUserProfile(userCredential.user!);
        await _analytics.logLogin(loginMethod: 'guest_auto');
        debugPrint(
          'Guest user created successfully: ${userCredential.user!.uid}',
        );
      }
    } catch (e) {
      debugPrint('Error creating guest user: $e');
      // Continue without user - app can work offline
    }
  }

  // Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      await _analytics.logLogin(loginMethod: 'anonymous');
      return userCredential.user;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Anonymous sign in failed',
      );
      return null;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      await _analytics.logLogin(loginMethod: 'email');
      return userCredential.user;
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      await _crashlytics.recordError(e, null, reason: 'Email sign in failed');
      return null;
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      await _analytics.logSignUp(signUpMethod: 'email');

      // Create user profile in Firestore
      if (userCredential.user != null) {
        await createUserProfile(userCredential.user!);
      }

      return userCredential.user;
    } catch (e) {
      debugPrint('Error signing up: $e');
      await _crashlytics.recordError(e, null, reason: 'Sign up failed');
      return null;
    }
  }

  // Create user profile in Firestore
  Future<void> createUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'statistics': {
          'totalGames': 0,
          'totalCorrect': 0,
          'totalPassed': 0,
          'highScore': 0,
        },
        'unlockedPremiumDecks': [],
        'customDecks': [],
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Create user profile failed',
      );
    }
  }

  // Update user last seen
  Future<void> updateUserLastSeen() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating last seen: $e');
      }
    }
  }

  // Save FCM token to user profile
  Future<void> saveFCMToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': _getPlatform(),
        });
        debugPrint('🔔 FCM token saved to Firestore');
      } catch (e) {
        debugPrint('Error saving FCM token: $e');
        // Try to create the field if it doesn't exist
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            'platform': _getPlatform(),
          }, SetOptions(merge: true));
        } catch (e2) {
          debugPrint('Error creating FCM token field: $e2');
        }
      }
    }
  }

  // Get platform string
  String _getPlatform() {
    try {
      if (kIsWeb) return 'web';
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _analytics.logEvent(name: 'user_logout');
    } catch (e) {
      debugPrint('Error signing out: $e');
      await _crashlytics.recordError(e, null, reason: 'Sign out failed');
    }
  }

  // Log custom event
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    try {
      // Convert parameters to Firebase Analytics compatible format
      // Firebase Analytics only accepts String, num (int/double) as values
      final Map<String, Object>? analyticsParams = parameters?.map((
        key,
        value,
      ) {
        // Convert booleans to integers (0/1)
        if (value is bool) {
          return MapEntry(key, value ? 1 : 0);
        }
        // Keep strings and numbers as is
        else if (value is String || value is num) {
          return MapEntry(key, value as Object);
        }
        // Convert other types to string
        else {
          return MapEntry(key, value.toString());
        }
      });

      await _analytics.logEvent(name: name, parameters: analyticsParams);
    } catch (e) {
      debugPrint('Error logging event: $e');
    }
  }
  
  // Log event with sampling rate to reduce Analytics costs
  // samplingRate: 0.0-1.0 (e.g., 0.2 = 20% of events logged)
  Future<void> logEventSampled(
    String name, {
    Map<String, dynamic>? parameters,
    double samplingRate = 1.0,
  }) async {
    if (samplingRate >= 1.0) {
      // Always log if sampling rate is 100%
      await logEvent(name, parameters: parameters);
      return;
    }
    
    if (samplingRate <= 0.0) {
      // Never log if sampling rate is 0%
      return;
    }
    
    // Use deterministic sampling based on milliseconds
    // This ensures consistent sampling across app sessions
    final shouldLog = (DateTime.now().millisecondsSinceEpoch % 100) < (samplingRate * 100);
    
    if (shouldLog) {
      await logEvent(name, parameters: parameters);
    }
  }

  // Log screen view
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Error logging screen view: $e');
    }
  }

  // Initialize Firebase Remote Config
  Future<void> _initializeRemoteConfig() async {
    try {
      // Set default values (CRITICAL: Default to false for safety)
      await _remoteConfig.setDefaults({
        _useProductionAdsKey: false, // Default to test ads
        // Version service defaults
        ...VersionService.getRemoteConfigDefaults(),
      });

      debugPrint(
        '📝 Remote Config: Default value set for $_useProductionAdsKey = false',
      );

      // Set config settings with SHORT fetch timeout to avoid blocking
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval:
              EnvironmentConfig.enableDebugLogging
                  ? const Duration(hours: 1)
                  : const Duration(hours: 24),
        ),
      );

      // Try to fetch, but don't wait too long - use cached values if slow
      try {
        final bool fetchSucceeded = await _remoteConfig.fetchAndActivate().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('📦 Remote Config: Fetch timeout, using cached values');
            return false;
          },
        );

        // Log fetch status
        if (fetchSucceeded) {
          debugPrint('✅ Remote Config: Successfully fetched from Firebase');
        } else {
          debugPrint('📦 Remote Config: Using cached values');
        }
      } catch (e) {
        debugPrint('📦 Remote Config: Fetch failed, using cached values');
      }

      // Listen for real-time updates (non-blocking)
      _remoteConfig.onConfigUpdated.listen((event) async {
        debugPrint('🔔 Remote Config: Update detected from Firebase!');
        await _remoteConfig.activate();

        final bool newValue = _remoteConfig.getBool(_useProductionAdsKey);
        debugPrint('🔄 Remote Config Updated:');
        debugPrint('   - New Value: $newValue');
        debugPrint(
          '   - Effective Production Ads: ${shouldUseProductionAds()}',
        );
      });

      _remoteConfigReady = true;
      debugPrint('🎛️ Remote Config initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Remote Config initialization failed: $e');
      debugPrint('⚠️ Will use default values (test ads)');
    }
  }

  /// Ensures Firebase is initialized and Remote Config has been fetched.
  /// Safe to call multiple times — returns immediately if already ready.
  /// Fails open: on any error or timeout, returns without throwing so the
  /// caller can proceed with default/cached values.
  Future<void> ensureRemoteConfigReady() async {
    if (_remoteConfigReady) return;

    try {
      if (!_initialized) {
        await initialize();
      }

      final rc = FirebaseRemoteConfig.instance;

      await rc.setDefaults({
        _useProductionAdsKey: false,
        ...VersionService.getRemoteConfigDefaults(),
      });

      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval:
              EnvironmentConfig.enableDebugLogging
                  ? const Duration(hours: 1)
                  : const Duration(hours: 24),
        ),
      );

      await rc.fetchAndActivate().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('📦 ensureRemoteConfigReady: fetch timeout, using cached values');
          return false;
        },
      );

      _remoteConfigReady = true;
      debugPrint('✅ ensureRemoteConfigReady: Remote Config is ready');
    } catch (e) {
      debugPrint('⚠️ ensureRemoteConfigReady failed: $e — continuing with defaults');
    }
  }

  // Check if production ads should be used (EnvironmentConfig overrides Remote Config in dev/UAT)
  static bool shouldUseProductionAds() {
    if (EnvironmentConfig.useTestAds) return false;
    if (!_initialized) return EnvironmentConfig.isProduction;
    final useProductionAds = _instance._remoteConfig.getBool(_useProductionAdsKey);
    return useProductionAds;
  }

  // Log error to Crashlytics
  static void logError(dynamic error, StackTrace? stackTrace) {
    if (_initialized) {
      _instance._crashlytics.recordError(error, stackTrace);
    }
  }
}
