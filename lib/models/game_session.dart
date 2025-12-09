import 'deck.dart';

// Re-export DeckDifficulty for convenience
export 'deck.dart' show DeckDifficulty;

enum GameResult { correct, pass, timeUp }

class CardResult {
  final String word;
  final GameResult result;
  final Duration timeSpent;

  CardResult({
    required this.word,
    required this.result,
    required this.timeSpent,
  });
}

class Team {
  final String id;
  final String name;
  final int score;
  final List<CardResult> results;

  Team({
    required this.id,
    required this.name,
    this.score = 0,
    List<CardResult>? results,
  }) : results = results ?? [];

  Team copyWith({
    String? id,
    String? name,
    int? score,
    List<CardResult>? results,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      results: results ?? this.results,
    );
  }
}

class GameSession {
  final String id;
  final Deck deck;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration roundDuration;
  final List<String> cards;
  final List<CardResult> results;
  final bool isTeamMode;
  final List<Team>? teams;
  final int currentTeamIndex;
  final int currentCardIndex;
  final bool isPaused;
  final int roundNumber;
  final int totalRounds;

  GameSession({
    required this.id,
    required this.deck,
    required this.startTime,
    this.endTime,
    this.roundDuration = const Duration(seconds: 60),
    required this.cards,
    List<CardResult>? results,
    this.isTeamMode = false,
    this.teams,
    this.currentTeamIndex = 0,
    this.currentCardIndex = 0,
    this.isPaused = false,
    this.roundNumber = 1,
    this.totalRounds = 1,
  }) : results = results ?? [];

  factory GameSession.start({
    required Deck deck,
    Duration roundDuration = const Duration(seconds: 60),
    bool isTeamMode = false,
    List<String>? teamNames,
    int totalRounds = 1,
    DeckDifficulty difficulty = DeckDifficulty.mixed,
  }) {
    final shuffledCards = deck.getShuffledCards(null, difficulty);
    List<Team>? teams;

    if (isTeamMode && teamNames != null && teamNames.isNotEmpty) {
      teams =
          teamNames
              .map(
                (name) => Team(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                ),
              )
              .toList();
    }

    return GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deck: deck,
      startTime: DateTime.now(),
      roundDuration: roundDuration,
      cards: shuffledCards,
      isTeamMode: isTeamMode,
      teams: teams,
      totalRounds: totalRounds,
    );
  }

  GameSession copyWith({
    String? id,
    Deck? deck,
    DateTime? startTime,
    DateTime? endTime,
    Duration? roundDuration,
    List<String>? cards,
    List<CardResult>? results,
    bool? isTeamMode,
    List<Team>? teams,
    int? currentTeamIndex,
    int? currentCardIndex,
    bool? isPaused,
    int? roundNumber,
    int? totalRounds,
  }) {
    return GameSession(
      id: id ?? this.id,
      deck: deck ?? this.deck,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      roundDuration: roundDuration ?? this.roundDuration,
      cards: cards ?? this.cards,
      results: results ?? this.results,
      isTeamMode: isTeamMode ?? this.isTeamMode,
      teams: teams ?? this.teams,
      currentTeamIndex: currentTeamIndex ?? this.currentTeamIndex,
      currentCardIndex: currentCardIndex ?? this.currentCardIndex,
      isPaused: isPaused ?? this.isPaused,
      roundNumber: roundNumber ?? this.roundNumber,
      totalRounds: totalRounds ?? this.totalRounds,
    );
  }

  // Get current card
  String? get currentCard {
    if (currentCardIndex < cards.length) {
      return cards[currentCardIndex];
    }
    return null;
  }

  // Get current team
  Team? get currentTeam {
    if (isTeamMode && teams != null && teams!.isNotEmpty) {
      return teams![currentTeamIndex % teams!.length];
    }
    return null;
  }

  // Add result for current card
  GameSession addResult(GameResult result) {
    final cardResult = CardResult(
      word: currentCard ?? '',
      result: result,
      timeSpent: DateTime.now().difference(startTime),
    );

    List<CardResult> newResults = [...results, cardResult];
    List<Team>? newTeams = teams;

    // Update team score if in team mode
    if (isTeamMode && teams != null && result == GameResult.correct) {
      newTeams = [...teams!];
      final teamIndex = currentTeamIndex % teams!.length;
      newTeams[teamIndex] = newTeams[teamIndex].copyWith(
        score: newTeams[teamIndex].score + 1,
        results: [...newTeams[teamIndex].results, cardResult],
      );
    }

    return copyWith(
      results: newResults,
      teams: newTeams,
      currentCardIndex: currentCardIndex + 1,
    );
  }

  // Move to next team
  GameSession nextTeam() {
    if (!isTeamMode || teams == null || teams!.isEmpty) {
      return this;
    }
    return copyWith(
      currentTeamIndex: (currentTeamIndex + 1) % teams!.length,
      currentCardIndex: 0,
      cards: deck.getShuffledCards(),
    );
  }

  // End the game session
  GameSession end() {
    return copyWith(endTime: DateTime.now());
  }

  // Pause/Resume game
  GameSession togglePause() {
    return copyWith(isPaused: !isPaused);
  }

  // Get statistics
  int get correctCount =>
      results.where((r) => r.result == GameResult.correct).length;
  int get passCount => results.where((r) => r.result == GameResult.pass).length;
  int get totalScore => correctCount;

  List<CardResult> get correctCards =>
      results.where((r) => r.result == GameResult.correct).toList();
  List<CardResult> get passedCards =>
      results.where((r) => r.result == GameResult.pass).toList();

  // Check if game is complete
  bool get isComplete => endTime != null || currentCardIndex >= cards.length;

  // Get elapsed time
  Duration get elapsedTime {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  // Get remaining time
  Duration get remainingTime {
    if (isPaused || isComplete) {
      return Duration.zero;
    }
    final elapsed = elapsedTime;
    final remaining = roundDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Get winning team
  Team? get winningTeam {
    if (!isTeamMode || teams == null || teams!.isEmpty) {
      return null;
    }
    return teams!.reduce((a, b) => a.score > b.score ? a : b);
  }

  @override
  String toString() {
    return 'GameSession(id: $id, deck: ${deck.name}, score: $totalScore)';
  }
}
