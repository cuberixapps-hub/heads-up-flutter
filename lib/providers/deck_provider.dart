import 'package:flutter/material.dart';
import 'dart:async';
import '../models/deck.dart';
import '../constants/default_decks.dart';
import '../services/deck_firebase_service.dart';
import '../services/firebase_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeckProvider extends ChangeNotifier {
  final DeckFirebaseService _deckFirebaseService = DeckFirebaseService();
  final FirebaseService _firebaseService = FirebaseService();

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
      // First, check if default decks exist in Firestore
      final firebaseDefaultDecks = await _deckFirebaseService.getDefaultDecks();

      if (firebaseDefaultDecks.isEmpty) {
        // Initialize default decks in Firestore if they don't exist
        debugPrint('Initializing default decks in Firestore...');
        await _deckFirebaseService.initializeDefaultDecks(DefaultDecks.decks);

        // Fetch again after initialization
        _defaultDecks = await _deckFirebaseService.getDefaultDecks();
      } else {
        _defaultDecks = firebaseDefaultDecks;
      }

      // Set up real-time listeners
      _setupRealtimeListeners();

      // Load user-specific data
      await _loadUserData();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing decks: $e');
      // Fallback to local default decks if Firebase fails
      _loadLocalDefaultDecks();
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

    // Listen to custom decks changes
    _customDecksSubscription?.cancel();
    _customDecksSubscription = _deckFirebaseService.streamCustomDecks().listen(
      (decks) {
        _customDecks = decks;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error streaming custom decks: $error');
      },
    );
  }

  Future<void> _loadUserData() async {
    try {
      // Load custom decks
      _customDecks = await _deckFirebaseService.getCustomDecks();

      // Load unlocked premium decks
      _unlockedPremiumDeckIds =
          await _deckFirebaseService.getUnlockedPremiumDecks();

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

      final deckId = await _deckFirebaseService.createCustomDeck(newDeck);

      if (deckId != null) {
        // The real-time listener will update the local list
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

      final success = await _deckFirebaseService.updateCustomDeck(
        deckId,
        updatedDeck,
      );

      if (success) {
        // The real-time listener will update the local list
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
      final success = await _deckFirebaseService.deleteCustomDeck(deckId);

      if (success) {
        // The real-time listener will update the local list
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting custom deck: $e');
      return false;
    }
  }

  // Unlock a premium deck
  Future<bool> unlockPremiumDeck(String deckId) async {
    try {
      final success = await _deckFirebaseService.unlockPremiumDeck(deckId);

      if (success) {
        _unlockedPremiumDeckIds.add(deckId);
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

  // Get recent decks
  Future<List<String>> getRecentDeckIds() async {
    try {
      return await _deckFirebaseService.getRecentDeckIds();
    } catch (e) {
      debugPrint('Error getting recent deck IDs: $e');
      return [];
    }
  }

  // Add to recent decks
  Future<void> addToRecentDecks(String deckId) async {
    try {
      await _deckFirebaseService.addToRecentDecks(deckId);
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

  // Refresh data from Firebase
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _defaultDecks = await _deckFirebaseService.getDefaultDecks();
      _customDecks = await _deckFirebaseService.getCustomDecks();
      _unlockedPremiumDeckIds =
          await _deckFirebaseService.getUnlockedPremiumDecks();
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
