import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/deck.dart';
import '../constants/default_decks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeckProvider extends ChangeNotifier {
  List<Deck> _decks = [];
  List<Deck> _customDecks = [];
  Set<String> _unlockedPremiumDeckIds = {};
  bool _isLoading = false;

  List<Deck> get allDecks => [..._decks, ..._customDecks];
  List<Deck> get defaultDecks => _decks;
  List<Deck> get customDecks => _customDecks;
  List<Deck> get freeDecks => _decks.where((d) => !d.isPremium).toList();
  List<Deck> get premiumDecks => _decks.where((d) => d.isPremium).toList();
  List<Deck> get unlockedDecks =>
      _decks
          .where((d) => !d.isPremium || _unlockedPremiumDeckIds.contains(d.id))
          .toList();
  bool get isLoading => _isLoading;

  DeckProvider() {
    _initializeDecks();
  }

  Future<void> _initializeDecks() async {
    _isLoading = true;
    notifyListeners();

    // Load default decks
    _decks =
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

    // Load saved data
    await _loadSavedData();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load custom decks
      final customDecksJson = prefs.getString('custom_decks');
      if (customDecksJson != null) {
        final List<dynamic> decoded = json.decode(customDecksJson);
        _customDecks =
            decoded.map((deckMap) {
              return Deck(
                id: deckMap['id'],
                name: deckMap['name'],
                description: deckMap['description'],
                icon: IconData(deckMap['icon'], fontFamily: 'MaterialIcons'),
                color: Color(deckMap['color']),
                isCustom: true,
                cards: List<String>.from(deckMap['cards']),
                createdAt: DateTime.parse(deckMap['createdAt']),
                updatedAt:
                    deckMap['updatedAt'] != null
                        ? DateTime.parse(deckMap['updatedAt'])
                        : null,
              );
            }).toList();
      }

      // Load unlocked premium decks
      final unlockedDecks = prefs.getStringList('unlocked_premium_decks');
      if (unlockedDecks != null) {
        _unlockedPremiumDeckIds = unlockedDecks.toSet();
      }
    } catch (e) {
      debugPrint('Error loading saved data: $e');
    }
  }

  Future<void> _saveCustomDecks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customDecksJson = json.encode(
        _customDecks.map((deck) => deck.toMap()).toList(),
      );
      await prefs.setString('custom_decks', customDecksJson);
    } catch (e) {
      debugPrint('Error saving custom decks: $e');
    }
  }

  Future<void> _saveUnlockedDecks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'unlocked_premium_decks',
        _unlockedPremiumDeckIds.toList(),
      );
    } catch (e) {
      debugPrint('Error saving unlocked decks: $e');
    }
  }

  // Create a custom deck
  Future<void> createCustomDeck({
    required String name,
    required String description,
    required List<String> cards,
    IconData? icon,
    Color? color,
  }) async {
    final newDeck = Deck(
      name: name,
      description: description,
      icon: icon ?? FontAwesomeIcons.solidStar,
      color: color ?? Colors.purple,
      isCustom: true,
      cards: cards,
    );

    _customDecks.add(newDeck);
    await _saveCustomDecks();
    notifyListeners();
  }

  // Update a custom deck
  Future<void> updateCustomDeck({
    required String deckId,
    String? name,
    String? description,
    List<String>? cards,
    IconData? icon,
    Color? color,
  }) async {
    final index = _customDecks.indexWhere((deck) => deck.id == deckId);
    if (index == -1) return;

    final deck = _customDecks[index];
    _customDecks[index] = deck.copyWith(
      name: name,
      description: description,
      cards: cards,
      icon: icon,
      color: color,
      updatedAt: DateTime.now(),
    );

    await _saveCustomDecks();
    notifyListeners();
  }

  // Delete a custom deck
  Future<void> deleteCustomDeck(String deckId) async {
    _customDecks.removeWhere((deck) => deck.id == deckId);
    await _saveCustomDecks();
    notifyListeners();
  }

  // Unlock a premium deck
  Future<void> unlockPremiumDeck(String deckId) async {
    _unlockedPremiumDeckIds.add(deckId);
    await _saveUnlockedDecks();
    notifyListeners();
  }

  // Check if a deck is unlocked
  bool isDeckUnlocked(String deckId) {
    final deck = getDeckById(deckId);
    if (deck == null) return false;
    if (!deck.isPremium) return true;
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
          deck.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Get recent decks (for quick play)
  Future<List<String>> getRecentDeckIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recent_deck_ids') ?? [];
  }

  // Add to recent decks
  Future<void> addToRecentDecks(String deckId) async {
    final prefs = await SharedPreferences.getInstance();
    final recentIds = await getRecentDeckIds();

    // Remove if already exists and add to front
    recentIds.remove(deckId);
    recentIds.insert(0, deckId);

    // Keep only last 5
    if (recentIds.length > 5) {
      recentIds.removeRange(5, recentIds.length);
    }

    await prefs.setStringList('recent_deck_ids', recentIds);
  }

  // Remove all ads (for purchase)
  Future<void> removeAds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ads_removed', true);
    notifyListeners();
  }

  // Check if ads are removed
  Future<bool> areAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ads_removed') ?? false;
  }
}
