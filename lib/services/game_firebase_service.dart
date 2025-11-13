import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../models/deck.dart';
import '../models/leaderboard_page.dart';
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

  // Save game session with batched writes
  Future<String?> saveGameSession(GameSession session) async {
    if (_userId == null) return null;

    try {
      // Use batched writes for atomic operation
      final batch = _firestore.batch();
      
      // 1. Add game session
      final sessionData = _sessionToFirestore(session);
      final sessionDocRef = _gameSessionsRef.doc();
      batch.set(sessionDocRef, sessionData);
      
      // 2. Update user statistics
      await _prepareBatchedUserStatisticsUpdate(batch, session);
      
      // 3. Update global leaderboard if needed
      await _prepareBatchedLeaderboardUpdate(batch, session);
      
      // 4. Update deck-specific leaderboard
      await _prepareBatchedDeckLeaderboardUpdate(batch, session);
      
      // Commit all writes atomically
      await batch.commit();
      
      // Log analytics event after successful save
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
      
      await _firebaseService.logEvent('batch_write_success', parameters: {
        'batch_type': 'game_session',
        'operations_count': 4,
      });

      return sessionDocRef.id;
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

  // Get game history with pagination
  Future<LeaderboardPage> getGameHistoryPage({
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
  }) async {
    if (_userId == null) {
      return LeaderboardPage(entries: [], hasMore: false);
    }

    try {
      Query query = _gameSessionsRef
          .orderBy('endTime', descending: true)
          .limit(pageSize);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final QuerySnapshot snapshot = await query.get();
      
      return LeaderboardPage(
        entries: snapshot.docs,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      debugPrint('Error getting game history page: $e');
      return LeaderboardPage(entries: [], hasMore: false);
    }
  }
  
  // Get game history (legacy, uses pagination internally)
  Future<List<GameSession>> getGameHistory({int limit = 50}) async {
    if (_userId == null) return [];

    try {
      final allSessions = <GameSession>[];
      DocumentSnapshot? lastDoc;
      
      while (allSessions.length < limit) {
        final page = await getGameHistoryPage(
          lastDocument: lastDoc,
          pageSize: 20,
        );
        
        for (final doc in page.entries) {
          final data = doc.data() as Map<String, dynamic>;
          allSessions.add(_sessionFromFirestore(data, doc.id));
        }
        
        if (!page.hasMore || allSessions.length >= limit) {
          break;
        }
        
        lastDoc = page.lastDocument;
      }
      
      return allSessions.take(limit).toList();
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

  // Prepare user statistics update for batch
  Future<void> _prepareBatchedUserStatisticsUpdate(
    WriteBatch batch,
    GameSession session,
  ) async {
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

      batch.update(_userRef, {'statistics': newStats});
    } catch (e) {
      debugPrint('Error preparing user statistics update: $e');
    }
  }

  // Get global leaderboard with cursor-based pagination
  Future<LeaderboardPage> getGlobalLeaderboardPage({
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
  }) async {
    try {
      Query query = _globalLeaderboardRef
          .orderBy('score', descending: true)
          .limit(pageSize);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final QuerySnapshot snapshot = await query.get();
      
      // Log pagination event
      await _firebaseService.logEvent('pagination_page_loaded', parameters: {
        'type': 'global_leaderboard',
        'page_size': pageSize,
        'results_count': snapshot.docs.length,
      });
      
      return LeaderboardPage(
        entries: snapshot.docs,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      debugPrint('Error getting global leaderboard page: $e');
      return LeaderboardPage(
        entries: [],
        hasMore: false,
      );
    }
  }
  
  // Get global leaderboard (legacy, uses pagination internally)
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({
    int limit = 100,
  }) async {
    try {
      final allEntries = <Map<String, dynamic>>[];
      DocumentSnapshot? lastDoc;
      
      while (allEntries.length < limit) {
        final page = await getGlobalLeaderboardPage(
          lastDocument: lastDoc,
          pageSize: 20,
        );
        
        for (final doc in page.entries) {
          final data = doc.data() as Map<String, dynamic>;
          allEntries.add({
            'rank': 0, // Will be calculated on client side
            'userId': doc.id,
            'displayName': data['displayName'] ?? 'Anonymous',
            'score': data['score'] ?? 0,
            'deckName': data['deckName'] ?? '',
            'timestamp':
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          });
        }
        
        if (!page.hasMore || allEntries.length >= limit) {
          break;
        }
        
        lastDoc = page.lastDocument;
      }
      
      return allEntries.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting global leaderboard: $e');
      return [];
    }
  }

  // Prepare global leaderboard update for batch
  Future<void> _prepareBatchedLeaderboardUpdate(
    WriteBatch batch,
    GameSession session,
  ) async {
    if (_userId == null) return;

    try {
      // Check if this is a high score for this user
      final userLeaderboardDoc = await _globalLeaderboardRef.doc(_userId).get();

      if (!userLeaderboardDoc.exists ||
          (userLeaderboardDoc.data() as Map<String, dynamic>)['score'] <
              session.correctCount) {
        // Update or create leaderboard entry
        batch.set(_globalLeaderboardRef.doc(_userId), {
          'displayName':
              _firebaseService.currentUser?.displayName ?? 'Anonymous',
          'score': session.correctCount,
          'deckName': session.deck.name,
          'deckId': session.deck.id,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error preparing global leaderboard update: $e');
    }
  }
  
  // Prepare deck-specific leaderboard update for batch
  Future<void> _prepareBatchedDeckLeaderboardUpdate(
    WriteBatch batch,
    GameSession session,
  ) async {
    if (_userId == null) return;

    try {
      final deckLeaderboardRef = _firestore
          .collection('deckLeaderboards')
          .doc(session.deck.id)
          .collection('scores')
          .doc(_userId);
      
      final deckLeaderboardDoc = await deckLeaderboardRef.get();
      
      if (!deckLeaderboardDoc.exists ||
          (deckLeaderboardDoc.data()?['score'] ?? 0) <
              session.correctCount) {
        batch.set(deckLeaderboardRef, {
          'displayName':
              _firebaseService.currentUser?.displayName ?? 'Anonymous',
          'score': session.correctCount,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error preparing deck leaderboard update: $e');
    }
  }

  // Get deck-specific leaderboard with cursor-based pagination
  Future<LeaderboardPage> getDeckLeaderboardPage(
    String deckId, {
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
  }) async {
    try {
      Query query = _firestore
          .collection('deckLeaderboards')
          .doc(deckId)
          .collection('scores')
          .orderBy('score', descending: true)
          .limit(pageSize);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final QuerySnapshot snapshot = await query.get();
      
      // Log pagination event
      await _firebaseService.logEvent('pagination_page_loaded', parameters: {
        'type': 'deck_leaderboard',
        'deck_id': deckId,
        'page_size': pageSize,
        'results_count': snapshot.docs.length,
      });
      
      return LeaderboardPage(
        entries: snapshot.docs,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      debugPrint('Error getting deck leaderboard page: $e');
      return LeaderboardPage(
        entries: [],
        hasMore: false,
      );
    }
  }
  
  // Get deck-specific leaderboard (legacy, uses pagination internally)
  Future<List<Map<String, dynamic>>> getDeckLeaderboard(
    String deckId, {
    int limit = 50,
  }) async {
    try {
      final allEntries = <Map<String, dynamic>>[];
      DocumentSnapshot? lastDoc;
      
      while (allEntries.length < limit) {
        final page = await getDeckLeaderboardPage(
          deckId,
          lastDocument: lastDoc,
          pageSize: 20,
        );
        
        for (final doc in page.entries) {
          final data = doc.data() as Map<String, dynamic>;
          allEntries.add({
            'userId': doc.id,
            'displayName': data['displayName'] ?? 'Anonymous',
            'score': data['score'] ?? 0,
            'timestamp':
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          });
        }
        
        if (!page.hasMore || allEntries.length >= limit) {
          break;
        }
        
        lastDoc = page.lastDocument;
      }
      
      return allEntries.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting deck leaderboard: $e');
      return [];
    }
  }

  // Save game settings with batching support
  Future<void> saveGameSettings(
    Map<String, dynamic> settings, {
    WriteBatch? existingBatch,
  }) async {
    if (_userId == null) return;

    try {
      if (existingBatch != null) {
        // Add to existing batch
        existingBatch.update(_userRef, {'gameSettings': settings});
      } else {
        // Direct update
        await _userRef.update({'gameSettings': settings});
      }

      // Log the event (Firebase service will handle type conversion)
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

  // Clear all user data
  Future<void> clearUserData() async {
    if (_userId == null) return;

    try {
      // Delete all game sessions
      final sessionsQuery =
          await _firestore
              .collection('gameSessions')
              .where('userId', isEqualTo: _userId)
              .get();

      for (var doc in sessionsQuery.docs) {
        await doc.reference.delete();
      }

      // Reset user statistics
      await _firestore.collection('userStatistics').doc(_userId).set({
        'totalGames': 0,
        'totalCorrect': 0,
        'totalPassed': 0,
        'highScore': 0,
        'favoriteDecks': [],
        'achievements': [],
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Clear user settings (reset to defaults)
      await _firestore.collection('userSettings').doc(_userId).set({
        'roundDuration': 60,
        'soundEnabled': true,
        'vibrationEnabled': true,
        'kidFriendlyMode': false,
        'showWordsAfterPass': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('User data cleared successfully');
    } catch (e) {
      print('Error clearing user data: $e');
      rethrow;
    }
  }
}
