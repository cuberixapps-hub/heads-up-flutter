import 'package:flutter_vibrate/flutter_vibrate.dart';

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
      Vibrate.feedback(FeedbackType.light);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> mediumImpact() async {
    if (!_isVibrationEnabled) return;
    try {
      Vibrate.feedback(FeedbackType.medium);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> heavyImpact() async {
    if (!_isVibrationEnabled) return;
    try {
      Vibrate.feedback(FeedbackType.heavy);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> success() async {
    if (!_isVibrationEnabled) return;
    try {
      Vibrate.feedback(FeedbackType.success);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> warning() async {
    if (!_isVibrationEnabled) return;
    try {
      Vibrate.feedback(FeedbackType.warning);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> error() async {
    if (!_isVibrationEnabled) return;
    try {
      Vibrate.feedback(FeedbackType.error);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> selection() async {
    if (!_isVibrationEnabled) return;
    try {
      Vibrate.feedback(FeedbackType.selection);
    } catch (e) {
      // Handle error silently
    }
  }
}
