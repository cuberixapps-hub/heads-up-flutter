import 'dart:async';
import 'package:flutter/material.dart';
import '../models/deck.dart';
import 'supabase_service.dart';
import 'cache_service.dart';
import 'recommendation_service.dart';

/// Service for deck operations using Supabase
/// Replaces DeckFirebaseService for deck content
/// Firebase is still used for auth, analytics, custom decks, etc.
class DeckSupabaseService {
  final SupabaseService _supabaseService = SupabaseService();
  final CacheService _cacheService = CacheService();

  /// Get all default decks from Supabase
  Future<List<Deck>> getDefaultDecks() async {
    try {
      // Try cache first
      final cachedDecks = await _cacheService.getCachedDecksByCountry('ALL');
      if (cachedDecks != null) {
        debugPrint('✅ Using cached default decks: ${cachedDecks.length} decks');
        return cachedDecks;
      }

      // Cache miss, fetch from Supabase
      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('is_active', true)
          .order('priority', ascending: true)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      final decks = (response as List)
          .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
          .toList();

      // Cache the results
      await _cacheService.cacheDecksByCountry('ALL', decks);

      debugPrint('✅ Loaded ${decks.length} default decks from Supabase');
      return decks;
    } catch (e) {
      debugPrint('Error getting default decks from Supabase: $e');
      throw Exception('Failed to load decks. Please check your internet connection.');
    }
  }

  /// Get decks filtered by country (supports multi-country decks)
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
      
      debugPrint('🔍 Searching for decks with countries: $countriesToSearch');

      // Use Supabase's overlaps operator to find decks where countries array overlaps with our search list
      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('is_active', true)
          .overlaps('countries', countriesToSearch)
          .order('priority', ascending: true)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      var decks = (response as List)
          .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
          .toList();

      // If no results with 'countries' array, try legacy 'country' field
      if (decks.isEmpty) {
        debugPrint('🔄 No results with countries array, trying legacy country field...');
        final legacyResponse = await _supabaseService
            .from('decks')
            .select()
            .eq('is_active', true)
            .inFilter('country', ['UNIVERSAL', countryCode])
            .order('priority', ascending: true)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 15));

        decks = (legacyResponse as List)
            .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
            .toList();
      }

      debugPrint('✅ Found ${decks.length} decks for $countryCode');

      // Cache the results
      await _cacheService.cacheDecksByCountry(countryCode, decks);

      return decks;
    } catch (e) {
      debugPrint('Error getting decks by country from Supabase: $e');
      throw Exception('Failed to load decks. Please check your internet connection.');
    }
  }

  /// Get decks filtered by multiple countries
  Future<List<Deck>> getDecksByCountries(List<String> countryCodes) async {
    try {
      if (countryCodes.isEmpty) {
        return getDefaultDecks();
      }

      // Ensure UNIVERSAL is included
      final countriesToSearch = <String>{'UNIVERSAL', ...countryCodes}.toList();

      debugPrint('🔍 Searching for decks with countries: $countriesToSearch');

      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('is_active', true)
          .overlaps('countries', countriesToSearch)
          .order('priority', ascending: true)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      final decks = (response as List)
          .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Found ${decks.length} decks for countries: $countryCodes');

      return decks;
    } catch (e) {
      debugPrint('Error getting decks by countries from Supabase: $e');
      throw Exception('Failed to load decks. Please check your internet connection.');
    }
  }

  /// Force refresh decks for a specific country (bypasses cache)
  Future<List<Deck>> refreshDecksByCountry(String countryCode) async {
    try {
      // Clear cache for this country
      await _cacheService.clearCache('cached_decks_$countryCode');
      
      // Fetch fresh data
      return getDecksByCountry(countryCode);
    } catch (e) {
      debugPrint('Error refreshing decks for $countryCode: $e');
      rethrow;
    }
  }

  /// Search decks globally
  Future<List<Deck>> searchDecksGlobally(String searchTerm) async {
    try {
      if (searchTerm.isEmpty) {
        return [];
      }

      debugPrint('🔍 Searching for decks: "$searchTerm"');

      // Supabase text search using ilike
      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('is_active', true)
          .or('name.ilike.%$searchTerm%,description.ilike.%$searchTerm%')
          .order('priority', ascending: true)
          .limit(50)
          .timeout(const Duration(seconds: 15));

      final decks = (response as List)
          .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Found ${decks.length} decks matching "$searchTerm"');

      return decks;
    } catch (e) {
      debugPrint('Error searching decks: $e');
      return [];
    }
  }

  /// Stream decks by country (real-time updates)
  Stream<List<Deck>> streamDecksByCountry(String countryCode) {
    final countriesToSearch = ['UNIVERSAL', countryCode];

    return _supabaseService.client
        .from('decks')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .map((data) {
          return data
              .where((row) {
                final countries = row['countries'] as List<dynamic>?;
                if (countries == null) return false;
                return countries.any((c) => countriesToSearch.contains(c));
              })
              .map((row) => Deck.fromSupabase(row))
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));
        });
  }

  /// Get a single deck by ID
  Future<Deck?> getDeckById(String deckId) async {
    try {
      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('id', deckId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (response == null) {
        return null;
      }

      return Deck.fromSupabase(response);
    } catch (e) {
      debugPrint('Error getting deck by ID: $e');
      return null;
    }
  }

  /// Increment play count for a deck
  Future<void> incrementDeckPlayCount(String deckId) async {
    try {
      // Get current play count
      final response = await _supabaseService
          .from('decks')
          .select('play_count')
          .eq('id', deckId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (response != null) {
        final currentCount = (response['play_count'] as int?) ?? 0;
        await _supabaseService
            .from('decks')
            .update({'play_count': currentCount + 1})
            .eq('id', deckId)
            .timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      debugPrint('Error incrementing play count: $e');
      // Non-critical error, don't throw
    }
  }

  /// Get popular decks (sorted by play count)
  Future<List<Deck>> getPopularDecks({int limit = 20}) async {
    try {
      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('is_active', true)
          .order('play_count', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 15));

      return (response as List)
          .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting popular decks: $e');
      return [];
    }
  }

  /// Get new decks (sorted by creation date)
  Future<List<Deck>> getNewDecks({int limit = 20}) async {
    try {
      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 15));

      return (response as List)
          .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting new decks: $e');
      return [];
    }
  }

  /// Get premium decks
  Future<List<Deck>> getPremiumDecks() async {
    try {
      final response = await _supabaseService
          .from('decks')
          .select()
          .eq('is_active', true)
          .eq('is_premium', true)
          .order('priority', ascending: true)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      return (response as List)
          .map((row) => Deck.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting premium decks: $e');
      return [];
    }
  }
}
