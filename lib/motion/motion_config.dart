/// Configuration for Heads Up motion detection
///
/// This class contains all tunable parameters for the motion detection system.
/// Default values are optimized for typical gameplay, but can be adjusted
/// based on testing and user feedback.
class MotionConfig {
  // Angle thresholds (in degrees)
  final double forwardEnterDeg;
  final double forwardExitDeg;
  final double backEnterDeg;
  final double backExitDeg;

  // Time thresholds (in milliseconds)
  final int holdMs;
  final int cooldownMs;

  // Sensor processing
  final int throttleHz;
  final double lpfAlpha;

  // Optional gyroscope support
  final double gyroMinDps;
  final bool requireGyroForEnter;

  // Fallback mode
  final bool useZAxisFallback;

  // Z-axis thresholds for fallback mode (m/s²)
  final double forwardEnterZ;
  final double forwardExitZ;
  final double backEnterZ;
  final double backExitZ;

  // Calibration
  final int calibrationMs;

  const MotionConfig({
    // Angle thresholds
    this.forwardEnterDeg = -28.0,
    this.forwardExitDeg = -18.0,
    this.backEnterDeg = 28.0,
    this.backExitDeg = 18.0,

    // Time thresholds
    this.holdMs = 120,
    this.cooldownMs = 700,

    // Sensor processing
    this.throttleHz = 60,
    this.lpfAlpha = 0.20,

    // Gyroscope
    this.gyroMinDps = 35.0,
    this.requireGyroForEnter = false,

    // Fallback mode
    this.useZAxisFallback = false,

    // Z-axis thresholds
    this.forwardEnterZ = -7.0,
    this.forwardExitZ = -5.0,
    this.backEnterZ = 7.0,
    this.backExitZ = 5.0,

    // Calibration
    this.calibrationMs = 500,
  });

  /// Create a config optimized for low-end devices with noisy sensors
  factory MotionConfig.lowEnd() {
    return const MotionConfig(
      holdMs: 150, // Require longer hold
      lpfAlpha: 0.15, // More aggressive filtering
      gyroMinDps: 45.0, // Higher gyro threshold
    );
  }

  /// Create a config for testing with more lenient thresholds
  factory MotionConfig.testing() {
    return const MotionConfig(
      forwardEnterDeg: -20.0,
      forwardExitDeg: -12.0,
      backEnterDeg: 20.0,
      backExitDeg: 12.0,
      holdMs: 80,
      cooldownMs: 500,
    );
  }

  /// Copy with modifications
  MotionConfig copyWith({
    double? forwardEnterDeg,
    double? forwardExitDeg,
    double? backEnterDeg,
    double? backExitDeg,
    int? holdMs,
    int? cooldownMs,
    int? throttleHz,
    double? lpfAlpha,
    double? gyroMinDps,
    bool? requireGyroForEnter,
    bool? useZAxisFallback,
    double? forwardEnterZ,
    double? forwardExitZ,
    double? backEnterZ,
    double? backExitZ,
    int? calibrationMs,
  }) {
    return MotionConfig(
      forwardEnterDeg: forwardEnterDeg ?? this.forwardEnterDeg,
      forwardExitDeg: forwardExitDeg ?? this.forwardExitDeg,
      backEnterDeg: backEnterDeg ?? this.backEnterDeg,
      backExitDeg: backExitDeg ?? this.backExitDeg,
      holdMs: holdMs ?? this.holdMs,
      cooldownMs: cooldownMs ?? this.cooldownMs,
      throttleHz: throttleHz ?? this.throttleHz,
      lpfAlpha: lpfAlpha ?? this.lpfAlpha,
      gyroMinDps: gyroMinDps ?? this.gyroMinDps,
      requireGyroForEnter: requireGyroForEnter ?? this.requireGyroForEnter,
      useZAxisFallback: useZAxisFallback ?? this.useZAxisFallback,
      forwardEnterZ: forwardEnterZ ?? this.forwardEnterZ,
      forwardExitZ: forwardExitZ ?? this.forwardExitZ,
      backEnterZ: backEnterZ ?? this.backEnterZ,
      backExitZ: backExitZ ?? this.backExitZ,
      calibrationMs: calibrationMs ?? this.calibrationMs,
    );
  }
}
