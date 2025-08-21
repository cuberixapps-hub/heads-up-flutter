import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/deck.dart';
import 'firebase_service.dart';

class DeckFirebaseService {
  final FirebaseService _firebaseService = FirebaseService();

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
      final QuerySnapshot snapshot = await _defaultDecksRef.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _deckFromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting default decks: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get default decks',
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
          'isPremium': deckData['isPremium'] ?? false,
          'cards': deckData['cards'],
          'createdAt': FieldValue.serverTimestamp(),
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
    return Deck(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: IconData(
        data['iconCodePoint'] ?? Icons.category.codePoint,
        fontFamily: data['iconFontFamily'] ?? 'MaterialIcons',
        fontPackage: data['iconFontPackage'],
      ),
      color: Color(data['colorValue'] ?? Colors.blue.value),
      isPremium: data['isPremium'] ?? false,
      isCustom: isCustom,
      cards: List<String>.from(data['cards'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
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
      'isPremium': deck.isPremium,
      'cards': deck.cards,
      'createdAt': deck.createdAt,
      'updatedAt': deck.updatedAt,
    };
  }
}
