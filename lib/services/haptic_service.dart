import 'package:flutter/services.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _isHapticEnabled = true;

  void setHapticEnabled(bool enabled) {
    _isHapticEnabled = enabled;
  }

  /// Fire a single haptic without awaiting — guarantees the platform channel
  /// message is dispatched immediately and never blocked by a prior pattern.
  void _fire(Future<void> Function() haptic) {
    if (!_isHapticEnabled) return;
    haptic().catchError((_) {});
  }

  void lightImpact() => _fire(HapticFeedback.lightImpact);

  void mediumImpact() => _fire(HapticFeedback.mediumImpact);

  void heavyImpact() => _fire(HapticFeedback.heavyImpact);

  void success() => _fire(HapticFeedback.mediumImpact);

  void warning() => _fire(HapticFeedback.lightImpact);

  void error() => _fire(HapticFeedback.heavyImpact);

  void selection() => _fire(HapticFeedback.selectionClick);

  /// CORRECT answer — single strong impact that fires instantly during gameplay.
  /// Multi-step patterns get swallowed by rapid sensor-driven actions because
  /// the platform channel coalesces calls that arrive while a previous
  /// Future.delayed chain is still in flight.
  void correctAnswer() => _fire(HapticFeedback.heavyImpact);

  /// PASS answer — single medium impact, distinct from correct.
  void passAnswer() => _fire(HapticFeedback.mediumImpact);

  /// Streak bonus (3+ consecutive corrects) — double heavy tap.
  void streakBonus() {
    if (!_isHapticEnabled) return;
    HapticFeedback.heavyImpact().catchError((_) {});
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.heavyImpact().catchError((_) {});
    });
  }

  /// Time running low — quick double medium pulse.
  void timeWarning() {
    if (!_isHapticEnabled) return;
    HapticFeedback.mediumImpact().catchError((_) {});
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.mediumImpact().catchError((_) {});
    });
  }

  void countdown() => _fire(HapticFeedback.mediumImpact);

  /// Game start — heavy burst.
  void gameStart() => _fire(HapticFeedback.heavyImpact);

  /// Game end — conclusive double heavy.
  void gameEnd() {
    if (!_isHapticEnabled) return;
    HapticFeedback.heavyImpact().catchError((_) {});
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact().catchError((_) {});
    });
  }
}
