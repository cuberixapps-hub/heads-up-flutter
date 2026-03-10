import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a user interest category for content preferences
class InterestCategory {
  final String id;
  final String displayName;
  final String iconName;
  final int colorValue;

  const InterestCategory({
    required this.id,
    required this.displayName,
    required this.iconName,
    required this.colorValue,
  });
}

/// Service for managing user content preferences
/// Stores selected interests locally and provides methods to filter/prioritize decks
class UserPreferenceService {
  static final UserPreferenceService _instance = UserPreferenceService._internal();
  factory UserPreferenceService() => _instance;
  UserPreferenceService._internal();

  // SharedPreferences keys
  static const String _selectedInterestsKey = 'user_selected_interests';
  static const String _hasSetPreferencesKey = 'has_set_preferences';
  static const String _preferencesVersionKey = 'preferences_version';

  // Current version for future migrations
  static const int _currentVersion = 1;

  /// Available interest categories that users can select
  /// These map to deck tags for filtering
  static const List<InterestCategory> availableInterests = [
    InterestCategory(
      id: 'movies',
      displayName: 'Movies & TV',
      iconName: 'movie_rounded',
      colorValue: 0xFFFF6B6B,
    ),
    InterestCategory(
      id: 'music',
      displayName: 'Music',
      iconName: 'music_note_rounded',
      colorValue: 0xFFA855F7,
    ),
    InterestCategory(
      id: 'sports',
      displayName: 'Sports',
      iconName: 'sports_basketball_rounded',
      colorValue: 0xFF22C55E,
    ),
    InterestCategory(
      id: 'party',
      displayName: 'Party Games',
      iconName: 'celebration_rounded',
      colorValue: 0xFFF59E0B,
    ),
    InterestCategory(
      id: 'trivia',
      displayName: 'Trivia & Facts',
      iconName: 'psychology_rounded',
      colorValue: 0xFF06B6D4,
    ),
    InterestCategory(
      id: 'celebrities',
      displayName: 'Celebrities',
      iconName: 'star_rounded',
      colorValue: 0xFFEC4899,
    ),
    InterestCategory(
      id: 'gaming',
      displayName: 'Gaming',
      iconName: 'sports_esports_rounded',
      colorValue: 0xFF8B5CF6,
    ),
    InterestCategory(
      id: 'food',
      displayName: 'Food & Drink',
      iconName: 'restaurant_rounded',
      colorValue: 0xFFEF4444,
    ),
    InterestCategory(
      id: 'nature',
      displayName: 'Nature & Animals',
      iconName: 'pets_rounded',
      colorValue: 0xFF10B981,
    ),
    InterestCategory(
      id: 'science',
      displayName: 'Science & Tech',
      iconName: 'science_rounded',
      colorValue: 0xFF3B82F6,
    ),
    InterestCategory(
      id: 'history',
      displayName: 'History',
      iconName: 'history_edu_rounded',
      colorValue: 0xFF78716C,
    ),
    InterestCategory(
      id: 'kids',
      displayName: 'Kids & Family',
      iconName: 'family_restroom_rounded',
      colorValue: 0xFFFBBF24,
    ),
  ];

  /// Mapping of interest IDs to related deck tags and keywords
  /// Used for matching decks to user preferences (comprehensive keywords for better matching)
  static const Map<String, List<String>> interestToTagsMap = {
    'movies': [
      'movies', 'movie', 'tv', 'television', 'film', 'cinema', 'entertainment', 
      'actors', 'actress', 'hollywood', 'bollywood', 'netflix', 'streaming',
      'series', 'shows', 'sitcom', 'drama', 'comedy', 'thriller', 'horror',
      'action', 'romantic', 'blockbuster', 'oscar', 'emmy', 'marvel', 'dc',
      'disney', 'pixar', 'animated', 'animation', 'cartoon'
    ],
    'music': [
      'music', 'songs', 'singers', 'artists', 'bands', 'albums', 'concerts',
      'pop', 'rock', 'hip hop', 'rap', 'jazz', 'classical', 'country',
      'r&b', 'edm', 'electronic', 'indie', 'metal', 'punk', 'soul',
      'grammy', 'billboard', 'spotify', 'lyrics', 'melody', 'rhythm',
      'musical', 'instrument', 'guitar', 'piano', 'drums'
    ],
    'sports': [
      'sports', 'football', 'basketball', 'soccer', 'baseball', 'tennis', 
      'athletes', 'olympics', 'nfl', 'nba', 'mlb', 'fifa', 'cricket',
      'hockey', 'golf', 'boxing', 'mma', 'ufc', 'racing', 'f1',
      'swimming', 'athletics', 'gym', 'fitness', 'workout', 'players',
      'teams', 'championship', 'world cup', 'super bowl', 'ipl'
    ],
    'party': [
      'party', 'fun', 'games', 'drinking', 'social', 'group', 'friends',
      'celebration', 'gathering', 'charades', 'acting', 'guessing',
      'ice breaker', 'team', 'multiplayer', 'adult', 'night', 'weekend'
    ],
    'trivia': [
      'trivia', 'facts', 'knowledge', 'quiz', 'general', 'education',
      'brain', 'iq', 'smart', 'learn', 'educational', 'questions',
      'answers', 'challenge', 'test', 'geography', 'vocabulary', 'words'
    ],
    'celebrities': [
      'celebrities', 'famous', 'stars', 'influencers', 'pop culture', 'hollywood',
      'bollywood', 'actors', 'singers', 'models', 'social media', 'instagram',
      'tiktok', 'youtube', 'viral', 'trending', 'personality', 'icon',
      'legend', 'superstar', 'award', 'red carpet'
    ],
    'gaming': [
      'gaming', 'video games', 'games', 'esports', 'console', 'pc games',
      'playstation', 'xbox', 'nintendo', 'steam', 'twitch', 'streamer',
      'rpg', 'fps', 'moba', 'battle royale', 'fortnite', 'minecraft',
      'gamer', 'controller', 'keyboard', 'mouse', 'vr', 'mobile games'
    ],
    'food': [
      'food', 'cooking', 'drinks', 'cuisine', 'recipes', 'restaurants',
      'chef', 'baking', 'dessert', 'pizza', 'burger', 'sushi', 'indian',
      'italian', 'mexican', 'chinese', 'thai', 'healthy', 'junk food',
      'snacks', 'beverages', 'cocktails', 'wine', 'beer', 'coffee', 'tea'
    ],
    'nature': [
      'nature', 'animals', 'wildlife', 'pets', 'environment', 'outdoors',
      'dogs', 'cats', 'birds', 'fish', 'zoo', 'safari', 'jungle',
      'ocean', 'forest', 'mountains', 'rivers', 'plants', 'flowers',
      'trees', 'garden', 'conservation', 'endangered', 'mammals', 'reptiles'
    ],
    'science': [
      'science', 'technology', 'tech', 'space', 'innovation', 'computers',
      'ai', 'artificial intelligence', 'robot', 'nasa', 'astronomy',
      'physics', 'chemistry', 'biology', 'medicine', 'health', 'research',
      'invention', 'scientist', 'discovery', 'experiment', 'lab', 'data'
    ],
    'history': [
      'history', 'historical', 'ancient', 'world events', 'past',
      'war', 'civilization', 'empire', 'king', 'queen', 'president',
      'revolution', 'independence', 'medieval', 'renaissance', 'century',
      'monument', 'heritage', 'culture', 'tradition', 'archaeology'
    ],
    'kids': [
      'kids', 'family', 'children', 'cartoon', 'animated', 'disney', 'pixar',
      'nickelodeon', 'paw patrol', 'peppa pig', 'cocomelon', 'toy',
      'superhero', 'princess', 'fairy tale', 'nursery', 'school',
      'learning', 'educational', 'fun for kids', 'child friendly', 'pg'
    ],
  };

  /// Save user's selected interest IDs
  Future<void> savePreferences(List<String> interestIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_selectedInterestsKey, interestIds);
      await prefs.setBool(_hasSetPreferencesKey, true);
      await prefs.setInt(_preferencesVersionKey, _currentVersion);
      debugPrint('✅ UserPreferenceService: Saved ${interestIds.length} interests: $interestIds');
    } catch (e) {
      debugPrint('❌ UserPreferenceService: Error saving preferences: $e');
    }
  }

  /// Get user's selected interest IDs
  Future<List<String>> getPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interests = prefs.getStringList(_selectedInterestsKey) ?? [];
      debugPrint('📖 UserPreferenceService: Loaded ${interests.length} interests');
      return interests;
    } catch (e) {
      debugPrint('❌ UserPreferenceService: Error loading preferences: $e');
      return [];
    }
  }

  /// Check if user has set preferences before
  Future<bool> hasSetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasSetPreferencesKey) ?? false;
    } catch (e) {
      debugPrint('❌ UserPreferenceService: Error checking preferences: $e');
      return false;
    }
  }

  /// Clear all preferences (for reset or testing)
  Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedInterestsKey);
      await prefs.remove(_hasSetPreferencesKey);
      await prefs.remove(_preferencesVersionKey);
      debugPrint('🗑️ UserPreferenceService: Cleared all preferences');
    } catch (e) {
      debugPrint('❌ UserPreferenceService: Error clearing preferences: $e');
    }
  }

  /// Get all deck tags that match user's selected interests
  Future<Set<String>> getPreferredTags() async {
    final selectedInterests = await getPreferences();
    final tags = <String>{};
    
    for (final interest in selectedInterests) {
      final relatedTags = interestToTagsMap[interest];
      if (relatedTags != null) {
        tags.addAll(relatedTags);
      }
    }
    
    return tags;
  }

  /// Check if a deck matches user preferences
  /// Returns a score from 0-100 based on how well the deck matches
  Future<int> getDeckPreferenceScore(List<String> deckTags) async {
    if (deckTags.isEmpty) return 0;
    
    final preferredTags = await getPreferredTags();
    if (preferredTags.isEmpty) return 50; // Neutral score if no preferences set
    
    // Convert deck tags to lowercase for comparison
    final lowerDeckTags = deckTags.map((t) => t.toLowerCase()).toSet();
    
    // Count matching tags
    int matchCount = 0;
    for (final tag in preferredTags) {
      if (lowerDeckTags.contains(tag.toLowerCase())) {
        matchCount++;
      }
    }
    
    if (matchCount == 0) return 0;
    
    // Calculate score based on match ratio (max 100)
    final score = ((matchCount / preferredTags.length) * 100).round().clamp(0, 100);
    return score;
  }

  /// Synchronous version for use in providers (uses cached data)
  List<String> _cachedPreferences = [];
  bool _isCacheLoaded = false;

  /// Initialize cache - call this early in app startup
  Future<void> initialize() async {
    _cachedPreferences = await getPreferences();
    _isCacheLoaded = true;
    debugPrint('🚀 UserPreferenceService: Initialized with ${_cachedPreferences.length} preferences');
  }

  /// Get cached preferences synchronously
  List<String> get cachedPreferences => _cachedPreferences;
  
  /// Check if cache is loaded
  bool get isCacheLoaded => _isCacheLoaded;

  /// Update cache after saving
  Future<void> savePreferencesAndUpdateCache(List<String> interestIds) async {
    await savePreferences(interestIds);
    _cachedPreferences = interestIds;
    _isCacheLoaded = true;
  }

  /// Get preferred tags synchronously from cache
  Set<String> getCachedPreferredTags() {
    final tags = <String>{};
    
    for (final interest in _cachedPreferences) {
      final relatedTags = interestToTagsMap[interest];
      if (relatedTags != null) {
        tags.addAll(relatedTags);
      }
    }
    
    return tags;
  }

  /// Calculate deck preference score synchronously from cache
  int getCachedDeckPreferenceScore(List<String> deckTags) {
    if (deckTags.isEmpty) return 0;
    
    final preferredTags = getCachedPreferredTags();
    if (preferredTags.isEmpty) return 50; // Neutral score if no preferences set
    
    // Convert deck tags to lowercase for comparison
    final lowerDeckTags = deckTags.map((t) => t.toLowerCase()).toSet();
    
    // Count matching tags
    int matchCount = 0;
    for (final tag in preferredTags) {
      if (lowerDeckTags.contains(tag.toLowerCase())) {
        matchCount++;
      }
    }
    
    if (matchCount == 0) return 0;
    
    // Calculate score based on match ratio (max 100)
    final score = ((matchCount / preferredTags.length) * 100).round().clamp(0, 100);
    return score;
  }

  /// Check if a deck name or description matches user interests
  /// Used as fallback when deck has no tags
  /// Enhanced to match whole words and give higher scores for strong matches
  int getNameMatchScore(String deckName, String deckDescription) {
    if (!_isCacheLoaded || _cachedPreferences.isEmpty) return 50;
    
    final combinedText = '${deckName.toLowerCase()} ${deckDescription.toLowerCase()}';
    final preferredTags = getCachedPreferredTags();
    
    int matchCount = 0;
    int strongMatchCount = 0; // For whole word matches
    
    for (final tag in preferredTags) {
      final tagLower = tag.toLowerCase();
      
      // Check for whole word match (more valuable)
      // Using word boundary check
      final wordPattern = RegExp(r'\b' + RegExp.escape(tagLower) + r'\b');
      if (wordPattern.hasMatch(combinedText)) {
        strongMatchCount++;
        matchCount++;
      } else if (combinedText.contains(tagLower)) {
        // Partial match (less valuable but still counts)
        matchCount++;
      }
    }
    
    if (matchCount == 0) return 0;
    
    // Calculate score: strong matches count more
    // Base score from total matches, with bonus for strong matches
    final baseScore = ((matchCount / preferredTags.length) * 80).round();
    final strongBonus = (strongMatchCount * 5).clamp(0, 20); // Up to 20 bonus points
    
    return (baseScore + strongBonus).clamp(0, 100);
  }

  /// Check if a specific interest matches a deck (for debugging)
  bool doesInterestMatchDeck(String interestId, String deckName, String deckDescription, List<String> deckTags) {
    final tags = interestToTagsMap[interestId];
    if (tags == null) return false;
    
    final combinedText = '${deckName.toLowerCase()} ${deckDescription.toLowerCase()} ${deckTags.join(' ').toLowerCase()}';
    
    for (final tag in tags) {
      if (combinedText.contains(tag.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
