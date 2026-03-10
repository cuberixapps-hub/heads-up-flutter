import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Translation data for a deck
class DeckTranslation {
  final String name;
  final String description;
  final List<String>? cards;

  DeckTranslation({
    required this.name,
    required this.description,
    this.cards,
  });

  factory DeckTranslation.fromMap(Map<String, dynamic> map) {
    return DeckTranslation(
      name: map['name'] as String,
      description: map['description'] as String,
      cards: map['cards'] != null ? List<String>.from(map['cards'] as List) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      if (cards != null) 'cards': cards,
    };
  }
}

/// Difficulty levels for deck cards
enum DeckDifficulty {
  mixed,  // All difficulties combined
  easy,
  medium,
  hard,
}

/// Cards organized by difficulty level
class CardsByDifficulty {
  final List<String> easy;
  final List<String> medium;
  final List<String> hard;

  const CardsByDifficulty({
    this.easy = const [],
    this.medium = const [],
    this.hard = const [],
  });

  factory CardsByDifficulty.fromMap(Map<String, dynamic> map) {
    return CardsByDifficulty(
      easy: map['easy'] != null ? List<String>.from(map['easy'] as List) : [],
      medium: map['medium'] != null ? List<String>.from(map['medium'] as List) : [],
      hard: map['hard'] != null ? List<String>.from(map['hard'] as List) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'easy': easy,
      'medium': medium,
      'hard': hard,
    };
  }

  /// Get all cards combined
  List<String> get all => [...easy, ...medium, ...hard];

  /// Check if there are any cards
  bool get isEmpty => easy.isEmpty && medium.isEmpty && hard.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Get total card count
  int get totalCount => easy.length + medium.length + hard.length;
}

class Deck {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  final bool isPremium;
  final bool isCustom;
  final List<String> cards;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? country; // Legacy single country field for backward compatibility
  final List<String> countries; // Multi-country support: ['UNIVERSAL', 'IN', 'US', etc.]
  final List<String> tags;
  final int priority; // Lower number = higher priority
  final bool isActive; // Enable/disable deck remotely
  final bool premiumOnly; // If true, ads cannot unlock this deck - purchase only
  final Map<String, DeckTranslation>? translations; // Language code -> Translation
  final CardsByDifficulty? cardsByDifficulty; // Cards organized by difficulty
  final bool hasDifficultyModes; // Flag indicating this deck supports difficulty modes
  final int playCount; // Track popularity

  Deck({
    String? id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.imageUrl,
    this.isPremium = false,
    this.isCustom = false,
    required this.cards,
    DateTime? createdAt,
    this.updatedAt,
    this.country,
    this.countries = const [],
    this.tags = const [],
    this.priority = 0,
    this.isActive = true,
    this.premiumOnly = false,
    this.translations,
    this.cardsByDifficulty,
    this.hasDifficultyModes = false,
    this.playCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Get the effective list of countries for this deck
  /// Handles backward compatibility with legacy single country field
  List<String> get effectiveCountries {
    if (countries.isNotEmpty) {
      return countries;
    }
    // Fallback to legacy single country field
    if (country != null && country!.isNotEmpty) {
      return [country!];
    }
    return ['UNIVERSAL']; // Default to universal if no country specified
  }

  /// Check if this deck is available in a specific country
  bool isAvailableInCountry(String countryCode) {
    final effective = effectiveCountries;
    return effective.contains('UNIVERSAL') || effective.contains(countryCode);
  }

  /// Check if this deck is universal (available everywhere)
  bool get isUniversal => effectiveCountries.contains('UNIVERSAL');

  factory Deck.fromMap(Map<String, dynamic> map) {
    // Parse translations if available
    Map<String, DeckTranslation>? parsedTranslations;
    if (map['translations'] != null) {
      final translationsMap = map['translations'] as Map<String, dynamic>;
      parsedTranslations = {};
      translationsMap.forEach((key, value) {
        parsedTranslations![key] = DeckTranslation.fromMap(value as Map<String, dynamic>);
      });
    }

    // Parse cardsByDifficulty if available
    CardsByDifficulty? parsedCardsByDifficulty;
    if (map['cardsByDifficulty'] != null) {
      parsedCardsByDifficulty = CardsByDifficulty.fromMap(
        map['cardsByDifficulty'] as Map<String, dynamic>,
      );
    }

    // Parse countries array (with backward compatibility for legacy single country field)
    List<String> parsedCountries = [];
    if (map['countries'] != null) {
      parsedCountries = List<String>.from(map['countries'] as List);
    } else if (map['country'] != null) {
      // Backward compatibility: convert single country to array
      parsedCountries = [map['country'] as String];
    }

    return Deck(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      icon: map['icon'] as IconData,
      color: map['color'] as Color,
      imageUrl: map['imageUrl'] as String?,
      isPremium: map['isPremium'] as bool? ?? false,
      isCustom: map['isCustom'] as bool? ?? false,
      cards: List<String>.from(map['cards'] as List),
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String)
              : DateTime.now(),
      updatedAt:
          map['updatedAt'] != null
              ? DateTime.parse(map['updatedAt'] as String)
              : null,
      country: map['country'] as String?,
      countries: parsedCountries,
      tags: map['tags'] != null 
          ? List<String>.from(map['tags'] as List)
          : [],
      priority: map['priority'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      premiumOnly: map['premiumOnly'] as bool? ?? false,
      translations: parsedTranslations,
      cardsByDifficulty: parsedCardsByDifficulty,
      hasDifficultyModes: map['hasDifficultyModes'] as bool? ?? false,
      playCount: map['playCount'] as int? ?? 0,
    );
  }

  /// Create a Deck from Supabase response (snake_case to camelCase)
  factory Deck.fromSupabase(Map<String, dynamic> row) {
    // Parse translations if available
    Map<String, DeckTranslation>? parsedTranslations;
    if (row['translations'] != null) {
      final translationsMap = row['translations'] as Map<String, dynamic>;
      parsedTranslations = {};
      translationsMap.forEach((key, value) {
        parsedTranslations![key] = DeckTranslation.fromMap(value as Map<String, dynamic>);
      });
    }

    // Parse cardsByDifficulty if available (Supabase uses snake_case)
    CardsByDifficulty? parsedCardsByDifficulty;
    if (row['cards_by_difficulty'] != null) {
      parsedCardsByDifficulty = CardsByDifficulty.fromMap(
        row['cards_by_difficulty'] as Map<String, dynamic>,
      );
    }

    // Parse countries array
    List<String> parsedCountries = [];
    if (row['countries'] != null) {
      parsedCountries = List<String>.from(row['countries'] as List);
    } else if (row['country'] != null) {
      parsedCountries = [row['country'] as String];
    }

    // Parse icon from code point
    final iconCodePoint = row['icon_code_point'] as int? ?? 0xf005;
    final iconFontFamily = row['icon_font_family'] as String? ?? 'FontAwesomeIcons';
    
    // Parse color from int value
    final colorValue = row['color_value'] as int? ?? 0xFF9C27B0;

    return Deck(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      icon: IconData(iconCodePoint, fontFamily: iconFontFamily, fontPackage: 'font_awesome_flutter'),
      color: Color(colorValue),
      imageUrl: row['image_url'] as String?,
      isPremium: row['is_premium'] as bool? ?? false,
      isCustom: false, // Supabase decks are not custom
      cards: row['cards'] != null ? List<String>.from(row['cards'] as List) : [],
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      country: row['country'] as String?,
      countries: parsedCountries,
      tags: row['tags'] != null ? List<String>.from(row['tags'] as List) : [],
      priority: row['priority'] as int? ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      premiumOnly: row['premium_only'] as bool? ?? false,
      translations: parsedTranslations,
      cardsByDifficulty: parsedCardsByDifficulty,
      hasDifficultyModes: row['has_difficulty_modes'] as bool? ?? false,
      playCount: row['play_count'] as int? ?? 0,
    );
  }

  /// Convert to Supabase format (camelCase to snake_case)
  Map<String, dynamic> toSupabase() {
    final translationsMap = <String, dynamic>{};
    if (translations != null) {
      translations!.forEach((key, value) {
        translationsMap[key] = value.toMap();
      });
    }

    return {
      'id': id,
      'name': name,
      'description': description,
      'cards': cards,
      'icon_code_point': icon.codePoint,
      'icon_font_family': icon.fontFamily ?? 'FontAwesomeIcons',
      'color_value': color.value,
      'image_url': imageUrl,
      'is_premium': isPremium,
      'is_active': isActive,
      'premium_only': premiumOnly,
      'country': country,
      'countries': countries.isNotEmpty ? countries : effectiveCountries,
      'tags': tags,
      'priority': priority,
      'play_count': playCount,
      'has_difficulty_modes': hasDifficultyModes,
      if (cardsByDifficulty != null) 'cards_by_difficulty': cardsByDifficulty!.toMap(),
      if (translations != null && translations!.isNotEmpty) 'translations': translationsMap,
    };
  }

  Map<String, dynamic> toMap() {
    final translationsMap = <String, dynamic>{};
    if (translations != null) {
      translations!.forEach((key, value) {
        translationsMap[key] = value.toMap();
      });
    }

    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon.codePoint,
      'color':
          '0x${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      'imageUrl': imageUrl,
      'isPremium': isPremium,
      'isCustom': isCustom,
      'cards': cards,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'country': country, // Legacy field for backward compatibility
      'countries': countries.isNotEmpty ? countries : effectiveCountries,
      'tags': tags,
      'priority': priority,
      'isActive': isActive,
      'premiumOnly': premiumOnly,
      if (translations != null && translations!.isNotEmpty) 'translations': translationsMap,
      if (cardsByDifficulty != null) 'cardsByDifficulty': cardsByDifficulty!.toMap(),
      'hasDifficultyModes': hasDifficultyModes,
      'playCount': playCount,
    };
  }

  Deck copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    Color? color,
    String? imageUrl,
    bool? isPremium,
    bool? isCustom,
    List<String>? cards,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? country,
    List<String>? countries,
    List<String>? tags,
    int? priority,
    bool? isActive,
    bool? premiumOnly,
    Map<String, DeckTranslation>? translations,
    CardsByDifficulty? cardsByDifficulty,
    bool? hasDifficultyModes,
    int? playCount,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      isPremium: isPremium ?? this.isPremium,
      isCustom: isCustom ?? this.isCustom,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      country: country ?? this.country,
      countries: countries ?? this.countries,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      premiumOnly: premiumOnly ?? this.premiumOnly,
      translations: translations ?? this.translations,
      cardsByDifficulty: cardsByDifficulty ?? this.cardsByDifficulty,
      hasDifficultyModes: hasDifficultyModes ?? this.hasDifficultyModes,
      playCount: playCount ?? this.playCount,
    );
  }

  /// Get localized name for the given locale code
  /// Falls back to original name if translation not available
  String getLocalizedName(String locale) {
    if (translations != null && translations!.containsKey(locale)) {
      return translations![locale]!.name;
    }
    // Fall back to English if available
    if (locale != 'en' && translations != null && translations!.containsKey('en')) {
      return translations!['en']!.name;
    }
    // Fall back to original name
    return name;
  }

  /// Get localized description for the given locale code
  /// Falls back to original description if translation not available
  String getLocalizedDescription(String locale) {
    if (translations != null && translations!.containsKey(locale)) {
      return translations![locale]!.description;
    }
    // Fall back to English if available
    if (locale != 'en' && translations != null && translations!.containsKey('en')) {
      return translations!['en']!.description;
    }
    // Fall back to original description
    return description;
  }

  /// Get localized cards for the given locale code
  /// Falls back to original cards if translation not available
  List<String> getLocalizedCards(String locale) {
    if (translations != null && translations!.containsKey(locale)) {
      final translation = translations![locale]!;
      if (translation.cards != null && translation.cards!.isNotEmpty) {
        return translation.cards!;
      }
    }
    // Fall back to English if available
    if (locale != 'en' && translations != null && translations!.containsKey('en')) {
      final enTranslation = translations!['en']!;
      if (enTranslation.cards != null && enTranslation.cards!.isNotEmpty) {
        return enTranslation.cards!;
      }
    }
    // Fall back to original cards
    return cards;
  }

  /// Get cards by difficulty level
  /// Returns cards for the specified difficulty, or all cards if no difficulty modes
  List<String> getCardsByDifficulty(DeckDifficulty difficulty, [String? locale]) {
    // If no difficulty modes available, return all cards
    if (!hasDifficultyModes || cardsByDifficulty == null || cardsByDifficulty!.isEmpty) {
      return locale != null ? getLocalizedCards(locale) : cards;
    }

    switch (difficulty) {
      case DeckDifficulty.easy:
        return cardsByDifficulty!.easy.isNotEmpty 
            ? cardsByDifficulty!.easy 
            : cards;
      case DeckDifficulty.medium:
        return cardsByDifficulty!.medium.isNotEmpty 
            ? cardsByDifficulty!.medium 
            : cards;
      case DeckDifficulty.hard:
        return cardsByDifficulty!.hard.isNotEmpty 
            ? cardsByDifficulty!.hard 
            : cards;
      case DeckDifficulty.mixed:
        // Return all cards from all difficulties combined
        final allCards = <String>[];
        if (cardsByDifficulty!.easy.isNotEmpty) allCards.addAll(cardsByDifficulty!.easy);
        if (cardsByDifficulty!.medium.isNotEmpty) allCards.addAll(cardsByDifficulty!.medium);
        if (cardsByDifficulty!.hard.isNotEmpty) allCards.addAll(cardsByDifficulty!.hard);
        return allCards.isNotEmpty ? allCards : cards;
    }
  }

  /// Get card count by difficulty
  int getCardCountByDifficulty(DeckDifficulty difficulty) {
    if (!hasDifficultyModes || cardsByDifficulty == null) {
      return cards.length;
    }

    switch (difficulty) {
      case DeckDifficulty.easy:
        return cardsByDifficulty!.easy.length;
      case DeckDifficulty.medium:
        return cardsByDifficulty!.medium.length;
      case DeckDifficulty.hard:
        return cardsByDifficulty!.hard.length;
      case DeckDifficulty.mixed:
        return cardsByDifficulty!.totalCount > 0 
            ? cardsByDifficulty!.totalCount 
            : cards.length;
    }
  }

  // Get shuffled cards for gameplay (localized and with difficulty support)
  List<String> getShuffledCards([String? locale, DeckDifficulty? difficulty]) {
    List<String> cardsToShuffle;
    
    if (difficulty != null && hasDifficultyModes && cardsByDifficulty != null) {
      cardsToShuffle = getCardsByDifficulty(difficulty, locale);
    } else {
      cardsToShuffle = locale != null ? getLocalizedCards(locale) : cards;
    }
    
    final shuffled = List<String>.from(cardsToShuffle);
    shuffled.shuffle();
    return shuffled;
  }

  // Check if deck has enough cards for a game
  bool get hasEnoughCards => cards.length >= 5;

  /// Configuration for NEW/UPDATED tags (in days)
  static const int newDeckThresholdDays = 7;
  static const int updatedDeckThresholdDays = 7;
  static const int minHoursBetweenCreateAndUpdate = 1;

  /// Check if this deck is newly created (within the last 7 days)
  bool get isNew {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays < newDeckThresholdDays;
  }

  /// Check if this deck was recently updated (within the last 7 days)
  /// Returns false if the deck is new (to avoid showing both tags)
  /// Only shows UPDATED if updatedAt is at least 1 hour after createdAt
  bool get isRecentlyUpdated {
    if (updatedAt == null) return false;
    
    // Don't show UPDATED tag if deck is NEW
    if (isNew) return false;
    
    // Check if updatedAt is significantly after createdAt (at least 1 hour)
    final hoursBetweenCreateAndUpdate = updatedAt!.difference(createdAt).inHours;
    if (hoursBetweenCreateAndUpdate < minHoursBetweenCreateAndUpdate) return false;
    
    final now = DateTime.now();
    final difference = now.difference(updatedAt!);
    return difference.inDays < updatedDeckThresholdDays;
  }

  /// Get the deck status for UI display
  /// Returns: 'new', 'updated', or null
  String? get statusTag {
    if (isNew) return 'new';
    if (isRecentlyUpdated) return 'updated';
    return null;
  }

  /// Check if translation is available for a given locale
  bool hasTranslation(String locale) {
    return translations != null && translations!.containsKey(locale);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Deck && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Deck(id: $id, name: $name, cards: ${cards.length}, countries: $effectiveCountries, translations: ${translations?.keys.length ?? 0}, hasDifficultyModes: $hasDifficultyModes)';
  }
}
