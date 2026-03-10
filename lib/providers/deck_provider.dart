import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/deck.dart';
import '../services/deck_supabase_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import '../services/cache_service.dart';
import '../services/sync_config_service.dart';
import '../services/listener_manager.dart';
import '../services/recommendation_service.dart';
import '../services/user_preference_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeckProvider extends ChangeNotifier {
  // Use Supabase for deck content
  final DeckSupabaseService _deckService = DeckSupabaseService();
  // Custom decks are stored locally (not in Firebase or Supabase)
  final LocalStorageService _localStorageService = LocalStorageService();
  final LocationService _locationService = LocationService();
  final CacheService _cacheService = CacheService();
  final SyncConfigService _syncConfigService = SyncConfigService();
  final ListenerManager _listenerManager = ListenerManager();
  final UserPreferenceService _userPreferenceService = UserPreferenceService();

  List<Deck> _defaultDecks = [];
  List<Deck> _customDecks = [];
  Set<String> _unlockedPremiumDeckIds = {};
  Set<String> _favoriteDeckIds = {};
  List<String> _recentDeckIds = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String _userCountryCode = 'US'; // Default country
  String _errorMessage = '';
  bool _isUsingManualCountry = false;

  // Streams
  StreamSubscription? _defaultDecksSubscription;
  StreamSubscription? _customDecksSubscription;

  List<Deck> get allDecks => [..._defaultDecks, ..._customDecks];
  List<Deck> get defaultDecks => _defaultDecks;
  List<Deck> get customDecks => _customDecks;
  List<Deck> get freeDecks => _defaultDecks.where((d) => !d.isPremium).toList();
  List<Deck> get premiumDecks =>
      _defaultDecks.where((d) => d.isPremium).toList();
  List<Deck> get unlockedDecks =>
      _defaultDecks
          .where((d) => !d.isPremium || _unlockedPremiumDeckIds.contains(d.id))
          .toList() +
      _customDecks;
  Set<String> get favoriteDecks => _favoriteDeckIds;
  List<Deck> get favoriteDecksAsList =>
      allDecks.where((d) => _favoriteDeckIds.contains(d.id)).toList();
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get userCountryCode => _userCountryCode;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get isUsingManualCountry => _isUsingManualCountry;
  
  /// Get decks sorted by recommendation score
  List<Deck> get recommendedDecks {
    return DeckRecommendationService.getDecksByCountryWithRecommendation(
      allDecks: allDecks,
      userCountry: _userCountryCode,
      recentDeckIds: _recentDeckIds,
      favoriteDeckIds: _favoriteDeckIds.toList(),
    );
  }
  
  /// Get top recommended decks for featured section
  List<Deck> getTopRecommendedDecks({int limit = 10}) {
    return DeckRecommendationService.getTopRecommendedDecks(
      allDecks: allDecks,
      userCountry: _userCountryCode,
      recentDeckIds: _recentDeckIds,
      favoriteDeckIds: _favoriteDeckIds.toList(),
      limit: limit,
    );
  }
  
  /// Get decks grouped by recommendation category
  Map<String, List<Deck>> getDecksGroupedByCategory() {
    return DeckRecommendationService.getDecksGroupedByCategory(
      allDecks: allDecks,
      userCountry: _userCountryCode,
      recentDeckIds: _recentDeckIds,
      favoriteDeckIds: _favoriteDeckIds.toList(),
    );
  }

  /// Get decks prioritized by user preferences
  /// Returns decks sorted with preference-matching decks first
  List<Deck> getPreferencePrioritizedDecks(List<Deck> decks) {
    if (!_userPreferenceService.isCacheLoaded || 
        _userPreferenceService.cachedPreferences.isEmpty) {
      // No preferences set, return original order
      return decks;
    }

    // Calculate preference score for each deck (combining multiple signals)
    final scoredDecks = decks.map((deck) {
      int totalScore = 0;
      
      // 1. Score based on deck tags (primary signal)
      if (deck.tags.isNotEmpty) {
        totalScore += _userPreferenceService.getCachedDeckPreferenceScore(deck.tags);
      }
      
      // 2. Score based on deck name/description (additional signal)
      // This helps match decks that don't have proper tags
      final nameScore = _userPreferenceService.getNameMatchScore(deck.name, deck.description);
      
      // If tag score is 0, use name score; otherwise add half of name score as boost
      if (totalScore == 0) {
        totalScore = nameScore;
      } else if (nameScore > 0) {
        totalScore += (nameScore * 0.5).round(); // Boost for double match
      }
      
      return MapEntry(deck, totalScore);
    }).toList();

    // Sort by score (highest first), maintaining relative order for equal scores
    scoredDecks.sort((a, b) {
      final scoreDiff = b.value.compareTo(a.value);
      if (scoreDiff != 0) return scoreDiff;
      // For equal scores, maintain original order
      return decks.indexOf(a.key).compareTo(decks.indexOf(b.key));
    });

    return scoredDecks.map((e) => e.key).toList();
  }

  /// Get decks filtered to only show preference-matching ones
  /// Returns decks sorted by preference score
  List<Deck> getPreferenceMatchingDecks(List<Deck> decks, {int minScore = 1}) {
    if (!_userPreferenceService.isCacheLoaded || 
        _userPreferenceService.cachedPreferences.isEmpty) {
      return decks;
    }

    // Calculate scores and filter
    final scoredDecks = <MapEntry<Deck, int>>[];
    
    for (final deck in decks) {
      int totalScore = 0;
      
      // Score based on deck tags
      if (deck.tags.isNotEmpty) {
        totalScore += _userPreferenceService.getCachedDeckPreferenceScore(deck.tags);
      }
      
      // Score based on deck name/description
      final nameScore = _userPreferenceService.getNameMatchScore(deck.name, deck.description);
      if (totalScore == 0) {
        totalScore = nameScore;
      } else if (nameScore > 0) {
        totalScore += (nameScore * 0.5).round();
      }
      
      if (totalScore >= minScore) {
        scoredDecks.add(MapEntry(deck, totalScore));
      }
    }
    
    // Sort by score (highest first)
    scoredDecks.sort((a, b) => b.value.compareTo(a.value));
    
    return scoredDecks.map((e) => e.key).toList();
  }

  /// Get user's preferred interest IDs
  List<String> get userPreferences => _userPreferenceService.cachedPreferences;

  /// Check if user has set preferences
  bool get hasUserPreferences => 
      _userPreferenceService.isCacheLoaded && 
      _userPreferenceService.cachedPreferences.isNotEmpty;

  /// Refresh user preferences (call after preferences are updated)
  Future<void> refreshUserPreferences() async {
    await _userPreferenceService.initialize();
    notifyListeners();
  }

  DeckProvider() {
    // Start async initialization but don't block constructor
    // This allows the UI to render immediately
    _initializeDecks();
  }

  Future<void> _initializeDecks() async {
    _isLoading = true;
    _errorMessage = '';
    
    // DON'T call notifyListeners here - let UI render first with loading state
    // Schedule the notification for after the current frame
    Future.microtask(() => notifyListeners());

    try {
      debugPrint('🎮 DeckProvider: Starting initialization...');
      
      // PHASE 1: Fast local initialization (< 100ms)
      // Initialize sync config service
      await _syncConfigService.initialize();
      
      // Initialize listener manager (sync)
      _listenerManager.initialize();
      
      // Initialize cache, location, and user preferences in parallel
      await Future.wait([
        _cacheService.initialize(),
        _locationService.initialize(),
        _userPreferenceService.initialize(),
      ]);

      // Get user's preferred country (fast - from local storage)
      _userCountryCode = await _locationService.getUserPreferredCountry();
      _isUsingManualCountry = _locationService.isUsingManualOverride();
      debugPrint('📍 User country: $_userCountryCode');
      
      // PHASE 2: Load cached decks immediately (fast)
      final cachedDecks = await _cacheService.getCachedDecksByCountry(_userCountryCode);
      if (cachedDecks != null && cachedDecks.isNotEmpty) {
        _defaultDecks = cachedDecks;
        _isInitialized = true; // Mark as ready even with cached data
        _isLoading = false;
        debugPrint('✅ Loaded ${cachedDecks.length} decks from cache - UI ready!');
        notifyListeners(); // Show cached data immediately - UI can proceed
      }

      // PHASE 3: Background refresh from Supabase (if needed)
      // This runs in background while user can already use the app
      _refreshDecksInBackground();

    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
      _errorMessage = 'An error occurred. Please restart the app.';
      _isInitialized = false;
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Refresh decks from Supabase in background (non-blocking)
  Future<void> _refreshDecksInBackground() async {
    try {
      final shouldRefresh = await _cacheService.shouldRefreshDecks(_userCountryCode);
      
      if (shouldRefresh || _defaultDecks.isEmpty) {
        debugPrint('🔄 Background: Fetching decks from Supabase...');
        
        final freshDecks = await _deckService
            .refreshDecksByCountry(_userCountryCode)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                debugPrint('⚠️ Supabase fetch timeout - using cached data');
                return _defaultDecks; // Return existing data on timeout
              },
            );

        if (freshDecks.isNotEmpty) {
          _defaultDecks = freshDecks;
          await _cacheService.recordFetchTimestamp(_userCountryCode);
          debugPrint('✅ Background: Loaded ${freshDecks.length} fresh decks');
        }
        _errorMessage = '';
      } else {
        debugPrint('💾 Cache valid - no Supabase fetch needed');
      }
      
      // Set up real-time listeners if enabled
      _setupRealtimeListeners();

      // Load user-specific data in background
      await _loadUserData();

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      
      debugPrint('🎉 DeckProvider fully initialized');
    } catch (e) {
      debugPrint('⚠️ Background refresh failed: $e');
      // Don't show error if we have cached data
      if (_defaultDecks.isEmpty) {
        _errorMessage = 'Unable to load decks. Please check your connection.';
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRealtimeListeners() {
    // Only set up real-time listeners if enabled in sync settings
    if (!_syncConfigService.shouldEnableRealtimeDecks()) {
      debugPrint('📊 Real-time deck listeners DISABLED (using manual refresh)');
      return;
    }
    
    debugPrint('📡 Setting up real-time deck listeners (Supabase)');
    
    // Listen to country-filtered decks changes via Supabase
    _listenerManager.cancelListener('decks_default');
    final subscription = _deckService
        .streamDecksByCountry(_userCountryCode)
        .listen(
          (decks) {
            _defaultDecks = decks;
            _errorMessage = '';
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error streaming decks: $error');
            _errorMessage = 'Connection lost. Some features may not work properly.';
            notifyListeners();
          },
        );
    
    _listenerManager.registerListener('decks_default', subscription);

    // Custom decks remain locally stored (no listener needed)
  }

  Future<void> _loadUserData() async {
    try {
      // Load custom decks from local storage
      _customDecks = await _localStorageService.loadCustomDecks();

      // Load unlocked premium decks from local storage
      _unlockedPremiumDeckIds =
          await _localStorageService.loadUnlockedPremiumDeckIds();

      // Load favorite decks from local storage
      _favoriteDeckIds =
          await _localStorageService.loadFavoriteDeckIds();
      
      // Load recent deck IDs for recommendations
      _recentDeckIds = await _localStorageService.loadRecentDeckIds();
      debugPrint('✅ Loaded ${_recentDeckIds.length} recent deck IDs');

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // Retry loading decks
  Future<void> retryLoading() async {
    await _initializeDecks();
  }
  
  // Force refresh decks from Supabase (clear cache)
  Future<void> forceRefresh() async {
    debugPrint('🔄 Force refreshing decks...');
    await _deckService.refreshDecksByCountry(_userCountryCode);
    await refreshData();
  }
  
  // Manual refresh for when real-time listeners are disabled
  Future<void> manualRefreshDecks() async {
    if (_syncConfigService.shouldEnableRealtimeDecks()) {
      debugPrint('📊 Real-time enabled, skipping manual refresh');
      return;
    }
    
    // Check if enough time has passed for manual refresh
    final shouldRefresh = await _syncConfigService.shouldManualRefresh('decks');
    if (!shouldRefresh) {
      debugPrint('📊 Manual refresh not needed yet');
      return;
    }
    
    debugPrint('🔄 Manual refreshing decks...');
    _isLoading = true;
    notifyListeners();
    
    try {
      _defaultDecks = await _deckService.getDecksByCountry(_userCountryCode);
      await _syncConfigService.recordManualRefresh('decks');
      _errorMessage = '';
      debugPrint('✅ Manual refresh complete: ${_defaultDecks.length} decks');
    } catch (e) {
      debugPrint('❌ Manual refresh failed: $e');
      _errorMessage = 'Failed to refresh decks';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search decks globally across all countries
  Future<List<Deck>> searchDecksGlobally(String searchTerm) async {
    if (searchTerm.isEmpty) return [];

    try {
      final results = await _deckService.searchDecksGlobally(searchTerm);
      return results;
    } catch (e) {
      debugPrint('Error searching decks globally: $e');
      return [];
    }
  }

  // Create a custom deck
  Future<bool> createCustomDeck({
    required String name,
    required String description,
    required List<String> cards,
    IconData? icon,
    Color? color,
  }) async {
    try {
      final newDeck = Deck(
        name: name,
        description: description,
        icon: icon ?? FontAwesomeIcons.solidStar,
        color: color ?? Colors.purple,
        isCustom: true,
        cards: cards,
      );

      final deckId = await _localStorageService.addCustomDeck(newDeck);

      if (deckId != null) {
        // Reload custom decks from local storage
        _customDecks = await _localStorageService.loadCustomDecks();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error creating custom deck: $e');
      return false;
    }
  }

  // Update a custom deck
  Future<bool> updateCustomDeck({
    required String deckId,
    String? name,
    String? description,
    List<String>? cards,
    IconData? icon,
    Color? color,
  }) async {
    try {
      final deck = getDeckById(deckId);
      if (deck == null || !deck.isCustom) return false;

      final updatedDeck = deck.copyWith(
        name: name,
        description: description,
        cards: cards,
        icon: icon,
        color: color,
        updatedAt: DateTime.now(),
      );

      final success = await _localStorageService.updateCustomDeck(
        deckId,
        updatedDeck,
      );

      if (success) {
        // Reload custom decks from local storage
        _customDecks = await _localStorageService.loadCustomDecks();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating custom deck: $e');
      return false;
    }
  }

  // Delete a custom deck
  Future<bool> deleteCustomDeck(String deckId) async {
    try {
      final success = await _localStorageService.deleteCustomDeck(deckId);

      if (success) {
        // Reload custom decks from local storage
        _customDecks = await _localStorageService.loadCustomDecks();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting custom deck: $e');
      return false;
    }
  }

  // Unlock a premium deck (stored locally)
  Future<bool> unlockPremiumDeck(String deckId) async {
    try {
      _unlockedPremiumDeckIds.add(deckId);
      final success = await _localStorageService.saveUnlockedPremiumDeckIds(
        _unlockedPremiumDeckIds,
      );

      if (success) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error unlocking premium deck: $e');
      return false;
    }
  }

  // Check if a deck is unlocked
  bool isDeckUnlocked(String deckId) {
    final deck = getDeckById(deckId);
    if (deck == null) return false;
    if (!deck.isPremium) return true;
    if (deck.isCustom) return true;
    return _unlockedPremiumDeckIds.contains(deckId);
  }

  // Get deck by ID
  Deck? getDeckById(String id) {
    try {
      return allDecks.firstWhere((deck) => deck.id == id);
    } catch (e) {
      return null;
    }
  }

  // Search decks (local search within user's country)
  List<Deck> searchDecks(String query) {
    if (query.isEmpty) return allDecks;

    final lowerQuery = query.toLowerCase();
    return allDecks.where((deck) {
      return deck.name.toLowerCase().contains(lowerQuery) ||
          deck.description.toLowerCase().contains(lowerQuery) ||
          deck.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)) ||
          deck.cards.any((card) => card.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Get recent decks (from local storage)
  Future<List<String>> getRecentDeckIds() async {
    try {
      return await _localStorageService.loadRecentDeckIds();
    } catch (e) {
      debugPrint('Error getting recent deck IDs: $e');
      return [];
    }
  }

  // Add to recent decks (stored locally) and track play for recommendations
  Future<void> addToRecentDecks(String deckId) async {
    try {
      await _localStorageService.addToRecentDecks(deckId);
      
      // Update local recent deck IDs list
      _recentDeckIds.remove(deckId);
      _recentDeckIds.insert(0, deckId);
      if (_recentDeckIds.length > 10) {
        _recentDeckIds = _recentDeckIds.sublist(0, 10);
      }
      
      // Increment play count in Supabase for popularity tracking
      await _deckService.incrementDeckPlayCount(deckId);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to recent decks: $e');
    }
  }
  
  // Remove from recent decks
  Future<void> removeFromRecentDecks(String deckId) async {
    try {
      await _localStorageService.removeFromRecentDecks(deckId);
      
      // Update local recent deck IDs list
      _recentDeckIds.remove(deckId);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from recent decks: $e');
    }
  }
  
  /// Change user's country preference
  Future<bool> setUserCountry(String? countryCode) async {
    try {
      final success = await _locationService.setManualCountryOverride(countryCode);
      
      if (success) {
        final previousCountry = _userCountryCode;
        
        // Update the country code
        _userCountryCode = await _locationService.getUserPreferredCountry();
        _isUsingManualCountry = _locationService.isUsingManualOverride();
        
        debugPrint('📍 Country changed from $previousCountry to $_userCountryCode (manual: $_isUsingManualCountry)');
        
        // Clear cache for old country
        await _cacheService.clearCache('cached_decks_$previousCountry');
        
        // Reload decks for new country
        _isLoading = true;
        notifyListeners();
        
        try {
          _defaultDecks = await _deckService.getDecksByCountry(_userCountryCode);
          debugPrint('✅ Loaded ${_defaultDecks.length} decks for new country: $_userCountryCode');
          
          // Re-setup real-time listeners for new country
          _setupRealtimeListeners();
          
          _errorMessage = '';
        } catch (e) {
          debugPrint('❌ Error loading decks for new country: $e');
          _errorMessage = 'Failed to load decks for selected region';
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error setting user country: $e');
      return false;
    }
  }
  
  /// Reset to auto-detected country
  Future<bool> resetToAutoDetectedCountry() async {
    return await setUserCountry(null);
  }
  
  /// Get the current manual country override (null if auto-detecting)
  String? getManualCountryOverride() {
    return _locationService.getManualCountryOverride();
  }

  // Add to favorites (stored locally)
  Future<bool> addToFavorites(String deckId) async {
    try {
      _favoriteDeckIds.add(deckId);
      final success = await _localStorageService.saveFavoriteDeckIds(
        _favoriteDeckIds,
      );

      if (success) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      return false;
    }
  }

  // Remove from favorites (stored locally)
  Future<bool> removeFromFavorites(String deckId) async {
    try {
      _favoriteDeckIds.remove(deckId);
      final success = await _localStorageService.saveFavoriteDeckIds(
        _favoriteDeckIds,
      );

      if (success) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      return false;
    }
  }

  // Check if deck is in favorites
  bool isFavorite(String deckId) {
    return _favoriteDeckIds.contains(deckId);
  }

  // Get recent decks
  Future<List<Deck>> getRecentDecks() async {
    final recentIds = await getRecentDeckIds();
    final recentDecks = <Deck>[];

    for (final id in recentIds) {
      final deck = getDeckById(id);
      if (deck != null) {
        recentDecks.add(deck);
      }
    }

    return recentDecks;
  }

  // Refresh data
  Future<void> refreshData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Show cached data first if available
      final cachedDecks = await _cacheService.getCachedDecksByCountry(_userCountryCode);
      if (cachedDecks != null && cachedDecks.isNotEmpty) {
        _defaultDecks = cachedDecks;
        notifyListeners();
      }
      
      // Fetch country-filtered decks from Supabase (will update cache)
      _defaultDecks = await _deckService.getDecksByCountry(_userCountryCode);
      // Custom decks from local storage
      _customDecks = await _localStorageService.loadCustomDecks();
      // Unlocked premium decks from local storage
      _unlockedPremiumDeckIds =
          await _localStorageService.loadUnlockedPremiumDeckIds();
      // Favorite decks from local storage
      _favoriteDeckIds =
          await _localStorageService.loadFavoriteDeckIds();
      _errorMessage = '';
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      _errorMessage = 'Failed to refresh data. Please check your connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _defaultDecksSubscription?.cancel();
    _customDecksSubscription?.cancel();
    super.dispose();
  }
}
