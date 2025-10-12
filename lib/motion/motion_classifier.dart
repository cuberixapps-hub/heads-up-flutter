import 'dart:math' as math;
import 'motion_config.dart';

/// Gesture types that can be detected
enum GestureType { correct, pass }

/// States of the motion detection state machine
enum MotionState { neutral, fwdPending, backPending, cooldown }

/// Event emitted when a gesture is detected
class GestureEvent {
  final GestureType type;
  final DateTime timestamp;

  const GestureEvent({
    required this.type,
    required this.timestamp,
  });
}

/// Calibration data for motion detection
class CalibrationData {
  final double neutralPitchDeg;
  final double orientationSign;
  final DateTime timestamp;

  const CalibrationData({
    required this.neutralPitchDeg,
    required this.orientationSign,
    required this.timestamp,
  });
}

/// Pure logic motion classifier using state machine
///
/// This class implements the core motion detection logic without
/// any platform-specific dependencies. It processes sensor data
/// and emits gesture events based on the configured thresholds.
class MotionClassifier {
  final MotionConfig config;

  // State machine
  MotionState _state = MotionState.neutral;
  DateTime? _stateEnteredAt;
  DateTime? _cooldownStartedAt;

  // Calibration
  CalibrationData? _calibration;

  // Smoothing
  double _smoothedPitch = 0.0;

  // Debug data
  final List<_SensorSample> _recentSamples = [];
  static const int _maxSamples = 100;

  MotionClassifier({required this.config});

  /// Set calibration data
  void setCalibration(CalibrationData calibration) {
    _calibration = calibration;
    _resetState();
  }

  /// Feed sensor data and get potential gesture event
  GestureEvent? feed({
    required double ax,
    required double ay,
    required double az,
    double? gx,
    double? gy,
    double? gz,
    required DateTime timestamp,
  }) {
    // Store sample for diagnostics
    _addSample(
        ax: ax, ay: ay, az: az, gx: gx, gy: gy, gz: gz, timestamp: timestamp);

    // Can't process without calibration
    if (_calibration == null) return null;

    // Calculate pitch from accelerometer
    final pitchRad = math.atan2(-ax, math.sqrt(ay * ay + az * az));
    final pitchDeg = pitchRad * 180 / math.pi;

    // Apply orientation sign from calibration
    final orientedPitch = pitchDeg * _calibration!.orientationSign;

    // Apply low-pass filter
    _smoothedPitch = config.lpfAlpha * orientedPitch +
        (1 - config.lpfAlpha) * _smoothedPitch;

    // Calculate relative pitch from neutral
    final pitchRel = _smoothedPitch - _calibration!.neutralPitchDeg;

    // Process gyroscope if available
    final gyroY = gy != null ? gy * _calibration!.orientationSign : 0.0;

    // Run state machine
    return _processStateMachine(pitchRel, gyroY, timestamp);
  }

  /// Process Z-axis fallback mode
  GestureEvent? feedZAxis({
    required double z,
    required DateTime timestamp,
  }) {
    if (!config.useZAxisFallback) return null;

    // In Z-axis mode, we use raw Z values with hysteresis
    return _processStateMachineZAxis(z, timestamp);
  }

  /// Get current state for diagnostics
  MotionState get currentState => _state;

  /// Get current pitch for diagnostics
  double get currentPitch => _smoothedPitch;

  /// Get relative pitch for diagnostics
  double get relativePitch => _calibration != null
      ? _smoothedPitch - _calibration!.neutralPitchDeg
      : 0.0;

  /// Get recent samples for diagnostics
  List<Map<String, dynamic>> get recentSamples => _recentSamples
      .map((s) => {
            'timestamp': s.timestamp.toIso8601String(),
            'ax': s.ax,
            'ay': s.ay,
            'az': s.az,
            'gx': s.gx,
            'gy': s.gy,
            'gz': s.gz,
          })
      .toList();

  /// Reset to neutral state
  void reset() {
    _resetState();
  }

  // Private methods

  void _resetState() {
    _state = MotionState.neutral;
    _stateEnteredAt = null;
    _cooldownStartedAt = null;
  }

  GestureEvent? _processStateMachine(
      double pitchRel, double gyroY, DateTime timestamp) {
    switch (_state) {
      case MotionState.neutral:
        if (pitchRel <= config.forwardEnterDeg && _allowEntryForward(gyroY)) {
          _enterState(MotionState.fwdPending, timestamp);
        } else if (pitchRel >= config.backEnterDeg && _allowEntryBack(gyroY)) {
          _enterState(MotionState.backPending, timestamp);
        }
        break;

      case MotionState.fwdPending:
        if (pitchRel > config.forwardExitDeg) {
          _enterState(MotionState.neutral, timestamp);
        } else if (_elapsedInState(timestamp) >= config.holdMs) {
          return _fireGesture(GestureType.correct, timestamp);
        }
        break;

      case MotionState.backPending:
        if (pitchRel < config.backExitDeg) {
          _enterState(MotionState.neutral, timestamp);
        } else if (_elapsedInState(timestamp) >= config.holdMs) {
          return _fireGesture(GestureType.pass, timestamp);
        }
        break;

      case MotionState.cooldown:
        final cooldownElapsed =
            timestamp.difference(_cooldownStartedAt!).inMilliseconds;
        if (cooldownElapsed >= config.cooldownMs &&
            _isInNeutralBand(pitchRel)) {
          _enterState(MotionState.neutral, timestamp);
        }
        break;
    }

    return null;
  }

  GestureEvent? _processStateMachineZAxis(double z, DateTime timestamp) {
    // Similar state machine but using Z-axis thresholds
    switch (_state) {
      case MotionState.neutral:
        if (z <= config.forwardEnterZ) {
          _enterState(MotionState.fwdPending, timestamp);
        } else if (z >= config.backEnterZ) {
          _enterState(MotionState.backPending, timestamp);
        }
        break;

      case MotionState.fwdPending:
        if (z > config.forwardExitZ) {
          _enterState(MotionState.neutral, timestamp);
        } else if (_elapsedInState(timestamp) >= config.holdMs) {
          return _fireGesture(GestureType.correct, timestamp);
        }
        break;

      case MotionState.backPending:
        if (z < config.backExitZ) {
          _enterState(MotionState.neutral, timestamp);
        } else if (_elapsedInState(timestamp) >= config.holdMs) {
          return _fireGesture(GestureType.pass, timestamp);
        }
        break;

      case MotionState.cooldown:
        final cooldownElapsed =
            timestamp.difference(_cooldownStartedAt!).inMilliseconds;
        final isNeutralZ = z > config.forwardExitZ && z < config.backExitZ;
        if (cooldownElapsed >= config.cooldownMs && isNeutralZ) {
          _enterState(MotionState.neutral, timestamp);
        }
        break;
    }

    return null;
  }

  void _enterState(MotionState newState, DateTime timestamp) {
    _state = newState;
    _stateEnteredAt = timestamp;
  }

  int _elapsedInState(DateTime now) {
    if (_stateEnteredAt == null) return 0;
    return now.difference(_stateEnteredAt!).inMilliseconds;
  }

  bool _allowEntryForward(double gyroY) {
    if (!config.requireGyroForEnter) return true;
    return gyroY <= -config.gyroMinDps;
  }

  bool _allowEntryBack(double gyroY) {
    if (!config.requireGyroForEnter) return true;
    return gyroY >= config.gyroMinDps;
  }

  bool _isInNeutralBand(double pitchRel) {
    return pitchRel > -config.backExitDeg && pitchRel < config.backExitDeg;
  }

  GestureEvent _fireGesture(GestureType type, DateTime timestamp) {
    _state = MotionState.cooldown;
    _cooldownStartedAt = timestamp;
    _stateEnteredAt = timestamp;

    return GestureEvent(type: type, timestamp: timestamp);
  }

  void _addSample({
    required double ax,
    required double ay,
    required double az,
    double? gx,
    double? gy,
    double? gz,
    required DateTime timestamp,
  }) {
    _recentSamples.add(_SensorSample(
      ax: ax,
      ay: ay,
      az: az,
      gx: gx,
      gy: gy,
      gz: gz,
      timestamp: timestamp,
    ));

    // Keep only recent samples
    while (_recentSamples.length > _maxSamples) {
      _recentSamples.removeAt(0);
    }
  }
}

// Internal sample storage
class _SensorSample {
  final double ax, ay, az;
  final double? gx, gy, gz;
  final DateTime timestamp;

  _SensorSample({
    required this.ax,
    required this.ay,
    required this.az,
    this.gx,
    this.gy,
    this.gz,
    required this.timestamp,
  });
}
