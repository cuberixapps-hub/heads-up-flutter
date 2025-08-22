import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;
  FirebaseAnalytics get analytics => _analytics;
  FirebaseCrashlytics get crashlytics => _crashlytics;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Initialize Firebase and auto-create guest user
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      // Enable Firestore offline persistence
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configure Crashlytics
      if (!kDebugMode) {
        await _crashlytics.setCrashlyticsCollectionEnabled(true);
        FlutterError.onError = _crashlytics.recordFlutterError;
      }

      // Auto-create guest user if not already signed in
      if (_auth.currentUser == null) {
        await _createGuestUser();
      } else {
        // Update last seen for existing user
        await updateUserLastSeen();
      }

      debugPrint('Firebase initialized successfully');
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

  // Log screen view
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Error logging screen view: $e');
    }
  }
}
