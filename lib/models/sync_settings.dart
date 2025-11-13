import 'package:flutter/foundation.dart';

/// Sync settings for controlling real-time listeners and data synchronization
/// This helps reduce Firebase costs by allowing manual control over real-time updates
class SyncSettings {
  final bool enableRealtimeDecks;
  final bool enableRealtimeGames;
  final bool enableRealtimeLeaderboards;
  final Duration manualRefreshInterval;
  final SyncMode mode;

  const SyncSettings({
    required this.enableRealtimeDecks,
    required this.enableRealtimeGames,
    required this.enableRealtimeLeaderboards,
    required this.manualRefreshInterval,
    required this.mode,
  });

  /// Balanced mode - optimized for cost and performance (default)
  /// - Decks: Manual refresh
  /// - Games: Real-time only during active gameplay
  /// - Leaderboards: Manual refresh
  factory SyncSettings.balanced() {
    return const SyncSettings(
      enableRealtimeDecks: false,
      enableRealtimeGames: false, // Enabled only during gameplay
      enableRealtimeLeaderboards: false,
      manualRefreshInterval: Duration(minutes: 5),
      mode: SyncMode.balanced,
    );
  }

  /// Best performance mode - all real-time updates enabled
  /// Higher Firebase costs but immediate updates
  factory SyncSettings.bestPerformance() {
    return const SyncSettings(
      enableRealtimeDecks: true,
      enableRealtimeGames: true,
      enableRealtimeLeaderboards: true,
      manualRefreshInterval: Duration(minutes: 1),
      mode: SyncMode.bestPerformance,
    );
  }

  /// Reduce costs mode - all manual, minimal Firebase reads
  /// Lowest cost but requires manual refresh for updates
  factory SyncSettings.reduceCosts() {
    return const SyncSettings(
      enableRealtimeDecks: false,
      enableRealtimeGames: false,
      enableRealtimeLeaderboards: false,
      manualRefreshInterval: Duration(minutes: 15),
      mode: SyncMode.reduceCosts,
    );
  }

  /// Custom sync settings
  factory SyncSettings.custom({
    required bool enableRealtimeDecks,
    required bool enableRealtimeGames,
    required bool enableRealtimeLeaderboards,
    Duration? manualRefreshInterval,
  }) {
    return SyncSettings(
      enableRealtimeDecks: enableRealtimeDecks,
      enableRealtimeGames: enableRealtimeGames,
      enableRealtimeLeaderboards: enableRealtimeLeaderboards,
      manualRefreshInterval: manualRefreshInterval ?? const Duration(minutes: 5),
      mode: SyncMode.custom,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'enableRealtimeDecks': enableRealtimeDecks,
      'enableRealtimeGames': enableRealtimeGames,
      'enableRealtimeLeaderboards': enableRealtimeLeaderboards,
      'manualRefreshIntervalMinutes': manualRefreshInterval.inMinutes,
      'mode': mode.name,
    };
  }

  /// Create from JSON
  factory SyncSettings.fromJson(Map<String, dynamic> json) {
    return SyncSettings(
      enableRealtimeDecks: json['enableRealtimeDecks'] as bool? ?? false,
      enableRealtimeGames: json['enableRealtimeGames'] as bool? ?? false,
      enableRealtimeLeaderboards: json['enableRealtimeLeaderboards'] as bool? ?? false,
      manualRefreshInterval: Duration(
        minutes: json['manualRefreshIntervalMinutes'] as int? ?? 5,
      ),
      mode: SyncMode.values.firstWhere(
        (mode) => mode.name == (json['mode'] as String?),
        orElse: () => SyncMode.balanced,
      ),
    );
  }

  /// Copy with modifications
  SyncSettings copyWith({
    bool? enableRealtimeDecks,
    bool? enableRealtimeGames,
    bool? enableRealtimeLeaderboards,
    Duration? manualRefreshInterval,
    SyncMode? mode,
  }) {
    return SyncSettings(
      enableRealtimeDecks: enableRealtimeDecks ?? this.enableRealtimeDecks,
      enableRealtimeGames: enableRealtimeGames ?? this.enableRealtimeGames,
      enableRealtimeLeaderboards: enableRealtimeLeaderboards ?? this.enableRealtimeLeaderboards,
      manualRefreshInterval: manualRefreshInterval ?? this.manualRefreshInterval,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncSettings &&
        other.enableRealtimeDecks == enableRealtimeDecks &&
        other.enableRealtimeGames == enableRealtimeGames &&
        other.enableRealtimeLeaderboards == enableRealtimeLeaderboards &&
        other.manualRefreshInterval == manualRefreshInterval &&
        other.mode == mode;
  }

  @override
  int get hashCode {
    return Object.hash(
      enableRealtimeDecks,
      enableRealtimeGames,
      enableRealtimeLeaderboards,
      manualRefreshInterval,
      mode,
    );
  }

  @override
  String toString() {
    return 'SyncSettings(mode: $mode, realtimeDecks: $enableRealtimeDecks, '
        'realtimeGames: $enableRealtimeGames, realtimeLeaderboards: $enableRealtimeLeaderboards, '
        'refreshInterval: ${manualRefreshInterval.inMinutes}min)';
  }
}

/// Sync mode presets
enum SyncMode {
  balanced,
  bestPerformance,
  reduceCosts,
  custom;

  String get displayName {
    switch (this) {
      case SyncMode.balanced:
        return 'Balanced';
      case SyncMode.bestPerformance:
        return 'Best Performance';
      case SyncMode.reduceCosts:
        return 'Reduce Costs';
      case SyncMode.custom:
        return 'Custom';
    }
  }

  String get description {
    switch (this) {
      case SyncMode.balanced:
        return 'Optimized for both cost and performance. Real-time updates during gameplay only.';
      case SyncMode.bestPerformance:
        return 'All real-time updates enabled. Higher data usage but immediate updates.';
      case SyncMode.reduceCosts:
        return 'Manual refresh for all data. Lowest data usage and Firebase costs.';
      case SyncMode.custom:
        return 'Customize which features use real-time updates.';
    }
  }

  /// Estimated monthly Firebase reads for 100 active sessions
  String get estimatedReads {
    switch (this) {
      case SyncMode.balanced:
        return '~10-20K reads/month';
      case SyncMode.bestPerformance:
        return '~100-150K reads/month';
      case SyncMode.reduceCosts:
        return '~2-5K reads/month';
      case SyncMode.custom:
        return 'Varies';
    }
  }
}

