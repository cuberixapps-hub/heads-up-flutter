import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_history_entry.dart';

class GameHistoryService {
  static final GameHistoryService _instance = GameHistoryService._internal();
  factory GameHistoryService() => _instance;
  GameHistoryService._internal();

  static const String _historyKey = 'game_video_history';
  static const int _maxEntries = 20;

  List<GameHistoryEntry> _cachedEntries = [];
  bool _isLoaded = false;

  final ValueNotifier<List<GameHistoryEntry>> entriesNotifier =
      ValueNotifier<List<GameHistoryEntry>>([]);

  Future<Directory> get _historyDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/GameHistory');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<GameHistoryEntry>> loadHistory({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return _cachedEntries;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_historyKey);

      if (jsonString == null || jsonString.isEmpty) {
        _cachedEntries = [];
        _isLoaded = true;
        entriesNotifier.value = _cachedEntries;
        return _cachedEntries;
      }

      final entries = GameHistoryEntry.decodeList(jsonString);

      // Prune entries whose video files no longer exist
      final valid = <GameHistoryEntry>[];
      for (final entry in entries) {
        if (await File(entry.videoPath).exists()) {
          valid.add(entry);
        } else {
          _cleanupEntryFiles(entry);
        }
      }

      _cachedEntries = valid;
      _isLoaded = true;
      entriesNotifier.value = _cachedEntries;

      if (valid.length != entries.length) {
        await _persist();
      }

      return _cachedEntries;
    } catch (e) {
      debugPrint('Error loading game history: $e');
      _cachedEntries = [];
      _isLoaded = true;
      entriesNotifier.value = _cachedEntries;
      return _cachedEntries;
    }
  }

  Future<GameHistoryEntry?> addEntry({
    required String videoPath,
    String? thumbnailPath,
    required String deckName,
    required int deckColor,
    required int correctCount,
    required int passCount,
    required int durationSeconds,
    String? deckId,
    bool hasOverlayBaked = false,
  }) async {
    try {
      final dir = await _historyDir;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final id = 'history_$timestamp';

      final persistentVideoPath = '${dir.path}/${id}_video.mp4';
      await File(videoPath).copy(persistentVideoPath);

      String? persistentThumbPath;
      if (thumbnailPath != null && await File(thumbnailPath).exists()) {
        persistentThumbPath = '${dir.path}/${id}_thumb.jpg';
        await File(thumbnailPath).copy(persistentThumbPath);
      }

      final entry = GameHistoryEntry(
        id: id,
        videoPath: persistentVideoPath,
        thumbnailPath: persistentThumbPath,
        deckName: deckName,
        deckColor: deckColor,
        correctCount: correctCount,
        passCount: passCount,
        durationSeconds: durationSeconds,
        playedAt: DateTime.now(),
        deckId: deckId,
        hasOverlayBaked: hasOverlayBaked,
      );

      await loadHistory();

      _cachedEntries.insert(0, entry);

      // Evict oldest entries beyond limit
      while (_cachedEntries.length > _maxEntries) {
        final removed = _cachedEntries.removeLast();
        _cleanupEntryFiles(removed);
      }

      await _persist();
      entriesNotifier.value = List.from(_cachedEntries);

      debugPrint('Game history entry saved: ${entry.deckName}');
      return entry;
    } catch (e) {
      debugPrint('Error saving game history entry: $e');
      return null;
    }
  }

  Future<void> removeEntry(String id) async {
    await loadHistory();

    final index = _cachedEntries.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final entry = _cachedEntries.removeAt(index);
    _cleanupEntryFiles(entry);
    await _persist();
    entriesNotifier.value = List.from(_cachedEntries);
  }

  Future<void> clearAll() async {
    await loadHistory();

    for (final entry in _cachedEntries) {
      _cleanupEntryFiles(entry);
    }

    _cachedEntries.clear();
    await _persist();
    entriesNotifier.value = [];
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = GameHistoryEntry.encodeList(_cachedEntries);
      await prefs.setString(_historyKey, jsonString);
    } catch (e) {
      debugPrint('Error persisting game history: $e');
    }
  }

  void _cleanupEntryFiles(GameHistoryEntry entry) {
    try {
      final videoFile = File(entry.videoPath);
      if (videoFile.existsSync()) videoFile.deleteSync();

      if (entry.thumbnailPath != null) {
        final thumbFile = File(entry.thumbnailPath!);
        if (thumbFile.existsSync()) thumbFile.deleteSync();
      }
    } catch (e) {
      debugPrint('Error cleaning up history entry files: $e');
    }
  }
}
