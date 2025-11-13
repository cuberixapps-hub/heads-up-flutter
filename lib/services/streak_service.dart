import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StreakService {
  static const String _playHistoryKey = 'play_history';
  static const String _lastPlayDateKey = 'last_play_date';
  static const String _currentStreakKey = 'current_streak';
  static const String _longestStreakKey = 'longest_streak';
  static const String _totalGamesPlayedKey = 'total_games_played';

  // Get current streak count
  Future<int> getCurrentStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPlayDateStr = prefs.getString(_lastPlayDateKey);
      
      if (lastPlayDateStr == null) {
        return 0;
      }

      final lastPlayDate = DateTime.parse(lastPlayDateStr);
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final lastPlayDay = DateTime(lastPlayDate.year, lastPlayDate.month, lastPlayDate.day);
      final todayDay = DateTime(today.year, today.month, today.day);

      // If last play was today, return current streak
      if (lastPlayDay == todayDay) {
        return prefs.getInt(_currentStreakKey) ?? 1;
      }
      
      // If last play was yesterday, streak continues
      if (lastPlayDay == yesterday) {
        return prefs.getInt(_currentStreakKey) ?? 1;
      }
      
      // Otherwise, streak is broken
      return 0;
    } catch (e) {
      debugPrint('Error getting current streak: $e');
      return 0;
    }
  }

  // Record a play for today
  Future<void> recordPlay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = _dateToString(today);
      
      // Get play history
      final playHistory = await getPlayHistory();
      
      // Check if already played today
      if (playHistory.contains(todayStr)) {
        return; // Already recorded for today
      }
      
      // Add today to play history
      playHistory.add(todayStr);
      
      // Keep only last 365 days
      if (playHistory.length > 365) {
        playHistory.removeAt(0);
      }
      
      // Calculate new streak
      final currentStreak = await _calculateStreak(playHistory);
      
      // Update longest streak if needed
      final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
      if (currentStreak > longestStreak) {
        await prefs.setInt(_longestStreakKey, currentStreak);
      }
      
      // Update total games played
      final totalGames = prefs.getInt(_totalGamesPlayedKey) ?? 0;
      await prefs.setInt(_totalGamesPlayedKey, totalGames + 1);
      
      // Save everything
      await prefs.setString(_playHistoryKey, jsonEncode(playHistory));
      await prefs.setString(_lastPlayDateKey, today.toIso8601String());
      await prefs.setInt(_currentStreakKey, currentStreak);
      
      debugPrint('✅ Play recorded - Streak: $currentStreak');
    } catch (e) {
      debugPrint('Error recording play: $e');
    }
  }

  // Get play history (list of date strings)
  Future<List<String>> getPlayHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_playHistoryKey);
      
      if (historyJson == null) {
        return [];
      }
      
      return List<String>.from(jsonDecode(historyJson));
    } catch (e) {
      debugPrint('Error getting play history: $e');
      return [];
    }
  }

  // Get weekly progress (last 7 days)
  Future<List<bool>> getWeeklyProgress() async {
    try {
      final playHistory = await getPlayHistory();
      final weekProgress = <bool>[];
      final today = DateTime.now();
      
      for (int i = 6; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        final dayStr = _dateToString(day);
        weekProgress.add(playHistory.contains(dayStr));
      }
      
      return weekProgress;
    } catch (e) {
      debugPrint('Error getting weekly progress: $e');
      return List.filled(7, false);
    }
  }

  // Check if played today
  Future<bool> hasPlayedToday() async {
    try {
      final playHistory = await getPlayHistory();
      final todayStr = _dateToString(DateTime.now());
      return playHistory.contains(todayStr);
    } catch (e) {
      debugPrint('Error checking if played today: $e');
      return false;
    }
  }

  // Get achievement milestone info
  Future<StreakMilestone?> getNextMilestone() async {
    final currentStreak = await getCurrentStreak();
    
    const milestones = [
      StreakMilestone(days: 3, name: 'Getting Started', icon: '🔥'),
      StreakMilestone(days: 7, name: 'Week Warrior', icon: '🎯'),
      StreakMilestone(days: 14, name: 'Consistent Player', icon: '💪'),
      StreakMilestone(days: 30, name: 'Monthly Master', icon: '🏆'),
      StreakMilestone(days: 50, name: 'Dedicated Gamer', icon: '⭐'),
      StreakMilestone(days: 100, name: 'Century Club', icon: '💯'),
    ];
    
    // Find next milestone
    for (final milestone in milestones) {
      if (currentStreak < milestone.days) {
        return milestone;
      }
    }
    
    return null; // All milestones achieved
  }

  // Get achievement status
  Future<List<AchievementStatus>> getAchievements() async {
    final currentStreak = await getCurrentStreak();
    final longestStreak = await getLongestStreak();
    
    const milestones = [
      StreakMilestone(days: 3, name: 'Getting Started', icon: '🔥'),
      StreakMilestone(days: 7, name: 'Week Warrior', icon: '🎯'),
      StreakMilestone(days: 14, name: 'Consistent Player', icon: '💪'),
      StreakMilestone(days: 30, name: 'Monthly Master', icon: '🏆'),
      StreakMilestone(days: 50, name: 'Dedicated Gamer', icon: '⭐'),
      StreakMilestone(days: 100, name: 'Century Club', icon: '💯'),
    ];
    
    return milestones.map((milestone) {
      final isAchieved = longestStreak >= milestone.days;
      final progress = currentStreak / milestone.days;
      
      return AchievementStatus(
        milestone: milestone,
        isAchieved: isAchieved,
        progress: progress.clamp(0.0, 1.0),
        isActive: currentStreak >= milestone.days,
      );
    }).toList();
  }

  // Get longest streak
  Future<int> getLongestStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_longestStreakKey) ?? 0;
    } catch (e) {
      debugPrint('Error getting longest streak: $e');
      return 0;
    }
  }

  // Get total games played
  Future<int> getTotalGamesPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_totalGamesPlayedKey) ?? 0;
    } catch (e) {
      debugPrint('Error getting total games: $e');
      return 0;
    }
  }

  // Clear all streak data (for testing)
  Future<void> clearStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_playHistoryKey);
      await prefs.remove(_lastPlayDateKey);
      await prefs.remove(_currentStreakKey);
      await prefs.remove(_longestStreakKey);
      await prefs.remove(_totalGamesPlayedKey);
      debugPrint('🧹 Streak data cleared');
    } catch (e) {
      debugPrint('Error clearing streak data: $e');
    }
  }

  // Private helper methods

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<int> _calculateStreak(List<String> playHistory) async {
    if (playHistory.isEmpty) return 0;
    
    // Sort dates in descending order
    final sortedDates = playHistory.map((dateStr) {
      final parts = dateStr.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList()
      ..sort((a, b) => b.compareTo(a));
    
    int streak = 1;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Check if the most recent date is today or yesterday
    final mostRecent = sortedDates[0];
    final yesterday = todayDate.subtract(const Duration(days: 1));
    
    if (mostRecent != todayDate && mostRecent != yesterday) {
      return 0; // Streak is broken
    }
    
    // Count consecutive days
    for (int i = 1; i < sortedDates.length; i++) {
      final currentDate = sortedDates[i];
      final prevDate = sortedDates[i - 1];
      
      final difference = prevDate.difference(currentDate).inDays;
      
      if (difference == 1) {
        streak++;
      } else {
        break; // Streak is broken
      }
    }
    
    return streak;
  }
}

// Data models
class StreakMilestone {
  final int days;
  final String name;
  final String icon;

  const StreakMilestone({
    required this.days,
    required this.name,
    required this.icon,
  });
}

class AchievementStatus {
  final StreakMilestone milestone;
  final bool isAchieved;
  final double progress;
  final bool isActive;

  const AchievementStatus({
    required this.milestone,
    required this.isAchieved,
    required this.progress,
    required this.isActive,
  });
}

