import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';
import 'firebase_service.dart';

/// Feedback category with display properties
class FeedbackCategory {
  final String id;
  final String displayName;
  final String iconName;
  final int colorValue;
  final String description;

  const FeedbackCategory({
    required this.id,
    required this.displayName,
    required this.iconName,
    required this.colorValue,
    this.description = '',
  });
}

/// User feedback data model
class DeckFeedback {
  final String? id;
  final String userId;
  final String? deviceId;
  final String feedbackType;
  final List<String> selectedCategories;
  final String? deckSuggestion;
  final String? suggestionCategory;
  final String? userMessage;
  final int? rating;
  final String? relatedDeckId;
  final String? userCountry;
  final String? userLanguage;
  final String? platform;
  final String? appVersion;
  final DateTime? createdAt;

  DeckFeedback({
    this.id,
    required this.userId,
    this.deviceId,
    this.feedbackType = 'interest',
    this.selectedCategories = const [],
    this.deckSuggestion,
    this.suggestionCategory,
    this.userMessage,
    this.rating,
    this.relatedDeckId,
    this.userCountry,
    this.userLanguage,
    this.platform,
    this.appVersion,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'device_id': deviceId,
      'feedback_type': feedbackType,
      'selected_categories': selectedCategories,
      'deck_suggestion': deckSuggestion,
      'suggestion_category': suggestionCategory,
      'user_message': userMessage,
      'rating': rating,
      'related_deck_id': relatedDeckId,
      'user_country': userCountry,
      'user_language': userLanguage,
      'platform': platform,
      'app_version': appVersion,
    };
  }

  factory DeckFeedback.fromJson(Map<String, dynamic> json) {
    return DeckFeedback(
      id: json['id'],
      userId: json['user_id'] ?? '',
      deviceId: json['device_id'],
      feedbackType: json['feedback_type'] ?? 'interest',
      selectedCategories: List<String>.from(json['selected_categories'] ?? []),
      deckSuggestion: json['deck_suggestion'],
      suggestionCategory: json['suggestion_category'],
      userMessage: json['user_message'],
      rating: json['rating'],
      relatedDeckId: json['related_deck_id'],
      userCountry: json['user_country'],
      userLanguage: json['user_language'],
      platform: json['platform'],
      appVersion: json['app_version'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }
}

/// Service for managing deck feedback and user preferences
/// Stores data in Supabase for analytics and content planning
class DeckFeedbackService {
  static final DeckFeedbackService _instance = DeckFeedbackService._internal();
  factory DeckFeedbackService() => _instance;
  DeckFeedbackService._internal();

  final _supabaseService = SupabaseService();
  final _firebaseService = FirebaseService();

  // SharedPreferences keys
  static const String _feedbackSubmitCountKey = 'deck_feedback_submit_count';
  static const String _lastFeedbackDateKey = 'last_deck_feedback_date';
  static const String _deviceIdKey = 'device_uuid';

  // Default max feedback submissions (configurable via Supabase)
  static const int _defaultMaxFeedbackCount = 5;
  
  // Cached max feedback count from Supabase
  int? _cachedMaxFeedbackCount;

  /// Categories users can express interest in
  /// These are different from preferences - focused on desired NEW content
  static const List<FeedbackCategory> feedbackCategories = [
    FeedbackCategory(
      id: 'trending_pop_culture',
      displayName: 'Trending & Pop Culture',
      iconName: 'trending_up',
      colorValue: 0xFFFF6B6B,
      description: 'Latest viral trends, memes, and pop culture moments',
    ),
    FeedbackCategory(
      id: 'classic_nostalgia',
      displayName: '90s & 2000s Nostalgia',
      iconName: 'history',
      colorValue: 0xFFFECA57,
      description: 'Throwback content from the golden eras',
    ),
    FeedbackCategory(
      id: 'regional_content',
      displayName: 'Regional & Cultural',
      iconName: 'public',
      colorValue: 0xFF48BB78,
      description: 'Content specific to your country or culture',
    ),
    FeedbackCategory(
      id: 'party_games',
      displayName: 'Party & Social',
      iconName: 'celebration',
      colorValue: 0xFFA855F7,
      description: 'Fun decks perfect for parties and gatherings',
    ),
    FeedbackCategory(
      id: 'educational',
      displayName: 'Learning & Trivia',
      iconName: 'school',
      colorValue: 0xFF3B82F6,
      description: 'Educational content that\'s fun to play',
    ),
    FeedbackCategory(
      id: 'kids_family',
      displayName: 'Kids & Family',
      iconName: 'family_restroom',
      colorValue: 0xFFEC4899,
      description: 'Family-friendly content for all ages',
    ),
    FeedbackCategory(
      id: 'sports',
      displayName: 'Sports & Athletes',
      iconName: 'sports_basketball',
      colorValue: 0xFFEF4444,
      description: 'Sports legends, teams, and memorable moments',
    ),
    FeedbackCategory(
      id: 'gaming_esports',
      displayName: 'Gaming & Esports',
      iconName: 'sports_esports',
      colorValue: 0xFF8B5CF6,
      description: 'Video games, streamers, and esports',
    ),
    FeedbackCategory(
      id: 'music_artists',
      displayName: 'Music & Artists',
      iconName: 'music_note',
      colorValue: 0xFF06B6D4,
      description: 'Songs, albums, and musical artists',
    ),
    FeedbackCategory(
      id: 'movies_shows',
      displayName: 'Movies & TV Shows',
      iconName: 'movie',
      colorValue: 0xFFF59E0B,
      description: 'Films, series, and entertainment',
    ),
    FeedbackCategory(
      id: 'food_travel',
      displayName: 'Food & Travel',
      iconName: 'restaurant',
      colorValue: 0xFF10B981,
      description: 'Cuisines, destinations, and experiences',
    ),
    FeedbackCategory(
      id: 'custom_themed',
      displayName: 'Themed Events',
      iconName: 'event',
      colorValue: 0xFF78716C,
      description: 'Holiday specials, seasonal content',
    ),
  ];

  /// Get or create device ID for anonymous tracking
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }

  /// Get current user ID (Firebase UID or device ID)
  String _getUserId() {
    return _firebaseService.currentUser?.uid ?? '';
  }

  /// Get platform string
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

  /// Get max feedback count from Supabase config or use default
  Future<int> getMaxFeedbackCount() async {
    // Return cached value if available
    if (_cachedMaxFeedbackCount != null) {
      return _cachedMaxFeedbackCount!;
    }

    try {
      if (!_supabaseService.isInitialized || !_supabaseService.isConfigured) {
        return _defaultMaxFeedbackCount;
      }

      // Try to fetch from Supabase app_config table
      final response = await _supabaseService
          .from('app_config')
          .select('value')
          .eq('key', 'max_deck_feedback_count')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final value = int.tryParse(response['value'].toString());
        if (value != null && value > 0) {
          _cachedMaxFeedbackCount = value;
          debugPrint('📊 Max feedback count from Supabase: $value');
          return value;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch max feedback count from Supabase: $e');
    }

    // Use default if fetch fails
    _cachedMaxFeedbackCount = _defaultMaxFeedbackCount;
    return _defaultMaxFeedbackCount;
  }

  /// Get number of feedback submissions
  Future<int> getFeedbackSubmitCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_feedbackSubmitCountKey) ?? 0;
  }

  /// Increment feedback submit count
  Future<void> _incrementFeedbackCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_feedbackSubmitCountKey) ?? 0;
    await prefs.setInt(_feedbackSubmitCountKey, currentCount + 1);
    await prefs.setString(_lastFeedbackDateKey, DateTime.now().toIso8601String());
  }

  /// Get remaining feedback submissions allowed
  Future<int> getRemainingFeedbackCount() async {
    final maxCount = await getMaxFeedbackCount();
    final submitCount = await getFeedbackSubmitCount();
    return (maxCount - submitCount).clamp(0, maxCount);
  }

  /// Check if user can still submit feedback
  Future<bool> canSubmitFeedback() async {
    final remaining = await getRemainingFeedbackCount();
    return remaining > 0;
  }

  /// Submit user feedback to Supabase
  Future<bool> submitFeedback({
    required List<String> selectedCategories,
    String? deckSuggestion,
    String? userMessage,
    String? userCountry,
    String? userLanguage,
    String? appVersion,
  }) async {
    try {
      // Check if user can still submit
      if (!await canSubmitFeedback()) {
        debugPrint('❌ User has reached max feedback submissions');
        return false;
      }

      if (!_supabaseService.isInitialized || !_supabaseService.isConfigured) {
        debugPrint('❌ Supabase not initialized or configured');
        return false;
      }

      final deviceId = await _getDeviceId();
      final userId = _getUserId();
      final submitCount = await getFeedbackSubmitCount();

      final feedback = DeckFeedback(
        userId: userId.isEmpty ? deviceId : userId,
        deviceId: deviceId,
        feedbackType: 'interest',
        selectedCategories: selectedCategories,
        deckSuggestion: deckSuggestion,
        userMessage: userMessage,
        userCountry: userCountry,
        userLanguage: userLanguage,
        platform: _getPlatform(),
        appVersion: appVersion,
      );

      await _supabaseService.from('user_deck_feedback').insert(feedback.toJson());

      // Increment submission count
      await _incrementFeedbackCount();

      final newCount = submitCount + 1;
      final maxCount = await getMaxFeedbackCount();
      debugPrint('✅ Deck feedback submitted ($newCount/$maxCount): ${selectedCategories.length} categories');
      
      // Log to analytics
      await _firebaseService.logEvent(
        'deck_feedback_submitted',
        parameters: {
          'categories_count': selectedCategories.length,
          'has_suggestion': deckSuggestion?.isNotEmpty ?? false,
          'has_message': userMessage?.isNotEmpty ?? false,
          'submission_number': newCount,
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ Failed to submit deck feedback: $e');
      return false;
    }
  }

  /// Submit a deck suggestion
  Future<bool> submitSuggestion({
    required String suggestion,
    String? category,
    String? userCountry,
    String? appVersion,
  }) async {
    try {
      // Check if user can still submit
      if (!await canSubmitFeedback()) {
        debugPrint('❌ User has reached max feedback submissions');
        return false;
      }

      if (!_supabaseService.isInitialized || !_supabaseService.isConfigured) {
        debugPrint('❌ Supabase not initialized or configured');
        return false;
      }

      final deviceId = await _getDeviceId();
      final userId = _getUserId();

      final feedback = DeckFeedback(
        userId: userId.isEmpty ? deviceId : userId,
        deviceId: deviceId,
        feedbackType: 'suggestion',
        deckSuggestion: suggestion,
        suggestionCategory: category,
        userCountry: userCountry,
        platform: _getPlatform(),
        appVersion: appVersion,
      );

      await _supabaseService.from('user_deck_feedback').insert(feedback.toJson());

      // Increment submission count
      await _incrementFeedbackCount();

      debugPrint('✅ Deck suggestion submitted: $suggestion');
      
      await _firebaseService.logEvent(
        'deck_suggestion_submitted',
        parameters: {
          'category': category ?? 'none',
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ Failed to submit deck suggestion: $e');
      return false;
    }
  }

  /// Check if feedback section should be shown
  Future<bool> shouldShowFeedbackSection() async {
    // Check if user can still submit feedback
    return await canSubmitFeedback();
  }

  /// Reset feedback state (for testing)
  Future<void> resetFeedbackState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedbackSubmitCountKey);
    await prefs.remove(_lastFeedbackDateKey);
    _cachedMaxFeedbackCount = null;
    debugPrint('🗑️ Deck feedback state reset');
  }

  /// Clear cached config (call when app resumes to refresh)
  void clearCache() {
    _cachedMaxFeedbackCount = null;
  }
}
