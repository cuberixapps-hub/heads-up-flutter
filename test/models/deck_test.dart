import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:heads_up_game/models/deck.dart';
import '../test_helpers/test_data.dart';

void main() {
  group('Deck Model Tests', () {
    test('should create a Deck with all properties', () {
      final deck = TestData.sampleDeck;

      expect(deck.id, equals('test-deck-1'));
      expect(deck.name, equals('Test Deck'));
      expect(deck.description, equals('A test deck for unit testing'));
      expect(deck.icon, equals(FontAwesomeIcons.star));
      expect(deck.color, equals(Colors.blue));
      expect(deck.isPremium, isFalse);
      expect(deck.isCustom, isFalse);
      expect(deck.cards.length, equals(10));
      expect(deck.createdAt, equals(DateTime(2024, 1, 1)));
      expect(deck.updatedAt, isNull);
    });

    test('should generate a unique ID if not provided', () {
      final deck = Deck(
        name: 'New Deck',
        description: 'Description',
        icon: FontAwesomeIcons.gamepad,
        color: Colors.red,
        cards: ['Card 1', 'Card 2'],
      );

      expect(deck.id, isNotEmpty);
      expect(deck.id.length, greaterThan(0));
    });

    test('should set createdAt to current time if not provided', () {
      final beforeCreation = DateTime.now();

      final deck = Deck(
        name: 'New Deck',
        description: 'Description',
        icon: FontAwesomeIcons.gamepad,
        color: Colors.red,
        cards: ['Card 1', 'Card 2'],
      );

      final afterCreation = DateTime.now();

      expect(
        deck.createdAt.isAfter(beforeCreation) ||
            deck.createdAt.isAtSameMomentAs(beforeCreation),
        isTrue,
      );
      expect(
        deck.createdAt.isBefore(afterCreation) ||
            deck.createdAt.isAtSameMomentAs(afterCreation),
        isTrue,
      );
    });

    test('should convert Deck to Map correctly', () {
      final deck = TestData.sampleDeck;
      final map = deck.toMap();

      expect(map['id'], equals('test-deck-1'));
      expect(map['name'], equals('Test Deck'));
      expect(map['description'], equals('A test deck for unit testing'));
      expect(map['icon'], equals(FontAwesomeIcons.star.codePoint));
      expect(map['color'], equals('0xFF2196F3')); // Blue color in hex
      expect(map['isPremium'], isFalse);
      expect(map['isCustom'], isFalse);
      expect(map['cards'], equals(deck.cards));
      expect(map['createdAt'], equals(deck.createdAt.toIso8601String()));
      expect(map['updatedAt'], isNull);
    });

    test('should create Deck from Map correctly', () {
      final map = {
        'id': 'deck-from-map',
        'name': 'Deck From Map',
        'description': 'Created from map',
        'icon': FontAwesomeIcons.heart,
        'color': Colors.pink,
        'isPremium': true,
        'isCustom': false,
        'cards': ['Card A', 'Card B', 'Card C'],
        'createdAt': '2024-01-15T10:30:00.000',
        'updatedAt': '2024-01-16T11:45:00.000',
      };

      final deck = Deck.fromMap(map);

      expect(deck.id, equals('deck-from-map'));
      expect(deck.name, equals('Deck From Map'));
      expect(deck.description, equals('Created from map'));
      expect(deck.icon, equals(FontAwesomeIcons.heart));
      expect(deck.color, equals(Colors.pink));
      expect(deck.isPremium, isTrue);
      expect(deck.isCustom, isFalse);
      expect(deck.cards, equals(['Card A', 'Card B', 'Card C']));
      expect(deck.createdAt, equals(DateTime.parse('2024-01-15T10:30:00.000')));
      expect(deck.updatedAt, equals(DateTime.parse('2024-01-16T11:45:00.000')));
    });

    test('should handle missing optional fields in fromMap', () {
      final map = {
        'id': 'minimal-deck',
        'name': 'Minimal Deck',
        'description': 'Minimal',
        'icon': FontAwesomeIcons.star,
        'color': Colors.blue,
        'cards': ['Card 1'],
      };

      final deck = Deck.fromMap(map);

      expect(deck.isPremium, isFalse);
      expect(deck.isCustom, isFalse);
      expect(deck.updatedAt, isNull);
    });

    test('should copy deck with updated properties', () {
      final original = TestData.sampleDeck;
      final copied = original.copyWith(
        name: 'Updated Name',
        color: Colors.green,
        isPremium: true,
        cards: ['New Card 1', 'New Card 2'],
      );

      expect(copied.id, equals(original.id));
      expect(copied.name, equals('Updated Name'));
      expect(copied.description, equals(original.description));
      expect(copied.icon, equals(original.icon));
      expect(copied.color, equals(Colors.green));
      expect(copied.isPremium, isTrue);
      expect(copied.isCustom, equals(original.isCustom));
      expect(copied.cards, equals(['New Card 1', 'New Card 2']));
      expect(copied.createdAt, equals(original.createdAt));
    });

    test('should return shuffled cards', () {
      final deck = Deck(
        name: 'Shuffle Test',
        description: 'Test shuffling',
        icon: FontAwesomeIcons.shuffle,
        color: Colors.orange,
        cards: List.generate(20, (i) => 'Card ${i + 1}'),
      );

      final shuffled1 = deck.getShuffledCards();
      final shuffled2 = deck.getShuffledCards();

      // Check that shuffled lists have same elements
      expect(shuffled1.length, equals(deck.cards.length));
      expect(shuffled1.toSet(), equals(deck.cards.toSet()));

      // Check that shuffling produces different orders (with high probability)
      // Note: There's a small chance this could fail if shuffle produces same order
      expect(shuffled1, isNot(equals(shuffled2)));

      // Original deck cards should remain unchanged
      expect(deck.cards, equals(List.generate(20, (i) => 'Card ${i + 1}')));
    });

    test('should check if deck has enough cards', () {
      final deckWithEnoughCards = TestData.sampleDeck;
      final deckWithFewCards = Deck(
        name: 'Few Cards',
        description: 'Not enough cards',
        icon: FontAwesomeIcons.exclamation,
        color: Colors.red,
        cards: ['Card 1', 'Card 2', 'Card 3'],
      );
      final emptyDeck = TestData.emptyDeck;

      expect(deckWithEnoughCards.hasEnoughCards, isTrue);
      expect(deckWithFewCards.hasEnoughCards, isFalse);
      expect(emptyDeck.hasEnoughCards, isFalse);
    });

    test('should implement equality based on ID', () {
      final deck1 = Deck(
        id: 'same-id',
        name: 'Deck 1',
        description: 'First deck',
        icon: FontAwesomeIcons.star,
        color: Colors.blue,
        cards: ['Card 1'],
      );

      final deck2 = Deck(
        id: 'same-id',
        name: 'Deck 2',
        description: 'Second deck',
        icon: FontAwesomeIcons.heart,
        color: Colors.red,
        cards: ['Card 2'],
      );

      final deck3 = Deck(
        id: 'different-id',
        name: 'Deck 1',
        description: 'First deck',
        icon: FontAwesomeIcons.star,
        color: Colors.blue,
        cards: ['Card 1'],
      );

      expect(deck1, equals(deck2)); // Same ID
      expect(deck1, isNot(equals(deck3))); // Different ID
      expect(deck1.hashCode, equals(deck2.hashCode));
      expect(deck1.hashCode, isNot(equals(deck3.hashCode)));
    });

    test('should provide meaningful toString representation', () {
      final deck = TestData.sampleDeck;
      final stringRep = deck.toString();

      expect(stringRep, contains('Deck'));
      expect(stringRep, contains('test-deck-1'));
      expect(stringRep, contains('Test Deck'));
      expect(stringRep, contains('10')); // Number of cards
    });

    test('should handle premium deck correctly', () {
      final premiumDeck = TestData.premiumDeck;

      expect(premiumDeck.isPremium, isTrue);
      expect(premiumDeck.isCustom, isFalse);
      expect(premiumDeck.name, equals('Premium Deck'));
      expect(premiumDeck.color, equals(Colors.purple));
    });

    test('should handle custom deck correctly', () {
      final customDeck = TestData.customDeck;

      expect(customDeck.isCustom, isTrue);
      expect(customDeck.isPremium, isFalse);
      expect(customDeck.name, equals('Custom Deck'));
      expect(customDeck.color, equals(Colors.green));
    });

    test('should handle empty deck correctly', () {
      final emptyDeck = TestData.emptyDeck;

      expect(emptyDeck.cards, isEmpty);
      expect(emptyDeck.hasEnoughCards, isFalse);
      expect(emptyDeck.getShuffledCards(), isEmpty);
    });
  });
}

