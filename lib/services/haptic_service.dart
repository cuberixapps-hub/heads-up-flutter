import 'package:flutter/services.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _isHapticEnabled = true;

  void setHapticEnabled(bool enabled) {
    _isHapticEnabled = enabled;
  }

  Future<void> lightImpact() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> mediumImpact() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> heavyImpact() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> success() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> warning() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> error() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> selection() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for CORRECT answer - elegant celebratory crescendo
  /// Creates an emotionally satisfying "achievement unlocked" sensation
  /// Pattern: soft → medium → STRONG → soft fade (like a heartbeat of joy)
  Future<void> correctAnswer() async {
    if (!_isHapticEnabled) return;
    try {
      // 1. Soft anticipation pulse
      await HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 40));

      // 2. Building medium pulse
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 60));

      // 3. STRONG celebratory peak - the "YES!" moment
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));

      // 4. Satisfying resolution pulse
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));

      // 5. Gentle fade out - elegant finish
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for PASS - swift elegant dismissal
  /// Creates a refined "moving on" sensation - not punishing, just decisive
  /// Pattern: quick double-tap with descending intensity (like brushing away)
  Future<void> passAnswer() async {
    if (!_isHapticEnabled) return;
    try {
      // 1. Quick decisive first tap
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 45));

      // 2. Lighter follow-up - the "swoosh" feeling
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 35));

      // 3. Subtle final whisper - smooth exit
      await HapticFeedback.selectionClick();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for streak bonus - extra celebration for consecutive corrects
  /// Use this after 3+ correct answers in a row
  Future<void> streakBonus() async {
    if (!_isHapticEnabled) return;
    try {
      // Rapid ascending celebration burst
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 30));
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 30));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 40));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for time running low - urgent but elegant pulse
  Future<void> timeWarning() async {
    if (!_isHapticEnabled) return;
    try {
      // Quick attention-grabbing double pulse
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for game countdown - building anticipation
  Future<void> countdown() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for game start - exciting burst
  Future<void> gameStart() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for game end - conclusive finish
  Future<void> gameEnd() async {
    if (!_isHapticEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Handle error silently
    }
  }
}
