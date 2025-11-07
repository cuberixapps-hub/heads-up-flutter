import 'package:flutter/material.dart';
import 'dart:async';
import '../models/deck.dart';
import '../services/deck_firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeckProvider extends ChangeNotifier {
  final DeckFirebaseService _deckFirebaseService = DeckFirebaseService();
  final LocalStorageService _localStorageService = LocalStorageService();

  List<Deck> _defaultDecks = [];
  List<Deck> _customDecks = [];
  Set<String> _unlockedPremiumDeckIds = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  String _userCountryCode = 'US'; // Default country
  String _errorMessage = '';

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
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get userCountryCode => _userCountryCode;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;

  DeckProvider() {
    _initializeDecks();
  }

  Future<void> _initializeDecks() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      debugPrint('🎮 HEADS UP: Starting app initialization...');

      // Detect user's country automatically
      _userCountryCode = await LocationService.detectUserCountry();
      debugPrint('📍 Detected user country: $_userCountryCode');

      // Fetch decks from Firebase filtered by country
      try {
        _defaultDecks = await _deckFirebaseService
            .getDecksByCountry(_userCountryCode)
          .timeout(
              const Duration(seconds: 10),
            onTimeout: () {
                throw TimeoutException(
                  'Connection timeout. Please check your internet connection.',
              );
              },
            );

        debugPrint('✅ Loaded ${_defaultDecks.length} decks for country: $_userCountryCode');

        // Set up real-time listeners
      _setupRealtimeListeners();

      // Load user-specific data
      await _loadUserData();

      _isInitialized = true;
        _errorMessage = '';
      debugPrint(
          '🎉 APP READY: Heads Up game is fully loaded with country-specific decks!',
      );
      } catch (e) {
        // Handle Firebase/Network errors
        debugPrint('❌ Error loading decks: $e');
        _errorMessage = 'Unable to load decks. Please check your internet connection and try again.';
        _isInitialized = false;
      }
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
      _errorMessage = 'An error occurred during initialization. Please restart the app.';
      _isInitialized = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRealtimeListeners() {
    // Listen to country-filtered decks changes
    _defaultDecksSubscription?.cancel();
    _defaultDecksSubscription = _deckFirebaseService
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

    // Custom decks remain locally stored
    _customDecksSubscription?.cancel();
  }

  Future<void> _loadUserData() async {
    try {
      // Load custom decks from local storage
      _customDecks = await _localStorageService.loadCustomDecks();

      // Load unlocked premium decks from local storage
      _unlockedPremiumDeckIds =
          await _localStorageService.loadUnlockedPremiumDeckIds();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // Retry loading decks
  Future<void> retryLoading() async {
    await _initializeDecks();
  }

  // Search decks globally across all countries
  Future<List<Deck>> searchDecksGlobally(String searchTerm) async {
    if (searchTerm.isEmpty) return [];

    try {
      final results = await _deckFirebaseService.searchDecksGlobally(searchTerm);
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

  // Add to recent decks (stored locally)
  Future<void> addToRecentDecks(String deckId) async {
    try {
      await _localStorageService.addToRecentDecks(deckId);
    } catch (e) {
      debugPrint('Error adding to recent decks: $e');
    }
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
      // Fetch country-filtered decks from Firebase
      _defaultDecks = await _deckFirebaseService.getDecksByCountry(_userCountryCode);
      // Custom decks from local storage
      _customDecks = await _localStorageService.loadCustomDecks();
      // Unlocked premium decks from local storage
      _unlockedPremiumDeckIds =
          await _localStorageService.loadUnlockedPremiumDeckIds();
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
