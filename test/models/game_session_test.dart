import 'package:flutter_test/flutter_test.dart';
import 'package:heads_up_game/models/game_session.dart';
import '../test_helpers/test_data.dart';

void main() {
  group('GameSession Model Tests', () {
    test('should create a GameSession with all properties', () {
      final session = TestData.sampleGameSession;

      expect(session.id, equals('session-1'));
      expect(session.deck, equals(TestData.sampleDeck));
      expect(session.startTime, equals(DateTime(2024, 1, 1, 10, 0)));
      expect(session.endTime, isNull);
      expect(session.roundDuration, equals(const Duration(seconds: 60)));
      expect(session.cards.length, equals(10));
      expect(session.results, isEmpty);
      expect(session.isTeamMode, isFalse);
      expect(session.teams, isNull);
      expect(session.currentTeamIndex, equals(0));
      expect(session.currentCardIndex, equals(0));
      expect(session.isPaused, isFalse);
      expect(session.roundNumber, equals(1));
      expect(session.totalRounds, equals(1));
    });

    test('should start a new game session', () {
      final deck = TestData.sampleDeck;
      final beforeStart = DateTime.now();

      final session = GameSession.start(
        deck: deck,
        roundDuration: const Duration(seconds: 90),
        isTeamMode: false,
      );

      final afterStart = DateTime.now();

      expect(session.deck, equals(deck));
      expect(session.roundDuration, equals(const Duration(seconds: 90)));
      expect(session.isTeamMode, isFalse);
      expect(session.cards.length, equals(deck.cards.length));
      expect(session.cards.toSet(), equals(deck.cards.toSet()));
      expect(
        session.startTime.isAfter(beforeStart) ||
            session.startTime.isAtSameMomentAs(beforeStart),
        isTrue,
      );
      expect(
        session.startTime.isBefore(afterStart) ||
            session.startTime.isAtSameMomentAs(afterStart),
        isTrue,
      );
    });

    test('should start a team mode game session', () {
      final deck = TestData.sampleDeck;
      final teamNames = ['Team A', 'Team B', 'Team C'];

      final session = GameSession.start(
        deck: deck,
        isTeamMode: true,
        teamNames: teamNames,
        totalRounds: 3,
      );

      expect(session.isTeamMode, isTrue);
      expect(session.teams, isNotNull);
      expect(session.teams!.length, equals(3));
      expect(session.teams![0].name, equals('Team A'));
      expect(session.teams![1].name, equals('Team B'));
      expect(session.teams![2].name, equals('Team C'));
      expect(session.totalRounds, equals(3));
    });

    test('should get current card correctly', () {
      final session = TestData.sampleGameSession;

      expect(session.currentCard, equals('Card 1'));

      final updatedSession = session.copyWith(currentCardIndex: 5);
      expect(updatedSession.currentCard, equals('Card 6'));

      final outOfBoundsSession = session.copyWith(
        currentCardIndex: session.cards.length,
      );
      expect(outOfBoundsSession.currentCard, isNull);
    });

    test('should get current team correctly', () {
      final session = TestData.teamGameSession;

      expect(session.currentTeam, isNotNull);
      expect(session.currentTeam!.name, equals('Team Alpha'));

      final updatedSession = session.copyWith(currentTeamIndex: 1);
      expect(updatedSession.currentTeam!.name, equals('Team Beta'));

      // Test wrap-around
      final wrapSession = session.copyWith(currentTeamIndex: 2);
      expect(wrapSession.currentTeam!.name, equals('Team Alpha'));
    });

    test('should add result for correct answer', () {
      final session = TestData.sampleGameSession;

      final updatedSession = session.addResult(GameResult.correct);

      expect(updatedSession.results.length, equals(1));
      expect(updatedSession.results[0].word, equals('Card 1'));
      expect(updatedSession.results[0].result, equals(GameResult.correct));
      expect(updatedSession.currentCardIndex, equals(1));
    });

    test('should add result for passed answer', () {
      final session = TestData.sampleGameSession;

      final updatedSession = session.addResult(GameResult.pass);

      expect(updatedSession.results.length, equals(1));
      expect(updatedSession.results[0].word, equals('Card 1'));
      expect(updatedSession.results[0].result, equals(GameResult.pass));
      expect(updatedSession.currentCardIndex, equals(1));
    });

    test('should update team score in team mode', () {
      final session = TestData.teamGameSession;

      final updatedSession = session.addResult(GameResult.correct);

      expect(updatedSession.teams![0].score, equals(1));
      expect(updatedSession.teams![0].results.length, equals(1));
      expect(updatedSession.teams![1].score, equals(0));
    });

    test('should move to next team', () {
      final session = TestData.teamGameSession;

      final nextTeamSession = session.nextTeam();

      expect(nextTeamSession.currentTeamIndex, equals(1));
      expect(nextTeamSession.currentCardIndex, equals(0));
      expect(nextTeamSession.cards.length, equals(session.deck.cards.length));
    });

    test('should handle next team when not in team mode', () {
      final session = TestData.sampleGameSession;

      final nextTeamSession = session.nextTeam();

      expect(nextTeamSession, equals(session));
    });

    test('should end the game session', () {
      final session = TestData.sampleGameSession;
      final beforeEnd = DateTime.now();

      final endedSession = session.end();

      final afterEnd = DateTime.now();

      expect(endedSession.endTime, isNotNull);
      expect(
        endedSession.endTime!.isAfter(beforeEnd) ||
            endedSession.endTime!.isAtSameMomentAs(beforeEnd),
        isTrue,
      );
      expect(
        endedSession.endTime!.isBefore(afterEnd) ||
            endedSession.endTime!.isAtSameMomentAs(afterEnd),
        isTrue,
      );
    });

    test('should toggle pause state', () {
      final session = TestData.sampleGameSession;

      expect(session.isPaused, isFalse);

      final pausedSession = session.togglePause();
      expect(pausedSession.isPaused, isTrue);

      final resumedSession = pausedSession.togglePause();
      expect(resumedSession.isPaused, isFalse);
    });

    test('should calculate statistics correctly', () {
      final session = TestData.completedGameSession;

      expect(session.correctCount, equals(3));
      expect(session.passCount, equals(1));
      expect(session.totalScore, equals(3));
      expect(session.correctCards.length, equals(3));
      expect(session.passedCards.length, equals(1));
    });

    test('should check if game is complete', () {
      final session = TestData.sampleGameSession;
      expect(session.isComplete, isFalse);

      final endedSession = session.end();
      expect(endedSession.isComplete, isTrue);

      final allCardsPlayedSession = session.copyWith(
        currentCardIndex: session.cards.length,
      );
      expect(allCardsPlayedSession.isComplete, isTrue);
    });

    test('should calculate elapsed time', () {
      final startTime = DateTime(2024, 1, 1, 10, 0);
      final session = GameSession(
        id: 'test',
        deck: TestData.sampleDeck,
        startTime: startTime,
        cards: TestData.sampleDeck.cards,
      );

      // Mock current time by ending the session
      final endTime = DateTime(2024, 1, 1, 10, 0, 30);
      final endedSession = session.copyWith(endTime: endTime);

      expect(endedSession.elapsedTime, equals(const Duration(seconds: 30)));
    });

    test('should calculate remaining time', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 30));
      final session = GameSession(
        id: 'test',
        deck: TestData.sampleDeck,
        startTime: startTime,
        roundDuration: const Duration(seconds: 60),
        cards: TestData.sampleDeck.cards,
      );

      final remaining = session.remainingTime;
      expect(remaining.inSeconds, lessThanOrEqualTo(30));
      expect(remaining.inSeconds, greaterThanOrEqualTo(29));

      // Test when paused
      final pausedSession = session.togglePause();
      expect(pausedSession.remainingTime, equals(Duration.zero));

      // Test when complete
      final completedSession = session.end();
      expect(completedSession.remainingTime, equals(Duration.zero));
    });

    test('should get winning team', () {
      var session = TestData.teamGameSession;

      // Add scores to teams
      session = session.addResult(GameResult.correct); // Team Alpha scores
      session = session.nextTeam();
      session = session.addResult(GameResult.correct); // Team Beta scores
      session = session.addResult(GameResult.correct); // Team Beta scores again

      final winningTeam = session.winningTeam;
      expect(winningTeam, isNotNull);
      expect(winningTeam!.name, equals('Team Beta'));
      expect(winningTeam.score, equals(2));
    });

    test('should handle winning team when not in team mode', () {
      final session = TestData.sampleGameSession;
      expect(session.winningTeam, isNull);
    });

    test('should copy session with updated properties', () {
      final original = TestData.sampleGameSession;
      final copied = original.copyWith(
        currentCardIndex: 5,
        isPaused: true,
        roundNumber: 2,
      );

      expect(copied.id, equals(original.id));
      expect(copied.deck, equals(original.deck));
      expect(copied.currentCardIndex, equals(5));
      expect(copied.isPaused, isTrue);
      expect(copied.roundNumber, equals(2));
      expect(copied.startTime, equals(original.startTime));
    });

    test('should provide meaningful toString representation', () {
      final session = TestData.sampleGameSession;
      final stringRep = session.toString();

      expect(stringRep, contains('GameSession'));
      expect(stringRep, contains('session-1'));
      expect(stringRep, contains('Test Deck'));
      expect(stringRep, contains('0')); // Score
    });
  });

  group('CardResult Tests', () {
    test('should create CardResult with all properties', () {
      final result = CardResult(
        word: 'Test Word',
        result: GameResult.correct,
        timeSpent: const Duration(seconds: 5),
      );

      expect(result.word, equals('Test Word'));
      expect(result.result, equals(GameResult.correct));
      expect(result.timeSpent, equals(const Duration(seconds: 5)));
    });
  });

  group('Team Tests', () {
    test('should create Team with all properties', () {
      final team = Team(
        id: 'team-1',
        name: 'Test Team',
        score: 5,
        results: TestData.sampleCardResults,
      );

      expect(team.id, equals('team-1'));
      expect(team.name, equals('Test Team'));
      expect(team.score, equals(5));
      expect(team.results.length, equals(3));
    });

    test('should create Team with default values', () {
      final team = Team(id: 'team-1', name: 'Test Team');

      expect(team.score, equals(0));
      expect(team.results, isEmpty);
    });

    test('should copy team with updated properties', () {
      final original = Team(id: 'team-1', name: 'Original Team', score: 3);

      final copied = original.copyWith(
        name: 'Updated Team',
        score: 5,
        results: TestData.sampleCardResults,
      );

      expect(copied.id, equals(original.id));
      expect(copied.name, equals('Updated Team'));
      expect(copied.score, equals(5));
      expect(copied.results.length, equals(3));
    });
  });
}

