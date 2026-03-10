import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../models/cache_entry.dart';
import '../models/deck.dart';
import 'firebase_service.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Cache keys
  static const String _decksCacheKey = 'cached_decks_';
  static const String _leaderboardCacheKey = 'cached_leaderboard_';
  static const String _cacheMetadataKey = 'cache_metadata';
  static const String _lastFetchTimestampKey = 'last_decks_fetch_';
  
  // TTL: production = 24h; dev + UAT = 0 (always fetch fresh)
  static Duration get decksTTL => EnvironmentConfig.isProduction
      ? const Duration(hours: 24)
      : Duration.zero;
  
  static const Duration leaderboardTTL = Duration(minutes: 30);
  static const Duration gameHistoryTTL = Duration(minutes: 15);
  static const Duration statisticsTTL = Duration(hours: 1);
  
  // Cache size limits
  static const int maxCacheEntries = 50;
  static const int maxCacheSizeMB = 10;
  
  /// Check if we should fetch fresh data from Firebase
  /// - Dev + UAT: always true (fresh data)
  /// - Production: false (rely on cache TTL)
  bool get shouldFetchFreshData {
    if (!EnvironmentConfig.isProduction) {
      if (EnvironmentConfig.enableDebugLogging) {
        debugPrint('🔧 Non-production: Will always fetch fresh data from Firebase');
      }
      return true;
    }
    return false;
  }
  
  /// Check if decks cache for a specific country needs refresh
  /// Returns true if:
  /// - In debug/profile mode (always fresh)
  /// - Cache is expired in production mode
  /// - No cache exists
  Future<bool> shouldRefreshDecks(String countryCode) async {
    if (!_initialized) await initialize();
    
    if (!EnvironmentConfig.isProduction) {
      if (EnvironmentConfig.enableDebugLogging) {
        debugPrint('🔧 Non-production: Forcing fresh fetch for $countryCode');
      }
      return true;
    }
    
    // In production, check if cache is expired
    final lastFetchTime = await getLastFetchTimestamp(countryCode);
    if (lastFetchTime == null) {
      debugPrint('📭 No previous fetch timestamp for $countryCode - will fetch');
      return true;
    }
    
    final timeSinceLastFetch = DateTime.now().difference(lastFetchTime);
    final isExpired = timeSinceLastFetch >= decksTTL;
    
    if (isExpired) {
      debugPrint('⏰ Cache expired for $countryCode (${timeSinceLastFetch.inHours}h old) - will fetch');
    } else {
      debugPrint('✅ Cache valid for $countryCode (${timeSinceLastFetch.inHours}h old, TTL: ${decksTTL.inHours}h)');
    }
    
    return isExpired;
  }
  
  /// Get last fetch timestamp for a country
  Future<DateTime?> getLastFetchTimestamp(String countryCode) async {
    if (!_initialized) await initialize();
    
    try {
      final timestampStr = _prefs.getString('$_lastFetchTimestampKey$countryCode');
      if (timestampStr != null) {
        return DateTime.parse(timestampStr);
      }
    } catch (e) {
      debugPrint('Error getting last fetch timestamp: $e');
    }
    return null;
  }
  
  /// Record fetch timestamp for a country
  Future<void> recordFetchTimestamp(String countryCode) async {
    if (!_initialized) await initialize();
    
    try {
      await _prefs.setString(
        '$_lastFetchTimestampKey$countryCode',
        DateTime.now().toIso8601String(),
      );
      debugPrint('📝 Recorded fetch timestamp for $countryCode');
    } catch (e) {
      debugPrint('Error recording fetch timestamp: $e');
    }
  }
  
  // Initialize the cache service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      
      // Clean expired entries on startup
      await cleanExpiredEntries();
      
      debugPrint('✅ CacheService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing CacheService: $e');
    }
  }
  
  // Cache decks by country
  Future<void> cacheDecksByCountry(String countryCode, List<Deck> decks) async {
    if (!_initialized) await initialize();
    
    try {
      final cacheEntry = CacheEntry<List<Map<String, dynamic>>>(
        data: decks.map((d) => _deckToMap(d)).toList(),
        timestamp: DateTime.now(),
        ttl: decksTTL,
      );
      
      final key = '$_decksCacheKey$countryCode';
      final json = cacheEntry.toJson(
        dataToJson: (data) => {'decks': data},
      );
      
      await _prefs.setString(key, jsonEncode(json));
      await _updateCacheMetadata(key);
      
      // Log cache event
      await FirebaseService().logEvent('cache_write', parameters: {
        'cache_type': 'decks',
        'country': countryCode,
        'items_count': decks.length,
      });
      
      debugPrint('📝 Cached ${decks.length} decks for country: $countryCode');
    } catch (e) {
      debugPrint('Error caching decks: $e');
    }
  }
  
  // Get cached decks by country
  // Note: This returns cached data regardless of expiry status.
  // The shouldRefreshDecks() method controls whether to fetch fresh data.
  // This ensures cached data is always available as fallback.
  Future<List<Deck>?> getCachedDecksByCountry(String countryCode) async {
    if (!_initialized) await initialize();
    
    try {
      final key = '$_decksCacheKey$countryCode';
      final cachedJson = _prefs.getString(key);
      
      if (cachedJson == null) {
        await FirebaseService().logEvent('cache_miss', parameters: {
          'cache_type': 'decks',
          'country': countryCode,
        });
        return null;
      }
      
      final json = jsonDecode(cachedJson);
      final cacheEntry = CacheEntry<List<dynamic>>.fromJson(
        json: json,
        dataFromJson: (data) => (data['decks'] as List<dynamic>),
      );
      
      final decks = cacheEntry.data
          .map((map) => _mapToDeck(map as Map<String, dynamic>))
          .toList();
      
      // Check if cache is expired for logging purposes only
      // (we still return the data, shouldRefreshDecks() handles refresh logic)
      final isExpired = cacheEntry.isExpired;
      
      await FirebaseService().logEvent('cache_hit', parameters: {
        'cache_type': 'decks',
        'country': countryCode,
        'items_count': decks.length,
        'was_expired': isExpired,
      });
      
      debugPrint('✅ Cache hit: ${decks.length} decks for $countryCode${isExpired ? ' (stale)' : ''}');
      return decks;
    } catch (e) {
      debugPrint('Error getting cached decks: $e');
      return null;
    }
  }
  
  // Cache leaderboard page
  Future<void> cacheLeaderboardPage(
    String leaderboardId,
    int pageNumber,
    List<Map<String, dynamic>> entries,
  ) async {
    if (!_initialized) await initialize();
    
    try {
      final key = '$_leaderboardCacheKey${leaderboardId}_page_$pageNumber';
      final cacheEntry = CacheEntry<List<Map<String, dynamic>>>(
        data: entries,
        timestamp: DateTime.now(),
        ttl: leaderboardTTL,
      );
      
      final json = cacheEntry.toJson(
        dataToJson: (data) => {'entries': data},
      );
      
      await _prefs.setString(key, jsonEncode(json));
      await _updateCacheMetadata(key);
      
      debugPrint('📝 Cached leaderboard page $pageNumber for $leaderboardId');
    } catch (e) {
      debugPrint('Error caching leaderboard page: $e');
    }
  }
  
  // Get cached leaderboard page
  Future<List<Map<String, dynamic>>?> getCachedLeaderboardPage(
    String leaderboardId,
    int pageNumber,
  ) async {
    if (!_initialized) await initialize();
    
    try {
      final key = '$_leaderboardCacheKey${leaderboardId}_page_$pageNumber';
      final cachedJson = _prefs.getString(key);
      
      if (cachedJson == null) return null;
      
      final json = jsonDecode(cachedJson);
      final cacheEntry = CacheEntry<List<dynamic>>.fromJson(
        json: json,
        dataFromJson: (data) => (data['entries'] as List<dynamic>),
      );
      
      if (cacheEntry.isExpired) {
        await _prefs.remove(key);
        return null;
      }
      
      return cacheEntry.data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting cached leaderboard page: $e');
      return null;
    }
  }
  
  // Generic cache methods
  Future<void> cacheData<T>({
    required String key,
    required T data,
    required Duration ttl,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    if (!_initialized) await initialize();
    
    try {
      final cacheEntry = CacheEntry<T>(
        data: data,
        timestamp: DateTime.now(),
        ttl: ttl,
      );
      
      final json = cacheEntry.toJson(dataToJson: toJson);
      await _prefs.setString(key, jsonEncode(json));
      await _updateCacheMetadata(key);
    } catch (e) {
      debugPrint('Error caching data for key $key: $e');
    }
  }
  
  Future<T?> getCachedData<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    if (!_initialized) await initialize();
    
    try {
      final cachedJson = _prefs.getString(key);
      if (cachedJson == null) return null;
      
      final json = jsonDecode(cachedJson);
      final cacheEntry = CacheEntry<Map<String, dynamic>>.fromJson(
        json: json,
        dataFromJson: (Map<String, dynamic> data) => data,
      );
      
      if (cacheEntry.isExpired) {
        await _prefs.remove(key);
        return null;
      }
      
      return fromJson(cacheEntry.data);
    } catch (e) {
      debugPrint('Error getting cached data for key $key: $e');
      return null;
    }
  }
  
  // Clear specific cache
  Future<void> clearCache(String pattern) async {
    if (!_initialized) await initialize();
    
    final keys = _prefs.getKeys().where((key) => key.contains(pattern));
    for (final key in keys) {
      await _prefs.remove(key);
    }
    
    debugPrint('🗑️ Cleared cache matching pattern: $pattern');
  }
  
  // Clear all cache
  Future<void> clearAllCache() async {
    if (!_initialized) await initialize();
    
    final keys = _prefs.getKeys().where((key) => 
      key.startsWith(_decksCacheKey) || 
      key.startsWith(_leaderboardCacheKey) ||
      key == _cacheMetadataKey
    );
    
    for (final key in keys) {
      await _prefs.remove(key);
    }
    
    debugPrint('🗑️ Cleared all cache');
  }
  
  // Clean expired entries
  Future<void> cleanExpiredEntries() async {
    if (!_initialized) await initialize();
    
    try {
      final metadata = _getCacheMetadata();
      final keysToRemove = <String>[];
      
      for (final entry in metadata.entries) {
        final cachedJson = _prefs.getString(entry.key);
        if (cachedJson != null) {
          try {
            final json = jsonDecode(cachedJson);
            final timestamp = DateTime.parse(json['timestamp']);
            final ttl = Duration(seconds: json['ttl']);
            
            if (DateTime.now().isAfter(timestamp.add(ttl))) {
              keysToRemove.add(entry.key);
            }
          } catch (_) {
            keysToRemove.add(entry.key);
          }
        }
      }
      
      for (final key in keysToRemove) {
        await _prefs.remove(key);
        metadata.remove(key);
      }
      
      await _saveCacheMetadata(metadata);
      
      if (keysToRemove.isNotEmpty) {
        debugPrint('🧹 Cleaned ${keysToRemove.length} expired cache entries');
      }
    } catch (e) {
      debugPrint('Error cleaning expired entries: $e');
    }
  }
  
  // Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    if (!_initialized) return {};
    
    final metadata = _getCacheMetadata();
    int totalSize = 0;
    int decksCacheCount = 0;
    int leaderboardCacheCount = 0;
    
    for (final key in metadata.keys) {
      final value = _prefs.getString(key);
      if (value != null) {
        totalSize += value.length;
        if (key.startsWith(_decksCacheKey)) decksCacheCount++;
        if (key.startsWith(_leaderboardCacheKey)) leaderboardCacheCount++;
      }
    }
    
    return {
      'totalEntries': metadata.length,
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'decksCacheCount': decksCacheCount,
      'leaderboardCacheCount': leaderboardCacheCount,
    };
  }
  
  // Private helper methods
  Map<String, DateTime> _getCacheMetadata() {
    final json = _prefs.getString(_cacheMetadataKey);
    if (json == null) return {};
    
    try {
      final Map<String, dynamic> data = jsonDecode(json);
      return data.map((key, value) => 
        MapEntry(key, DateTime.parse(value as String))
      );
    } catch (_) {
      return {};
    }
  }
  
  Future<void> _saveCacheMetadata(Map<String, DateTime> metadata) async {
    final json = metadata.map((key, value) => 
      MapEntry(key, value.toIso8601String())
    );
    await _prefs.setString(_cacheMetadataKey, jsonEncode(json));
  }
  
  Future<void> _updateCacheMetadata(String key) async {
    final metadata = _getCacheMetadata();
    metadata[key] = DateTime.now();
    
    // Limit cache entries
    if (metadata.length > maxCacheEntries) {
      // Remove oldest entries
      final sorted = metadata.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      for (int i = 0; i < metadata.length - maxCacheEntries; i++) {
        await _prefs.remove(sorted[i].key);
        metadata.remove(sorted[i].key);
      }
    }
    
    await _saveCacheMetadata(metadata);
  }
  
  // Deck conversion helpers
  Map<String, dynamic> _deckToMap(Deck deck) {
    return {
      'id': deck.id,
      'name': deck.name,
      'description': deck.description,
      'iconCodePoint': deck.icon.codePoint,
      'iconFontFamily': deck.icon.fontFamily ?? 'MaterialIcons',
      'iconFontPackage': deck.icon.fontPackage,
      'colorValue': deck.color.value,
      'imageUrl': deck.imageUrl,
      'isPremium': deck.isPremium,
      'isCustom': deck.isCustom,
      'cards': deck.cards,
      'createdAt': deck.createdAt.toIso8601String(),
      'updatedAt': deck.updatedAt?.toIso8601String(),
      'country': deck.country, // Legacy field for backward compatibility
      'countries': deck.countries.isNotEmpty ? deck.countries : deck.effectiveCountries,
      'tags': deck.tags,
      'priority': deck.priority,
      'isActive': deck.isActive,
      'playCount': deck.playCount,
    };
  }
  
  Deck _mapToDeck(Map<String, dynamic> map) {
    // Parse countries array (with backward compatibility for legacy single country field)
    List<String> parsedCountries = [];
    if (map['countries'] != null) {
      parsedCountries = List<String>.from(map['countries'] as List);
    } else if (map['country'] != null) {
      // Backward compatibility: convert single country to array
      parsedCountries = [map['country'] as String];
    }

    return Deck(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      icon: IconData(
        map['iconCodePoint'],
        fontFamily: map['iconFontFamily'],
        fontPackage: map['iconFontPackage'],
      ),
      color: Color(map['colorValue']),
      imageUrl: map['imageUrl'],
      isPremium: map['isPremium'] ?? false,
      isCustom: map['isCustom'] ?? false,
      cards: List<String>.from(map['cards'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : null,
      country: map['country'],
      countries: parsedCountries,
      tags: List<String>.from(map['tags'] ?? []),
      priority: map['priority'] ?? 0,
      isActive: map['isActive'] ?? true,
      playCount: map['playCount'] ?? 0,
    );
  }
}
