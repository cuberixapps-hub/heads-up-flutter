import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../constants/app_theme.dart';
import '../models/deck.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../services/video_processing_manager.dart';
import 'results_screen.dart';
import 'team_results_screen.dart';
import '../services/camera_recording_service.dart';
import '../models/video_recording_result.dart';
import '../utils/responsive.dart';
import '../config/environment.dart';

class GameplayScreen extends StatefulWidget {
  final Deck deck;
  final bool isTeamMode;
  final List<String>? teamNames;
  final int? currentTeamIndex;

  const GameplayScreen({
    super.key,
    required this.deck,
    this.isTeamMode = false,
    this.teamNames,
    this.currentTeamIndex,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin {
  // Services
  final _audioService = AudioService();
  final _hapticService = HapticService();

  /// Helper to get a contrasted text color for yellow colors on light backgrounds.
  /// Yellow colors have poor visibility on white/light backgrounds, so we darken them.
  Color _getContrastedTextColor(Color color) {
    // Check if the color is in the yellow range
    // Yellow hue is approximately 40-70 degrees in HSL
    final hslColor = HSLColor.fromColor(color);
    final hue = hslColor.hue;
    final saturation = hslColor.saturation;

    // Detect yellow colors (hue 40-70)
    final isYellow = hue >= 40 && hue <= 70;

    if (isYellow) {
      // Return a much darker version of yellow for text visibility
      // Use a dark brown/amber color that maintains the yellow feel
      return HSLColor.fromAHSL(
        1.0,
        hue,
        saturation.clamp(0.6, 1.0), // Keep saturation high
        0.25, // Very dark lightness for strong contrast on white
      ).toColor();
    }

    // For non-yellow colors, return as-is
    return color;
  }

  /// Get a contrasted color for decorative elements (badges, borders) for yellow
  Color _getContrastedDecorationColor(Color color) {
    final hslColor = HSLColor.fromColor(color);
    final hue = hslColor.hue;
    final saturation = hslColor.saturation;

    // Detect yellow colors
    final isYellow = hue >= 40 && hue <= 70;

    if (isYellow) {
      // Return a moderately darker version for decorations
      return HSLColor.fromAHSL(
        1.0,
        hue,
        saturation.clamp(0.7, 1.0),
        0.35, // Darker but not as dark as text
      ).toColor();
    }

    return color;
  }

  // Animations
  late AnimationController _countdownController;
  late AnimationController _countdownPulseController;
  late AnimationController _countdownRingController;
  late AnimationController _countdownBlurController;
  late AnimationController _cardFlipController;
  late AnimationController _cardExitController;
  late AnimationController _cardEnterController;
  late AnimationController _feedbackController;
  late AnimationController _feedbackBurstController;
  late AnimationController _timerPulseController;
  late AnimationController _backgroundAnimController;
  late AnimationController _glowController;

  // ── Sensor-based tilt detection (ΔZ for CORRECT/PASS, ΔY as orientation guard) ──
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  StreamSubscription<AccelerometerEvent>? _calibrationSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  static const _sensorSamplingPeriod = Duration(milliseconds: 20);

  // ── Thresholds ──
  static const _smoothingAlpha =
      0.15; // EMA smoothing factor (lower = smoother)
  static const _tiltTriggerThreshold =
      5.0; // ΔZ must exceed this for CORRECT/PASS
  static const _returnThreshold =
      2.5; // ΔZ must be within this to count as "neutral"
  static const _orientationGuardThreshold =
      5.0; // if |ΔY| > this, phone is NOT in landscape → ignore
  static const _cooldownMs = 400; // minimum ms between two actions
  static const _returnStableSamplesRequired =
      8; // consecutive neutral samples before unlocking
  static const _waitingTimeoutMs =
      2000; // watchdog: force-clear waitingForReturn after this
  static const _calibrationStableThreshold =
      3.0; // |rawY| must be below this for calibration to accept samples
  static const _calibrationVerticalThreshold =
      5.0; // |rawX| must exceed this — ensures phone is upright, not flat
  static const _baselineDriftAlpha =
      0.005; // very slow EMA to correct persistent sensor bias in _calZ
  static const _baselineDriftZone =
      3.0; // only drift-correct when |smoothedΔZ| is within this zone

  // Raw accelerometer values (for debug overlay)
  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;

  // Raw gyroscope values (for debug overlay)
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;

  // Computed values (for debug overlay)
  double _gravityMag = 0.0;

  // Calibration baseline
  double _calX = 0.0, _calY = 0.0, _calZ = 0.0;
  bool _isCalibrated = false;

  // Smoothed ΔZ for trigger detection
  double _smoothedDeltaZ = 0.0;

  // State machine
  bool _waitingForReturn = false;
  bool _actionLocked = false;
  DateTime? _lastActionTime;
  int _returnStableCount = 0;
  bool _animationComplete = false;
  bool _returnComplete = false;
  DateTime? _waitingStartTime;

  // Debug status string for overlay
  String _sensorState = 'INIT';

  // Game state
  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;

  // Feedback state
  Color _feedbackColor = Colors.transparent;

  // Card action animation state
  bool _isCorrectAction = false;
  bool _isPassAction = false;

  // Control mode
  bool _useManualControls = false;

  // Camera recording
  final _cameraRecording = CameraRecordingService.instance;
  bool _isCameraEnabled = false;
  bool _isRecordingVideo = false;
  bool _isNavigating = false;

  // Streak tracking for premium haptics
  int _currentStreak = 0;
  static const _streakThreshold = 3; // Trigger bonus haptic after 3 corrects

  // Time warning haptic tracking
  bool _hasTriggeredTimeWarning = false;
  int _lastRemainingTime = -1;

  @override
  void initState() {
    super.initState();

    // Cancel any previous video processing from a previous game session
    // This ensures video generation doesn't continue when starting a new game
    VideoProcessingManager.instance.cancelCurrentProcessing(
      reason: 'New game started',
    );

    // Lock to a SINGLE landscape direction for the entire gameplay session.
    // Allowing both landscapeLeft + landscapeRight causes iOS/Android to jitter
    // between the two on small physical movements, triggering rebuilds and
    // recalibration at bad moments, which breaks sensor consistency.
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);

    // Keep screen awake during gameplay — user doesn't touch the screen (hands-free)
    WakelockPlus.enable();

    _initializeAnimations();
    _checkPreferredOrientation();
    _checkCameraPreference();
    _startCountdown();

    // Listen for game state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = context.read<GameProvider>();
      gameProvider.addListener(_checkGameState);
    });
  }

  void _checkGameState() {
    if (!mounted) return;
    final gameProvider = context.read<GameProvider>();
    if (!gameProvider.isGameActive &&
        !_isNavigating &&
        _countdownController.isCompleted) {
      // Game ended via timer/provider

      // Delay slightly to ensure proper cleanup
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted && !_isNavigating) {
          await _navigateToResults();
        }
      });
    }
  }

  Future<void> _checkPreferredOrientation() async {
    final prefs = await SharedPreferences.getInstance();
    _useManualControls = prefs.getBool('use_manual_controls') ?? false;

    // Reinforce single-landscape lock (in case initState wasn't enough)
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
  }

  Future<void> _checkCameraPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isCameraEnabled = prefs.getBool('enable_reaction_recording') ?? true;

    // Pre-initialize camera during countdown so it's ready when game starts.
    // This eliminates the delay between game start and recording start,
    // keeping the camera video and game overlay in sync.
    // Permissions are handled by GameplayPermissionsScreen before reaching here.
    if (_isCameraEnabled) {
      _cameraRecording.initialize().then((success) {
        if (!success && mounted) {
          _isCameraEnabled = false;
        }
      });
    }
  }

  void _initializeAnimations() {
    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _countdownPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _countdownRingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _countdownBlurController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _cardFlipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _cardExitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _cardEnterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _feedbackBurstController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _timerPulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _backgroundAnimController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _startCountdown() {
    // Play sound for initial "3" and trigger all animations
    _audioService.playCountdown();
    _hapticService.mediumImpact();

    // Start all countdown animations simultaneously
    _countdownController.forward(from: 0);
    _countdownPulseController.forward(from: 0);
    _countdownRingController.forward(from: 0);
    _countdownBlurController.forward(from: 0).then((_) {
      _countdownBlurController.reverse();
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
        });
        // Reset and restart all animations for each number
        _countdownController.forward(from: 0);
        _countdownPulseController.forward(from: 0);
        _countdownRingController.forward(from: 0);
        _countdownBlurController.forward(from: 0).then((_) {
          _countdownBlurController.reverse();
        });
        _audioService.playCountdown();
        _hapticService.mediumImpact();
      } else {
        timer.cancel();
        // Final dramatic exit animation
        _countdownBlurController.forward().then((_) {
          setState(() {
            _isCountingDown = false;
          });
          _startGame();
        });
      }
    });
  }

  void _startGame() async {
    _audioService.playClick();
    _hapticService.mediumImpact();

    // Start camera recording BEFORE sensors so the video captures everything
    // from the moment gameplay begins. Camera should already be pre-initialized
    // during the countdown via _checkCameraPreference().
    if (_isCameraEnabled) {
      if (!_cameraRecording.isInitialized) {
        // Fallback: initialize now if pre-init didn't finish in time
        final initialized = await _cameraRecording.initialize();
        if (!initialized) {
          _isCameraEnabled = false;
        }
      }

      if (_isCameraEnabled) {
        await _startVideoRecording();

        // Log the first word immediately so the game overlay is in sync
        // with the camera. Without this, the overlay shows "Get Ready!"
        // for the entire duration of the first card.
        final gameProvider = context.read<GameProvider>();
        final currentWord = gameProvider.currentSession?.currentCard ?? '';
        if (_isRecordingVideo && currentWord.isNotEmpty) {
          _cameraRecording.logGameEvent(
            type: 'word_shown',
            word: currentWord,
            score: gameProvider.currentSession?.correctCount ?? 0,
            remainingTime: gameProvider.remainingTime,
          );
        }
      }
    }

    // Start sensors AFTER recording so the user can only interact
    // (tilt to correct/pass) once the camera is actively recording.
    // This keeps camera video and game overlay perfectly in sync.
    if (!_useManualControls) {
      _initializeSensors();
    }
  }

  Future<bool> _startVideoRecording() async {
    if (!_isCameraEnabled) return false;

    final success = await _cameraRecording.startRecording(
      widget.deck.name,
      widget.deck.color.toString(),
    );

    if (success) {
      setState(() {
        _isRecordingVideo = true;
      });
    }

    return success;
  }

  void _initializeSensors({bool isRecalibration = false}) {
    _calibrationSubscription?.cancel();
    _calibrationSubscription = null;
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;

    _smoothedDeltaZ = 0.0;
    _waitingForReturn = false;
    _actionLocked = false;
    _isCalibrated = false;
    _returnStableCount = 0;
    _animationComplete = false;
    _returnComplete = false;
    _waitingStartTime = null;
    _sensorState = 'CALIBRATING';
    if (!isRecalibration) {
      _lastActionTime = null;
    }

    final delay = isRecalibration ? 50 : 200;
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _calibrateSensor();
    });
  }

  /// Calibrates baseline accelerometer values only when the phone is in the
  /// correct "heads-up" position (vertical landscape on forehead).
  /// Rejects samples where |Y| is large (portrait) or |X| is small (phone flat).
  void _calibrateSensor() {
    _calibrationSubscription?.cancel();

    int totalCount = 0;
    int usedCount = 0;
    double sumX = 0, sumY = 0, sumZ = 0;
    const discardSamples = 5;
    const requiredSamples = 25;
    bool calibrationDone = false;

    _sensorState = 'CALIBRATING...';

    _calibrationSubscription = accelerometerEventStream(
      samplingPeriod: _sensorSamplingPeriod,
    ).listen((event) {
      if (calibrationDone) return;

      // Update raw values for debug overlay even during calibration
      _accelX = event.x;
      _accelY = event.y;
      _accelZ = event.z;
      _gravityMag = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      totalCount++;
      if (totalCount <= discardSamples) return;

      // ORIENTATION GATE: Only accept calibration samples when phone is
      // in the "heads-up" position (vertical landscape on forehead).
      //
      // In this position:
      //   |X| ≈ 9.8 (gravity along short axis — phone is vertical)
      //   |Y| ≈ 0   (landscape — long axis is horizontal)
      //   |Z| ≈ 0   (screen faces outward, perpendicular to gravity)
      //
      // Reject if |Y| is large (portrait / transitioning).
      if (event.y.abs() > _calibrationStableThreshold) {
        _sensorState =
            'WAITING FOR LANDSCAPE (Y=${event.y.toStringAsFixed(1)})';
        usedCount = 0;
        sumX = 0;
        sumY = 0;
        sumZ = 0;
        return;
      }

      // Reject if |X| is too small — phone is flat (e.g. lying on a table/bed)
      // instead of vertical on the forehead. When flat, X ≈ 0 and Z ≈ 9.8.
      if (event.x.abs() < _calibrationVerticalThreshold) {
        _sensorState = 'HOLD ON FOREHEAD (X=${event.x.toStringAsFixed(1)})';
        usedCount = 0;
        sumX = 0;
        sumY = 0;
        sumZ = 0;
        return;
      }

      sumX += event.x;
      sumY += event.y;
      sumZ += event.z;
      usedCount++;

      _sensorState = 'CALIBRATING ($usedCount/$requiredSamples)';

      if (usedCount >= requiredSamples) {
        calibrationDone = true;
        _calibrationSubscription?.cancel();
        _calibrationSubscription = null;

        _calX = sumX / usedCount;
        _calY = sumY / usedCount;
        _calZ = sumZ / usedCount;
        _isCalibrated = true;
        _sensorState = 'READY';
        _startSensorListener();
      }
    });

    // Timeout fallback: if we can't get good samples in 5 seconds, use what we have
    Future.delayed(const Duration(seconds: 5), () {
      if (calibrationDone || !mounted) return;
      calibrationDone = true;
      _calibrationSubscription?.cancel();
      _calibrationSubscription = null;
      _calX = usedCount > 0 ? sumX / usedCount : 9.8;
      _calY = usedCount > 0 ? sumY / usedCount : 0.0;
      _calZ = usedCount > 0 ? sumZ / usedCount : 0.0;
      _isCalibrated = true;
      _sensorState = 'READY (timeout cal)';
      _startSensorListener();
    });
  }

  /// Main sensor listener — ΔZ-based CORRECT/PASS detection with ΔY orientation guard.
  ///
  /// State machine:
  ///   READY → (ΔZ crosses threshold) → WAITING_FOR_RETURN → (N consecutive neutral samples) → READY
  ///
  /// Guards:
  ///   - |ΔY| > orientationGuardThreshold → phone is not in landscape → ignore
  ///   - |gravity| < 7.0 → sensor is unreliable → ignore
  ///   - _actionLocked → animation not done yet → don't trigger new action
  ///   - cooldown → too soon after last action → don't trigger
  void _startSensorListener() {
    // Accelerometer stream — main detection + debug display
    _sensorSubscription?.cancel();
    _sensorSubscription = accelerometerEventStream(
      samplingPeriod: _sensorSamplingPeriod,
    ).listen((event) {
      if (!mounted || !_isCalibrated) return;

      // Update raw values for debug overlay
      _accelX = event.x;
      _accelY = event.y;
      _accelZ = event.z;
      _gravityMag = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // ── Guard 1: Gravity magnitude check ──
      // If total gravity is too low, sensor data is unreliable (e.g. free-fall or sensor glitch)
      if (_gravityMag < 7.0) {
        _sensorState = 'BAD GRAVITY (${_gravityMag.toStringAsFixed(1)})';
        return;
      }

      // Compute deltas from calibrated baseline
      final deltaY = event.y - _calY;
      final rawDeltaZ = event.z - _calZ;

      // ── Guard 2: Orientation guard using ΔY ──
      // In landscape, Y should be near calibrated value (small ΔY).
      // Large |ΔY| means phone is portrait or transitioning → ignore all sensor input.
      if (deltaY.abs() > _orientationGuardThreshold) {
        _sensorState = 'NOT LANDSCAPE (ΔY=${deltaY.toStringAsFixed(1)})';
        // Don't reset smoothedDeltaZ — we'll let it naturally decay or stabilize
        // when the phone returns to landscape
        return;
      }

      // ── Smooth ΔZ using EMA ──
      _smoothedDeltaZ =
          _smoothedDeltaZ * (1 - _smoothingAlpha) + rawDeltaZ * _smoothingAlpha;

      // ── Baseline drift correction ──
      // When the phone is near neutral (user isn't tilting), slowly nudge _calZ
      // toward the actual current Z reading. This eliminates persistent bias
      // from sensor offset or slight head angle without affecting tilt detection.
      if (!_waitingForReturn &&
          !_actionLocked &&
          _smoothedDeltaZ.abs() < _baselineDriftZone) {
        _calZ += (_smoothedDeltaZ) * _baselineDriftAlpha;
      }

      // ── State: WAITING FOR RETURN TO NEUTRAL ──
      if (_waitingForReturn) {
        // Check if phone has returned to neutral position
        // Require BOTH smoothed AND raw to be near zero (prevents EMA from falsely declaring neutral)
        if (_smoothedDeltaZ.abs() < _returnThreshold &&
            rawDeltaZ.abs() < _returnThreshold) {
          _returnStableCount++;
          _sensorState =
              'RETURNING (${_returnStableCount}/$_returnStableSamplesRequired)';
          if (_returnStableCount >= _returnStableSamplesRequired) {
            _waitingForReturn = false;
            _returnStableCount = 0;
            _waitingStartTime = null;
            _returnComplete = true;
            _sensorState = _actionLocked ? 'WAITING ANIM' : 'READY';
            _maybeUnlockAfterAction();
          }
        } else {
          // Not neutral yet — reset consecutive counter
          _returnStableCount = 0;
          _sensorState =
              'WAIT NEUTRAL (ΔZ=${_smoothedDeltaZ.toStringAsFixed(1)})';
        }

        // Watchdog: if stuck in waitingForReturn too long AND close to neutral, force-clear
        if (_waitingForReturn && _waitingStartTime != null) {
          final elapsed =
              DateTime.now().difference(_waitingStartTime!).inMilliseconds;
          if (elapsed > _waitingTimeoutMs &&
              _smoothedDeltaZ.abs() < _returnThreshold * 1.5) {
            _waitingForReturn = false;
            _returnStableCount = 0;
            _waitingStartTime = null;
            _returnComplete = true;
            _sensorState = 'READY (watchdog)';
            _maybeUnlockAfterAction();
          }
        }

        // Update debug overlay periodically
        if (DateTime.now().millisecondsSinceEpoch % 100 < 25) {
          setState(() {});
        }
        return;
      }

      // ── Don't trigger if action is locked (animation in progress) ──
      if (_actionLocked) {
        _sensorState = 'LOCKED (anim)';
        if (DateTime.now().millisecondsSinceEpoch % 100 < 25) {
          setState(() {});
        }
        return;
      }

      // ── Cooldown check ──
      if (_lastActionTime != null) {
        final elapsed =
            DateTime.now().difference(_lastActionTime!).inMilliseconds;
        if (elapsed < _cooldownMs) {
          _sensorState = 'COOLDOWN (${_cooldownMs - elapsed}ms)';
          if (DateTime.now().millisecondsSinceEpoch % 100 < 25) {
            setState(() {});
          }
          return;
        }
      }

      // ── Skip if counting down ──
      if (_isCountingDown) {
        _sensorState = 'COUNTDOWN';
        return;
      }

      _sensorState = 'READY (ΔZ=${_smoothedDeltaZ.toStringAsFixed(1)})';

      // ── Trigger detection ──
      // CORRECT = tilt forward (nod down) → ΔZ goes NEGATIVE (phone face tilts toward floor)
      // PASS = tilt backward (lean back) → ΔZ goes POSITIVE (phone face tilts toward ceiling)
      if (_smoothedDeltaZ < -_tiltTriggerThreshold) {
        _triggerAction(isCorrect: true);
      } else if (_smoothedDeltaZ > _tiltTriggerThreshold) {
        _triggerAction(isCorrect: false);
      }

      // Update debug overlay periodically
      if (DateTime.now().millisecondsSinceEpoch % 100 < 25) {
        setState(() {});
      }
    });

    // Gyroscope stream — for debug overlay only
    _gyroSubscription?.cancel();
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: _sensorSamplingPeriod,
    ).listen((event) {
      if (!mounted) return;
      _gyroX = event.x;
      _gyroY = event.y;
      _gyroZ = event.z;
    });
  }

  // ── Stubs for compatibility (manual controls still call these) ──

  void _maybeUnlockAfterAction() {
    if (_animationComplete && _returnComplete) {
      _actionLocked = false;
    }
  }

  void _triggerAction({required bool isCorrect}) {
    _actionLocked = true;
    _waitingForReturn = true;
    _returnStableCount = 0;
    _animationComplete = false;
    _returnComplete = false;
    _lastActionTime = DateTime.now();
    _waitingStartTime = DateTime.now();
    // NOTE: We do NOT reset _smoothedDeltaZ here! The phone is still tilted,
    // and we need real sensor data to detect when it returns to neutral.
    _sensorState = isCorrect ? 'TRIGGERED CORRECT' : 'TRIGGERED PASS';
    if (isCorrect) {
      _handleCorrect();
    } else {
      _handlePass();
    }
  }

  void _handleCorrect() {
    // Get current word before marking correct
    final gameProvider = context.read<GameProvider>();
    final currentWord = gameProvider.currentSession?.currentCard ?? '';

    // Update game state
    gameProvider.markCorrect();

    // Update streak counter
    _currentStreak++;

    // Haptics on every correct card (before any other feedback so it always runs)
    if (_currentStreak >= _streakThreshold) {
      _hapticService.streakBonus(); // 🔥 Extra celebration for hot streak!
    } else {
      _hapticService.correctAnswer(); // Celebratory haptic for every correct
    }

    // Log video event
    if (_isRecordingVideo) {
      _cameraRecording.logGameEvent(
        type: 'correct',
        word: currentWord,
        score: gameProvider.currentSession?.correctCount ?? 0,
        remainingTime: gameProvider.remainingTime,
      );
    }

    // Set action state for premium animation
    setState(() {
      _isCorrectAction = true;
      _isPassAction = false;
    });

    // Show feedback with burst animation
    _showFeedback('CORRECT!', AppTheme.successColor, Icons.check_circle);
    _feedbackBurstController.forward(from: 0);

    // Play audio
    _audioService.playCorrect();

    // Premium card exit animation — unlock tied to BOTH animation + return-to-neutral.
    _cardExitController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _isCorrectAction = false;
      });
      _cardExitController.reset();
      _cardEnterController.forward(from: 0);
      _prepareNextCard();
      // Mark animation as done; actual unlock happens only when return is also complete
      _animationComplete = true;
      _maybeUnlockAfterAction();
    });
  }

  void _handlePass() {
    // Haptics on every pass card (first so it always runs)
    _hapticService.passAnswer();

    // Get current word before marking pass
    final gameProvider = context.read<GameProvider>();
    final currentWord = gameProvider.currentSession?.currentCard ?? '';

    // Update game state
    gameProvider.markPass();

    // Reset streak on pass
    _currentStreak = 0;

    // Log video event
    if (_isRecordingVideo) {
      _cameraRecording.logGameEvent(
        type: 'pass',
        word: currentWord,
        score: gameProvider.currentSession?.correctCount ?? 0,
        remainingTime: gameProvider.remainingTime,
      );
    }

    // Set action state for premium animation
    setState(() {
      _isPassAction = true;
      _isCorrectAction = false;
    });

    // Show feedback
    _showFeedback('PASS', AppTheme.warningColor, Icons.skip_next);
    _feedbackBurstController.forward(from: 0);

    // Play audio
    _audioService.playPass();

    // Premium card exit animation — unlock tied to BOTH animation + return-to-neutral.
    _cardExitController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _isPassAction = false;
      });
      _cardExitController.reset();
      _cardEnterController.forward(from: 0);
      _prepareNextCard();
      // Mark animation as done; actual unlock happens only when return is also complete
      _animationComplete = true;
      _maybeUnlockAfterAction();
    });
  }

  void _showFeedback(String text, Color color, IconData icon) {
    setState(() {
      _feedbackColor = color;
    });

    _feedbackController.forward(from: 0).then((_) {
      _feedbackController.reverse();
    });
  }

  void _prepareNextCard() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      final gameProvider = context.read<GameProvider>();

      // Check if game is over
      if (!gameProvider.isGameActive ||
          gameProvider.currentSession?.isComplete == true) {
        // Game over detected
        if (!_isNavigating) {
          _navigateToResults();
        }
      } else {
        // Log word shown event
        final currentWord = gameProvider.currentSession?.currentCard ?? '';
        if (_isRecordingVideo && currentWord.isNotEmpty) {
          _cameraRecording.logGameEvent(
            type: 'word_shown',
            word: currentWord,
            score: gameProvider.currentSession?.correctCount ?? 0,
            remainingTime: gameProvider.remainingTime,
          );
        }

        // Decay smoothed delta toward neutral to prevent stuck state
        _smoothedDeltaZ *= 0.5;

        setState(() {});
      }
    });
  }

  Future<void> _navigateToResults() async {
    if (_isNavigating) return;
    _isNavigating = true;

    _calibrationSubscription?.cancel();
    _sensorSubscription?.cancel();
    _gyroSubscription?.cancel();

    // Stop video recording and get result
    if (_isRecordingVideo) {
      await _stopRecordingAndNavigate();
    } else {
      _navigateToResultsScreen();
    }
  }

  Future<void> _stopRecordingAndNavigate() async {
    VideoRecordingResult? recordingResult;

    if (_isRecordingVideo) {
      setState(() {
        _isRecordingVideo = false; // Prevent multiple stops
      });

      recordingResult = await _cameraRecording.stopRecording(
        widget.deck.name,
        widget.deck.color.toString(),
      );

      // Store in game provider
      if (recordingResult != null) {
        // Verify file exists before storing
        final videoFile = File(recordingResult.videoPath);
        final exists = await videoFile.exists();

        if (!mounted) return;

        if (exists) {
          context.read<GameProvider>().setVideoRecording(recordingResult);
        }

        // Small delay to ensure provider updates propagate
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (mounted) {
      _navigateToResultsScreen();
    }
  }

  void _navigateToResultsScreen() {
    final gameProvider = context.read<GameProvider>();

    // Restore normal screen timeout and orientation before leaving gameplay
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (widget.isTeamMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TeamResultsScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ResultsScreen()),
      );
    }
  }

  void _handleManualCorrect() {
    if (_isCountingDown || _actionLocked) return;
    _actionLocked = true;
    _animationComplete = false;
    _returnComplete = true; // No tilt return needed for manual tap
    _handleCorrect();
  }

  void _handleManualPass() {
    if (_isCountingDown || _actionLocked) return;
    _actionLocked = true;
    _animationComplete = false;
    _returnComplete = true; // No tilt return needed for manual tap
    _handlePass();
  }

  void _handleFinishGame() {
    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder:
          (dialogContext) => Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.white.withOpacity(0.95)],
                ),
                borderRadius: BorderRadius.circular(28.s),
                boxShadow: [
                  BoxShadow(
                    color: widget.deck.color.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 48,
                      color: widget.deck.color,
                    ),
                    SizedBox(height: 16.s),
                    Text(
                      'Finish Game?',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8.s),
                    Text(
                      'Are you sure you want to end this game?',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.s),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.deck.color,
                                  widget.deck.color.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12.s),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.deck.color.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _hapticService.mediumImpact();

                                  // End the current game and navigate
                                  context.read<GameProvider>().endGame();
                                  _navigateToResults();
                                },
                                borderRadius: BorderRadius.circular(12.s),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Finish',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _pauseGame() {
    context.read<GameProvider>().togglePause();
    _isCalibrated = false; // Disable sensors during pause

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder:
          (dialogContext) => Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.white.withOpacity(0.95)],
                ),
                borderRadius: BorderRadius.circular(28.s),
                boxShadow: [
                  BoxShadow(
                    color: widget.deck.color.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            widget.deck.color.withOpacity(0.1),
                            widget.deck.color.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content - wrapped in scrollable container with proper constraints
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated pause icon
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 500),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          widget.deck.color.withOpacity(0.2),
                                          widget.deck.color.withOpacity(0.1),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.deck.color.withOpacity(
                                            0.2,
                                          ),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.pause_rounded,
                                      size: 32,
                                      color: widget.deck.color,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),

                            // Title with gradient
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => LinearGradient(
                                    colors: [
                                      widget.deck.color,
                                      widget.deck.color.withOpacity(0.7),
                                    ],
                                  ).createShader(bounds),
                              child: const Text(
                                'Game Paused',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Message
                            Text(
                              'Take a breather!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Your game is waiting for you',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Resume button with gradient
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    widget.deck.color,
                                    widget.deck.color.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.deck.color.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    context.read<GameProvider>().togglePause();
                                    // Reinitialize sensors on resume for better accuracy
                                    if (!_useManualControls) {
                                      _initializeSensors(isRecalibration: true);
                                    }
                                    _hapticService.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Resume Game',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // End game button with subtle design
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    _hapticService.mediumImpact();

                                    // End the current game
                                    context.read<GameProvider>().endGame();

                                    // Restore normal screen timeout and orientation
                                    WakelockPlus.disable();
                                    SystemChrome.setPreferredOrientations([
                                      DeviceOrientation.portraitUp,
                                      DeviceOrientation.portraitDown,
                                    ]);

                                    // Navigate to results screen
                                    if (widget.isTeamMode) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const TeamResultsScreen(),
                                        ),
                                      );
                                    } else {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const ResultsScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.stop_rounded,
                                          color: Colors.red[400],
                                          size: 22,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'End Game',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    // Remove game state listener
    try {
      final gameProvider = context.read<GameProvider>();
      gameProvider.removeListener(_checkGameState);
    } catch (e) {
      // Context might be deactivated
      debugPrint('Could not remove listener: $e');
    }

    _countdownController.dispose();
    _countdownPulseController.dispose();
    _countdownRingController.dispose();
    _countdownBlurController.dispose();
    _cardFlipController.dispose();
    _cardExitController.dispose();
    _cardEnterController.dispose();
    _feedbackController.dispose();
    _feedbackBurstController.dispose();
    _timerPulseController.dispose();
    _backgroundAnimController.dispose();
    _glowController.dispose();
    _countdownTimer?.cancel();
    _calibrationSubscription?.cancel();
    _sensorSubscription?.cancel();
    _gyroSubscription?.cancel();
    // Safety: always restore normal screen timeout on dispose
    WakelockPlus.disable();
    // Reset orientation to portrait only (not all orientations)
    // This prevents the device from auto-rotating back to landscape
    // when the user is still holding the device in landscape position
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Clean up camera if still recording
    if (_isRecordingVideo) {
      debugPrint('Stopping recording in dispose');
      _cameraRecording
          .stopRecording(widget.deck.name, widget.deck.color.toString())
          .then((result) {
            if (result != null) {
              debugPrint(
                'Recording stopped in dispose, but cannot save to provider',
              );
            }
          });
    }

    super.dispose();
  }

  Widget _buildSensorDebugOverlay() {
    final deltaY = _accelY - _calY;
    final rawDeltaZ = _accelZ - _calZ;

    // Determine trigger direction for display
    String triggerDir = 'NEUTRAL';
    Color triggerColor = Colors.white;
    if (_smoothedDeltaZ < -_tiltTriggerThreshold) {
      triggerDir =
          '✅ CORRECT (ΔZ < -${_tiltTriggerThreshold.toStringAsFixed(0)})';
      triggerColor = Colors.green;
    } else if (_smoothedDeltaZ > _tiltTriggerThreshold) {
      triggerDir = '⏭ PASS (ΔZ > ${_tiltTriggerThreshold.toStringAsFixed(0)})';
      triggerColor = Colors.orange;
    }

    // Orientation guard status
    final isLandscape = deltaY.abs() <= _orientationGuardThreshold;
    final orientColor = isLandscape ? Colors.greenAccent : Colors.redAccent;

    return Positioned(
      top: 10,
      left: 10,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.greenAccent, width: 1),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.greenAccent,
              height: 1.4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // State machine status — most important info at top
                Text(
                  'STATE: $_sensorState',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color:
                        _sensorState.contains('READY')
                            ? Colors.greenAccent
                            : _sensorState.contains('TRIGGERED')
                            ? Colors.yellowAccent
                            : _sensorState.contains('NOT LANDSCAPE')
                            ? Colors.redAccent
                            : Colors.cyan,
                  ),
                ),
                const SizedBox(height: 6),
                // ΔZ — the trigger signal
                Text(
                  '── ΔZ (TRIGGER SIGNAL) ──',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color:
                        _smoothedDeltaZ.abs() > _tiltTriggerThreshold
                            ? Colors.yellowAccent
                            : Colors.greenAccent,
                  ),
                ),
                Text(
                  'smoothed: ${_smoothedDeltaZ.toStringAsFixed(2)}  raw: ${rawDeltaZ.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        _smoothedDeltaZ.abs() > _tiltTriggerThreshold
                            ? Colors.yellowAccent
                            : Colors.greenAccent,
                  ),
                ),
                Text(
                  'threshold: ±${_tiltTriggerThreshold.toStringAsFixed(1)}  return: ±${_returnThreshold.toStringAsFixed(1)}',
                ),
                const SizedBox(height: 4),
                // ΔY — orientation guard
                Text(
                  '── ΔY (ORIENT GUARD) ──',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: orientColor,
                  ),
                ),
                Text(
                  'ΔY: ${deltaY.toStringAsFixed(2)}  ${isLandscape ? "✓ LANDSCAPE" : "✗ NOT LANDSCAPE"}',
                  style: TextStyle(color: orientColor),
                ),
                Text(
                  'guard: ±${_orientationGuardThreshold.toStringAsFixed(1)}',
                ),
                const SizedBox(height: 4),
                // Flags
                const Text(
                  '── FLAGS ──',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  'locked: $_actionLocked  waiting: $_waitingForReturn  stableN: $_returnStableCount',
                ),
                Text(
                  'animDone: $_animationComplete  returnDone: $_returnComplete',
                ),
                const SizedBox(height: 4),
                // Calibration
                const Text(
                  '── CALIBRATION ──',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  'cal X: ${_calX.toStringAsFixed(2)}  Y: ${_calY.toStringAsFixed(2)}  Z: ${_calZ.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                // Trigger direction
                Text(
                  triggerDir,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: triggerColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _pauseGame();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.deck.color.withOpacity(0.8),
                widget.deck.color,
                widget.deck.color.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated background elements
              _buildAnimatedBackground(),

              // Main content
              SafeArea(
                child: _isCountingDown ? _buildCountdown() : _buildGameplay(),
              ),

              // Feedback overlay
              _buildFeedbackOverlay(),

              // Sensor debug overlay (dev only - requires both debug mode AND development environment)
              if (kDebugMode && EnvironmentConfig.isDevelopment)
                _buildSensorDebugOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Animated gradient mesh
        AnimatedBuilder(
          animation: _backgroundAnimController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(
                    -1 +
                        math.sin(
                              _backgroundAnimController.value * math.pi * 2,
                            ) *
                            0.3,
                    -1 +
                        math.cos(
                              _backgroundAnimController.value * math.pi * 2,
                            ) *
                            0.3,
                  ),
                  end: Alignment(
                    1 +
                        math.sin(
                              _backgroundAnimController.value * math.pi * 2 +
                                  math.pi,
                            ) *
                            0.3,
                    1 +
                        math.cos(
                              _backgroundAnimController.value * math.pi * 2 +
                                  math.pi,
                            ) *
                            0.3,
                  ),
                  colors: [
                    widget.deck.color.withOpacity(0.6),
                    widget.deck.color.withOpacity(0.4),
                    widget.deck.color.withOpacity(0.3),
                    widget.deck.color.withOpacity(0.5),
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            );
          },
        ),
        // Floating orbs with smooth animation
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _backgroundAnimController,
            builder: (context, child) {
              final progress =
                  (_backgroundAnimController.value + index * 0.33) % 1.0;
              final size = MediaQuery.of(context).size;
              final baseX = size.width * (0.2 + index * 0.3);
              final baseY = size.height * (0.3 + index * 0.2);

              return Positioned(
                left: baseX + math.sin(progress * math.pi * 2) * 50 - 100,
                top: baseY + math.cos(progress * math.pi * 2) * 80 - 100,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.15 * (1 - progress * 0.5)),
                        Colors.white.withOpacity(0.05 * (1 - progress * 0.5)),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Modern geometric pattern
        CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ElegantBackgroundPainter(
            animation: _backgroundAnimController.value,
            color: widget.deck.color,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    // iPhone 16 Pro Max reference dimensions (in logical pixels)
    // This serves as the design baseline - all sizes are defined for this device
    const double referenceWidth = 440.0;
    const double referenceHeight = 956.0;

    // Calculate responsive scale factor based on screen size
    // This ensures consistent visual proportions across all iPhone models
    // Elements will scale down proportionally on smaller devices
    double scaleFactor;
    if (isLandscape) {
      // For landscape, use height as the constraining dimension
      // Reference landscape height for iPhone 16 Pro Max
      const double referenceLandscapeHeight = 440.0;
      final heightScale = screenSize.height / referenceLandscapeHeight;
      scaleFactor = heightScale.clamp(0.55, 1.0);
    } else {
      // For portrait, scale based on both width and height relative to iPhone 16 Pro Max
      final widthScale = screenSize.width / referenceWidth;
      final heightScale = screenSize.height / referenceHeight;
      // Use the smaller scale to ensure content fits without overflow
      scaleFactor = (widthScale < heightScale ? widthScale : heightScale).clamp(
        0.7,
        1.0,
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _countdownController,
        _countdownPulseController,
        _countdownRingController,
        _countdownBlurController,
      ]),
      builder: (context, child) {
        // Premium easing curves for Netflix-like feel
        final elasticValue = Curves.elasticOut.transform(
          _countdownController.value.clamp(0.0, 1.0),
        );
        final pulseValue = Curves.easeOutCubic.transform(
          _countdownPulseController.value.clamp(0.0, 1.0),
        );
        final ringValue = Curves.easeOutQuart.transform(
          _countdownRingController.value.clamp(0.0, 1.0),
        );
        final blurValue = _countdownBlurController.value;

        // Dynamic scale with dramatic entrance
        final numberScale = 0.3 + (elasticValue * 0.7);
        final numberOpacity = (1.0 - (pulseValue * 0.15)).clamp(0.0, 1.0);

        // =================================================================
        // REFERENCE DIMENSIONS FOR IPHONE 16 PRO MAX (440 x 956 pts)
        // All values below are designed for iPhone 16 Pro Max
        // They will scale proportionally on smaller devices
        // =================================================================

        // Main countdown container size
        const double refCountdownSize = 360.0;

        // Typography
        const double refFontSize = 128.0;
        const double refLetterSpacing = -5.0;

        // Spacings
        const double refSpacing = 20.0;

        // Glow and circle effects
        const double refGlowSize = 220.0;
        const double refInnerCircle = 170.0;
        const double refArcSize = 190.0;
        const double refBorderWidth = 2.5;

        // Expanding ring animations
        const double refRingSize1 = 360.0;
        const double refRingStart1 = 130.0;
        const double refRingSize2 = 310.0;
        const double refRingStart2 = 110.0;
        const double refRingSize3 = 260.0;
        const double refRingStart3 = 90.0;

        // Shadow and blur effects
        const double refBlurRadius = 32.0;
        const double refSpreadRadius = 6.0;
        const double refShadowOffset = 12.0;

        // =================================================================
        // SCALED DIMENSIONS
        // All values are multiplied by scaleFactor to maintain
        // visual proportions on smaller devices
        // =================================================================
        final countdownSize = refCountdownSize * scaleFactor;
        final fontSize = refFontSize * scaleFactor;
        final letterSpacing = refLetterSpacing * scaleFactor;
        final spacing = refSpacing * scaleFactor;
        final glowSize = refGlowSize * scaleFactor;
        final innerCircleSize = refInnerCircle * scaleFactor;
        final arcSize = refArcSize * scaleFactor;
        final borderWidth = refBorderWidth * scaleFactor;
        final blurRadius = refBlurRadius * scaleFactor;
        final spreadRadius = refSpreadRadius * scaleFactor;
        final shadowOffset = refShadowOffset * scaleFactor;

        return Stack(
          children: [
            // Main countdown content - centered with safe area
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main countdown animation container
                      SizedBox(
                        width: countdownSize,
                        height: countdownSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outermost expanding ring with fade
                            // Reference stroke width: 1.2pt for iPhone 16 Pro Max
                            _buildExpandingRing(
                              ringValue,
                              size: refRingSize1 * scaleFactor,
                              startSize: refRingStart1 * scaleFactor,
                              opacity: 0.15,
                              strokeWidth: 1.2 * scaleFactor,
                            ),

                            // Second expanding ring
                            // Reference stroke width: 1.8pt for iPhone 16 Pro Max
                            _buildExpandingRing(
                              ringValue,
                              size: refRingSize2 * scaleFactor,
                              startSize: refRingStart2 * scaleFactor,
                              opacity: 0.25,
                              strokeWidth: 1.8 * scaleFactor,
                              delay: 0.1,
                            ),

                            // Third expanding ring
                            // Reference stroke width: 2.4pt for iPhone 16 Pro Max
                            _buildExpandingRing(
                              ringValue,
                              size: refRingSize3 * scaleFactor,
                              startSize: refRingStart3 * scaleFactor,
                              opacity: 0.35,
                              strokeWidth: 2.4 * scaleFactor,
                              delay: 0.2,
                            ),

                            // Pulsing glow effect behind number
                            Transform.scale(
                              scale: 1.0 + (pulseValue * 0.3),
                              child: Container(
                                width: glowSize,
                                height: glowSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      widget.deck.color.withOpacity(
                                        0.4 * (1 - pulseValue),
                                      ),
                                      widget.deck.color.withOpacity(
                                        0.2 * (1 - pulseValue),
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Inner glowing circle
                            Container(
                              width: innerCircleSize,
                              height: innerCircleSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(
                                    0.4 + (pulseValue * 0.2),
                                  ),
                                  width: borderWidth,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius:
                                        blurRadius +
                                        (pulseValue * 20 * scaleFactor),
                                    spreadRadius: spreadRadius,
                                  ),
                                  BoxShadow(
                                    color: widget.deck.color.withOpacity(0.4),
                                    blurRadius: blurRadius * 2,
                                    spreadRadius: spreadRadius * 1.8,
                                  ),
                                ],
                              ),
                            ),

                            // Animated progress arc
                            SizedBox(
                              width: arcSize,
                              height: arcSize,
                              child: CustomPaint(
                                painter: _CountdownArcPainter(
                                  progress: 1.0 - ringValue,
                                  color: Colors.white,
                                  strokeWidth: 3.5 * scaleFactor,
                                ),
                              ),
                            ),

                            // Main number with dramatic animation
                            Transform.scale(
                              scale: numberScale,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blurValue * 10 * scaleFactor,
                                  sigmaY: blurValue * 10 * scaleFactor,
                                ),
                                child: Opacity(
                                  opacity: numberOpacity * (1 - blurValue),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Shadow layer
                                      Text(
                                        _countdownValue.toString(),
                                        style: TextStyle(
                                          color: widget.deck.color.withOpacity(
                                            0.5,
                                          ),
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                          letterSpacing: letterSpacing,
                                        ),
                                      ),
                                      // Main text with gradient
                                      ShaderMask(
                                        shaderCallback:
                                            (bounds) => LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.white,
                                                Colors.white.withOpacity(0.9),
                                                Colors.white.withOpacity(0.7),
                                              ],
                                              stops: const [0.0, 0.5, 1.0],
                                            ).createShader(bounds),
                                        child: Text(
                                          _countdownValue.toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                            letterSpacing: letterSpacing,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black26,
                                                blurRadius: shadowOffset * 1.8,
                                                offset: Offset(0, shadowOffset),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Particle effects (scaled for landscape)
                            ..._buildParticlesScaled(pulseValue, scaleFactor),
                          ],
                        ),
                      ),

                      // Spacing between number and GET READY
                      SizedBox(height: spacing),

                      // Forehead instruction with animated icon - compact for landscape
                      // Reference entrance offset: 28pt for iPhone 16 Pro Max
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: elasticValue > 0.6 ? 1.0 : 0.0,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            28 * scaleFactor * (1 - elasticValue),
                          ),
                          child: _buildForeheadHint(pulseValue, scaleFactor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Compact, elegant forehead placement hint - responsive for all screen sizes
  /// Design baseline: iPhone 16 Pro Max (440 x 956 pts)
  Widget _buildForeheadHint(double pulseValue, double scaleFactor) {
    // =================================================================
    // REFERENCE VALUES FOR IPHONE 16 PRO MAX (440 x 956 pts)
    // All values below are designed for iPhone 16 Pro Max
    // They will scale proportionally on smaller devices
    // =================================================================

    // Container padding
    const double refHorizontalPadding = 18.0;
    const double refVerticalPadding = 12.0;
    const double refBorderRadius = 44.0;
    const double refBorderWidth = 1.2;

    // Icon container
    const double refIconContainerSize = 32.0;
    const double refHeadSize = 22.0;
    const double refHeadBorderWidth = 1.8;
    const double refPhoneWidth = 16.0;
    const double refPhoneHeight = 8.0;
    const double refPhoneRadius = 2.5;
    const double refPhoneGlow = 8.0;

    // Spacing
    const double refIconTextSpacing = 12.0;
    const double refTextLineSpacing = 2.0;

    // Typography
    const double refMainFontSize = 14.0;
    const double refMainLetterSpacing = 0.4;
    const double refSubFontSize = 11.0;
    const double refSubLetterSpacing = 0.3;
    const double refSubIconSize = 12.0;
    const double refSubIconSpacing = 4.0;

    // =================================================================
    // SCALED VALUES
    // =================================================================
    final horizontalPadding = refHorizontalPadding * scaleFactor;
    final verticalPadding = refVerticalPadding * scaleFactor;
    final borderRadius = refBorderRadius * scaleFactor;
    final borderWidth = refBorderWidth * scaleFactor;

    final iconContainerSize = refIconContainerSize * scaleFactor;
    final headSize = refHeadSize * scaleFactor;
    final headBorderWidth = refHeadBorderWidth * scaleFactor;
    final phoneWidth = refPhoneWidth * scaleFactor;
    final phoneHeight = refPhoneHeight * scaleFactor;
    final phoneRadius = refPhoneRadius * scaleFactor;
    final phoneGlow = refPhoneGlow * scaleFactor;

    final iconTextSpacing = refIconTextSpacing * scaleFactor;
    final textLineSpacing = refTextLineSpacing * scaleFactor;

    final mainFontSize = refMainFontSize * scaleFactor;
    final mainLetterSpacing = refMainLetterSpacing * scaleFactor;
    final subFontSize = refSubFontSize * scaleFactor;
    final subLetterSpacing = refSubLetterSpacing * scaleFactor;
    final subIconSize = refSubIconSize * scaleFactor;
    final subIconSpacing = refSubIconSpacing * scaleFactor;

    // Subtle floating animation for the phone icon
    final floatOffset = math.sin(pulseValue * math.pi * 2) * 2.5 * scaleFactor;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.14),
            Colors.white.withOpacity(0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated phone + head icon
          SizedBox(
            width: iconContainerSize,
            height: iconContainerSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Head silhouette
                Container(
                  width: headSize,
                  height: headSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.45),
                      width: headBorderWidth,
                    ),
                  ),
                ),
                // Phone on forehead with float animation
                Positioned(
                  top: floatOffset,
                  child: Transform.rotate(
                    angle: math.pi / 2,
                    child: Container(
                      width: phoneWidth,
                      height: phoneHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(phoneRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.45),
                            blurRadius: phoneGlow,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: iconTextSpacing),
          // Text instruction
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Place on forehead',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: mainFontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: mainLetterSpacing,
                  height: 1.2,
                ),
              ),
              SizedBox(height: textLineSpacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stay_current_landscape_rounded,
                    color: Colors.white.withOpacity(0.55),
                    size: subIconSize,
                  ),
                  SizedBox(width: subIconSpacing),
                  Text(
                    'Landscape',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: subFontSize,
                      fontWeight: FontWeight.w400,
                      letterSpacing: subLetterSpacing,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Premium animated card with Netflix-style exit/enter animations
  /// Animations match phone tilt direction for intuitive UX:
  /// - Correct (tilt down) → Card sweeps DOWN
  /// - Pass (tilt up) → Card sweeps UP
  Widget _buildAnimatedCard(String currentCard) {
    final exitProgress = Curves.easeInBack.transform(
      _cardExitController.value.clamp(0.0, 1.0),
    );
    final enterProgress = Curves.easeOutBack.transform(
      _cardEnterController.value.clamp(0.0, 1.0),
    );

    // Calculate transforms based on action type
    double translateY = 0;
    double rotation = 0;
    double scale = 1.0;
    double opacity = 1.0;

    if (_isCorrectAction && _cardExitController.isAnimating) {
      // Correct: Card sweeps DOWNWARD (matching phone tilt down gesture)
      translateY = 500 * exitProgress; // Positive = down
      rotation = -0.12 * exitProgress; // Slight tilt as it falls
      scale =
          1.0 + (0.08 * exitProgress) - (0.25 * exitProgress * exitProgress);
      opacity = 1.0 - (exitProgress * 0.9);
    } else if (_isPassAction && _cardExitController.isAnimating) {
      // Pass: Card sweeps UPWARD (matching phone tilt up gesture)
      translateY = -450 * exitProgress; // Negative = up
      rotation = 0.1 * exitProgress; // Slight tilt as it rises
      scale = 1.0 - (0.12 * exitProgress);
      opacity = 1.0 - exitProgress;
    }

    // Enter animation for new card - comes from opposite direction
    if (_cardEnterController.isAnimating &&
        !_isCorrectAction &&
        !_isPassAction) {
      final enterY = -50 * (1 - enterProgress); // Subtle slide in from above
      scale = 0.85 + (0.15 * enterProgress);
      opacity = enterProgress;

      return Transform(
        alignment: Alignment.center,
        transform:
            Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..translate(0.0, enterY)
              ..scale(scale),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: _buildCardFront(currentCard),
        ),
      );
    }

    return Transform(
      alignment: Alignment.center,
      transform:
          Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..translate(0.0, translateY)
            ..rotateZ(rotation)
            ..scale(scale),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: _buildCardFront(currentCard),
      ),
    );
  }

  /// Premium feedback burst with particles and glow
  /// Direction matches the card exit animation:
  /// - Correct: Burst emanates downward (green)
  /// - Pass: Burst emanates upward (orange)
  Widget _buildPremiumFeedbackBurst() {
    return AnimatedBuilder(
      animation: _feedbackBurstController,
      builder: (context, child) {
        final progress = _feedbackBurstController.value;
        if (progress == 0) return const SizedBox.shrink();

        final color =
            _isCorrectAction ? AppTheme.successColor : AppTheme.warningColor;
        final burstScale = Curves.easeOutQuart.transform(progress);
        final fadeOut = 1.0 - Curves.easeInQuart.transform(progress);

        // Direction multiplier: positive for down (correct), negative for up (pass)
        final directionY = _isCorrectAction ? 1.0 : -1.0;

        // Icon follows card direction
        final iconOffsetY =
            directionY * 150 * Curves.easeOutQuart.transform(progress);

        // Full screen flash opacity - quick flash in, slower fade out
        double flashOpacity;
        if (progress < 0.1) {
          // Quick flash in (0 to peak in first 10%)
          flashOpacity = Curves.easeOut.transform(progress / 0.1);
        } else {
          // Slower fade out
          flashOpacity =
              1.0 - Curves.easeInQuad.transform((progress - 0.1) / 0.9);
        }

        return Stack(
          children: [
            // FULL SCREEN solid color flash overlay - covers everything
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: color.withOpacity(0.5 * flashOpacity)),
              ),
            ),

            // Bright white flash layer for extra impact
            if (progress < 0.2)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.white.withOpacity(
                      0.25 * (1 - (progress / 0.2)),
                    ),
                  ),
                ),
              ),

            // Expanding ring that follows direction
            Center(
              child: Transform.translate(
                offset: Offset(0, iconOffsetY * 0.3),
                child: Transform.scale(
                  scale: 0.5 + (burstScale * 2.0),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(0.5 * fadeOut),
                        width: 3 * (1 - progress),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Second ring
            Center(
              child: Transform.translate(
                offset: Offset(0, iconOffsetY * 0.2),
                child: Transform.scale(
                  scale: 0.3 + (burstScale * 1.5),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35 * fadeOut),
                        width: 2 * (1 - progress),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Directional particle burst
            ..._buildDirectionalBurstParticles(progress, color, directionY),

            // Central icon that moves in the direction of the card
            Center(
              child: Transform.translate(
                offset: Offset(0, iconOffsetY),
                child: Transform.scale(
                  scale:
                      progress < 0.25
                          ? Curves.elasticOut.transform(
                            (progress / 0.25).clamp(0.0, 1.0),
                          )
                          : 1.0 - ((progress - 0.25) / 0.75 * 0.4),
                  child: Opacity(
                    opacity: fadeOut,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: 25,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isCorrectAction
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: Colors.white,
                        size: 55,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Text label follows direction
            Center(
              child: Transform.translate(
                offset: Offset(0, iconOffsetY + (directionY * 70)),
                child: Opacity(
                  opacity:
                      progress < 0.15
                          ? (progress / 0.15).clamp(0.0, 1.0)
                          : 1.0 - ((progress - 0.4) / 0.6).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      _isCorrectAction ? 'CORRECT!' : 'PASS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Generate directional burst particles for feedback animation
  /// Particles flow in the direction of the card movement
  List<Widget> _buildDirectionalBurstParticles(
    double progress,
    Color color,
    double directionY,
  ) {
    final particles = <Widget>[];
    final particleCount = _isCorrectAction ? 12 : 8;
    final fadeOut = 1.0 - Curves.easeInQuad.transform(progress);

    // Main directional particles - spread in a cone shape
    for (int i = 0; i < particleCount; i++) {
      // Angle spread: particles mostly go in the direction but with some spread
      final spreadAngle =
          (i / particleCount - 0.5) * math.pi * 0.8; // Cone spread
      final baseAngle =
          directionY > 0 ? math.pi / 2 : -math.pi / 2; // Down or Up
      final angle = baseAngle + spreadAngle;

      final distance = 60 + (progress * 200);
      final sizeVariation = 1.0 + (math.sin(i * 1.5) * 0.4);
      final speedVariation = 0.8 + (math.cos(i * 2.0) * 0.4);

      particles.add(
        Center(
          child: Transform.translate(
            offset: Offset(
              math.cos(angle) * distance * speedVariation,
              math.sin(angle) * distance * speedVariation,
            ),
            child: Transform.rotate(
              angle: progress * math.pi,
              child: Opacity(
                opacity: (fadeOut * 0.9).clamp(0.0, 1.0),
                child: Container(
                  width: (7 * sizeVariation) * (1 - progress * 0.4),
                  height: (7 * sizeVariation) * (1 - progress * 0.4),
                  decoration: BoxDecoration(
                    color: i % 2 == 0 ? color : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (i % 2 == 0 ? color : Colors.white).withOpacity(
                          0.5,
                        ),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Trail particles that follow the main direction
    for (int i = 0; i < 6; i++) {
      final trailProgress = (progress - (i * 0.05)).clamp(0.0, 1.0);
      if (trailProgress <= 0) continue;

      final trailDistance = 40 + (trailProgress * 120);
      final xOffset = (i - 2.5) * 25; // Spread horizontally

      particles.add(
        Center(
          child: Transform.translate(
            offset: Offset(xOffset, directionY * trailDistance),
            child: Opacity(
              opacity: ((1 - trailProgress) * 0.6).clamp(0.0, 1.0),
              child: Container(
                width: 5 * (1 - trailProgress * 0.5),
                height: 12 * (1 - trailProgress * 0.3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Extra celebration elements for correct action
    if (_isCorrectAction) {
      // Checkmark sparkles
      for (int i = 0; i < 6; i++) {
        final sparkleAngle = (i / 6) * math.pi + (math.pi / 2); // Bottom half
        final sparkleDistance = 100 + (progress * 150);
        final sparkleDelay = i * 0.08;
        final sparkleProgress = (progress - sparkleDelay).clamp(0.0, 1.0);

        if (sparkleProgress > 0) {
          particles.add(
            Center(
              child: Transform.translate(
                offset: Offset(
                  math.cos(sparkleAngle) * sparkleDistance * sparkleProgress,
                  math.sin(sparkleAngle) * sparkleDistance * sparkleProgress,
                ),
                child: Opacity(
                  opacity: ((1 - sparkleProgress) * 0.7).clamp(0.0, 1.0),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.amber,
                    size: 18 * (1 - sparkleProgress * 0.4),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return particles;
  }

  /// Builds animated particles around the countdown
  /// Design baseline: iPhone 16 Pro Max (440 x 956 pts)
  List<Widget> _buildParticlesScaled(double progress, double scale) {
    // =================================================================
    // REFERENCE VALUES FOR IPHONE 16 PRO MAX
    // =================================================================
    const double refBaseDistance = 110.0;
    const double refDistanceRange = 90.0;
    const double refBaseParticleSize = 5.0;
    const double refParticleSizeRange = 4.0;
    const double refBlurRadius = 12.0;
    const double refSpreadRadius = 3.0;
    const int particleCount = 8;

    final particles = <Widget>[];

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final distance =
          (refBaseDistance + (progress * refDistanceRange)) * scale;
      final particleOpacity = (1 - progress) * 0.65;
      final particleSize =
          (refBaseParticleSize +
              (math.sin(progress * math.pi) * refParticleSizeRange)) *
          scale;
      final blurRadius = refBlurRadius * scale;
      final spreadRadius = refSpreadRadius * scale;

      particles.add(
        Transform.translate(
          offset: Offset(
            math.cos(angle + (progress * 0.5)) * distance,
            math.sin(angle + (progress * 0.5)) * distance,
          ),
          child: Container(
            width: particleSize,
            height: particleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(particleOpacity),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(particleOpacity * 0.5),
                  blurRadius: blurRadius,
                  spreadRadius: spreadRadius,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return particles;
  }

  Widget _buildExpandingRing(
    double progress, {
    required double size,
    required double startSize,
    required double opacity,
    required double strokeWidth,
    double delay = 0.0,
  }) {
    final adjustedProgress = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    final currentSize = startSize + ((size - startSize) * adjustedProgress);
    final currentOpacity = opacity * (1 - adjustedProgress);

    return Container(
      width: currentSize,
      height: currentSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(currentOpacity),
          width: strokeWidth,
        ),
      ),
    );
  }

  Widget _buildGameplay() {
    final gameProvider = context.watch<GameProvider>();
    final currentCard =
        gameProvider.currentSession?.currentCard ?? 'Loading...';

    return Column(
      children: [
        // Modern header with timer
        _buildModernHeader(gameProvider),

        // Team indicator (if team mode)
        if (widget.isTeamMode)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.teamNames![widget.currentTeamIndex!],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Card area with premium animations
        Expanded(
          child: Stack(
            children: [
              // Main card with premium exit/enter animations
              Center(
                child: Semantics(
                  label: currentCard,
                  liveRegion: true,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _cardExitController,
                      _cardEnterController,
                    ]),
                    builder: (context, child) {
                      return _buildAnimatedCard(currentCard);
                    },
                  ),
                ),
              ),

              // Premium feedback burst overlay
              if (_isCorrectAction || _isPassAction)
                _buildPremiumFeedbackBurst(),

              // Manual control buttons
              if (_useManualControls && !_isCountingDown)
                _buildModernControlButtons(),

              // Control mode toggle
              _buildControlToggle(),
            ],
          ),
        ),

        // Score indicator
        _buildScoreIndicator(gameProvider),
      ],
    );
  }

  Widget _buildModernHeader(GameProvider gameProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pause button
          _buildGlassButton(icon: Icons.pause_rounded, onTap: _pauseGame),

          // Timer with modern design
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _timerPulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_timerPulseController.value * 0.05);
                  final remainingTime =
                      gameProvider.currentSession?.remainingTime.inSeconds ??
                      60;
                  final isUnlimited = gameProvider.isUnlimitedMode;
                  final isLowTime = !isUnlimited && remainingTime <= 10;

                  // Premium time warning haptics at key moments
                  if (!isUnlimited && remainingTime != _lastRemainingTime) {
                    _lastRemainingTime = remainingTime;
                    // Trigger warning haptics at critical time thresholds
                    if (remainingTime == 10 && !_hasTriggeredTimeWarning) {
                      _hasTriggeredTimeWarning = true;
                      _hapticService.timeWarning();
                    } else if (remainingTime <= 5 && remainingTime > 0) {
                      // Countdown haptics for final 5 seconds
                      _hapticService.mediumImpact();
                    } else if (remainingTime == 0) {
                      // Game over haptic
                      _hapticService.heavyImpact();
                    }
                  }

                  return Semantics(
                    label:
                        isUnlimited
                            ? 'Unlimited time'
                            : 'Time remaining: $remainingTime seconds',
                    child: Transform.scale(
                      scale: isLowTime ? scale : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color:
                                isLowTime
                                    ? Colors.redAccent.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isLowTime
                                      ? Colors.redAccent.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: isLowTime ? 5 : 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUnlimited
                                  ? Icons.all_inclusive_rounded
                                  : Icons.timer_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isUnlimited ? '∞' : '${remainingTime}s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Finish button in top right
          _buildFinishButton(),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: 'Pause game',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 24)),
        ),
      ),
    );
  }

  Widget _buildFinishButton() {
    return Semantics(
      label: 'Finish game',
      button: true,
      child: GestureDetector(
        onTap: _handleFinishGame,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Finish',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(String word) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: widget.deck.color.withOpacity(
                  0.3 + (_glowController.value * 0.1),
                ),
                blurRadius: 30 + (_glowController.value * 10),
                offset: const Offset(0, 15),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Builder(
              builder: (context) {
                final decorationColor = _getContrastedDecorationColor(
                  widget.deck.color,
                );

                return Stack(
                  children: [
                    // Decorative elements
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              decorationColor.withOpacity(0.15),
                              decorationColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Main content
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Category badge
                          Builder(
                            builder: (context) {
                              // Get contrasted colors for yellow
                              final textColor = _getContrastedTextColor(
                                widget.deck.color,
                              );
                              final badgeDecorationColor =
                                  _getContrastedDecorationColor(
                                    widget.deck.color,
                                  );

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeDecorationColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: badgeDecorationColor.withOpacity(
                                      0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.deck.icon,
                                      size: 16,
                                      color: textColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.deck.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          // Word with gradient - use contrasted color for yellow
                          Builder(
                            builder: (context) {
                              final textColor = _getContrastedTextColor(
                                widget.deck.color,
                              );

                              return Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: ShaderMask(
                                    shaderCallback:
                                        (bounds) => LinearGradient(
                                          colors: [
                                            textColor,
                                            textColor.withOpacity(0.8),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ).createShader(bounds),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        word,
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernControlButtons() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Pass button
            _buildActionButton(
              onTap: _handleManualPass,
              color: AppTheme.warningColor,
              icon: Icons.close_rounded,
              label: 'PASS',
              isLeft: true,
            ),
            // Correct button
            _buildActionButton(
              onTap: _handleManualCorrect,
              color: AppTheme.successColor,
              icon: Icons.check_rounded,
              label: 'CORRECT',
              isLeft: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required Color color,
    required IconData icon,
    required String label,
    required bool isLeft,
  }) {
    return Semantics(
      label:
          label == 'PASS' ? 'Pass, skip this card' : 'Correct, mark as guessed',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child:
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withOpacity(0.3), color.withOpacity(0.2)],
                    ),
                    border: Border.all(color: color.withOpacity(0.5), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 44),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .scale(
                  delay: isLeft ? 400.ms : 500.ms,
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(),
      ),
    );
  }

  Widget _buildControlToggle() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Semantics(
        label:
            _useManualControls
                ? 'Switch to tilt controls'
                : 'Switch to manual controls',
        button: true,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _useManualControls = !_useManualControls;

              if (!_useManualControls) {
                // Initialize sensors when switching to tilt mode
                _initializeSensors(isRecalibration: true);
              } else {
                // Stop all sensor subscriptions when using manual controls
                _calibrationSubscription?.cancel();
                _calibrationSubscription = null;
                _sensorSubscription?.cancel();
                _sensorSubscription = null;
                _gyroSubscription?.cancel();
                _gyroSubscription = null;
              }
            });
            SharedPreferences.getInstance().then((prefs) {
              prefs.setBool('use_manual_controls', _useManualControls);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12.s),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              _useManualControls ? Icons.touch_app : Icons.screen_rotation,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(GameProvider gameProvider) {
    final correct = gameProvider.currentSession?.correctCount ?? 0;
    final passed = gameProvider.currentSession?.passCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: '$correct correct',
            child: _buildScoreItem(
              icon: Icons.check_circle,
              count: correct,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 32),
          Semantics(
            label: '$passed passed',
            child: _buildScoreItem(
              icon: Icons.skip_next,
              count: passed,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem({
    required IconData icon,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackOverlay() {
    // The premium feedback is now handled by _buildPremiumFeedbackBurst
    // This overlay is kept for additional ambient effects
    return AnimatedBuilder(
      animation: _feedbackController,
      builder: (context, child) {
        if (_feedbackController.value == 0) {
          return const SizedBox.shrink();
        }

        // Premium curve for smooth fade
        final progress = _feedbackController.value;
        final opacity =
            progress < 0.5
                ? Curves.easeOut.transform(progress * 2)
                : Curves.easeIn.transform(1.0 - (progress - 0.5) * 2);

        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:
                      _feedbackColor == AppTheme.successColor
                          ? Alignment.topCenter
                          : Alignment.centerRight,
                  end:
                      _feedbackColor == AppTheme.successColor
                          ? Alignment.bottomCenter
                          : Alignment.centerLeft,
                  colors: [
                    _feedbackColor.withOpacity(0.15 * opacity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for modern background
class _ElegantBackgroundPainter extends CustomPainter {
  final double animation;
  final Color color;

  _ElegantBackgroundPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeWidth = 1;

    // Draw animated wave patterns
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final waveHeight = 30.0 - (layer * 10);
      final opacity = 0.05 - (layer * 0.015);

      path.moveTo(0, size.height * (0.3 + layer * 0.2));

      for (double x = 0; x <= size.width; x += 5) {
        final normalizedX = x / size.width;
        final baseY = size.height * (0.3 + layer * 0.2);
        final waveY =
            baseY +
            math.sin((normalizedX * 3 + animation * 2) * math.pi) * waveHeight +
            math.sin((normalizedX * 5 + animation * 3) * math.pi) *
                (waveHeight / 2);

        if (x == 0) {
          path.moveTo(x, waveY);
        } else {
          path.lineTo(x, waveY);
        }
      }

      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(path, paint);
    }

    // Draw subtle grid pattern
    paint.shader = null;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.5;

    final gridSize = 60.0;
    final gridOpacity = 0.03 + math.sin(animation * math.pi * 2) * 0.01;
    paint.color = Colors.white.withOpacity(gridOpacity);

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw corner accents
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    paint.color = Colors.white.withOpacity(0.1);

    final cornerLength = 40.0;

    // Top left
    canvas.drawLine(Offset(0, cornerLength), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(cornerLength, 0), paint);

    // Top right
    canvas.drawLine(
      Offset(size.width - cornerLength, 0),
      Offset(size.width, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom left
    canvas.drawLine(
      Offset(0, size.height - cornerLength),
      Offset(0, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );

    // Bottom right
    canvas.drawLine(
      Offset(size.width - cornerLength, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - cornerLength),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ElegantBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

// Custom painter for countdown arc animation
class _CountdownArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CountdownArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc (subtle)
    final backgroundPaint =
        Paint()
          ..color = color.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc with gradient effect
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Create gradient shader for the arc
    final gradientPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: [
              color.withOpacity(0.9),
              color.withOpacity(0.7),
              color.withOpacity(0.5),
              color.withOpacity(0.3),
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
            transform: GradientRotation(-math.pi / 2),
          ).createShader(rect);

    // Draw progress arc
    canvas.drawArc(
      rect,
      -math.pi / 2, // Start from top
      2 * math.pi * progress, // Sweep based on progress
      false,
      gradientPaint,
    );

    // Draw glow effect at the arc end point
    if (progress > 0) {
      final endAngle = -math.pi / 2 + (2 * math.pi * progress);
      final endPoint = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      final glowPaint =
          Paint()
            ..color = color.withOpacity(0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(endPoint, strokeWidth * 1.5, glowPaint);

      // Bright center point
      final dotPaint =
          Paint()
            ..color = color
            ..style = PaintingStyle.fill;

      canvas.drawCircle(endPoint, strokeWidth / 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CountdownArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
