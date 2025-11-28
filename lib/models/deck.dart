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
  final String? country; // 'UNIVERSAL', 'IN', 'JP', 'KR', 'BR', 'CN', 'US', 'GB', 'MX', 'TRENDING'
  final List<String> tags;
  final int priority; // Lower number = higher priority
  final bool isActive; // Enable/disable deck remotely
  final Map<String, DeckTranslation>? translations; // Language code -> Translation

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
    this.tags = const [],
    this.priority = 0,
    this.isActive = true,
    this.translations,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

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
      tags: map['tags'] != null 
          ? List<String>.from(map['tags'] as List)
          : [],
      priority: map['priority'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      translations: parsedTranslations,
    );
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
      'country': country,
      'tags': tags,
      'priority': priority,
      'isActive': isActive,
      if (translations != null && translations!.isNotEmpty) 'translations': translationsMap,
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
    List<String>? tags,
    int? priority,
    bool? isActive,
    Map<String, DeckTranslation>? translations,
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
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      translations: translations ?? this.translations,
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

  // Get shuffled cards for gameplay (localized)
  List<String> getShuffledCards([String? locale]) {
    final cardsToShuffle = locale != null ? getLocalizedCards(locale) : cards;
    final shuffled = List<String>.from(cardsToShuffle);
    shuffled.shuffle();
    return shuffled;
  }

  // Check if deck has enough cards for a game
  bool get hasEnoughCards => cards.length >= 5;

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
    return 'Deck(id: $id, name: $name, cards: ${cards.length}, translations: ${translations?.keys.length ?? 0})';
  }
}
