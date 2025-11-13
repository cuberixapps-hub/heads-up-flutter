import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game_session.dart';
import '../models/deck.dart';
import '../services/game_firebase_service.dart';
import '../services/firebase_service.dart';
import '../services/sync_config_service.dart';
import '../services/listener_manager.dart';
import '../models/video_recording_result.dart';
import '../utils/debounce.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameProvider extends ChangeNotifier {
  final GameFirebaseService _gameFirebaseService = GameFirebaseService();
  final FirebaseService _firebaseService = FirebaseService();
  final SyncConfigService _syncConfigService = SyncConfigService();
  final ListenerManager _listenerManager = ListenerManager();

  GameSession? _currentSession;
  Timer? _gameTimer;
  Duration _remainingTime = Duration.zero;
  bool _isGameActive = false;
  List<GameSession> _gameHistory = [];
  Map<String, dynamic> _statistics = {};

  // Video recording field
  VideoRecordingResult? _lastVideoRecording;

  // Streams
  StreamSubscription? _recentGamesSubscription;
  
  // Debouncer for settings updates
  late final Debouncer _settingsDebouncer;
  WriteBatch? _pendingSettingsBatch;
  final Map<String, dynamic> _pendingSettings = {};

  // Settings (now from Firebase)
  Map<String, dynamic> _settings = {
    'roundDuration': 60,
    'soundEnabled': true,
    'vibrationEnabled': true,
    'kidFriendlyMode': false,
    'showWordsAfterPass': true,
  };

  GameSession? get currentSession => _currentSession;
  Duration get remainingTime => _remainingTime;
  bool get isGameActive => _isGameActive;
  List<GameSession> get gameHistory => _gameHistory;
  Map<String, dynamic> get statistics => _statistics;

  // Settings getters
  int get roundDuration => _settings['roundDuration'] ?? 60;
  bool get soundEnabled => _settings['soundEnabled'] ?? true;
  bool get vibrationEnabled => _settings['vibrationEnabled'] ?? true;
  bool get kidFriendlyMode => _settings['kidFriendlyMode'] ?? false;
  bool get showWordsAfterPass => _settings['showWordsAfterPass'] ?? true;

  // Video recording getter
  VideoRecordingResult? get lastVideoRecording => _lastVideoRecording;

  GameProvider() {
    _settingsDebouncer = Debouncer(milliseconds: 1000);
    _initialize();
  }

  Future<void> _initialize() async {
    await _syncConfigService.initialize();
    await _loadSettings();
    await _loadStatistics();
    await _loadGameHistory();
    // Don't set up listeners initially - only during gameplay
  }

  void _setupRealtimeListeners() {
    // Only enable real-time listeners if configured and during active gameplay
    if (!_syncConfigService.shouldEnableRealtimeGames()) {
      debugPrint('📊 Real-time game listeners DISABLED (using manual refresh)');
      return;
    }
    
    if (!_isGameActive) {
      debugPrint('📊 Not in active gameplay, skipping game listeners');
      return;
    }
    
    debugPrint('📡 Setting up real-time game listeners');
    
    // Listen to recent games
    _listenerManager.cancelListener('games_recent');
    final subscription = _gameFirebaseService
        .streamRecentGames(limit: 10)
        .listen(
          (games) {
            if (games.isNotEmpty) {
              _gameHistory = games;
              notifyListeners();
            }
          },
          onError: (error) {
            debugPrint('Error streaming recent games: $error');
          },
        );
    
    _listenerManager.registerListener('games_recent', subscription);
  }
  
  // Cancel real-time listeners when not in active gameplay
  void _cancelRealtimeListeners() {
    debugPrint('🔌 Cancelling real-time game listeners');
    _listenerManager.cancelListenersByCategory('games');
  }

  Future<void> _loadSettings() async {
    try {
      _settings = await _gameFirebaseService.getGameSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings from Firebase: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      _statistics = await _gameFirebaseService.getUserStatistics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Future<void> _loadGameHistory() async {
    try {
      _gameHistory = await _gameFirebaseService.getGameHistory(limit: 10);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading game history: $e');
    }
  }
  
  // Manual refresh for game history when listeners are disabled
  Future<void> manualRefreshGameHistory() async {
    if (_syncConfigService.shouldEnableRealtimeGames()) {
      debugPrint('📊 Real-time enabled, skipping manual refresh');
      return;
    }
    
    final shouldRefresh = await _syncConfigService.shouldManualRefresh('games');
    if (!shouldRefresh) {
      debugPrint('📊 Manual refresh not needed yet');
      return;
    }
    
    debugPrint('🔄 Manual refreshing game history...');
    try {
      _gameHistory = await _gameFirebaseService.getGameHistory(limit: 10);
      await _syncConfigService.recordManualRefresh('games');
      notifyListeners();
      debugPrint('✅ Manual refresh complete');
    } catch (e) {
      debugPrint('❌ Manual refresh failed: $e');
    }
  }

  // Start a new game
  void startGame({
    required Deck deck,
    bool isTeamMode = false,
    List<String>? teamNames,
    int totalRounds = 1,
  }) {
    // Don't clear video recording here - it should be cleared when leaving results screen
    // clearVideoRecording();
    _currentSession = GameSession.start(
      deck: deck,
      roundDuration: Duration(seconds: roundDuration),
      isTeamMode: isTeamMode,
      teamNames: teamNames,
      totalRounds: totalRounds,
    );

    _isGameActive = true;
    _remainingTime = Duration(seconds: roundDuration);
    _startTimer();

    // Set up real-time listeners for active gameplay
    _setupRealtimeListeners();

    // Log event to Firebase Analytics
    _firebaseService.logEvent(
      'game_started',
      parameters: {
        'deck_id': deck.id,
        'deck_name': deck.name,
        'is_team_mode': isTeamMode,
        'total_rounds': totalRounds,
      },
    );

    notifyListeners();
  }

  // Start the game timer
  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentSession == null || _currentSession!.isPaused) {
        return;
      }

      _remainingTime = _currentSession!.remainingTime;

      if (_remainingTime <= Duration.zero) {
        _endRound();
      }

      notifyListeners();
    });
  }

  // Handle correct answer
  void markCorrect() {
    if (_currentSession == null || !_isGameActive) return;

    _currentSession = _currentSession!.addResult(GameResult.correct);

    if (_currentSession!.currentCardIndex >= _currentSession!.cards.length) {
      _endRound();
    }

    notifyListeners();
  }

  // Handle pass/skip
  void markPass() {
    if (_currentSession == null || !_isGameActive) return;

    _currentSession = _currentSession!.addResult(GameResult.pass);

    if (_currentSession!.currentCardIndex >= _currentSession!.cards.length) {
      _endRound();
    }

    notifyListeners();
  }

  // Pause/Resume game
  void togglePause() {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.togglePause();

    if (_currentSession!.isPaused) {
      _gameTimer?.cancel();
      _firebaseService.logEvent('game_paused');
    } else {
      _startTimer();
      _firebaseService.logEvent('game_resumed');
    }

    notifyListeners();
  }

  // End the current round
  Future<void> _endRound() async {
    if (_currentSession == null) return;

    _gameTimer?.cancel();
    _isGameActive = false;
    _currentSession = _currentSession!.end();
    
    // Cancel real-time listeners when game ends
    _cancelRealtimeListeners();

    // Save to Firebase
    await _saveGameSession();

    // Update local history
    _gameHistory.insert(0, _currentSession!);
    if (_gameHistory.length > 50) {
      _gameHistory.removeRange(50, _gameHistory.length);
    }

    // Update statistics
    await _updateStatistics();

    notifyListeners();
  }

  // Save game session to Firebase
  Future<void> _saveGameSession() async {
    if (_currentSession == null) return;

    try {
      await _gameFirebaseService.saveGameSession(_currentSession!);
    } catch (e) {
      debugPrint('Error saving game session: $e');
    }
  }

  // Update statistics
  Future<void> _updateStatistics() async {
    try {
      _statistics = await _gameFirebaseService.getUserStatistics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating statistics: $e');
    }
  }

  // End game manually
  Future<void> endGame() async {
    await _endRound();
  }

  // Move to next team (for team mode)
  void nextTeam() {
    if (_currentSession == null || !_currentSession!.isTeamMode) return;

    _currentSession = _currentSession!.nextTeam();
    _remainingTime = Duration(seconds: roundDuration);
    _isGameActive = true;
    _startTimer();

    _firebaseService.logEvent('team_switched');
    notifyListeners();
  }

  // Start a new round with the same deck
  void playAgain() {
    if (_currentSession == null) return;

    startGame(
      deck: _currentSession!.deck,
      isTeamMode: _currentSession!.isTeamMode,
      teamNames: _currentSession!.teams?.map((t) => t.name).toList(),
      totalRounds: _currentSession!.totalRounds,
    );
  }

  // Update settings with debouncing
  Future<void> updateRoundDuration(int seconds) async {
    _settings['roundDuration'] = seconds;
    _pendingSettings['roundDuration'] = seconds;
    notifyListeners();
    _debouncedSaveSettings();
  }

  Future<void> toggleSound() async {
    _settings['soundEnabled'] = !(_settings['soundEnabled'] ?? true);
    _pendingSettings['soundEnabled'] = _settings['soundEnabled'];
    notifyListeners();
    _debouncedSaveSettings();
  }

  Future<void> toggleVibration() async {
    _settings['vibrationEnabled'] = !(_settings['vibrationEnabled'] ?? true);
    _pendingSettings['vibrationEnabled'] = _settings['vibrationEnabled'];
    notifyListeners();
    _debouncedSaveSettings();
  }

  Future<void> toggleKidFriendlyMode() async {
    _settings['kidFriendlyMode'] = !(_settings['kidFriendlyMode'] ?? false);
    _pendingSettings['kidFriendlyMode'] = _settings['kidFriendlyMode'];
    notifyListeners();
    _debouncedSaveSettings();
  }

  Future<void> toggleShowWordsAfterPass() async {
    _settings['showWordsAfterPass'] =
        !(_settings['showWordsAfterPass'] ?? true);
    _pendingSettings['showWordsAfterPass'] = _settings['showWordsAfterPass'];
    notifyListeners();
    _debouncedSaveSettings();
  }
  
  // Debounced settings save
  void _debouncedSaveSettings() {
    _settingsDebouncer.run(() async {
      if (_pendingSettings.isNotEmpty) {
        await _saveSettingsBatch();
      }
    });
  }

  // Save batched settings
  Future<void> _saveSettingsBatch() async {
    try {
      final settingsToSave = Map<String, dynamic>.from(_pendingSettings);
      _pendingSettings.clear();
      
      // Create batch if needed
      if (_pendingSettingsBatch == null) {
        _pendingSettingsBatch = FirebaseFirestore.instance.batch();
      }
      
      // Save settings with batch
      await _gameFirebaseService.saveGameSettings(
        settingsToSave,
        existingBatch: _pendingSettingsBatch,
      );
      
      // Commit the batch
      await _pendingSettingsBatch?.commit();
      _pendingSettingsBatch = null;
      
      debugPrint('Settings saved with debouncing: ${settingsToSave.keys.join(', ')}');
    } catch (e) {
      debugPrint('Error saving batched settings: $e');
      _pendingSettingsBatch = null;
    }
  }

  // Get global leaderboard
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({
    int limit = 100,
  }) async {
    try {
      return await _gameFirebaseService.getGlobalLeaderboard(limit: limit);
    } catch (e) {
      debugPrint('Error getting global leaderboard: $e');
      return [];
    }
  }

  // Get deck-specific leaderboard
  Future<List<Map<String, dynamic>>> getDeckLeaderboard(
    String deckId, {
    int limit = 50,
  }) async {
    try {
      return await _gameFirebaseService.getDeckLeaderboard(
        deckId,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting deck leaderboard: $e');
      return [];
    }
  }

  // Refresh all data from Firebase
  Future<void> refreshData() async {
    await _loadSettings();
    await _loadStatistics();
    await _loadGameHistory();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    return _statistics;
  }

  // Double the score of the last completed game
  void doubleLastGameScore() {
    if (_currentSession != null && _currentSession!.isComplete) {
      // Get all current results
      final currentResults = _currentSession!.results;

      // Duplicate all correct results to double the score
      final correctResults =
          currentResults.where((r) => r.result == GameResult.correct).toList();
      final doubledResults = [...currentResults, ...correctResults];

      // Update the session with doubled results
      _currentSession = _currentSession!.copyWith(results: doubledResults);

      // Update statistics with doubled score
      final originalCorrect = correctResults.length;
      _statistics['totalCorrect'] =
          (_statistics['totalCorrect'] ?? 0) + originalCorrect;
      _statistics['highScore'] =
          (_statistics['highScore'] ?? 0) < (originalCorrect * 2)
              ? (originalCorrect * 2)
              : _statistics['highScore'];

      // Save updated session
      _saveGameSession();

      notifyListeners();
    }
  }

  // Calculate achievement progress
  Map<String, double> getAchievementProgress() {
    final stats = _statistics;
    final achievements = <String, double>{};

    // Games played achievement
    final totalGames = stats['totalGames'] ?? 0;
    achievements['rookie'] = (totalGames / 10).clamp(0.0, 1.0);
    achievements['veteran'] = (totalGames / 50).clamp(0.0, 1.0);
    achievements['master'] = (totalGames / 100).clamp(0.0, 1.0);

    // High score achievements
    final highScore = stats['highScore'] ?? 0;
    achievements['scorer'] = (highScore / 10).clamp(0.0, 1.0);
    achievements['highScorer'] = (highScore / 25).clamp(0.0, 1.0);
    achievements['champion'] = (highScore / 50).clamp(0.0, 1.0);

    // Total correct achievements
    final totalCorrect = stats['totalCorrect'] ?? 0;
    achievements['accurate'] = (totalCorrect / 100).clamp(0.0, 1.0);
    achievements['precise'] = (totalCorrect / 500).clamp(0.0, 1.0);
    achievements['perfect'] = (totalCorrect / 1000).clamp(0.0, 1.0);

    return achievements;
  }

  // Clear all game data
  Future<void> clearAllData() async {
    try {
      // Clear local data
      _currentSession = null;
      _gameHistory.clear();
      _statistics = {};
      _isGameActive = false;
      _remainingTime = Duration.zero;

      // Cancel any active timers
      _gameTimer?.cancel();

      // Clear Firebase data
      await _gameFirebaseService.clearUserData();

      // Reload fresh data
      await _loadStatistics();
      await _loadGameHistory();

      // Log event
      _firebaseService.logEvent('data_cleared');

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  // Video recording methods
  void setVideoRecording(VideoRecordingResult? recording) {
    _lastVideoRecording = recording;
    notifyListeners();
  }

  void clearVideoRecording() {
    _lastVideoRecording = null;
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _recentGamesSubscription?.cancel();
    _settingsDebouncer.dispose();
    super.dispose();
  }
}
