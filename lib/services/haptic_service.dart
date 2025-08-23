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
}
