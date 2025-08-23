import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_deck.dart';
import '../models/deck.dart';
import '../models/card.dart' as game_card;
import 'dart:convert';

class DailyDeckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'daily_decks';
  static const String _lastFetchKey = 'last_daily_deck_fetch';
  static const String _cachedDeckKey = 'cached_daily_deck';

  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedDeckKey);
      await prefs.remove(_lastFetchKey);
      print('🧹 Cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Get today's daily deck
  Future<DailyDeck?> getTodaysDeck({bool forceRefresh = false}) async {
    try {
      print('🔍 DailyDeckService: Getting today\'s deck...');

      // Clear cache if force refresh
      if (forceRefresh) {
        print('🔄 Force refresh requested - clearing cache');
        await clearCache();
      }

      // Skip cache check and always fetch fresh data from Firebase
      // This ensures we always get the latest data
      print('📡 Fetching fresh data from Firebase...');

      // Fetch from Firebase
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print('🔥 Fetching from Firebase...');
      print('📅 Date range: $startOfDay to $endOfDay');

      // First, let's check if ANY documents exist
      print('🔍 Checking collection: $_collectionName');
      final allDocsSnapshot =
          await _firestore.collection(_collectionName).limit(10).get();
      print('📚 Total documents in collection: ${allDocsSnapshot.docs.length}');

      if (allDocsSnapshot.docs.isEmpty) {
        print('⚠️ No documents found in daily_decks collection!');
        print('💡 Make sure you have created daily decks in the admin portal');
        return null;
      }

      for (var doc in allDocsSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        print(
          '  - Document: ${data['title']} | Date: $date | Active: ${data['isActive']}',
        );
      }

      // Try a simpler query first - just get any active deck
      print('🔍 Trying simple query for active decks...');
      final simpleQuery =
          await _firestore
              .collection(_collectionName)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

      if (simpleQuery.docs.isNotEmpty) {
        print('✅ Found active deck with simple query');
        final deck = DailyDeck.fromFirestore(simpleQuery.docs.first);
        // Disable caching to always get fresh data
        // await _cacheDeck(deck);
        return deck;
      }

      // Original compound query (might need indexes)
      final querySnapshot =
          await _firestore
              .collection(_collectionName)
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('date', isLessThan: Timestamp.fromDate(endOfDay))
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

      print('📊 Query results: ${querySnapshot.docs.length} documents found');

      if (querySnapshot.docs.isEmpty) {
        print('❌ No daily deck found for today');
        print('🔄 Trying to get the most recent active deck as fallback...');

        // Fallback: Get the most recent active deck
        final fallbackSnapshot =
            await _firestore
                .collection(_collectionName)
                .where('isActive', isEqualTo: true)
                .orderBy('date', descending: true)
                .limit(1)
                .get();

        if (fallbackSnapshot.docs.isEmpty) {
          print('❌ No active daily decks found at all');
          return null;
        }

        print('✅ Using fallback deck');
        final dailyDeck = DailyDeck.fromFirestore(fallbackSnapshot.docs.first);
        await _cacheDeck(dailyDeck);
        return dailyDeck;
      }

      final dailyDeck = DailyDeck.fromFirestore(querySnapshot.docs.first);
      print('✅ Found daily deck: ${dailyDeck.title}');

      // Cache the deck
      await _cacheDeck(dailyDeck);

      return dailyDeck;
    } catch (e, stackTrace) {
      print('❌ Error fetching today\'s deck: $e');
      print('📍 Stack trace: $stackTrace');
      // Try to return cached deck even if it's not today's
      final fallbackCached = await _getCachedDeck();
      if (fallbackCached != null) {
        print('🔄 Returning cached deck as emergency fallback');
        return fallbackCached;
      }
      return null;
    }
  }

  // Convert DailyDeck to regular Deck for gameplay
  Deck convertToRegularDeck(DailyDeck dailyDeck) {
    return Deck(
      id: 'daily_${dailyDeck.id}',
      name: dailyDeck.title,
      description: dailyDeck.description,
      cards: dailyDeck.cards.map((card) => card.word).toList(),
      color: Color(dailyDeck.color),
      icon: _getIconFromName(dailyDeck.iconName),
      imageUrl: dailyDeck.imageUrl,
      isCustom: false,
      createdAt: dailyDeck.createdAt,
    );
  }

  // Get upcoming daily decks (for preview in admin)
  Future<List<DailyDeck>> getUpcomingDecks({int limit = 7}) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final querySnapshot =
          await _firestore
              .collection(_collectionName)
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .orderBy('date')
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map((doc) => DailyDeck.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching upcoming decks: $e');
      return [];
    }
  }

  // Cache the daily deck locally
  Future<void> _cacheDeck(DailyDeck deck) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deckData = {
        'id': deck.id,
        'date': deck.date.toIso8601String(),
        'title': deck.title,
        'description': deck.description,
        'cards':
            deck.cards
                .map(
                  (card) => {
                    'word': card.word,
                    'category': card.category,
                    'difficulty': card.difficulty,
                  },
                )
                .toList(),
        'color': deck.color,
        'iconName': deck.iconName,
        'imageUrl': deck.imageUrl,
        'isActive': deck.isActive,
        'createdAt': deck.createdAt.toIso8601String(),
        'expiresAt': deck.expiresAt?.toIso8601String(),
      };

      await prefs.setString(_cachedDeckKey, jsonEncode(deckData));
      await prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching deck: $e');
    }
  }

  // Get cached deck from local storage
  Future<DailyDeck?> _getCachedDeck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cachedDeckKey);

      if (cachedData == null) return null;

      final deckData = jsonDecode(cachedData) as Map<String, dynamic>;

      return DailyDeck(
        id: deckData['id'],
        date: DateTime.parse(deckData['date']),
        title: deckData['title'],
        description: deckData['description'],
        cards:
            (deckData['cards'] as List<dynamic>)
                .map(
                  (card) => game_card.Card(
                    word: card['word'],
                    category: card['category'],
                    difficulty: card['difficulty'],
                  ),
                )
                .toList(),
        color: deckData['color'],
        iconName: deckData['iconName'],
        imageUrl: deckData['imageUrl'] as String?,
        isActive: deckData['isActive'],
        createdAt: DateTime.parse(deckData['createdAt']),
        expiresAt:
            deckData['expiresAt'] != null
                ? DateTime.parse(deckData['expiresAt'])
                : null,
      );
    } catch (e) {
      print('Error getting cached deck: $e');
      return null;
    }
  }

  // Helper to convert icon name to IconData
  IconData _getIconFromName(String iconName) {
    // This should match with the icon mapping in your app
    switch (iconName) {
      case 'calendar_today':
        return Icons.calendar_today;
      case 'star':
        return Icons.star;
      case 'trending_up':
        return Icons.trending_up;
      case 'celebration':
        return Icons.celebration;
      default:
        return Icons.today;
    }
  }

  // Check if user has played today's daily deck
  Future<bool> hasPlayedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get the last played deck ID and date
      final lastPlayedId = prefs.getString('last_daily_played_id');
      final lastPlayedDateStr = prefs.getString('last_daily_played_date');

      if (lastPlayedId == null || lastPlayedDateStr == null) {
        print('📊 No previous play record found');
        return false;
      }

      final lastPlayedDate = DateTime.parse(lastPlayedDateStr);
      final now = DateTime.now();

      // Check if it was played today
      final wasPlayedToday =
          lastPlayedDate.year == now.year &&
          lastPlayedDate.month == now.month &&
          lastPlayedDate.day == now.day;

      print('📊 Last played: $lastPlayedDateStr, Was today: $wasPlayedToday');

      return wasPlayedToday;
    } catch (e) {
      print('❌ Error checking play status: $e');
      return false;
    }
  }

  // Mark today's daily deck as played
  Future<void> markAsPlayed(String deckId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await prefs.setString('last_daily_played_id', deckId);
      await prefs.setString('last_daily_played_date', now.toIso8601String());

      print('✅ Marked deck $deckId as played at ${now.toIso8601String()}');
    } catch (e) {
      print('❌ Error marking as played: $e');
    }
  }

  // Clear the played status (useful for testing)
  Future<void> clearPlayedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_daily_played_id');
      await prefs.remove('last_daily_played_date');
      print('🧹 Cleared played status');
    } catch (e) {
      print('❌ Error clearing played status: $e');
    }
  }
}
