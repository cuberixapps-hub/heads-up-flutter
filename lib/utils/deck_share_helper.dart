import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/deck.dart';

class DeckShareHelper {
  // Encode deck to shareable string
  static String encodeDeck(Deck deck) {
    final deckData = {
      'name': deck.name,
      'description': deck.description,
      'cards': deck.cards,
      'colorValue': deck.color.value,
      'iconCodePoint': deck.icon.codePoint,
      'iconFontFamily': deck.icon.fontFamily ?? 'MaterialIcons',
      'version': '1.0',
    };

    final jsonString = jsonEncode(deckData);
    final bytes = utf8.encode(jsonString);
    final base64String = base64.encode(bytes);

    // Add prefix for easy identification
    return 'HEADSUP_DECK:$base64String';
  }

  // Decode shareable string to deck data
  static Map<String, dynamic>? decodeDeck(String encodedString) {
    try {
      // Check and remove prefix
      if (!encodedString.startsWith('HEADSUP_DECK:')) {
        return null;
      }

      final base64String = encodedString.substring('HEADSUP_DECK:'.length);
      final bytes = base64.decode(base64String);
      final jsonString = utf8.decode(bytes);
      final deckData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate required fields
      if (deckData['name'] == null ||
          deckData['cards'] == null ||
          deckData['cards'].isEmpty) {
        return null;
      }

      return deckData;
    } catch (e) {
      debugPrint('Error decoding deck: $e');
      return null;
    }
  }

  // Create Deck object from decoded data
  static Deck? createDeckFromData(Map<String, dynamic> data) {
    try {
      final icon = IconData(
        data['iconCodePoint'] ?? FontAwesomeIcons.solidStar.codePoint,
        fontFamily: data['iconFontFamily'] ?? 'MaterialIcons',
      );

      final color = Color(data['colorValue'] ?? Colors.purple.value);

      return Deck(
        name: data['name'],
        description: data['description'] ?? '',
        icon: icon,
        color: color,
        isCustom: true,
        cards: List<String>.from(data['cards']),
      );
    } catch (e) {
      debugPrint('Error creating deck from data: $e');
      return null;
    }
  }

  // Copy deck code to clipboard
  static Future<void> copyDeckToClipboard(Deck deck) async {
    final encodedDeck = encodeDeck(deck);
    await Clipboard.setData(ClipboardData(text: encodedDeck));
  }

  // Get deck code from clipboard
  static Future<String?> getDeckFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    return clipboardData?.text;
  }

  // Generate shareable link (placeholder for future implementation)
  static String generateShareLink(String deckCode) {
    // In a real app, this would generate a deep link or upload to a server
    // For now, just return the deck code
    return deckCode;
  }

  // Parse share link (placeholder for future implementation)
  static String? parseShareLink(String link) {
    // In a real app, this would parse a deep link or fetch from server
    // For now, just return the link if it's a valid deck code
    if (link.startsWith('HEADSUP_DECK:')) {
      return link;
    }
    return null;
  }
}
