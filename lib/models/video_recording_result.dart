// Represents a game event during recording
class GameEvent {
  final Duration timestamp;
  final String
  type; // 'word_shown', 'correct', 'pass', 'game_start', 'game_end'
  final String word;
  final int score;
  final Duration? remainingTime;

  GameEvent({
    required this.timestamp,
    required this.type,
    required this.word,
    required this.score,
    this.remainingTime,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.inMilliseconds,
    'type': type,
    'word': word,
    'score': score,
    'remainingTime': remainingTime?.inSeconds,
  };

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
    timestamp: Duration(milliseconds: json['timestamp']),
    type: json['type'],
    word: json['word'],
    score: json['score'],
    remainingTime:
        json['remainingTime'] != null
            ? Duration(seconds: json['remainingTime'])
            : null,
  );
}

// Result of video recording session
class VideoRecordingResult {
  final String videoPath;
  final List<GameEvent> events;
  final Duration duration;
  final DateTime recordingStartTime;
  final String deckName;
  final String deckColor;

  VideoRecordingResult({
    required this.videoPath,
    required this.events,
    required this.duration,
    required this.recordingStartTime,
    required this.deckName,
    required this.deckColor,
  });

  // Get events of a specific type
  List<GameEvent> getEventsByType(String type) {
    return events.where((e) => e.type == type).toList();
  }

  // Get the event at a specific timestamp
  GameEvent? getEventAtTime(Duration timestamp) {
    for (int i = events.length - 1; i >= 0; i--) {
      if (events[i].timestamp <= timestamp) {
        return events[i];
      }
    }
    return null;
  }
}
