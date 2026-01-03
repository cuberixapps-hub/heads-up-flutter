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

  /// Premium haptic for CORRECT answer - celebratory double pulse
  /// Creates a satisfying "ta-DUM" feeling like a victory confirmation
  Future<void> correctAnswer() async {
    if (!_isHapticEnabled) return;
    try {
      // First pulse - medium impact (the "ta")
      await HapticFeedback.mediumImpact();
      // Short pause for rhythm
      await Future.delayed(const Duration(milliseconds: 80));
      // Second pulse - heavy impact (the "DUM" - stronger, celebratory)
      await HapticFeedback.heavyImpact();
      // Optional third subtle pulse for extra satisfaction
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Premium haptic for PASS - quick dismissive double tap
  /// Creates a "skip-skip" feeling that's distinct but not punishing
  Future<void> passAnswer() async {
    if (!_isHapticEnabled) return;
    try {
      // Quick double tap pattern - feels like a "nope, next!"
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 60));
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
