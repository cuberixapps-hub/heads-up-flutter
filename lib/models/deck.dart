import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  factory Deck.fromMap(Map<String, dynamic> map) {
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
    );
  }

  Map<String, dynamic> toMap() {
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
    );
  }

  // Get shuffled cards for gameplay
  List<String> getShuffledCards() {
    final shuffled = List<String>.from(cards);
    shuffled.shuffle();
    return shuffled;
  }

  // Check if deck has enough cards for a game
  bool get hasEnoughCards => cards.length >= 5;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Deck && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Deck(id: $id, name: $name, cards: ${cards.length})';
  }
}
