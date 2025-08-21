import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:heads_up_game/models/deck.dart';
import 'package:heads_up_game/models/game_session.dart';

class TestData {
  // Sample Deck data
  static Deck get sampleDeck => Deck(
    id: 'test-deck-1',
    name: 'Test Deck',
    description: 'A test deck for unit testing',
    icon: FontAwesomeIcons.star,
    color: Colors.blue,
    isPremium: false,
    isCustom: false,
    cards: [
      'Card 1',
      'Card 2',
      'Card 3',
      'Card 4',
      'Card 5',
      'Card 6',
      'Card 7',
      'Card 8',
      'Card 9',
      'Card 10',
    ],
    createdAt: DateTime(2024, 1, 1),
  );

  static Deck get premiumDeck => Deck(
    id: 'premium-deck-1',
    name: 'Premium Deck',
    description: 'A premium test deck',
    icon: FontAwesomeIcons.crown,
    color: Colors.purple,
    isPremium: true,
    isCustom: false,
    cards: ['Premium 1', 'Premium 2', 'Premium 3', 'Premium 4', 'Premium 5'],
    createdAt: DateTime(2024, 1, 1),
  );

  static Deck get customDeck => Deck(
    id: 'custom-deck-1',
    name: 'Custom Deck',
    description: 'A custom test deck',
    icon: FontAwesomeIcons.userPen,
    color: Colors.green,
    isPremium: false,
    isCustom: true,
    cards: ['Custom 1', 'Custom 2', 'Custom 3'],
    createdAt: DateTime(2024, 1, 1),
  );

  static Deck get emptyDeck => Deck(
    id: 'empty-deck-1',
    name: 'Empty Deck',
    description: 'An empty test deck',
    icon: FontAwesomeIcons.box,
    color: Colors.grey,
    isPremium: false,
    isCustom: false,
    cards: [],
    createdAt: DateTime(2024, 1, 1),
  );

  // Sample GameSession data
  static GameSession get sampleGameSession => GameSession(
    id: 'session-1',
    deck: sampleDeck,
    startTime: DateTime(2024, 1, 1, 10, 0),
    roundDuration: const Duration(seconds: 60),
    cards: sampleDeck.cards,
    isTeamMode: false,
    totalRounds: 1,
  );

  static GameSession get teamGameSession => GameSession(
    id: 'session-team-1',
    deck: sampleDeck,
    startTime: DateTime(2024, 1, 1, 10, 0),
    roundDuration: const Duration(seconds: 60),
    cards: sampleDeck.cards,
    isTeamMode: true,
    teams: [
      Team(id: 'team-1', name: 'Team Alpha'),
      Team(id: 'team-2', name: 'Team Beta'),
    ],
    totalRounds: 2,
  );

  static GameSession get completedGameSession {
    var session = sampleGameSession;
    session = session.addResult(GameResult.correct);
    session = session.addResult(GameResult.pass);
    session = session.addResult(GameResult.correct);
    session = session.addResult(GameResult.correct);
    session = session.end();
    return session;
  }

  // Sample statistics
  static Map<String, dynamic> get sampleStatistics => {
    'totalGames': 10,
    'totalCorrect': 45,
    'totalPass': 15,
    'highScore': 12,
    'averageScore': 4.5,
    'totalPlayTime': 600, // seconds
    'favoriteCategory': 'Animals',
    'winStreak': 3,
  };

  // Sample game settings
  static Map<String, dynamic> get sampleSettings => {
    'roundDuration': 60,
    'soundEnabled': true,
    'vibrationEnabled': true,
    'kidFriendlyMode': false,
    'showWordsAfterPass': true,
  };

  // Sample leaderboard data
  static List<Map<String, dynamic>> get sampleLeaderboard => [
    {
      'userId': 'user-1',
      'username': 'Player1',
      'score': 100,
      'gamesPlayed': 20,
      'rank': 1,
    },
    {
      'userId': 'user-2',
      'username': 'Player2',
      'score': 85,
      'gamesPlayed': 15,
      'rank': 2,
    },
    {
      'userId': 'user-3',
      'username': 'Player3',
      'score': 70,
      'gamesPlayed': 10,
      'rank': 3,
    },
  ];

  // Sample card results
  static List<CardResult> get sampleCardResults => [
    CardResult(
      word: 'Card 1',
      result: GameResult.correct,
      timeSpent: const Duration(seconds: 3),
    ),
    CardResult(
      word: 'Card 2',
      result: GameResult.pass,
      timeSpent: const Duration(seconds: 2),
    ),
    CardResult(
      word: 'Card 3',
      result: GameResult.correct,
      timeSpent: const Duration(seconds: 4),
    ),
  ];

  // Firebase document data
  static Map<String, dynamic> get deckFirebaseData => {
    'id': 'test-deck-1',
    'name': 'Test Deck',
    'description': 'A test deck for unit testing',
    'icon': FontAwesomeIcons.star.codePoint,
    'color': '0xFF2196F3',
    'isPremium': false,
    'isCustom': false,
    'cards': ['Card 1', 'Card 2', 'Card 3'],
    'createdAt': '2024-01-01T00:00:00.000',
    'updatedAt': null,
  };
}

