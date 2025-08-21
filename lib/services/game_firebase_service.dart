import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../models/deck.dart';
import 'firebase_service.dart';

class GameFirebaseService {
  final FirebaseService _firebaseService = FirebaseService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  String? get _userId => _firebaseService.currentUser?.uid;

  // Collection references
  CollectionReference get _gameSessionsRef => _firestore
      .collection('users')
      .doc(_userId ?? 'anonymous')
      .collection('gameSessions');
  DocumentReference get _userRef =>
      _firestore.collection('users').doc(_userId ?? 'anonymous');
  CollectionReference get _globalLeaderboardRef =>
      _firestore.collection('globalLeaderboard');

  // Save game session
  Future<String?> saveGameSession(GameSession session) async {
    if (_userId == null) return null;

    try {
      final sessionData = _sessionToFirestore(session);
      final docRef = await _gameSessionsRef.add(sessionData);

      // Update user statistics
      await _updateUserStatistics(session);

      // Update global leaderboard if high score
      await _updateGlobalLeaderboard(session);

      await _firebaseService.logEvent(
        'game_completed',
        parameters: {
          'deck_id': session.deck.id,
          'deck_name': session.deck.name,
          'correct_count': session.correctCount,
          'pass_count': session.passCount,
          'score': session.totalScore,
          'duration': session.elapsedTime.inSeconds,
        },
      );

      return docRef.id;
    } catch (e) {
      debugPrint('Error saving game session: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to save game session',
      );
      return null;
    }
  }

  // Get game history
  Future<List<GameSession>> getGameHistory({int limit = 50}) async {
    if (_userId == null) return [];

    try {
      final QuerySnapshot snapshot =
          await _gameSessionsRef
              .orderBy('endTime', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _sessionFromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting game history: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get game history',
      );
      return [];
    }
  }

  // Stream of recent game sessions
  Stream<List<GameSession>> streamRecentGames({int limit = 10}) {
    if (_userId == null) return Stream.value([]);

    return _gameSessionsRef
        .orderBy('endTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _sessionFromFirestore(data, doc.id);
          }).toList();
        });
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStatistics() async {
    if (_userId == null) return _getDefaultStatistics();

    try {
      final doc = await _userRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['statistics'] ?? _getDefaultStatistics();
      }
      return _getDefaultStatistics();
    } catch (e) {
      debugPrint('Error getting user statistics: $e');
      return _getDefaultStatistics();
    }
  }

  // Update user statistics
  Future<void> _updateUserStatistics(GameSession session) async {
    if (_userId == null) return;

    try {
      final currentStats = await getUserStatistics();

      final newStats = {
        'totalGames': (currentStats['totalGames'] ?? 0) + 1,
        'totalCorrect':
            (currentStats['totalCorrect'] ?? 0) + session.correctCount,
        'totalPassed': (currentStats['totalPassed'] ?? 0) + session.passCount,
        'highScore':
            (session.correctCount > (currentStats['highScore'] ?? 0))
                ? session.correctCount
                : currentStats['highScore'],
        'totalPlayTime':
            (currentStats['totalPlayTime'] ?? 0) +
            session.elapsedTime.inSeconds,
        'lastPlayed': FieldValue.serverTimestamp(),
      };

      await _userRef.update({'statistics': newStats});
    } catch (e) {
      debugPrint('Error updating user statistics: $e');
    }
  }

  // Get global leaderboard
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({
    int limit = 100,
  }) async {
    try {
      final QuerySnapshot snapshot =
          await _globalLeaderboardRef
              .orderBy('score', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'rank': 0, // Will be calculated on client side
          'userId': doc.id,
          'displayName': data['displayName'] ?? 'Anonymous',
          'score': data['score'] ?? 0,
          'deckName': data['deckName'] ?? '',
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting global leaderboard: $e');
      return [];
    }
  }

  // Update global leaderboard
  Future<void> _updateGlobalLeaderboard(GameSession session) async {
    if (_userId == null) return;

    try {
      // Check if this is a high score for this user
      final userLeaderboardDoc = await _globalLeaderboardRef.doc(_userId).get();

      if (!userLeaderboardDoc.exists ||
          (userLeaderboardDoc.data() as Map<String, dynamic>)['score'] <
              session.correctCount) {
        // Update or create leaderboard entry
        await _globalLeaderboardRef.doc(_userId).set({
          'displayName':
              _firebaseService.currentUser?.displayName ?? 'Anonymous',
          'score': session.correctCount,
          'deckName': session.deck.name,
          'deckId': session.deck.id,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating global leaderboard: $e');
    }
  }

  // Get deck-specific leaderboard
  Future<List<Map<String, dynamic>>> getDeckLeaderboard(
    String deckId, {
    int limit = 50,
  }) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('deckLeaderboards')
              .doc(deckId)
              .collection('scores')
              .orderBy('score', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'userId': doc.id,
          'displayName': data['displayName'] ?? 'Anonymous',
          'score': data['score'] ?? 0,
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting deck leaderboard: $e');
      return [];
    }
  }

  // Save game settings
  Future<void> saveGameSettings(Map<String, dynamic> settings) async {
    if (_userId == null) return;

    try {
      await _userRef.update({'gameSettings': settings});

      await _firebaseService.logEvent('settings_updated', parameters: settings);
    } catch (e) {
      debugPrint('Error saving game settings: $e');
    }
  }

  // Get game settings
  Future<Map<String, dynamic>> getGameSettings() async {
    if (_userId == null) return _getDefaultSettings();

    try {
      final doc = await _userRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['gameSettings'] ?? _getDefaultSettings();
      }
      return _getDefaultSettings();
    } catch (e) {
      debugPrint('Error getting game settings: $e');
      return _getDefaultSettings();
    }
  }

  // Default statistics
  Map<String, dynamic> _getDefaultStatistics() {
    return {
      'totalGames': 0,
      'totalCorrect': 0,
      'totalPassed': 0,
      'highScore': 0,
      'totalPlayTime': 0,
      'averageScore': 0.0,
    };
  }

  // Default settings
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'roundDuration': 60,
      'soundEnabled': true,
      'vibrationEnabled': true,
      'kidFriendlyMode': false,
      'showWordsAfterPass': true,
    };
  }

  // Convert GameSession to Firestore data
  Map<String, dynamic> _sessionToFirestore(GameSession session) {
    return {
      'deckId': session.deck.id,
      'deckName': session.deck.name,
      'cards': session.cards,
      'results':
          session.results.map((r) => r.toString().split('.').last).toList(),
      'startTime': session.startTime,
      'endTime': session.endTime,
      'duration': session.elapsedTime.inSeconds,
      'isPaused': session.isPaused,
      'pausedDuration': 0, // TODO: Track paused duration if needed
      'correctCount': session.correctCount,
      'passCount': session.passCount,
      'score': session.totalScore,
      'isTeamMode': session.isTeamMode,
      'currentRound': session.roundNumber,
      'totalRounds': session.totalRounds,
      'teams':
          session.teams
              ?.map(
                (team) => {
                  'id': team.id,
                  'name': team.name,
                  'score': team.score,
                },
              )
              .toList(),
    };
  }

  // Convert Firestore data to GameSession
  GameSession _sessionFromFirestore(Map<String, dynamic> data, String docId) {
    // Note: This is a simplified conversion. In a real app, you'd need to
    // fetch the actual Deck object from Firestore or pass it in
    final deck = Deck(
      id: data['deckId'] ?? '',
      name: data['deckName'] ?? '',
      description: '',
      icon: Icons.category,
      color: Colors.blue,
      cards: List<String>.from(data['cards'] ?? []),
    );

    // Convert results to CardResult objects
    final results =
        (data['results'] as List<dynamic>?)?.map((r) {
          final resultType = GameResult.values.firstWhere(
            (e) => e.toString().split('.').last == r,
            orElse: () => GameResult.pass,
          );
          return CardResult(
            word: '', // Word is not stored separately
            result: resultType,
            timeSpent: Duration.zero, // Time spent is not stored
          );
        }).toList() ??
        [];

    List<Team>? teams;
    if (data['teams'] != null) {
      teams =
          (data['teams'] as List<dynamic>).map((teamData) {
            return Team(
              id:
                  teamData['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              name: teamData['name'] ?? '',
              score: teamData['score'] ?? 0,
            );
          }).toList();
    }

    return GameSession(
      id: docId,
      deck: deck,
      cards: List<String>.from(data['cards'] ?? []),
      results: results,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      roundDuration: Duration(seconds: 60), // Default, should be stored in data
      currentCardIndex: results.length,
      isPaused: data['isPaused'] ?? false,
      isTeamMode: data['isTeamMode'] ?? false,
      teams: teams,
      currentTeamIndex: 0,
      roundNumber: data['currentRound'] ?? 1,
      totalRounds: data['totalRounds'] ?? 1,
    );
  }
}
