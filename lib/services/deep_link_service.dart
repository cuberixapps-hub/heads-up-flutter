import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'firebase_service.dart';

/// Service for handling native App Links (Android) and Universal Links (iOS)
/// This implementation uses native deep linking without Firebase Dynamic Links
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static bool _initialized = false;
  
  // App Links instance
  late AppLinks _appLinks;
  
  // Stream subscription for link events
  StreamSubscription<Uri>? _linkSubscription;
  
  // Stream controller for deep link events
  final StreamController<DeepLinkData> _deepLinkController =
      StreamController<DeepLinkData>.broadcast();
  Stream<DeepLinkData> get onDeepLink => _deepLinkController.stream;

  // Configuration - Your app's domain for deep links
  // You'll need to host an assetlinks.json (Android) and apple-app-site-association (iOS) file
  static const String _baseUrl = 'https://headsupgame.app';
  static const String _fallbackUrl = 'https://headsupgame.app'; // Your website/landing page

  // Deep link paths
  static const String _deckPath = '/deck';
  static const String _resultsPath = '/results';
  static const String _invitePath = '/invite';
  
  // Custom URL scheme (fallback when Universal Links don't work)
  static const String _customScheme = 'headsup';

  /// Check if service is initialized
  static bool get isInitialized => _initialized;

  /// Initialize the deep link service
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ DeepLinkService already initialized');
      return;
    }

    final instance = DeepLinkService();
    await instance._init();
    _initialized = true;
    debugPrint('✅ DeepLinkService initialized (Native App Links)');
  }

  Future<void> _init() async {
    _appLinks = AppLinks();

    // Handle link when app is opened from terminated state
    await _handleInitialLink();

    // Listen for links while app is running
    _setupLinkListener();
  }

  /// Handle the initial deep link if app was opened from a link
  Future<void> _handleInitialLink() async {
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();

      if (initialLink != null) {
        debugPrint('🔗 Initial deep link: $initialLink');
        _processLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error handling initial deep link: $e');
    }
  }

  /// Set up listener for incoming links while app is running
  void _setupLinkListener() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('🔗 Received deep link: $uri');
        _processLink(uri);
      },
      onError: (error) {
        debugPrint('Error receiving deep link: $error');
      },
    );
  }

  /// Process a received deep link
  void _processLink(Uri link) {
    final path = link.path;
    final queryParams = link.queryParameters;

    DeepLinkData? linkData;

    if (path.contains(_deckPath) || queryParams.containsKey('deckId')) {
      linkData = DeepLinkData(
        type: DeepLinkType.deck,
        deckId: queryParams['deckId'] ?? queryParams['id'],
      );
    } else if (path.contains(_resultsPath) || queryParams.containsKey('score')) {
      linkData = DeepLinkData(
        type: DeepLinkType.results,
        deckName: queryParams['deck'] != null 
            ? Uri.decodeComponent(queryParams['deck']!)
            : null,
        score: int.tryParse(queryParams['score'] ?? ''),
        correct: int.tryParse(queryParams['correct'] ?? ''),
        passed: int.tryParse(queryParams['passed'] ?? ''),
      );
    } else if (path.contains(_invitePath) || queryParams.containsKey('ref')) {
      linkData = DeepLinkData(
        type: DeepLinkType.invite,
        referrerId: queryParams['ref'],
      );
    } else {
      // Default to opening home
      linkData = DeepLinkData(type: DeepLinkType.home);
    }

    _deepLinkController.add(linkData);
  }

  /// Navigate to the appropriate screen based on deep link data
  void handleDeepLinkNavigation(GoRouter router, DeepLinkData data) {
    switch (data.type) {
      case DeepLinkType.deck:
        if (data.deckId != null) {
          router.go('/deck/${data.deckId}');
        } else {
          router.go('/home');
        }
        break;
      case DeepLinkType.results:
        router.go('/shared-results', extra: data);
        break;
      case DeepLinkType.invite:
        // Track referral and go to home
        _trackReferral(data.referrerId);
        router.go('/home');
        break;
      case DeepLinkType.home:
        router.go('/home');
        break;
    }
  }

  /// Track referral for analytics
  Future<void> _trackReferral(String? referrerId) async {
    if (referrerId == null) return;
    
    try {
      await FirebaseService().logEvent(
        'referral_opened',
        parameters: {'referrer_id': referrerId},
      );
    } catch (e) {
      debugPrint('Error tracking referral: $e');
    }
  }

  // ============================================
  // LINK GENERATION
  // ============================================
  
  /// Generate a shareable link for a deck
  /// Returns a regular URL - for full deep link functionality, you need to
  /// host assetlinks.json (Android) and apple-app-site-association (iOS)
  String createDeckLink({
    required String deckId,
    required String deckName,
    String? description,
    String? imageUrl,
  }) {
    final encodedId = Uri.encodeComponent(deckId);
    return '$_baseUrl$_deckPath?deckId=$encodedId';
  }
  
  /// Create a fallback link using custom URL scheme (always works in-app)
  String createDeckLinkCustomScheme({required String deckId}) {
    final encodedId = Uri.encodeComponent(deckId);
    return '$_customScheme:/$_deckPath?deckId=$encodedId';
  }

  /// Generate a shareable link for game results
  String createResultsLink({
    required String deckName,
    required int score,
    required int correct,
    required int passed,
  }) {
    final encodedDeck = Uri.encodeComponent(deckName);
    return '$_baseUrl$_resultsPath?deck=$encodedDeck&score=$score&correct=$correct&passed=$passed';
  }

  /// Generate an app invite link
  String createInviteLink({String? referrerId}) {
    final userId = referrerId ?? FirebaseService().currentUser?.uid ?? 'unknown';
    return '$_baseUrl$_invitePath?ref=$userId';
  }
  
  /// Get the fallback/landing page URL for when app isn't installed
  String get fallbackUrl => _fallbackUrl;

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
    _deepLinkController.close();
  }
}

// ============================================
// DATA MODELS
// ============================================

/// Types of deep links
enum DeepLinkType {
  deck,
  results,
  invite,
  home,
}

/// Data extracted from a deep link
class DeepLinkData {
  final DeepLinkType type;
  final String? deckId;
  final String? deckName;
  final int? score;
  final int? correct;
  final int? passed;
  final String? referrerId;

  DeepLinkData({
    required this.type,
    this.deckId,
    this.deckName,
    this.score,
    this.correct,
    this.passed,
    this.referrerId,
  });

  @override
  String toString() {
    return 'DeepLinkData(type: $type, deckId: $deckId, deckName: $deckName, score: $score)';
  }
}
