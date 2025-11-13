import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

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

      // Configure Crashlytics
      if (!kDebugMode) {
        await _crashlytics.setCrashlyticsCollectionEnabled(true);
        FlutterError.onError = _crashlytics.recordFlutterError;
      }

      // Initialize Remote Config
      await _initializeRemoteConfig();

      // Auto-create guest user if not already signed in
      if (_auth.currentUser == null) {
        await _createGuestUser();
      } else {
        // Update last seen for existing user
        await updateUserLastSeen();
      }

      _initialized = true;
      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      rethrow;
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
    if (currentUser != null) {
      try {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating last seen: $e');
      }
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
      });

      debugPrint(
        '📝 Remote Config: Default value set for $_useProductionAdsKey = false',
      );

      // Set config settings
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval:
              kDebugMode
                  ? const Duration(hours: 1) // 1 hour in debug (was 5 min)
                  : const Duration(hours: 24), // 24 hours in production (was 12)
        ),
      );

      // Fetch and activate
      final bool fetchSucceeded = await _remoteConfig.fetchAndActivate();

      // Log fetch status
      if (fetchSucceeded) {
        debugPrint('✅ Remote Config: Successfully fetched from Firebase');
      } else {
        debugPrint('📦 Remote Config: Using cached values');
      }

      // Log the actual value and its source
      final bool configValue = _remoteConfig.getBool(_useProductionAdsKey);
      final ValueSource source =
          _remoteConfig.getValue(_useProductionAdsKey).source;

      debugPrint('🔍 Remote Config Value Details:');
      debugPrint('   - Parameter: $_useProductionAdsKey');
      debugPrint('   - Raw Value from Firebase: $configValue');
      debugPrint('   - Value Source: ${_getSourceName(source)}');
      debugPrint('   - Last Fetch Time: ${_remoteConfig.lastFetchTime}');

      // Listen for real-time updates
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

      debugPrint('🎛️ Remote Config initialized successfully');
      _logCurrentAdConfiguration();
    } catch (e) {
      debugPrint('⚠️ Remote Config initialization failed: $e');
      debugPrint('⚠️ Will use default values (test ads)');
    }
  }

  // Get human-readable source name
  static String _getSourceName(ValueSource source) {
    switch (source) {
      case ValueSource.valueStatic:
        return 'Static (Default value)';
      case ValueSource.valueDefault:
        return 'Default (Local default)';
      case ValueSource.valueRemote:
        return 'Remote (From Firebase)';
    }
  }

  // Log current ad configuration
  static void _logCurrentAdConfiguration() {
    final bool useProductionAds = shouldUseProductionAds();
    final bool remoteConfigValue = _instance._remoteConfig.getBool(
      _useProductionAdsKey,
    );

    debugPrint('');
    debugPrint('📱 === CURRENT AD CONFIGURATION ===');
    debugPrint(
      '   Build Mode: ${kDebugMode ? "DEBUG" : (kProfileMode ? "PROFILE" : "RELEASE")}',
    );
    debugPrint('   Remote Config ($_useProductionAdsKey): $remoteConfigValue');
    debugPrint(
      '   Effective Setting: ${useProductionAds ? "PRODUCTION ADS" : "TEST ADS"}',
    );

    if (kDebugMode || kProfileMode) {
      debugPrint(
        '   ⚠️ Note: Debug/Profile mode always uses TEST ADS for safety',
      );
    } else {
      debugPrint('   ✅ Production mode: Using Remote Config value');
    }
    debugPrint('===================================');
    debugPrint('');
  }

  // Check if production ads should be used based on Remote Config
  static bool shouldUseProductionAds() {
    if (!_initialized) {
      // If not initialized, use default behavior
      return !kDebugMode && !kProfileMode;
    }

    // Get the value from Remote Config
    final useProductionAds = _instance._remoteConfig.getBool(
      _useProductionAdsKey,
    );

    // SAFETY: In debug/profile mode, ALWAYS use test ads regardless of Remote Config
    if (kDebugMode || kProfileMode) {
      return false;
    }

    // In release mode, use the Remote Config value
    return useProductionAds;
  }

  // Log error to Crashlytics
  static void logError(dynamic error, StackTrace? stackTrace) {
    if (_initialized) {
      _instance._crashlytics.recordError(error, stackTrace);
    }
  }
}
