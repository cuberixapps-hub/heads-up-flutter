import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'firebase_service.dart';

/// Centralized manager for Firebase real-time listeners
/// Manages listener lifecycle to reduce Firebase costs and optimize performance
class ListenerManager with widgets.WidgetsBindingObserver {
  static final ListenerManager _instance = ListenerManager._internal();
  factory ListenerManager() => _instance;
  ListenerManager._internal();

  final Map<String, StreamSubscription> _activeListeners = {};
  final Map<String, DateTime> _listenerStartTimes = {};
  bool _isAppInForeground = true;
  bool _initialized = false;

  /// Get count of active listeners
  int get activeListenerCount => _activeListeners.length;

  /// Check if app is in foreground
  bool get isAppInForeground => _isAppInForeground;

  /// Initialize the listener manager
  void initialize() {
    if (_initialized) return;
    
    widgets.WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    debugPrint('✅ ListenerManager initialized');
  }

  /// Register a listener with a unique key
  void registerListener(String key, StreamSubscription subscription) {
    // Cancel existing listener with same key if exists
    cancelListener(key);
    
    _activeListeners[key] = subscription;
    _listenerStartTimes[key] = DateTime.now();
    
    debugPrint('📡 Listener registered: $key (Total: ${_activeListeners.length})');
    
    // Log analytics
    FirebaseService().logEvent('listener_registered', parameters: {
      'listener_key': key,
      'total_active': _activeListeners.length,
    });
  }

  /// Cancel a specific listener
  void cancelListener(String key) {
    final subscription = _activeListeners.remove(key);
    if (subscription != null) {
      subscription.cancel();
      
      // Calculate how long the listener was active
      final startTime = _listenerStartTimes.remove(key);
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        debugPrint('🔌 Listener cancelled: $key (Active for: ${duration.inSeconds}s, Remaining: ${_activeListeners.length})');
        
        // Log analytics
        FirebaseService().logEventSampled('listener_cancelled', 
          samplingRate: 0.2, // Sample 20% of listener cancellations
          parameters: {
            'listener_key': key,
            'duration_seconds': duration.inSeconds,
            'total_remaining': _activeListeners.length,
          }
        );
      }
    }
  }

  /// Cancel all listeners
  void cancelAllListeners() {
    debugPrint('🔌 Cancelling all listeners (${_activeListeners.length})');
    
    for (var entry in _activeListeners.entries) {
      entry.value.cancel();
    }
    
    _activeListeners.clear();
    _listenerStartTimes.clear();
    
    // Log analytics
    FirebaseService().logEvent('all_listeners_cancelled');
  }

  /// Cancel listeners by category (e.g., 'decks', 'games', 'leaderboards')
  void cancelListenersByCategory(String category) {
    final keysToRemove = _activeListeners.keys
        .where((key) => key.startsWith('${category}_'))
        .toList();
    
    debugPrint('🔌 Cancelling ${keysToRemove.length} listeners for category: $category');
    
    for (final key in keysToRemove) {
      cancelListener(key);
    }
  }

  /// Pause non-critical listeners when app goes to background
  void pauseNonCriticalListeners() {
    debugPrint('⏸️ Pausing non-critical listeners');
    
    // Cancel non-critical listeners (keep game session listeners if active)
    final nonCriticalKeys = _activeListeners.keys
        .where((key) => !key.startsWith('game_session_'))
        .toList();
    
    for (final key in nonCriticalKeys) {
      cancelListener(key);
    }
    
    // Log analytics
    FirebaseService().logEvent('listeners_paused', parameters: {
      'paused_count': nonCriticalKeys.length,
      'remaining_count': _activeListeners.length,
    });
  }

  /// Get listener info for debugging
  Map<String, dynamic> getListenerInfo() {
    final info = <String, dynamic>{};
    
    for (var entry in _listenerStartTimes.entries) {
      final duration = DateTime.now().difference(entry.value);
      info[entry.key] = {
        'active_duration_seconds': duration.inSeconds,
        'started_at': entry.value.toIso8601String(),
      };
    }
    
    return info;
  }

  /// Get formatted listener summary
  String getListenerSummary() {
    final activeCount = _activeListeners.length;
    if (activeCount == 0) {
      return 'No active listeners';
    }
    
    final categories = <String, int>{};
    for (final key in _activeListeners.keys) {
      final category = key.split('_').first;
      categories[category] = (categories[category] ?? 0) + 1;
    }
    
    final categorySummary = categories.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    
    return '$activeCount active listeners ($categorySummary)';
  }

  /// Check if a specific listener is active
  bool isListenerActive(String key) {
    return _activeListeners.containsKey(key);
  }

  /// Get total time all listeners have been active (in seconds)
  int getTotalListenerTimeSeconds() {
    int totalSeconds = 0;
    final now = DateTime.now();
    
    for (final startTime in _listenerStartTimes.values) {
      totalSeconds += now.difference(startTime).inSeconds;
    }
    
    return totalSeconds;
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App going to background
        if (_isAppInForeground) {
          _isAppInForeground = false;
          debugPrint('📱 App backgrounded - pausing listeners');
          pauseNonCriticalListeners();
        }
        break;
        
      case AppLifecycleState.resumed:
        // App coming to foreground
        if (!_isAppInForeground) {
          _isAppInForeground = true;
          debugPrint('📱 App foregrounded - listeners can resume');
          
          // Log analytics
          FirebaseService().logEvent('app_foregrounded', parameters: {
            'active_listeners': _activeListeners.length,
          });
        }
        break;
        
      case AppLifecycleState.detached:
        // App terminating
        debugPrint('📱 App terminating - cleaning up listeners');
        cancelAllListeners();
        break;
        
      case AppLifecycleState.hidden:
        // Hidden state (not commonly used)
        break;
    }
  }

  /// Dispose and clean up
  void dispose() {
    widgets.WidgetsBinding.instance.removeObserver(this);
    cancelAllListeners();
    _initialized = false;
    debugPrint('🗑️ ListenerManager disposed');
  }

  /// Log current listener status for debugging
  void logStatus() {
    debugPrint('\n📊 === LISTENER STATUS ===');
    debugPrint('Active Listeners: ${_activeListeners.length}');
    debugPrint('App State: ${_isAppInForeground ? "Foreground" : "Background"}');
    debugPrint('Total Listener Time: ${getTotalListenerTimeSeconds()}s');
    
    if (_activeListeners.isNotEmpty) {
      debugPrint('\nActive Listener Details:');
      final info = getListenerInfo();
      info.forEach((key, value) {
        debugPrint('  - $key: ${value['active_duration_seconds']}s');
      });
    }
    debugPrint('========================\n');
  }
}

/// Extension to add sampling support to FirebaseService
extension FirebaseServiceSampling on FirebaseService {
  /// Log event with sampling rate
  Future<void> logEventSampled(
    String name, {
    Map<String, Object>? parameters,
    double samplingRate = 1.0,
  }) async {
    // Always log if sampling rate is 1.0 or if random check passes
    if (samplingRate >= 1.0 || (samplingRate > 0 && _shouldSample(samplingRate))) {
      await logEvent(name, parameters: parameters);
    }
  }

  bool _shouldSample(double rate) {
    return (DateTime.now().millisecondsSinceEpoch % 100) < (rate * 100);
  }
}

