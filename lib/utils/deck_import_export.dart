import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/deck.dart';

class DeckImportExport {
  // Export deck to JSON string
  static String exportDeckToJson(Deck deck) {
    final Map<String, dynamic> deckData = {
      'name': deck.name,
      'description': deck.description,
      'iconCodePoint': deck.icon.codePoint,
      'iconFontFamily': deck.icon.fontFamily ?? 'MaterialIcons',
      'colorValue': deck.color.value,
      'cards': deck.cards,
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0', // Version for future compatibility
    };

    return const JsonEncoder.withIndent('  ').convert(deckData);
  }

  // Import deck from JSON string
  static Deck? importDeckFromJson(String jsonString) {
    try {
      final Map<String, dynamic> deckData = json.decode(jsonString);

      // Validate required fields
      if (!deckData.containsKey('name') ||
          !deckData.containsKey('cards') ||
          (deckData['cards'] as List).isEmpty) {
        return null;
      }

      return Deck(
        name: deckData['name'] as String,
        description: deckData['description'] as String? ?? '',
        icon: IconData(
          deckData['iconCodePoint'] as int? ??
              FontAwesomeIcons.solidStar.codePoint,
          fontFamily: deckData['iconFontFamily'] as String? ?? 'MaterialIcons',
        ),
        color: Color(deckData['colorValue'] as int? ?? Colors.purple.value),
        isCustom: true,
        cards: List<String>.from(deckData['cards'] as List),
      );
    } catch (e) {
      debugPrint('Error importing deck: $e');
      return null;
    }
  }

  // Export deck to file
  static Future<File?> exportDeckToFile(Deck deck) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = '${deck.name.replaceAll(' ', '_')}_deck.json';
      final file = File('${directory.path}/$fileName');

      final jsonString = exportDeckToJson(deck);
      await file.writeAsString(jsonString);

      return file;
    } catch (e) {
      debugPrint('Error exporting deck to file: $e');
      return null;
    }
  }

  // Share deck
  static Future<void> shareDeck(Deck deck, BuildContext context) async {
    try {
      final file = await exportDeckToFile(deck);
      if (file != null) {
        final box = context.findRenderObject() as RenderBox?;

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Heads Up Deck: ${deck.name}',
          text:
              'Check out my custom Heads Up deck "${deck.name}"!\n\n${deck.description}\n\nContains ${deck.cards.length} cards.',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      debugPrint('Error sharing deck: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share deck: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Copy deck to clipboard
  static Future<void> copyDeckToClipboard(
    Deck deck,
    BuildContext context,
  ) async {
    try {
      final jsonString = exportDeckToJson(deck);
      await Clipboard.setData(ClipboardData(text: jsonString));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Deck copied to clipboard!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error copying deck to clipboard: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy deck: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Import deck from clipboard
  static Future<Deck?> importDeckFromClipboard(BuildContext context) async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData == null || clipboardData.text == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No deck data found in clipboard'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      final deck = importDeckFromJson(clipboardData.text!);
      if (deck == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid deck data in clipboard'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return deck;
    } catch (e) {
      debugPrint('Error importing deck from clipboard: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import deck: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // Generate shareable link (for future implementation with deep linking)
  static String generateShareableLink(String deckId) {
    // This would be implemented with Firebase Dynamic Links or similar
    return 'https://headsup.app/deck/$deckId';
  }

  // Format deck for display
  static String formatDeckForDisplay(Deck deck) {
    final buffer = StringBuffer();
    buffer.writeln('🎯 ${deck.name}');
    buffer.writeln('📝 ${deck.description}');
    buffer.writeln('🃏 ${deck.cards.length} cards');
    buffer.writeln('\nCards:');
    for (int i = 0; i < deck.cards.length; i++) {
      buffer.writeln('${i + 1}. ${deck.cards[i]}');
    }
    return buffer.toString();
  }
}
