import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../utils/icon_mapper.dart';
import 'firebase_service.dart';
import 'cache_service.dart';
import 'recommendation_service.dart';

class DeckFirebaseService {
  final FirebaseService _firebaseService = FirebaseService();
  final CacheService _cacheService = CacheService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  String? get _userId => _firebaseService.currentUser?.uid;

  // Collection references
  CollectionReference get _defaultDecksRef => _firestore.collection(
    'decks',
  ); // Changed from 'defaultDecks' to 'decks' to match admin portal
  CollectionReference get _userDecksRef => _firestore
      .collection('users')
      .doc(_userId ?? 'anonymous')
      .collection('customDecks');
  DocumentReference get _userRef =>
      _firestore.collection('users').doc(_userId ?? 'anonymous');

  // Get all default decks from Firestore
  Future<List<Deck>> getDefaultDecks() async {
    try {
      // Try cache first
      final cachedDecks = await _cacheService.getCachedDecksByCountry('ALL');
      if (cachedDecks != null) {
        debugPrint('✅ Using cached default decks: ${cachedDecks.length} decks');
        return cachedDecks;
      }
      
      // Cache miss, fetch from Firestore
      final QuerySnapshot snapshot = await _defaultDecksRef.get();

      final decks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id);
      }).toList();
      
      // Cache the results
      await _cacheService.cacheDecksByCountry('ALL', decks);
      
      return decks;
    } catch (e) {
      debugPrint('Error getting default decks: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get default decks',
      );
      throw Exception('Failed to load decks. Please check your internet connection.');
    }
  }

  // Get decks filtered by country (supports multi-country decks)
  Future<List<Deck>> getDecksByCountry(String countryCode) async {
    try {
      // Try cache first
      final cachedDecks = await _cacheService.getCachedDecksByCountry(countryCode);
      if (cachedDecks != null) {
        debugPrint('✅ Using cached decks for $countryCode: ${cachedDecks.length} decks');
        return cachedDecks;
      }
      
      // Get regional fallbacks for broader matching
      final regionalFallbacks = DeckRecommendationService.getRegionalFallbacks(countryCode);
      
      // Build list of country codes to search for
      final countriesToSearch = <String>{'UNIVERSAL', countryCode, ...regionalFallbacks}.toList();
      
      // Firestore arrayContainsAny supports up to 10 values
      // If we have more, we'll need to do multiple queries
      if (countriesToSearch.length > 10) {
        countriesToSearch.removeRange(10, countriesToSearch.length);
      }
      
      debugPrint('🔍 Searching for decks with countries: $countriesToSearch');
      
      // Cache miss, fetch from Firestore
      // Use arrayContainsAny to match decks that have any of the countries in their countries array
      Query query = _defaultDecksRef
          .where('countries', arrayContainsAny: countriesToSearch);

      final QuerySnapshot snapshot = await query.get();

      var decks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id);
      }).where((deck) => deck.isActive).toList();

      // If no results with new 'countries' field, try legacy 'country' field
      if (decks.isEmpty) {
        debugPrint('🔄 No results with countries array, trying legacy country field...');
        Query legacyQuery = _defaultDecksRef
            .where('country', whereIn: ['UNIVERSAL', countryCode]);
        
        final legacySnapshot = await legacyQuery.get();
        decks = legacySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _deckFromFirestore(data, doc.id);
        }).where((deck) => deck.isActive).toList();
      }

      // Sort by priority (lower number = higher priority)
      decks.sort((a, b) => a.priority.compareTo(b.priority));
      
      debugPrint('✅ Found ${decks.length} decks for $countryCode');
      
      // Cache the results
      await _cacheService.cacheDecksByCountry(countryCode, decks);

      return decks;
    } catch (e) {
      debugPrint('Error getting decks by country: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get decks by country: $countryCode',
      );
      throw Exception('Failed to load decks. Please check your internet connection.');
    }
  }
  
  // Get decks filtered by multiple countries
  Future<List<Deck>> getDecksByCountries(List<String> countryCodes) async {
    try {
      if (countryCodes.isEmpty) {
        return getDefaultDecks();
      }
      
      // Ensure UNIVERSAL is included
      final countriesToSearch = <String>{'UNIVERSAL', ...countryCodes}.toList();
      
      // Firestore arrayContainsAny supports up to 10 values
      if (countriesToSearch.length > 10) {
        countriesToSearch.removeRange(10, countriesToSearch.length);
      }
      
      debugPrint('🔍 Searching for decks with countries: $countriesToSearch');
      
      Query query = _defaultDecksRef
          .where('countries', arrayContainsAny: countriesToSearch);

      final QuerySnapshot snapshot = await query.get();

      var decks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id);
      }).where((deck) => deck.isActive).toList();

      // Fallback to legacy query if no results
      if (decks.isEmpty) {
        Query legacyQuery = _defaultDecksRef
            .where('country', whereIn: countriesToSearch.take(10).toList());
        
        final legacySnapshot = await legacyQuery.get();
        decks = legacySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _deckFromFirestore(data, doc.id);
        }).where((deck) => deck.isActive).toList();
      }

      decks.sort((a, b) => a.priority.compareTo(b.priority));
      
      return decks;
    } catch (e) {
      debugPrint('Error getting decks by countries: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get decks by countries: $countryCodes',
      );
      throw Exception('Failed to load decks. Please check your internet connection.');
    }
  }
  
  // Force refresh decks cache for a country
  Future<List<Deck>> refreshDecksByCountry(String countryCode) async {
    // Clear cache for this country
    await _cacheService.clearCache('cached_decks_$countryCode');
    
    // Fetch fresh data
    return getDecksByCountry(countryCode);
  }

  // Search decks across all countries
  Future<List<Deck>> searchDecksGlobally(String searchTerm) async {
    try {
      // For global search, we get all active decks and filter client-side
      final QuerySnapshot snapshot = await _defaultDecksRef
          .where('isActive', isEqualTo: true)
          .get();

      final allDecks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id);
      }).toList();

      final searchLower = searchTerm.toLowerCase();
      return allDecks.where((deck) {
        return deck.name.toLowerCase().contains(searchLower) ||
            deck.description.toLowerCase().contains(searchLower) ||
            deck.tags.any((tag) => tag.toLowerCase().contains(searchLower)) ||
            deck.cards.any((card) => card.toLowerCase().contains(searchLower));
      }).toList();
    } catch (e) {
      debugPrint('Error searching decks globally: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to search decks globally',
      );
      return [];
    }
  }

  // Stream of default decks
  Stream<List<Deck>> streamDefaultDecks() {
    return _defaultDecksRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id);
      }).toList();
    });
  }

  // Stream of decks filtered by country (supports multi-country decks)
  Stream<List<Deck>> streamDecksByCountry(String countryCode) {
    // Get regional fallbacks for broader matching
    final regionalFallbacks = DeckRecommendationService.getRegionalFallbacks(countryCode);
    
    // Build list of country codes to search for
    final countriesToSearch = <String>{'UNIVERSAL', countryCode, ...regionalFallbacks}.toList();
    
    // Firestore arrayContainsAny supports up to 10 values
    if (countriesToSearch.length > 10) {
      countriesToSearch.removeRange(10, countriesToSearch.length);
    }
    
    return _defaultDecksRef
        .where('countries', arrayContainsAny: countriesToSearch)
        .snapshots()
        .map((snapshot) {
      final decks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id);
      }).where((deck) => deck.isActive).toList();

      // Sort by priority
      decks.sort((a, b) => a.priority.compareTo(b.priority));
      return decks;
    });
  }

  // Get user's custom decks
  Future<List<Deck>> getCustomDecks() async {
    if (_userId == null) return [];

    try {
      final QuerySnapshot snapshot = await _userDecksRef.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id, isCustom: true);
      }).toList();
    } catch (e) {
      debugPrint('Error getting custom decks: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get custom decks',
      );
      return [];
    }
  }

  // Stream of custom decks
  Stream<List<Deck>> streamCustomDecks() {
    if (_userId == null) return Stream.value([]);

    return _userDecksRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id, isCustom: true);
      }).toList();
    });
  }

  // Create a custom deck
  Future<String?> createCustomDeck(Deck deck) async {
    if (_userId == null) return null;

    try {
      final deckData = _deckToFirestore(deck);
      final docRef = await _userDecksRef.add(deckData);

      await _firebaseService.logEvent(
        'custom_deck_created',
        parameters: {'deck_name': deck.name, 'card_count': deck.cards.length},
      );

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating custom deck: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to create custom deck',
      );
      return null;
    }
  }

  // Update a custom deck
  Future<bool> updateCustomDeck(String deckId, Deck deck) async {
    if (_userId == null) return false;

    try {
      final deckData = _deckToFirestore(deck);
      deckData['updatedAt'] = FieldValue.serverTimestamp();

      await _userDecksRef.doc(deckId).update(deckData);

      await _firebaseService.logEvent(
        'custom_deck_updated',
        parameters: {'deck_id': deckId, 'deck_name': deck.name},
      );

      return true;
    } catch (e) {
      debugPrint('Error updating custom deck: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to update custom deck',
      );
      return false;
    }
  }

  // Delete a custom deck
  Future<bool> deleteCustomDeck(String deckId) async {
    if (_userId == null) return false;

    try {
      await _userDecksRef.doc(deckId).delete();

      await _firebaseService.logEvent(
        'custom_deck_deleted',
        parameters: {'deck_id': deckId},
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting custom deck: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to delete custom deck',
      );
      return false;
    }
  }

  // Get unlocked premium decks for user
  Future<Set<String>> getUnlockedPremiumDecks() async {
    if (_userId == null) return {};

    try {
      final doc = await _userRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final unlocked = data['unlockedPremiumDecks'] as List<dynamic>?;
        return unlocked?.map((id) => id.toString()).toSet() ?? {};
      }
      return {};
    } catch (e) {
      debugPrint('Error getting unlocked decks: $e');
      return {};
    }
  }

  // Unlock a premium deck
  Future<bool> unlockPremiumDeck(String deckId) async {
    if (_userId == null) return false;

    try {
      await _userRef.update({
        'unlockedPremiumDecks': FieldValue.arrayUnion([deckId]),
      });

      await _firebaseService.logEvent(
        'premium_deck_unlocked',
        parameters: {'deck_id': deckId},
      );

      return true;
    } catch (e) {
      debugPrint('Error unlocking premium deck: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to unlock premium deck',
      );
      return false;
    }
  }

  // Add to recent decks
  Future<void> addToRecentDecks(String deckId) async {
    if (_userId == null) return;

    try {
      // First get current recent decks
      final doc = await _userRef.get();
      List<String> recentDecks = [];

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        recentDecks = List<String>.from(data['recentDecks'] ?? []);
      }

      // Remove if already exists and add to front
      recentDecks.remove(deckId);
      recentDecks.insert(0, deckId);

      // Keep only last 5
      if (recentDecks.length > 5) {
        recentDecks = recentDecks.sublist(0, 5);
      }

      await _userRef.update({'recentDecks': recentDecks});
    } catch (e) {
      debugPrint('Error adding to recent decks: $e');
    }
  }

  // Get recent deck IDs
  Future<List<String>> getRecentDeckIds() async {
    if (_userId == null) return [];

    try {
      final doc = await _userRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['recentDecks'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting recent decks: $e');
      return [];
    }
  }

  // Initialize default decks in Firestore (run once)
  Future<void> initializeDefaultDecks(
    List<Map<String, dynamic>> decksData,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final deckData in decksData) {
        final docRef = _defaultDecksRef.doc(deckData['id']);
        batch.set(docRef, {
          'name': deckData['name'],
          'description': deckData['description'],
          'iconCodePoint': (deckData['icon'] as IconData).codePoint,
          'iconFontFamily':
              (deckData['icon'] as IconData).fontFamily ?? 'MaterialIcons',
          'colorValue': (deckData['color'] as Color).value,
          'imageUrl': deckData['imageUrl'] as String?,
          'isPremium': deckData['isPremium'] ?? false,
          'cards': deckData['cards'],
          'createdAt': FieldValue.serverTimestamp(),
            'country': deckData['country'] ?? 'UNIVERSAL',
            'tags': deckData['tags'] ?? [],
            'priority': deckData['priority'] ?? 0,
            'isActive': deckData['isActive'] ?? true,
        });
      }

      await batch.commit();
      debugPrint('Default decks initialized in Firestore');
    } catch (e) {
      debugPrint('Error initializing default decks: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to initialize default decks',
      );
    }
  }

  // Convert Firestore data to Deck model
  Deck _deckFromFirestore(
    Map<String, dynamic> data,
    String id, {
    bool isCustom = false,
  }) {
    // Parse cardsByDifficulty if available
    CardsByDifficulty? cardsByDifficulty;
    if (data['cardsByDifficulty'] != null) {
      final difficultyData = data['cardsByDifficulty'] as Map<String, dynamic>;
      cardsByDifficulty = CardsByDifficulty(
        easy: difficultyData['easy'] != null 
            ? List<String>.from(difficultyData['easy'] as List) 
            : [],
        medium: difficultyData['medium'] != null 
            ? List<String>.from(difficultyData['medium'] as List) 
            : [],
        hard: difficultyData['hard'] != null 
            ? List<String>.from(difficultyData['hard'] as List) 
            : [],
      );
    }

    // Parse countries array (with backward compatibility for legacy single country field)
    List<String> parsedCountries = [];
    if (data['countries'] != null) {
      parsedCountries = List<String>.from(data['countries'] as List);
    } else if (data['country'] != null) {
      // Backward compatibility: convert single country to array
      parsedCountries = [data['country'] as String];
    }

    return Deck(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: IconMapper.mapIcon(
        codePoint: data['iconCodePoint'],
        fontFamily: data['iconFontFamily'],
        fontPackage: data['iconFontPackage'],
      ),
      color: Color(data['colorValue'] ?? Colors.blue.value),
      imageUrl: data['imageUrl'] as String?,
      isPremium: data['isPremium'] ?? false,
      isCustom: isCustom,
      cards: List<String>.from(data['cards'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      country: data['country'] as String?,
      countries: parsedCountries,
      tags: data['tags'] != null 
          ? List<String>.from(data['tags'] as List)
          : [],
      priority: data['priority'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      cardsByDifficulty: cardsByDifficulty,
      hasDifficultyModes: data['hasDifficultyModes'] as bool? ?? false,
      playCount: data['playCount'] as int? ?? 0,
    );
  }

  // Convert Deck model to Firestore data
  Map<String, dynamic> _deckToFirestore(Deck deck) {
    return {
      'name': deck.name,
      'description': deck.description,
      'iconCodePoint': deck.icon.codePoint,
      'iconFontFamily': deck.icon.fontFamily ?? 'MaterialIcons',
      'iconFontPackage': deck.icon.fontPackage,
      'colorValue': deck.color.value,
      'imageUrl': deck.imageUrl,
      'isPremium': deck.isPremium,
      'cards': deck.cards,
      'createdAt': deck.createdAt,
      'updatedAt': deck.updatedAt,
      'country': deck.country, // Legacy field for backward compatibility
      'countries': deck.countries.isNotEmpty ? deck.countries : deck.effectiveCountries,
      'tags': deck.tags,
      'priority': deck.priority,
      'isActive': deck.isActive,
      'playCount': deck.playCount,
    };
  }
  
  // Increment play count for a deck
  Future<void> incrementDeckPlayCount(String deckId) async {
    try {
      await _defaultDecksRef.doc(deckId).update({
        'playCount': FieldValue.increment(1),
      });
      debugPrint('📊 Incremented play count for deck: $deckId');
    } catch (e) {
      debugPrint('Error incrementing play count: $e');
      // Non-critical error, don't throw
    }
  }
}
