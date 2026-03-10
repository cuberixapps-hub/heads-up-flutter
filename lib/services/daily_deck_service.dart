import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_deck.dart';
import '../models/deck.dart';
import '../models/card.dart' as game_card;
import 'supabase_service.dart';

class DailyDeckService {
  final SupabaseService _supabaseService = SupabaseService();
  static const String _lastFetchKey = 'last_daily_deck_fetch';
  static const String _cachedDeckKey = 'cached_daily_deck';

  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedDeckKey);
      await prefs.remove(_lastFetchKey);
    } catch (e) {
      debugPrint('Error clearing daily deck cache: $e');
    }
  }

  // Get today's daily deck
  Future<DailyDeck?> getTodaysDeck({bool forceRefresh = false}) async {
    try {
      // Clear cache if force refresh
      if (forceRefresh) {
        await clearCache();
      }

      // Fetch from Supabase
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Try to get today's deck first
      final todayResponse = await _supabaseService
          .from('daily_decks')
          .select()
          .eq('is_active', true)
          .eq('date', todayStr)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (todayResponse != null) {
        final dailyDeck = DailyDeck.fromSupabase(todayResponse);
        await _cacheDeck(dailyDeck);
        return dailyDeck;
      }

      // Fallback: Get the most recent active deck
      final fallbackResponse = await _supabaseService
          .from('daily_decks')
          .select()
          .eq('is_active', true)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (fallbackResponse == null) {
        return null;
      }

      final dailyDeck = DailyDeck.fromSupabase(fallbackResponse);
      await _cacheDeck(dailyDeck);
      return dailyDeck;
    } catch (e, stackTrace) {
      debugPrint('Error fetching daily deck: $e');
      debugPrint('Stack trace: $stackTrace');
      // Try to return cached deck even if it's not today's
      final fallbackCached = await _getCachedDeck();
      return fallbackCached;
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
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final response = await _supabaseService
          .from('daily_decks')
          .select()
          .gte('date', todayStr)
          .order('date', ascending: true)
          .limit(limit)
          .timeout(const Duration(seconds: 15));

      return (response as List)
          .map((row) => DailyDeck.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching upcoming decks: $e');
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
      debugPrint('Error caching deck: $e');
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
      debugPrint('Error getting cached deck: $e');
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
        return false;
      }

      final lastPlayedDate = DateTime.parse(lastPlayedDateStr);
      final now = DateTime.now();

      // Check if it was played today
      final wasPlayedToday =
          lastPlayedDate.year == now.year &&
          lastPlayedDate.month == now.month &&
          lastPlayedDate.day == now.day;

      return wasPlayedToday;
    } catch (e) {
      debugPrint('Error checking play status: $e');
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
    } catch (e) {
      debugPrint('Error marking as played: $e');
    }
  }

  // Clear the played status (useful for testing)
  Future<void> clearPlayedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_daily_played_id');
      await prefs.remove('last_daily_played_date');
    } catch (e) {
      debugPrint('Error clearing played status: $e');
    }
  }
}
