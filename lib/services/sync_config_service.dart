import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_settings.dart';
import 'firebase_service.dart';

/// Service for managing sync configuration and preferences
/// Controls real-time listener behavior to optimize Firebase costs
class SyncConfigService {
  static final SyncConfigService _instance = SyncConfigService._internal();
  factory SyncConfigService() => _instance;
  SyncConfigService._internal();

  static const String _syncSettingsKey = 'sync_settings';
  static const String _lastManualRefreshKey = 'last_manual_refresh_';
  
  SharedPreferences? _prefs;
  SyncSettings _currentSettings = SyncSettings.balanced(); // Default to balanced mode
  bool _initialized = false;

  /// Get current sync settings
  SyncSettings get currentSettings => _currentSettings;

  /// Check if initialized
  bool get isInitialized => _initialized;

  /// Initialize the service and load saved settings
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      _initialized = true;
      debugPrint('✅ SyncConfigService initialized with mode: ${_currentSettings.mode.name}');
    } catch (e) {
      debugPrint('❌ Error initializing SyncConfigService: $e');
      // Continue with default balanced settings
      _initialized = true;
    }
  }

  /// Load saved settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final settingsJson = _prefs?.getString(_syncSettingsKey);
      if (settingsJson != null) {
        final map = jsonDecode(settingsJson) as Map<String, dynamic>;
        _currentSettings = SyncSettings.fromJson(map);
        debugPrint('📥 Loaded sync settings: ${_currentSettings.mode.name}');
      } else {
        // First time - use balanced mode as default
        _currentSettings = SyncSettings.balanced();
        await _saveSettings();
        debugPrint('🆕 Using default balanced sync settings');
      }
    } catch (e) {
      debugPrint('Error loading sync settings: $e');
      _currentSettings = SyncSettings.balanced();
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final settingsJson = jsonEncode(_currentSettings.toJson());
      await _prefs?.setString(_syncSettingsKey, settingsJson);
      debugPrint('💾 Saved sync settings: ${_currentSettings.mode.name}');
      
      // Log analytics event
      await FirebaseService().logEvent('sync_settings_changed', parameters: {
        'mode': _currentSettings.mode.name,
        'realtime_decks': _currentSettings.enableRealtimeDecks,
        'realtime_games': _currentSettings.enableRealtimeGames,
        'realtime_leaderboards': _currentSettings.enableRealtimeLeaderboards,
      });
    } catch (e) {
      debugPrint('Error saving sync settings: $e');
    }
  }

  /// Update sync settings with a preset mode
  Future<void> setPresetMode(SyncMode mode) async {
    switch (mode) {
      case SyncMode.balanced:
        _currentSettings = SyncSettings.balanced();
        break;
      case SyncMode.bestPerformance:
        _currentSettings = SyncSettings.bestPerformance();
        break;
      case SyncMode.reduceCosts:
        _currentSettings = SyncSettings.reduceCosts();
        break;
      case SyncMode.custom:
        // Keep current custom settings
        break;
    }
    
    await _saveSettings();
    debugPrint('🎯 Sync mode changed to: ${mode.name}');
  }

  /// Update sync settings with custom values
  Future<void> setCustomSettings({
    bool? enableRealtimeDecks,
    bool? enableRealtimeGames,
    bool? enableRealtimeLeaderboards,
    Duration? manualRefreshInterval,
  }) async {
    _currentSettings = _currentSettings.copyWith(
      enableRealtimeDecks: enableRealtimeDecks,
      enableRealtimeGames: enableRealtimeGames,
      enableRealtimeLeaderboards: enableRealtimeLeaderboards,
      manualRefreshInterval: manualRefreshInterval,
      mode: SyncMode.custom,
    );
    
    await _saveSettings();
    debugPrint('🔧 Custom sync settings updated');
  }

  /// Check if real-time decks should be enabled
  bool shouldEnableRealtimeDecks() {
    return _currentSettings.enableRealtimeDecks;
  }

  /// Check if real-time games should be enabled
  bool shouldEnableRealtimeGames() {
    return _currentSettings.enableRealtimeGames;
  }

  /// Check if real-time leaderboards should be enabled
  bool shouldEnableRealtimeLeaderboards() {
    return _currentSettings.enableRealtimeLeaderboards;
  }

  /// Check if it's time for a manual refresh based on the interval
  Future<bool> shouldManualRefresh(String dataType) async {
    final key = '$_lastManualRefreshKey$dataType';
    final lastRefreshStr = _prefs?.getString(key);
    
    if (lastRefreshStr == null) {
      // Never refreshed, should refresh now
      return true;
    }
    
    try {
      final lastRefresh = DateTime.parse(lastRefreshStr);
      final timeSinceRefresh = DateTime.now().difference(lastRefresh);
      return timeSinceRefresh >= _currentSettings.manualRefreshInterval;
    } catch (e) {
      debugPrint('Error parsing last refresh time: $e');
      return true;
    }
  }

  /// Record a manual refresh
  Future<void> recordManualRefresh(String dataType) async {
    final key = '$_lastManualRefreshKey$dataType';
    await _prefs?.setString(key, DateTime.now().toIso8601String());
    debugPrint('🔄 Manual refresh recorded for: $dataType');
  }

  /// Get time since last manual refresh
  Future<Duration?> getTimeSinceLastRefresh(String dataType) async {
    final key = '$_lastManualRefreshKey$dataType';
    final lastRefreshStr = _prefs?.getString(key);
    
    if (lastRefreshStr == null) return null;
    
    try {
      final lastRefresh = DateTime.parse(lastRefreshStr);
      return DateTime.now().difference(lastRefresh);
    } catch (e) {
      return null;
    }
  }

  /// Reset all manual refresh timestamps
  Future<void> resetAllRefreshTimestamps() async {
    final keys = _prefs?.getKeys().where((key) => key.startsWith(_lastManualRefreshKey)).toList() ?? [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }
    debugPrint('🗑️ All manual refresh timestamps cleared');
  }

  /// Get estimated Firebase reads per month based on current settings
  /// This is a rough estimation assuming ~100 active sessions per month
  Map<String, dynamic> getEstimatedUsage() {
    int estimatedReads = 0;
    
    // Deck reads estimation
    if (_currentSettings.enableRealtimeDecks) {
      estimatedReads += 50000; // Real-time: ~500 reads per user per month
    } else {
      estimatedReads += 500; // Manual: ~5 reads per user per month
    }
    
    // Game reads estimation
    if (_currentSettings.enableRealtimeGames) {
      estimatedReads += 30000; // Real-time: ~300 reads per user per month
    } else {
      estimatedReads += 200; // Manual: ~2 reads per user per month
    }
    
    // Leaderboard reads estimation
    if (_currentSettings.enableRealtimeLeaderboards) {
      estimatedReads += 20000; // Real-time: ~200 reads per user per month
    } else {
      estimatedReads += 100; // Manual: ~1 read per user per month
    }
    
    return {
      'estimatedReadsPerMonth': estimatedReads,
      'estimatedCostUSD': (estimatedReads / 50000) * 0.06, // Firebase pricing: $0.06 per 100K reads
      'savingsVsRealtime': _calculateSavings(estimatedReads),
    };
  }

  /// Calculate savings compared to all real-time mode
  double _calculateSavings(int currentReads) {
    const int allRealtimeReads = 100000; // Estimated reads if all real-time
    if (currentReads >= allRealtimeReads) return 0.0;
    
    return ((allRealtimeReads - currentReads) / allRealtimeReads) * 100;
  }

  /// Get formatted usage summary
  String getUsageSummary() {
    final usage = getEstimatedUsage();
    final reads = usage['estimatedReadsPerMonth'] as int;
    final cost = usage['estimatedCostUSD'] as double;
    final savings = usage['savingsVsRealtime'] as double;
    
    return 'Est. ${(reads / 1000).toStringAsFixed(1)}K reads/month '
        '(\$${cost.toStringAsFixed(2)}) • '
        '${savings.toStringAsFixed(0)}% savings vs all real-time';
  }

  /// Export settings for backup
  Map<String, dynamic> exportSettings() {
    return _currentSettings.toJson();
  }

  /// Import settings from backup
  Future<void> importSettings(Map<String, dynamic> settingsJson) async {
    try {
      _currentSettings = SyncSettings.fromJson(settingsJson);
      await _saveSettings();
      debugPrint('📥 Settings imported successfully');
    } catch (e) {
      debugPrint('Error importing settings: $e');
      throw Exception('Failed to import settings');
    }
  }

  /// Reset to default balanced settings
  Future<void> resetToDefaults() async {
    _currentSettings = SyncSettings.balanced();
    await _saveSettings();
    await resetAllRefreshTimestamps();
    debugPrint('🔄 Reset to default balanced settings');
  }
}

