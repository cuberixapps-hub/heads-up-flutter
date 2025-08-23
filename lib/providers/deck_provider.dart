import 'package:flutter/material.dart';
import 'dart:async';
import '../models/deck.dart';
import '../constants/default_decks.dart';
import '../services/deck_firebase_service.dart';
import '../services/local_storage_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeckProvider extends ChangeNotifier {
  final DeckFirebaseService _deckFirebaseService = DeckFirebaseService();
  final LocalStorageService _localStorageService = LocalStorageService();

  List<Deck> _defaultDecks = [];
  List<Deck> _customDecks = [];
  Set<String> _unlockedPremiumDeckIds = {};
  bool _isLoading = false;
  bool _isInitialized = false;

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

  DeckProvider() {
    _initializeDecks();
  }

  Future<void> _initializeDecks() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🎮 HEADS UP: Starting app initialization...');

      // Try to fetch from Firebase with a timeout
      final firebaseDefaultDecks = await _deckFirebaseService
          .getDefaultDecks()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint(
                '📱 OFFLINE MODE: No internet connection detected - loading local decks',
              );
              return <Deck>[];
            },
          );

      if (firebaseDefaultDecks.isEmpty) {
        // Try to initialize default decks in Firestore if they don't exist
        debugPrint('🎯 Loading default decks from local storage...');
        _loadLocalDefaultDecks();
        debugPrint(
          '✅ Successfully loaded ${_defaultDecks.length} default decks locally',
        );

        // Try to upload to Firebase in background (non-blocking)
        _deckFirebaseService
            .initializeDefaultDecks(DefaultDecks.decks)
            .then((_) {
              debugPrint('Default decks uploaded to Firebase');
              // Try to fetch from Firebase again
              _deckFirebaseService.getDefaultDecks().then((decks) {
                if (decks.isNotEmpty) {
                  _defaultDecks = decks;
                  notifyListeners();
                }
              });
            })
            .catchError((e) {
              // This is expected when offline - not an error
              debugPrint(
                '📴 Running in offline mode (Firebase sync will resume when online)',
              );
            });
      } else {
        _defaultDecks = firebaseDefaultDecks;
        debugPrint('✅ Loaded ${_defaultDecks.length} decks from Firebase');
      }

      // Set up real-time listeners (will work when connection is restored)
      _setupRealtimeListeners();

      // Load user-specific data
      await _loadUserData();

      _isInitialized = true;
      debugPrint(
        '🎉 APP READY: Heads Up game is fully loaded and ready to play!',
      );
    } catch (e) {
      debugPrint('📱 OFFLINE MODE: Loading local decks...');
      // Fallback to local default decks if Firebase fails
      _loadLocalDefaultDecks();
      _isInitialized = true;
      debugPrint(
        '✅ APP READY: Running in offline mode with ${_defaultDecks.length} decks available',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRealtimeListeners() {
    // Listen to default decks changes
    _defaultDecksSubscription?.cancel();
    _defaultDecksSubscription = _deckFirebaseService
        .streamDefaultDecks()
        .listen(
          (decks) {
            _defaultDecks = decks;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error streaming default decks: $error');
          },
        );

    // No longer streaming custom decks from Firebase
    // Custom decks are stored locally only
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

  void _loadLocalDefaultDecks() {
    // Fallback to local default decks
    _defaultDecks =
        DefaultDecks.decks.map((deckData) {
          return Deck(
            id: deckData['id'],
            name: deckData['name'],
            description: deckData['description'],
            icon: deckData['icon'],
            color: deckData['color'],
            isPremium: deckData['isPremium'],
            cards: List<String>.from(deckData['cards']),
          );
        }).toList();
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

  // Search decks
  List<Deck> searchDecks(String query) {
    if (query.isEmpty) return allDecks;

    final lowerQuery = query.toLowerCase();
    return allDecks.where((deck) {
      return deck.name.toLowerCase().contains(lowerQuery) ||
          deck.description.toLowerCase().contains(lowerQuery) ||
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
    notifyListeners();

    try {
      // Default decks still from Firebase
      _defaultDecks = await _deckFirebaseService.getDefaultDecks();
      // Custom decks from local storage
      _customDecks = await _localStorageService.loadCustomDecks();
      // Unlocked premium decks from local storage
      _unlockedPremiumDeckIds =
          await _localStorageService.loadUnlockedPremiumDeckIds();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
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
