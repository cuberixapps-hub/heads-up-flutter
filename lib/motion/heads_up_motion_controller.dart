import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'motion_config.dart';
import 'motion_classifier.dart';

/// Main controller for Heads Up motion detection
///
/// This class manages sensor subscriptions, calibration, filtering,
/// and lifecycle. It provides a clean API for the game to use.
class HeadsUpMotionController {
  final MotionConfig config;
  final MotionClassifier _classifier;

  // Callbacks
  VoidCallback? _onCorrect;
  VoidCallback? _onPass;

  // Sensor subscriptions
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;
  StreamSubscription? _processedDataSubscription;

  // Stream controllers
  final _gestureController = StreamController<GestureEvent>.broadcast();
  final _accelController = StreamController<AccelerometerEvent>();
  final _gyroController = StreamController<GyroscopeEvent?>();

  // Calibration
  bool _isCalibrating = false;
  final List<_CalibrationSample> _calibrationSamples = [];

  // State
  bool _isActive = false;
  DateTime? _lastProcessTime;

  // Debug
  bool _debugMode = false;

  HeadsUpMotionController({MotionConfig? config})
      : config = config ?? const MotionConfig(),
        _classifier = MotionClassifier(config: config ?? const MotionConfig());

  /// Stream of gesture events
  Stream<GestureEvent> get gestureStream => _gestureController.stream;

  /// Get current motion state for diagnostics
  MotionState get currentState => _classifier.currentState;

  /// Get current pitch for diagnostics
  double get currentPitch => _classifier.currentPitch;

  /// Get relative pitch for diagnostics
  double get relativePitch => _classifier.relativePitch;

  /// Enable/disable debug mode
  set debugMode(bool value) => _debugMode = value;

  /// Start motion detection with callbacks
  Future<void> start({
    VoidCallback? onCorrect,
    VoidCallback? onPass,
  }) async {
    if (_isActive) return;

    _onCorrect = onCorrect;
    _onPass = onPass;
    _isActive = true;

    // Keep screen on during gameplay
    try {
      await WakelockPlus.enable();
    } catch (e) {
      if (_debugMode) {
        debugPrint('HeadsUpMotionController: Failed to enable wakelock - $e');
      }
    }

    // Start with calibration
    await _calibrate();

    // Set up sensor streams with throttling
    _setupSensorStreams();

    // Listen to gesture events
    gestureStream.listen((event) {
      _handleGesture(event);
    });

    if (_debugMode) {
      debugPrint('HeadsUpMotionController: Started');
    }
  }

  /// Stop motion detection
  Future<void> stop() async {
    if (!_isActive) return;

    _isActive = false;

    // Cancel subscriptions
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _processedDataSubscription?.cancel();

    // Reset classifier
    _classifier.reset();

    // Release wakelock
    try {
      await WakelockPlus.disable();
    } catch (e) {
      if (_debugMode) {
        debugPrint('HeadsUpMotionController: Failed to disable wakelock - $e');
      }
    }

    if (_debugMode) {
      debugPrint('HeadsUpMotionController: Stopped');
    }
  }

  /// Recalibrate sensors
  Future<void> recalibrate() async {
    if (!_isActive) return;
    await _calibrate();
  }

  /// Dispose of resources
  void dispose() {
    stop();
    _gestureController.close();
    _accelController.close();
    _gyroController.close();
  }

  // Private methods

  Future<void> _calibrate() async {
    _isCalibrating = true;
    _calibrationSamples.clear();

    if (_debugMode) {
      debugPrint('HeadsUpMotionController: Starting calibration...');
    }

    // Collect samples for calibration duration
    final calibrationStream = accelerometerEventStream()
        .take(config.calibrationMs ~/ 16) // Approximate 60Hz sampling
        .listen((event) {
      _calibrationSamples.add(_CalibrationSample(
        ax: event.x,
        ay: event.y,
        az: event.z,
        timestamp: DateTime.now(),
      ));
    });

    // Wait for calibration to complete
    await Future.delayed(Duration(milliseconds: config.calibrationMs));
    await calibrationStream.cancel();

    // Process calibration data
    if (_calibrationSamples.isNotEmpty) {
      // Calculate average pitch
      double sumPitch = 0.0;
      for (final sample in _calibrationSamples) {
        final pitchRad = math.atan2(-sample.ax,
            math.sqrt(sample.ay * sample.ay + sample.az * sample.az));
        final pitchDeg = pitchRad * 180 / math.pi;
        sumPitch += pitchDeg;
      }
      final avgPitch = sumPitch / _calibrationSamples.length;

      // Determine orientation sign
      // In landscape, we need to detect which way the phone is oriented
      // This is simplified - in production you might want to use device orientation API
      double orientationSign = 1.0;

      // Check if we're in landscape-left or landscape-right
      // by looking at the gravity vector
      final lastSample = _calibrationSamples.last;
      if (lastSample.ay.abs() > lastSample.ax.abs()) {
        // Gravity is mainly on Y axis, we're in landscape
        orientationSign = lastSample.ay > 0 ? 1.0 : -1.0;
      }

      final calibration = CalibrationData(
        neutralPitchDeg: avgPitch,
        orientationSign: orientationSign,
        timestamp: DateTime.now(),
      );

      _classifier.setCalibration(calibration);

      if (_debugMode) {
        debugPrint('HeadsUpMotionController: Calibration complete');
        debugPrint('  Neutral pitch: ${avgPitch.toStringAsFixed(1)}°');
        debugPrint('  Orientation sign: $orientationSign');
      }
    }

    _isCalibrating = false;
  }

  void _setupSensorStreams() {
    // Set up accelerometer stream
    _accelerometerSubscription = accelerometerEventStream()
        .throttleTime(Duration(milliseconds: 1000 ~/ config.throttleHz))
        .listen((event) {
      _accelController.add(event);
    });

    // Set up gyroscope stream (optional)
    _gyroscopeSubscription = gyroscopeEventStream()
        .throttleTime(Duration(milliseconds: 1000 ~/ config.throttleHz))
        .listen((event) {
      _gyroController.add(event);
    }, onError: (_) {
      // Gyroscope not available
      _gyroController.add(null);
    });

    // Combine streams and process
    _processedDataSubscription = Rx.combineLatest2(
      _accelController.stream,
      _gyroController.stream,
      (AccelerometerEvent accel, GyroscopeEvent? gyro) {
        return _ProcessedSensorData(
          accel: accel,
          gyro: gyro,
          timestamp: DateTime.now(),
        );
      },
    ).listen((data) {
      _processSensorData(data);
    });
  }

  void _processSensorData(_ProcessedSensorData data) {
    if (!_isActive || _isCalibrating) return;

    final now = data.timestamp;

    // Throttle processing if needed
    if (_lastProcessTime != null) {
      final elapsed = now.difference(_lastProcessTime!).inMilliseconds;
      if (elapsed < 1000 / config.throttleHz) return;
    }
    _lastProcessTime = now;

    // Feed to classifier
    GestureEvent? event;

    if (config.useZAxisFallback) {
      event = _classifier.feedZAxis(z: data.accel.z, timestamp: now);
    } else {
      event = _classifier.feed(
        ax: data.accel.x,
        ay: data.accel.y,
        az: data.accel.z,
        gx: data.gyro?.x,
        gy: data.gyro?.y,
        gz: data.gyro?.z,
        timestamp: now,
      );
    }

    // Emit event if detected
    if (event != null) {
      _gestureController.add(event);
    }
  }

  void _handleGesture(GestureEvent event) {
    if (_debugMode) {
      debugPrint('HeadsUpMotionController: Gesture detected - ${event.type}');
    }

    // Haptic feedback
    _triggerHaptic();

    // Call appropriate callback
    switch (event.type) {
      case GestureType.correct:
        _onCorrect?.call();
        break;
      case GestureType.pass:
        _onPass?.call();
        break;
    }
  }

  Future<void> _triggerHaptic() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // iOS: Use system haptics
          HapticFeedback.lightImpact();
        } else {
          // Android: Use vibration
          Vibration.vibrate(duration: 30);
        }
      }
    } catch (e) {
      if (_debugMode) {
        debugPrint('HeadsUpMotionController: Haptic feedback failed - $e');
      }
    }
  }
}

// Internal data classes

class _CalibrationSample {
  final double ax, ay, az;
  final DateTime timestamp;

  _CalibrationSample({
    required this.ax,
    required this.ay,
    required this.az,
    required this.timestamp,
  });
}

class _ProcessedSensorData {
  final AccelerometerEvent accel;
  final GyroscopeEvent? gyro;
  final DateTime timestamp;

  _ProcessedSensorData({
    required this.accel,
    required this.gyro,
    required this.timestamp,
  });
}
