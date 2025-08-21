import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/game_session.dart';
import '../models/deck.dart';

class GameProvider extends ChangeNotifier {
  GameSession? _currentSession;
  Timer? _gameTimer;
  Duration _remainingTime = Duration.zero;
  bool _isGameActive = false;
  List<GameSession> _gameHistory = [];

  // Settings
  int _roundDuration = 60; // seconds
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _kidFriendlyMode = false;
  bool _showWordsAfterPass = true;

  GameSession? get currentSession => _currentSession;
  Duration get remainingTime => _remainingTime;
  bool get isGameActive => _isGameActive;
  List<GameSession> get gameHistory => _gameHistory;

  // Settings getters
  int get roundDuration => _roundDuration;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get kidFriendlyMode => _kidFriendlyMode;
  bool get showWordsAfterPass => _showWordsAfterPass;

  GameProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _roundDuration = prefs.getInt('round_duration') ?? 60;
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    _kidFriendlyMode = prefs.getBool('kid_friendly_mode') ?? false;
    _showWordsAfterPass = prefs.getBool('show_words_after_pass') ?? true;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('round_duration', _roundDuration);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setBool('kid_friendly_mode', _kidFriendlyMode);
    await prefs.setBool('show_words_after_pass', _showWordsAfterPass);
  }

  // Start a new game
  void startGame({
    required Deck deck,
    bool isTeamMode = false,
    List<String>? teamNames,
    int totalRounds = 1,
  }) {
    _currentSession = GameSession.start(
      deck: deck,
      roundDuration: Duration(seconds: _roundDuration),
      isTeamMode: isTeamMode,
      teamNames: teamNames,
      totalRounds: totalRounds,
    );

    _isGameActive = true;
    _remainingTime = Duration(seconds: _roundDuration);
    _startTimer();
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
    } else {
      _startTimer();
    }

    notifyListeners();
  }

  // End the current round
  void _endRound() {
    if (_currentSession == null) return;

    _gameTimer?.cancel();
    _isGameActive = false;
    _currentSession = _currentSession!.end();

    // Add to history
    _gameHistory.insert(0, _currentSession!);
    if (_gameHistory.length > 50) {
      _gameHistory.removeRange(50, _gameHistory.length);
    }

    _saveGameHistory();
    notifyListeners();
  }

  // End game manually
  void endGame() {
    _endRound();
  }

  // Move to next team (for team mode)
  void nextTeam() {
    if (_currentSession == null || !_currentSession!.isTeamMode) return;

    _currentSession = _currentSession!.nextTeam();
    _remainingTime = Duration(seconds: _roundDuration);
    _isGameActive = true;
    _startTimer();
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

  // Save game history
  Future<void> _saveGameHistory() async {
    // TODO: Implement saving game history to SharedPreferences
    // This would involve serializing the game sessions
  }

  // Update settings
  Future<void> updateRoundDuration(int seconds) async {
    _roundDuration = seconds;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleVibration() async {
    _vibrationEnabled = !_vibrationEnabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleKidFriendlyMode() async {
    _kidFriendlyMode = !_kidFriendlyMode;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleShowWordsAfterPass() async {
    _showWordsAfterPass = !_showWordsAfterPass;
    await _saveSettings();
    notifyListeners();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    int totalGames = _gameHistory.length;
    int totalCorrect = 0;
    int totalPassed = 0;
    int highScore = 0;

    for (final session in _gameHistory) {
      totalCorrect += session.correctCount;
      totalPassed += session.passCount;
      if (session.correctCount > highScore) {
        highScore = session.correctCount;
      }
    }

    return {
      'totalGames': totalGames,
      'totalCorrect': totalCorrect,
      'totalPassed': totalPassed,
      'highScore': highScore,
      'averageScore': totalGames > 0 ? totalCorrect / totalGames : 0,
    };
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}
