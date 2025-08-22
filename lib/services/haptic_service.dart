import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _isVibrationEnabled = true;

  void setVibrationEnabled(bool enabled) {
    _isVibrationEnabled = enabled;
  }

  Future<void> lightImpact() async {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.lightImpact();
      await Vibration.vibrate(duration: 10, amplitude: 50);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> mediumImpact() async {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.mediumImpact();
      await Vibration.vibrate(duration: 20, amplitude: 100);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> heavyImpact() async {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.heavyImpact();
      await Vibration.vibrate(duration: 30, amplitude: 150);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> success() async {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.mediumImpact();
      await Vibration.vibrate(
        pattern: [0, 50, 30, 50],
        intensities: [0, 100, 0, 100],
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> warning() async {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.lightImpact();
      await Vibration.vibrate(duration: 15, amplitude: 75);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> error() async {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.heavyImpact();
      await Vibration.vibrate(
        pattern: [0, 100, 50, 100],
        intensities: [0, 150, 0, 150],
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> selection() async {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.selectionClick();
      await Vibration.vibrate(duration: 5, amplitude: 30);
    } catch (e) {
      // Handle error silently
    }
  }
}
