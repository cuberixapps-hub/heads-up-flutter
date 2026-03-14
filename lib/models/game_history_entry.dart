import 'dart:convert';

class GameHistoryEntry {
  final String id;
  final String videoPath;
  final String? thumbnailPath;
  final String deckName;
  final int deckColor;
  final int correctCount;
  final int passCount;
  final int durationSeconds;
  final DateTime playedAt;
  final String? deckId;
  final bool hasOverlayBaked;

  GameHistoryEntry({
    required this.id,
    required this.videoPath,
    this.thumbnailPath,
    required this.deckName,
    required this.deckColor,
    required this.correctCount,
    required this.passCount,
    required this.durationSeconds,
    required this.playedAt,
    this.deckId,
    this.hasOverlayBaked = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'videoPath': videoPath,
    'thumbnailPath': thumbnailPath,
    'deckName': deckName,
    'deckColor': deckColor,
    'correctCount': correctCount,
    'passCount': passCount,
    'durationSeconds': durationSeconds,
    'playedAt': playedAt.toIso8601String(),
    'deckId': deckId,
    'hasOverlayBaked': hasOverlayBaked,
  };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    return GameHistoryEntry(
      id: json['id'] ?? '',
      videoPath: json['videoPath'] ?? '',
      thumbnailPath: json['thumbnailPath'],
      deckName: json['deckName'] ?? '',
      deckColor: json['deckColor'] ?? 0xFF000000,
      correctCount: json['correctCount'] ?? 0,
      passCount: json['passCount'] ?? 0,
      durationSeconds: json['durationSeconds'] ?? 0,
      playedAt: json['playedAt'] != null
          ? DateTime.parse(json['playedAt'])
          : DateTime.now(),
      deckId: json['deckId'],
      hasOverlayBaked: json['hasOverlayBaked'] ?? false,
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(playedAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${playedAt.day}/${playedAt.month}/${playedAt.year}';
  }

  String get formattedDuration {
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int get totalCards => correctCount + passCount;

  int get accuracyPercent =>
      totalCards > 0 ? (correctCount / totalCards * 100).round() : 0;

  static String encodeList(List<GameHistoryEntry> entries) {
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }

  static List<GameHistoryEntry> decodeList(String jsonString) {
    final List<dynamic> list = jsonDecode(jsonString);
    return list.map((e) => GameHistoryEntry.fromJson(e)).toList();
  }
}
