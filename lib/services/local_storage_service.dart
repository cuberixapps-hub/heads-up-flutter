import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/deck.dart';

class LocalStorageService {
  static const String _customDecksKey = 'custom_decks';
  static const String _recentDecksKey = 'recent_decks';
  static const String _unlockedPremiumKey = 'unlocked_premium_decks';
  static const String _favoriteDecksKey = 'favorite_decks';

  // Save custom decks to local storage
  Future<bool> saveCustomDecks(List<Deck> decks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decksJson = decks.map((deck) => _deckToJson(deck)).toList();
      final jsonString = jsonEncode(decksJson);
      return await prefs.setString(_customDecksKey, jsonString);
    } catch (e) {
      debugPrint('Error saving custom decks: $e');
      return false;
    }
  }

  // Load custom decks from local storage
  Future<List<Deck>> loadCustomDecks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_customDecksKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decksJson = jsonDecode(jsonString);
      return decksJson.map((json) => _jsonToDeck(json)).toList();
    } catch (e) {
      debugPrint('Error loading custom decks: $e');
      return [];
    }
  }

  // Add a custom deck
  Future<String?> addCustomDeck(Deck deck) async {
    try {
      final customDecks = await loadCustomDecks();

      // Generate a unique ID for the deck
      final newDeck = deck.copyWith(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      customDecks.add(newDeck);
      final success = await saveCustomDecks(customDecks);

      return success ? newDeck.id : null;
    } catch (e) {
      debugPrint('Error adding custom deck: $e');
      return null;
    }
  }

  // Update a custom deck
  Future<bool> updateCustomDeck(String deckId, Deck updatedDeck) async {
    try {
      final customDecks = await loadCustomDecks();
      final index = customDecks.indexWhere((deck) => deck.id == deckId);

      if (index == -1) {
        return false;
      }

      customDecks[index] = updatedDeck.copyWith(
        id: deckId,
        updatedAt: DateTime.now(),
      );

      return await saveCustomDecks(customDecks);
    } catch (e) {
      debugPrint('Error updating custom deck: $e');
      return false;
    }
  }

  // Delete a custom deck
  Future<bool> deleteCustomDeck(String deckId) async {
    try {
      final customDecks = await loadCustomDecks();
      customDecks.removeWhere((deck) => deck.id == deckId);
      return await saveCustomDecks(customDecks);
    } catch (e) {
      debugPrint('Error deleting custom deck: $e');
      return false;
    }
  }

  // Save recent deck IDs
  Future<bool> saveRecentDeckIds(List<String> deckIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only the last 10 recent decks
      final recentIds = deckIds.take(10).toList();
      return await prefs.setStringList(_recentDecksKey, recentIds);
    } catch (e) {
      debugPrint('Error saving recent deck IDs: $e');
      return false;
    }
  }

  // Load recent deck IDs
  Future<List<String>> loadRecentDeckIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentDecksKey) ?? [];
    } catch (e) {
      debugPrint('Error loading recent deck IDs: $e');
      return [];
    }
  }

  // Add to recent decks
  Future<void> addToRecentDecks(String deckId) async {
    try {
      final recentIds = await loadRecentDeckIds();

      // Remove if already exists and add to front
      recentIds.remove(deckId);
      recentIds.insert(0, deckId);

      await saveRecentDeckIds(recentIds);
    } catch (e) {
      debugPrint('Error adding to recent decks: $e');
    }
  }

  // Save unlocked premium deck IDs
  Future<bool> saveUnlockedPremiumDeckIds(Set<String> deckIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_unlockedPremiumKey, deckIds.toList());
    } catch (e) {
      debugPrint('Error saving unlocked premium deck IDs: $e');
      return false;
    }
  }

  // Load unlocked premium deck IDs
  Future<Set<String>> loadUnlockedPremiumDeckIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_unlockedPremiumKey) ?? [];
      return ids.toSet();
    } catch (e) {
      debugPrint('Error loading unlocked premium deck IDs: $e');
      return {};
    }
  }

  // Save favorite deck IDs
  Future<bool> saveFavoriteDeckIds(Set<String> deckIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_favoriteDecksKey, deckIds.toList());
    } catch (e) {
      debugPrint('Error saving favorite deck IDs: $e');
      return false;
    }
  }

  // Load favorite deck IDs
  Future<Set<String>> loadFavoriteDeckIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_favoriteDecksKey) ?? [];
      return ids.toSet();
    } catch (e) {
      debugPrint('Error loading favorite deck IDs: $e');
      return {};
    }
  }

  // Helper method to convert Deck to JSON
  Map<String, dynamic> _deckToJson(Deck deck) {
    return {
      'id': deck.id,
      'name': deck.name,
      'description': deck.description,
      'icon': _iconToString(deck.icon),
      'color': deck.color.value,
      'cards': deck.cards,
      'isPremium': deck.isPremium,
      'isCustom': deck.isCustom,
      'createdAt': deck.createdAt.toIso8601String(),
      'updatedAt':
          deck.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  // Helper method to convert JSON to Deck
  Deck _jsonToDeck(Map<String, dynamic> json) {
    return Deck(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: _stringToIcon(json['icon']),
      color: Color(json['color'] ?? 0xFF000000),
      cards: List<String>.from(json['cards'] ?? []),
      isPremium: json['isPremium'] ?? false,
      isCustom: json['isCustom'] ?? true,
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now(),
    );
  }

  // Helper method to convert IconData to String
  String _iconToString(IconData icon) {
    // Store icon codePoint and fontFamily
    return '${icon.codePoint},${icon.fontFamily ?? 'MaterialIcons'}';
  }

  // Helper method to convert String to IconData
  IconData _stringToIcon(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return FontAwesomeIcons.solidStar;
    }

    try {
      final parts = iconString.split(',');
      if (parts.length < 2) {
        return FontAwesomeIcons.solidStar;
      }

      final codePoint = int.parse(parts[0]);
      final fontFamily = parts[1];

      // Check if it's a FontAwesome icon
      if (fontFamily.contains('FontAwesome')) {
        // Try to match common FontAwesome icons
        return _getFontAwesomeIcon(codePoint) ?? FontAwesomeIcons.solidStar;
      }

      // Default to Material Icons
      return IconData(codePoint, fontFamily: fontFamily);
    } catch (e) {
      debugPrint('Error parsing icon: $e');
      return FontAwesomeIcons.solidStar;
    }
  }

  // Helper to get FontAwesome icons
  IconData? _getFontAwesomeIcon(int codePoint) {
    // Map of common FontAwesome icons used in the app
    final iconMap = {
      FontAwesomeIcons.solidStar.codePoint: FontAwesomeIcons.solidStar,
      FontAwesomeIcons.film.codePoint: FontAwesomeIcons.film,
      FontAwesomeIcons.music.codePoint: FontAwesomeIcons.music,
      FontAwesomeIcons.paw.codePoint: FontAwesomeIcons.paw,
      FontAwesomeIcons.futbol.codePoint: FontAwesomeIcons.futbol,
      FontAwesomeIcons.book.codePoint: FontAwesomeIcons.book,
      FontAwesomeIcons.utensils.codePoint: FontAwesomeIcons.utensils,
      FontAwesomeIcons.gamepad.codePoint: FontAwesomeIcons.gamepad,
      FontAwesomeIcons.tv.codePoint: FontAwesomeIcons.tv,
      FontAwesomeIcons.globe.codePoint: FontAwesomeIcons.globe,
      FontAwesomeIcons.flask.codePoint: FontAwesomeIcons.flask,
      FontAwesomeIcons.landmark.codePoint: FontAwesomeIcons.landmark,
      FontAwesomeIcons.palette.codePoint: FontAwesomeIcons.palette,
      FontAwesomeIcons.dumbbell.codePoint: FontAwesomeIcons.dumbbell,
      FontAwesomeIcons.plane.codePoint: FontAwesomeIcons.plane,
      FontAwesomeIcons.heart.codePoint: FontAwesomeIcons.heart,
      FontAwesomeIcons.champagneGlasses.codePoint:
          FontAwesomeIcons.champagneGlasses,
      FontAwesomeIcons.graduationCap.codePoint: FontAwesomeIcons.graduationCap,
      FontAwesomeIcons.rocket.codePoint: FontAwesomeIcons.rocket,
      FontAwesomeIcons.crown.codePoint: FontAwesomeIcons.crown,
      FontAwesomeIcons.fire.codePoint: FontAwesomeIcons.fire,
      FontAwesomeIcons.bolt.codePoint: FontAwesomeIcons.bolt,
      FontAwesomeIcons.gem.codePoint: FontAwesomeIcons.gem,
      FontAwesomeIcons.trophy.codePoint: FontAwesomeIcons.trophy,
    };

    return iconMap[codePoint];
  }

  // Clear all local data (for debugging/reset)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customDecksKey);
      await prefs.remove(_recentDecksKey);
      await prefs.remove(_unlockedPremiumKey);
      await prefs.remove(_favoriteDecksKey);
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }
}
