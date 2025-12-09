import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/deck.dart';
import '../models/game_session.dart';
import 'deep_link_service.dart';
import 'firebase_service.dart';

/// Unified sharing service for the app
/// Handles sharing decks, game results, and app invites with deep links
class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  final _deepLinkService = DeepLinkService();

  // ============================================
  // DECK SHARING
  // ============================================

  /// Share a deck with a deep link
  Future<void> shareDeck(Deck deck, BuildContext context) async {
    try {
      // Generate deep link (synchronous with native app links)
      final link = _deepLinkService.createDeckLink(
        deckId: deck.id.isNotEmpty ? deck.id : deck.name.hashCode.toString(),
        deckName: deck.name,
        description: deck.description,
        imageUrl: deck.imageUrl,
      );

      // Share text with link
      final shareText = _buildDeckShareText(deck, link);

      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        shareText,
        subject: 'Check out "${deck.name}" on Heads Up!',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );

      // Track share event
      await FirebaseService().logEvent(
        'deck_shared',
        parameters: {
          'deck_id': deck.id,
          'deck_name': deck.name,
          'card_count': deck.cards.length,
        },
      );
    } catch (e) {
      debugPrint('Error sharing deck: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to share deck');
      }
    }
  }

  /// Build share text for a deck
  String _buildDeckShareText(Deck deck, String link) {
    final buffer = StringBuffer();
    buffer.writeln('🎮 Check out this Heads Up deck!');
    buffer.writeln();
    buffer.writeln('📦 ${deck.name}');
    if (deck.description.isNotEmpty) {
      buffer.writeln('📝 ${deck.description}');
    }
    buffer.writeln('🃏 ${deck.cards.length} cards to play');
    buffer.writeln();
    buffer.writeln('Play it now:');
    buffer.writeln(link);
    return buffer.toString();
  }

  // ============================================
  // GAME RESULTS SHARING
  // ============================================

  /// Share game results with a deep link
  Future<void> shareGameResults(
    GameSession session,
    BuildContext context, {
    String? deckName,
  }) async {
    try {
      final name = deckName ?? session.deck.name;
      final score = session.correctCount;
      final correct = session.correctCount;
      final passed = session.passCount;

      // Generate deep link (synchronous with native app links)
      final link = _deepLinkService.createResultsLink(
        deckName: name,
        score: score,
        correct: correct,
        passed: passed,
      );

      // Share text with link
      final shareText = _buildResultsShareText(
        deckName: name,
        score: score,
        correct: correct,
        passed: passed,
        link: link,
      );

      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        shareText,
        subject: 'I scored $score points in Heads Up!',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );

      // Track share event
      await FirebaseService().logEvent(
        'results_shared',
        parameters: {
          'deck_name': name,
          'score': score,
          'correct': correct,
          'passed': passed,
        },
      );
    } catch (e) {
      debugPrint('Error sharing results: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to share results');
      }
    }
  }

  /// Share results without a deep link (simple text share)
  Future<void> shareResultsSimple(
    GameSession session,
    BuildContext context, {
    String? deckName,
  }) async {
    try {
      final name = deckName ?? session.deck.name;
      final score = session.correctCount;
      final correct = session.correctCount;
      final passed = session.passCount;
      final totalCards = session.results.length;
      final accuracy = totalCards > 0
          ? ((correct / totalCards) * 100).toStringAsFixed(0)
          : '0';

      final shareText = '''
🎮 Heads Up! Results

📦 Deck: $name
🏆 Score: $score points
✅ Correct: $correct
⏭️ Passed: $passed
🎯 Accuracy: $accuracy%

Can you beat my score? Download Heads Up now!
''';

      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        shareText,
        subject: 'I scored $score points in Heads Up!',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Error sharing results: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to share results');
      }
    }
  }

  /// Build share text for results
  String _buildResultsShareText({
    required String deckName,
    required int score,
    required int correct,
    required int passed,
    required String link,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🎮 I just played Heads Up!');
    buffer.writeln();
    buffer.writeln('📦 Deck: $deckName');
    buffer.writeln('🏆 Score: $score points');
    buffer.writeln('✅ Correct: $correct');
    buffer.writeln('⏭️ Passed: $passed');
    buffer.writeln();
    buffer.writeln('Can you beat my score? 🔥');
    buffer.writeln(link);
    return buffer.toString();
  }

  // ============================================
  // APP INVITE
  // ============================================

  /// Share an app invite with deep link
  Future<void> shareAppInvite(BuildContext context) async {
    try {
      // Generate deep link (synchronous with native app links)
      final link = _deepLinkService.createInviteLink();

      // Share text with link
      final shareText = _buildInviteShareText(link);

      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        shareText,
        subject: 'Join me on Heads Up!',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );

      // Track share event
      await FirebaseService().logEvent('app_invite_shared');
    } catch (e) {
      debugPrint('Error sharing invite: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to create invite link');
      }
    }
  }

  /// Build share text for app invite
  String _buildInviteShareText(String link) {
    return '''
🎉 Join me on Heads Up!

The ultimate party game! Hold your phone to your forehead and guess the word from your friends' clues.

✨ Dozens of fun categories
🎨 Create your own decks
🏆 Challenge your friends

Download now and let's play!
$link
''';
  }

  // ============================================
  // HELPERS
  // ============================================

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

