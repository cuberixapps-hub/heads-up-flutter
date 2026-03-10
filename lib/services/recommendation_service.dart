import 'package:flutter/foundation.dart';
import '../models/deck.dart';

/// Represents a deck with its recommendation score
class RecommendedDeck {
  final Deck deck;
  final double score;
  final String reason;

  RecommendedDeck({
    required this.deck,
    required this.score,
    required this.reason,
  });

  @override
  String toString() => 'RecommendedDeck(${deck.name}, score: $score, reason: $reason)';
}

/// Service for recommending decks based on user preferences and behavior
class DeckRecommendationService {
  // Scoring weights
  static const double _countryMatchWeight = 40.0;
  static const double _regionalMatchWeight = 20.0;
  static const double _universalWeight = 15.0;
  static const double _popularityWeight = 15.0;
  static const double _recentPlayWeight = 10.0;
  static const double _favoriteBoost = 25.0;

  // Regional mappings for fallback content
  static const Map<String, List<String>> _regionalGroups = {
    // North America
    'US': ['CA', 'US'],
    'CA': ['US', 'CA'],
    
    // UK & Commonwealth
    'GB': ['AU', 'NZ', 'IE', 'GB'],
    'AU': ['GB', 'NZ', 'AU'],
    'NZ': ['GB', 'AU', 'NZ'],
    
    // Latin America (Spanish speaking)
    'MX': ['AR', 'CO', 'CL', 'PE', 'VE', 'ES', 'MX'],
    'AR': ['MX', 'CO', 'CL', 'PE', 'VE', 'AR'],
    
    // Portuguese speaking
    'BR': ['PT', 'BR'],
    'PT': ['BR', 'PT'],
    
    // East Asia
    'JP': ['JP'],
    'KR': ['KR'],
    'CN': ['TW', 'HK', 'CN'],
    'TW': ['CN', 'TW'],
    'HK': ['CN', 'HK'],
    
    // South Asia
    'IN': ['IN', 'PK', 'BD'],
    
    // Southeast Asia
    'SG': ['MY', 'SG'],
    'MY': ['SG', 'MY'],
    'TH': ['TH'],
    'VN': ['VN'],
    'ID': ['ID'],
    'PH': ['PH', 'US'], // Philippines has strong US cultural influence
  };

  /// Get regional fallback countries for a given country code
  static List<String> getRegionalFallbacks(String countryCode) {
    final fallbacks = _regionalGroups[countryCode.toUpperCase()];
    if (fallbacks != null) {
      return fallbacks;
    }
    // Default fallback to US content for unsupported regions
    return ['US'];
  }

  /// Calculate recommendation score for a single deck
  static double _calculateDeckScore({
    required Deck deck,
    required String userCountry,
    required Set<String> recentDeckIds,
    required Set<String> favoriteDeckIds,
    int maxPlayCount = 100,
  }) {
    double score = 0.0;
    final effectiveCountries = deck.effectiveCountries;

    // 1. Country Match Score (40 points max)
    if (effectiveCountries.contains(userCountry)) {
      score += _countryMatchWeight;
    }

    // 2. Regional Match Score (20 points max)
    if (score < _countryMatchWeight) { // Only if no exact match
      final regionalFallbacks = getRegionalFallbacks(userCountry);
      for (final fallback in regionalFallbacks) {
        if (effectiveCountries.contains(fallback)) {
          score += _regionalMatchWeight;
          break;
        }
      }
    }

    // 3. Universal Score (15 points)
    if (effectiveCountries.contains('UNIVERSAL')) {
      score += _universalWeight;
    }

    // 4. Popularity Score (15 points max)
    // Normalize play count to 0-1 range, then multiply by weight
    if (maxPlayCount > 0 && deck.playCount > 0) {
      final normalizedPopularity = (deck.playCount / maxPlayCount).clamp(0.0, 1.0);
      score += normalizedPopularity * _popularityWeight;
    }

    // 5. Recent Play Boost (10 points)
    if (recentDeckIds.contains(deck.id)) {
      score += _recentPlayWeight;
    }

    // 6. Favorite Boost (25 points extra)
    if (favoriteDeckIds.contains(deck.id)) {
      score += _favoriteBoost;
    }

    // 7. Priority Adjustment (lower priority = higher in list)
    // Subtract priority to give higher-priority decks a boost
    score -= deck.priority * 0.5;

    return score;
  }

  /// Get the primary reason for recommending a deck
  static String _getRecommendationReason({
    required Deck deck,
    required String userCountry,
    required Set<String> recentDeckIds,
    required Set<String> favoriteDeckIds,
  }) {
    final effectiveCountries = deck.effectiveCountries;

    if (favoriteDeckIds.contains(deck.id)) {
      return 'Favorited';
    }

    if (recentDeckIds.contains(deck.id)) {
      return 'Recently played';
    }

    if (effectiveCountries.contains(userCountry)) {
      return 'Popular in your region';
    }

    final regionalFallbacks = getRegionalFallbacks(userCountry);
    for (final fallback in regionalFallbacks) {
      if (effectiveCountries.contains(fallback)) {
        return 'Popular in similar regions';
      }
    }

    if (effectiveCountries.contains('UNIVERSAL')) {
      return 'Popular worldwide';
    }

    if (deck.playCount > 50) {
      return 'Trending';
    }

    return 'Recommended for you';
  }

  /// Get recommended decks sorted by relevance score
  static List<RecommendedDeck> getRecommendedDecks({
    required List<Deck> allDecks,
    required String userCountry,
    List<String> recentDeckIds = const [],
    List<String> favoriteDeckIds = const [],
    int? limit,
  }) {
    if (allDecks.isEmpty) return [];

    final recentSet = recentDeckIds.toSet();
    final favoriteSet = favoriteDeckIds.toSet();

    // Calculate max play count for normalization
    final maxPlayCount = allDecks.fold<int>(
      1,
      (max, deck) => deck.playCount > max ? deck.playCount : max,
    );

    // Score all decks
    final scoredDecks = allDecks
        .where((deck) => deck.isActive)
        .map((deck) {
          final score = _calculateDeckScore(
            deck: deck,
            userCountry: userCountry,
            recentDeckIds: recentSet,
            favoriteDeckIds: favoriteSet,
            maxPlayCount: maxPlayCount,
          );
          final reason = _getRecommendationReason(
            deck: deck,
            userCountry: userCountry,
            recentDeckIds: recentSet,
            favoriteDeckIds: favoriteSet,
          );
          return RecommendedDeck(deck: deck, score: score, reason: reason);
        })
        .toList();

    // Sort by score (descending)
    scoredDecks.sort((a, b) => b.score.compareTo(a.score));

    debugPrint('📊 Recommendation scores for top decks:');
    for (int i = 0; i < scoredDecks.length && i < 5; i++) {
      debugPrint('   ${i + 1}. ${scoredDecks[i]}');
    }

    // Apply limit if specified
    if (limit != null && limit > 0 && scoredDecks.length > limit) {
      return scoredDecks.sublist(0, limit);
    }

    return scoredDecks;
  }

  /// Get top recommended decks for featured section
  static List<Deck> getTopRecommendedDecks({
    required List<Deck> allDecks,
    required String userCountry,
    List<String> recentDeckIds = const [],
    List<String> favoriteDeckIds = const [],
    int limit = 10,
  }) {
    final recommended = getRecommendedDecks(
      allDecks: allDecks,
      userCountry: userCountry,
      recentDeckIds: recentDeckIds,
      favoriteDeckIds: favoriteDeckIds,
      limit: limit,
    );

    return recommended.map((r) => r.deck).toList();
  }

  /// Get decks filtered by country with recommendation sorting
  static List<Deck> getDecksByCountryWithRecommendation({
    required List<Deck> allDecks,
    required String userCountry,
    List<String> recentDeckIds = const [],
    List<String> favoriteDeckIds = const [],
    bool includeUniversal = true,
    bool includeRegionalFallback = true,
  }) {
    final regionalFallbacks = includeRegionalFallback 
        ? getRegionalFallbacks(userCountry) 
        : <String>[];

    // Filter decks by country
    final filteredDecks = allDecks.where((deck) {
      if (!deck.isActive) return false;
      
      final countries = deck.effectiveCountries;
      
      // Include if matches user's country
      if (countries.contains(userCountry)) return true;
      
      // Include universal decks
      if (includeUniversal && countries.contains('UNIVERSAL')) return true;
      
      // Include regional fallbacks
      if (includeRegionalFallback) {
        for (final fallback in regionalFallbacks) {
          if (countries.contains(fallback)) return true;
        }
      }
      
      return false;
    }).toList();

    // Sort by recommendation
    final recommended = getRecommendedDecks(
      allDecks: filteredDecks,
      userCountry: userCountry,
      recentDeckIds: recentDeckIds,
      favoriteDeckIds: favoriteDeckIds,
    );

    return recommended.map((r) => r.deck).toList();
  }

  /// Get decks grouped by recommendation category
  static Map<String, List<Deck>> getDecksGroupedByCategory({
    required List<Deck> allDecks,
    required String userCountry,
    List<String> recentDeckIds = const [],
    List<String> favoriteDeckIds = const [],
  }) {
    final result = <String, List<Deck>>{
      'favorites': [],
      'recentlyPlayed': [],
      'forYou': [],
      'popular': [],
      'universal': [],
    };

    final recentSet = recentDeckIds.toSet();
    final favoriteSet = favoriteDeckIds.toSet();

    for (final deck in allDecks) {
      if (!deck.isActive) continue;

      // Favorites
      if (favoriteSet.contains(deck.id)) {
        result['favorites']!.add(deck);
        continue;
      }

      // Recently played
      if (recentSet.contains(deck.id)) {
        result['recentlyPlayed']!.add(deck);
        continue;
      }

      final countries = deck.effectiveCountries;

      // For You (matches user's country)
      if (countries.contains(userCountry)) {
        result['forYou']!.add(deck);
        continue;
      }

      // Regional fallbacks go to "For You" as well
      final regionalFallbacks = getRegionalFallbacks(userCountry);
      bool isRegional = false;
      for (final fallback in regionalFallbacks) {
        if (countries.contains(fallback)) {
          result['forYou']!.add(deck);
          isRegional = true;
          break;
        }
      }
      if (isRegional) continue;

      // Popular (high play count)
      if (deck.playCount > 50) {
        result['popular']!.add(deck);
        continue;
      }

      // Universal
      if (countries.contains('UNIVERSAL')) {
        result['universal']!.add(deck);
      }
    }

    // Sort each category by score
    for (final category in result.keys) {
      if (result[category]!.isNotEmpty) {
        final recommended = getRecommendedDecks(
          allDecks: result[category]!,
          userCountry: userCountry,
          recentDeckIds: recentDeckIds,
          favoriteDeckIds: favoriteDeckIds,
        );
        result[category] = recommended.map((r) => r.deck).toList();
      }
    }

    return result;
  }
}








