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
import '../constants/app_theme.dart';
import '../models/deck.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../widgets/tutorial_hint_overlay.dart';
import 'results_screen.dart';
import 'team_results_screen.dart';
import '../services/camera_recording_service.dart';
import '../models/video_recording_result.dart';
import '../utils/responsive.dart';

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

  // Accelerometer
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _canDetectTilt = false;
  bool _hasTriggeredAction = false;

  // Calibration values
  double _calibrationX = 0.0;
  double _calibrationY = 0.0;
  double _calibrationZ = 0.0;
  bool _isCalibrated = false;

  // Neutral position tracking
  bool _isInNeutralPosition = true;
  DateTime? _lastActionTime;
  static const _minTimeBetweenActions = Duration(
    milliseconds: 1500,
  ); // Increased for stability
  static const _neutralThreshold = 20.0; // Increased neutral zone for stability

  // Stability improvements
  static const _actionThreshold =
      45.0; // High threshold for very deliberate actions only
  bool _actionLocked = false; // Prevent any action during cooldown

  // Debug flag - set to true to see accelerometer values
  static const _debugAccelerometer = false;

  // Game state
  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;

  // Feedback state
  Color _feedbackColor = Colors.transparent;

  // Card action animation state
  bool _isCorrectAction = false;
  bool _isPassAction = false;

  // Tutorial hints
  bool _showTutorialHints = false;
  int _gamesPlayed = 0;

  // Control mode
  bool _useManualControls = false;
  bool _isLandscapeMode = false;

  // Camera recording
  final _cameraRecording = CameraRecordingService.instance;
  bool _isCameraEnabled = false;
  bool _isRecordingVideo = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkTutorialHints();
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
      debugPrint('=== GAME STATE CHANGE DETECTED ===');
      debugPrint('Game ended via timer/provider, navigating to results...');
      debugPrint('Is recording: $_isRecordingVideo');

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
    _isLandscapeMode = prefs.getBool('prefer_landscape_gameplay') ?? true;
    _useManualControls = prefs.getBool('use_manual_controls') ?? false;

    if (_isLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _checkTutorialHints() async {
    final prefs = await SharedPreferences.getInstance();
    _gamesPlayed = prefs.getInt('games_played') ?? 0;

    // Show hints for first 3 games
    if (_gamesPlayed < 3) {
      setState(() {
        _showTutorialHints = true;
      });
    }

    // Increment games played
    await prefs.setInt('games_played', _gamesPlayed + 1);
  }

  Future<void> _checkCameraPreference() async {
    debugPrint('Checking camera preference...');
    final prefs = await SharedPreferences.getInstance();
    _isCameraEnabled = prefs.getBool('enable_reaction_recording') ?? true;
    debugPrint('Camera enabled preference: $_isCameraEnabled');

    // Debug: Check all preferences
    final allKeys = prefs.getKeys();
    debugPrint('All preference keys: $allKeys');
    for (final key in allKeys) {
      if (key.contains('reaction') ||
          key.contains('camera') ||
          key.contains('record')) {
        debugPrint('Preference $key = ${prefs.get(key)}');
      }
    }

    // Don't initialize camera here - wait until game starts
    // This ensures permissions are requested when app is fully active
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
    if (!_useManualControls) {
      _calibrateAccelerometer();
    }
    _audioService.playClick();
    _hapticService.mediumImpact();

    // Initialize camera first, then start recording
    if (_isCameraEnabled) {
      debugPrint('=== CAMERA RECORDING START ===');
      debugPrint('Game starting - initializing camera...');
      debugPrint('Camera preference enabled: $_isCameraEnabled');

      // The camera package will automatically request permissions
      final initialized = await _cameraRecording.initialize();
      debugPrint('Camera initialization result: $initialized');

      if (initialized) {
        debugPrint('Camera initialized during game start');
        final recordingStarted = await _startVideoRecording();
        debugPrint('Recording started result: $recordingStarted');
      } else {
        debugPrint('Camera initialization failed during game start');
        _isCameraEnabled = false;
      }
    } else {
      debugPrint('=== CAMERA DISABLED ===');
      debugPrint('Camera recording disabled by user preference');
    }
  }

  Future<bool> _startVideoRecording() async {
    debugPrint(
      '_startVideoRecording called. Camera enabled: $_isCameraEnabled',
    );
    if (!_isCameraEnabled) {
      debugPrint('Camera not enabled, skipping recording');
      return false;
    }

    debugPrint('Starting video recording...');
    debugPrint('Deck name: ${widget.deck.name}');
    debugPrint('Deck color: ${widget.deck.color.toString()}');

    final success = await _cameraRecording.startRecording(
      widget.deck.name,
      widget.deck.color.toString(),
    );

    if (success) {
      setState(() {
        _isRecordingVideo = true;
      });
      debugPrint('Video recording started successfully');
      debugPrint('_isRecordingVideo set to: $_isRecordingVideo');
    } else {
      debugPrint('Failed to start video recording');
    }

    return success;
  }

  void _calibrateAccelerometer() {
    // Reset state before calibration
    _isInNeutralPosition = true;
    _hasTriggeredAction = false;
    _lastActionTime = null;
    _actionLocked = false;

    // Wait a moment for the user to position the phone, then calibrate
    Future.delayed(const Duration(milliseconds: 500), () {
      accelerometerEventStream().first.then((event) {
        _calibrationX = event.x;
        _calibrationY = event.y;
        _calibrationZ = event.z;
        _isCalibrated = true;
        _canDetectTilt = true;
        _startAccelerometer();
      });
    });
  }

  void _startAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!_canDetectTilt || !_isCalibrated) return;

      // Calculate relative tilt from calibrated position
      final deltaX = event.x - _calibrationX;
      final deltaY = event.y - _calibrationY;
      final deltaZ = event.z - _calibrationZ;

      // IMPORTANT: Understanding accelerometer axes in different orientations:
      //
      // Portrait mode (phone vertical):
      // - X-axis: left(-) to right(+)
      // - Y-axis: bottom(-) to top(+) - THIS IS OUR TILT AXIS
      // - Z-axis: back(-) to front(+)
      //
      // Landscape mode (phone horizontal, rotated 90° counter-clockwise):
      // - The axes rotate with the device!
      // - What was Y-axis becomes X-axis
      // - What was X-axis becomes -Y-axis
      // - Z-axis remains the same
      //
      // When phone is held to forehead in landscape:
      // - Tilting forward (away from head) = CORRECT
      // - Tilting backward (toward head) = PASS
      // - This is detected via Z-axis changes

      double tiltAngle;

      if (_isLandscapeMode) {
        // In landscape mode, when phone is on forehead:
        // Forward/backward tilt affects Z-axis (perpendicular to screen)
        // We use Z-axis change to detect the tilt
        tiltAngle = deltaZ * 10; // Scale for sensitivity

        if (_debugAccelerometer) {
          print(
            'Landscape - X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, Z: ${event.z.toStringAsFixed(2)} | '
            'DeltaX: ${deltaX.toStringAsFixed(2)}, DeltaY: ${deltaY.toStringAsFixed(2)}, DeltaZ: ${deltaZ.toStringAsFixed(2)} | '
            'TiltAngle: ${tiltAngle.toStringAsFixed(1)}',
          );
        }

        // Filter out side-to-side movements (rotation around vertical axis)
        // In landscape, this would be deltaY (because axes are rotated)
        if (deltaY.abs() > 5.0) {
          if (_debugAccelerometer) {
            print('Ignoring - too much rotation');
          }
          return;
        }
      } else {
        // In portrait mode:
        // Forward/backward tilt affects Y-axis
        tiltAngle = deltaY * 10;

        if (_debugAccelerometer) {
          print(
            'Portrait - X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, Z: ${event.z.toStringAsFixed(2)} | '
            'DeltaX: ${deltaX.toStringAsFixed(2)}, DeltaY: ${deltaY.toStringAsFixed(2)}, DeltaZ: ${deltaZ.toStringAsFixed(2)} | '
            'TiltAngle: ${tiltAngle.toStringAsFixed(1)}',
          );
        }

        // Filter out side-to-side movements
        if (deltaX.abs() > 5.0) {
          if (_debugAccelerometer) {
            print('Ignoring - too much side movement');
          }
          return;
        }
      }

      // Check if we're in neutral position
      if (tiltAngle.abs() < _neutralThreshold) {
        // Phone is in neutral position
        if (!_isInNeutralPosition) {
          _isInNeutralPosition = true;
          _hasTriggeredAction =
              false; // Reset trigger flag when returning to neutral
        }
        return;
      }

      // Check if enough time has passed since last action
      if (_lastActionTime != null) {
        final timeSinceLastAction = DateTime.now().difference(_lastActionTime!);
        if (timeSinceLastAction < _minTimeBetweenActions) {
          return; // Too soon for another action
        }
      }

      // Only process tilt if we were in neutral position and haven't triggered yet
      if (!_isInNeutralPosition || _hasTriggeredAction) {
        return;
      }

      // Adjusted thresholds for better detection
      // In landscape with Z-axis: positive deltaZ = tilt backward (toward head) = PASS
      //                           negative deltaZ = tilt forward (away from head) = CORRECT
      const correctThreshold =
          -_actionThreshold; // Tilt forward (away from head) to mark correct
      const passThreshold =
          _actionThreshold; // Tilt backward (toward head) to pass

      if (_isLandscapeMode) {
        // In landscape mode, the directions are specific to Z-axis behavior
        if (tiltAngle < correctThreshold) {
          // Tilted forward (away from head) - Correct
          _isInNeutralPosition = false;
          _hasTriggeredAction = true;
          _lastActionTime = DateTime.now();
          _handleCorrect();
        } else if (tiltAngle > passThreshold) {
          // Tilted backward (toward head) - Pass
          _isInNeutralPosition = false;
          _hasTriggeredAction = true;
          _lastActionTime = DateTime.now();
          _handlePass();
        }
      } else {
        // In portrait mode, keep the original logic
        if (tiltAngle > _actionThreshold) {
          // Tilted forward - Pass
          _isInNeutralPosition = false;
          _hasTriggeredAction = true;
          _lastActionTime = DateTime.now();
          _handlePass();
        } else if (tiltAngle < -_actionThreshold) {
          // Tilted backward - Correct
          _isInNeutralPosition = false;
          _hasTriggeredAction = true;
          _lastActionTime = DateTime.now();
          _handleCorrect();
        }
      }
    });
  }

  void _handleCorrect() {
    if (_actionLocked) return; // Prevent duplicate actions
    _actionLocked = true;

    // Get current word before marking correct
    final gameProvider = context.read<GameProvider>();
    final currentWord = gameProvider.currentSession?.currentCard ?? '';

    // Update game state
    gameProvider.markCorrect();

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

    // Play effects
    _audioService.playCorrect();
    _hapticService.lightImpact();

    // Premium card exit animation
    _cardExitController.forward(from: 0).then((_) {
      setState(() {
        _isCorrectAction = false;
      });
      _cardExitController.reset();
      _cardEnterController.forward(from: 0);
      _prepareNextCard();
    });

    // Unlock after cooldown
    Future.delayed(_minTimeBetweenActions, () {
      _actionLocked = false;
    });
  }

  void _handlePass() {
    if (_actionLocked) return; // Prevent duplicate actions
    _actionLocked = true;

    // Get current word before marking pass
    final gameProvider = context.read<GameProvider>();
    final currentWord = gameProvider.currentSession?.currentCard ?? '';

    // Update game state
    gameProvider.markPass();

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

    // Play effects
    _audioService.playPass();
    _hapticService.selection();

    // Premium card exit animation
    _cardExitController.forward(from: 0).then((_) {
      setState(() {
        _isPassAction = false;
      });
      _cardExitController.reset();
      _cardEnterController.forward(from: 0);
      _prepareNextCard();
    });

    // Unlock after cooldown
    Future.delayed(_minTimeBetweenActions, () {
      _actionLocked = false;
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
        debugPrint('Game over detected in _prepareNextCard');
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

        // Note: We don't reset flags here anymore
        // The neutral position detection will handle resetting when phone returns to neutral
        // This prevents the issue where holding the phone tilted causes continuous triggers
        setState(() {});
      }
    });
  }

  Future<void> _navigateToResults() async {
    if (_isNavigating) {
      debugPrint('Already navigating, skipping...');
      return;
    }
    _isNavigating = true;

    debugPrint('_navigateToResults called');
    _accelerometerSubscription?.cancel();

    // Stop video recording and get result
    if (_isRecordingVideo) {
      debugPrint('Video is recording, stopping and navigating...');
      await _stopRecordingAndNavigate();
    } else {
      debugPrint('No video recording, navigating directly...');
      _navigateToResultsScreen();
    }
  }

  Future<void> _stopRecordingAndNavigate() async {
    debugPrint(
      '_stopRecordingAndNavigate called. Is recording: $_isRecordingVideo',
    );
    VideoRecordingResult? recordingResult;

    if (_isRecordingVideo) {
      debugPrint('Stopping video recording...');
      setState(() {
        _isRecordingVideo = false; // Prevent multiple stops
      });

      recordingResult = await _cameraRecording.stopRecording(
        widget.deck.name,
        widget.deck.color.toString(),
      );

      // Store in game provider
      if (recordingResult != null) {
        debugPrint(
          'Recording result received. Video path: ${recordingResult.videoPath}',
        );
        debugPrint('Recording duration: ${recordingResult.duration}');
        debugPrint('Recording events: ${recordingResult.events.length}');

        // Verify file exists before storing
        final videoFile = File(recordingResult.videoPath);
        final exists = await videoFile.exists();
        debugPrint('Video file exists before storing: $exists');

        if (!mounted) {
          debugPrint('Widget not mounted, cannot store recording');
          return;
        }

        context.read<GameProvider>().setVideoRecording(recordingResult);
        debugPrint('Recording result stored in GameProvider');

        // Verify it was stored
        final storedRecording = context.read<GameProvider>().lastVideoRecording;
        debugPrint('Verified storage: ${storedRecording != null}');

        // Small delay to ensure provider updates propagate
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        debugPrint('Recording result is null');
      }
    } else {
      debugPrint('Not recording video, skipping stop');
    }

    if (mounted) {
      _navigateToResultsScreen();
    }
  }

  void _navigateToResultsScreen() {
    debugPrint('=== NAVIGATING TO RESULTS ===');
    final gameProvider = context.read<GameProvider>();
    final recording = gameProvider.lastVideoRecording;
    debugPrint('Video recording in provider: ${recording != null}');
    if (recording != null) {
      debugPrint('Video path: ${recording.videoPath}');
      debugPrint('Video duration: ${recording.duration}');
    }

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
    _handleCorrect();
  }

  void _handleManualPass() {
    if (_isCountingDown || _actionLocked) return;
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
                      style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
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
    _canDetectTilt = false;

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
                                    _canDetectTilt = true;
                                    // Reset tilt detection state when resuming
                                    _isInNeutralPosition = true;
                                    _hasTriggeredAction = false;
                                    _actionLocked = false;
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
    _accelerometerSubscription?.cancel();
    // Reset orientation to default
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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

              // Tutorial hints
              if (_showTutorialHints && !_isCountingDown)
                TutorialHintOverlay(
                  showHints: true,
                  onDismiss: () {
                    setState(() {
                      _showTutorialHints = false;
                    });
                  },
                ),
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
    // Use the smaller dimension to ensure it fits in landscape
    final minDimension = isLandscape ? screenSize.height : screenSize.width;
    // Scale factor for landscape mode
    final scaleFactor = isLandscape ? (minDimension / 400).clamp(0.6, 1.0) : 1.0;

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

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main countdown animation container
              SizedBox(
                width: 350 * scaleFactor,
                height: 350 * scaleFactor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outermost expanding ring with fade
                    _buildExpandingRing(
                      ringValue,
                      size: 350 * scaleFactor,
                      startSize: 120 * scaleFactor,
                      opacity: 0.15,
                      strokeWidth: 1,
                    ),

                    // Second expanding ring
                    _buildExpandingRing(
                      ringValue,
                      size: 300 * scaleFactor,
                      startSize: 100 * scaleFactor,
                      opacity: 0.25,
                      strokeWidth: 1.5,
                      delay: 0.1,
                    ),

                    // Third expanding ring
                    _buildExpandingRing(
                      ringValue,
                      size: 250 * scaleFactor,
                      startSize: 80 * scaleFactor,
                      opacity: 0.35,
                      strokeWidth: 2,
                      delay: 0.2,
                    ),

                    // Pulsing glow effect behind number
                    Transform.scale(
                      scale: 1.0 + (pulseValue * 0.3),
              child: Container(
                        width: 200 * scaleFactor,
                        height: 200 * scaleFactor,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.deck.color.withOpacity(0.4 * (1 - pulseValue)),
                              widget.deck.color.withOpacity(0.2 * (1 - pulseValue)),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Inner glowing circle
                    Container(
                      width: 160 * scaleFactor,
                      height: 160 * scaleFactor,
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
                          color: Colors.white.withOpacity(0.4 + (pulseValue * 0.2)),
                          width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 30 + (pulseValue * 20),
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: widget.deck.color.withOpacity(0.4),
                            blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                    ),

                    // Animated progress arc
                    SizedBox(
                      width: 180 * scaleFactor,
                      height: 180 * scaleFactor,
                      child: CustomPaint(
                        painter: _CountdownArcPainter(
                          progress: 1.0 - ringValue,
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),

                    // Main number with dramatic animation
                    Transform.scale(
                      scale: numberScale,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: blurValue * 8,
                          sigmaY: blurValue * 8,
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
                                  color: widget.deck.color.withOpacity(0.5),
                                  fontSize: 120 * scaleFactor,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -4,
                                ),
                              ),
                              // Main text with gradient
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
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
                                    fontSize: 120 * scaleFactor,
                          fontWeight: FontWeight.w900,
                          height: 1,
                                    letterSpacing: -4,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 20,
                                        offset: Offset(0, 10),
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
              SizedBox(height: 16 * scaleFactor),

              // Forehead instruction with animated icon - compact for landscape
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: elasticValue > 0.6 ? 1.0 : 0.0,
                child: Transform.translate(
                  offset: Offset(0, 25 * (1 - elasticValue)),
                  child: _buildForeheadHint(pulseValue, scaleFactor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compact, elegant forehead placement hint for landscape mode
  Widget _buildForeheadHint(double pulseValue, double scaleFactor) {
    // Subtle floating animation for the phone icon
    final floatOffset = math.sin(pulseValue * math.pi * 2) * 2;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scaleFactor,
        vertical: 10 * scaleFactor,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated phone + head icon
          SizedBox(
            width: 28 * scaleFactor,
            height: 28 * scaleFactor,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Head silhouette
                Container(
                  width: 20 * scaleFactor,
                  height: 20 * scaleFactor,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                ),
                // Phone on forehead with float animation
                Positioned(
                  top: (1 + floatOffset) * scaleFactor,
                  child: Transform.rotate(
                    angle: math.pi / 2,
                    child: Container(
                      width: 14 * scaleFactor,
                      height: 7 * scaleFactor,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * scaleFactor),
          // Text instruction
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                      Text(
                'Place on forehead',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                  fontSize: 12 * scaleFactor,
                          fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 1 * scaleFactor),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stay_current_landscape_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 10 * scaleFactor,
                  ),
                  SizedBox(width: 3 * scaleFactor),
                  Text(
                    'Landscape',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 9 * scaleFactor,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
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
      scale = 1.0 + (0.08 * exitProgress) - (0.25 * exitProgress * exitProgress);
      opacity = 1.0 - (exitProgress * 0.9);
    } else if (_isPassAction && _cardExitController.isAnimating) {
      // Pass: Card sweeps UPWARD (matching phone tilt up gesture)
      translateY = -450 * exitProgress; // Negative = up
      rotation = 0.1 * exitProgress; // Slight tilt as it rises
      scale = 1.0 - (0.12 * exitProgress);
      opacity = 1.0 - exitProgress;
    }

    // Enter animation for new card - comes from opposite direction
    if (_cardEnterController.isAnimating && !_isCorrectAction && !_isPassAction) {
      final enterY = -50 * (1 - enterProgress); // Subtle slide in from above
      scale = 0.85 + (0.15 * enterProgress);
      opacity = enterProgress;
      
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
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
      transform: Matrix4.identity()
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

        final color = _isCorrectAction ? AppTheme.successColor : AppTheme.warningColor;
        final burstScale = Curves.easeOutQuart.transform(progress);
        final fadeOut = 1.0 - Curves.easeInQuart.transform(progress);
        
        // Direction multiplier: positive for down (correct), negative for up (pass)
        final directionY = _isCorrectAction ? 1.0 : -1.0;
        
        // Icon follows card direction
        final iconOffsetY = directionY * 150 * Curves.easeOutQuart.transform(progress);
        
        // Full screen flash opacity - quick flash in, slower fade out
        double flashOpacity;
        if (progress < 0.1) {
          // Quick flash in (0 to peak in first 10%)
          flashOpacity = Curves.easeOut.transform(progress / 0.1);
        } else {
          // Slower fade out
          flashOpacity = 1.0 - Curves.easeInQuad.transform((progress - 0.1) / 0.9);
        }

        return Stack(
          children: [
            // FULL SCREEN solid color flash overlay - covers everything
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: color.withOpacity(0.5 * flashOpacity),
                ),
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
                  scale: progress < 0.25
                      ? Curves.elasticOut.transform((progress / 0.25).clamp(0.0, 1.0))
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
                  opacity: progress < 0.15
                      ? (progress / 0.15).clamp(0.0, 1.0)
                      : 1.0 - ((progress - 0.4) / 0.6).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
  List<Widget> _buildDirectionalBurstParticles(double progress, Color color, double directionY) {
    final particles = <Widget>[];
    final particleCount = _isCorrectAction ? 12 : 8;
    final fadeOut = 1.0 - Curves.easeInQuad.transform(progress);
    
    // Main directional particles - spread in a cone shape
    for (int i = 0; i < particleCount; i++) {
      // Angle spread: particles mostly go in the direction but with some spread
      final spreadAngle = (i / particleCount - 0.5) * math.pi * 0.8; // Cone spread
      final baseAngle = directionY > 0 ? math.pi / 2 : -math.pi / 2; // Down or Up
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
                        color: (i % 2 == 0 ? color : Colors.white).withOpacity(0.5),
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
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                    ),
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

  List<Widget> _buildParticlesScaled(double progress, double scale) {
    final particles = <Widget>[];
    const particleCount = 8;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final distance = (100 + (progress * 80)) * scale;
      final particleOpacity = (1 - progress) * 0.6;
      final particleSize = (4 + (math.sin(progress * math.pi) * 3)) * scale;

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
                  blurRadius: 10,
                  spreadRadius: 2,
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

                  return Transform.scale(
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
    return GestureDetector(
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
    );
  }

  Widget _buildFinishButton() {
    return GestureDetector(
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
            child: Stack(
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
                          widget.deck.color.withOpacity(0.1),
                          widget.deck.color.withOpacity(0.0),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.deck.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.deck.color.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.deck.icon,
                              size: 16,
                              color: widget.deck.color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.deck.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.deck.color,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Word with gradient
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ShaderMask(
                            shaderCallback:
                                (bounds) => LinearGradient(
                                  colors: [
                                    widget.deck.color,
                                    widget.deck.color.withOpacity(0.7),
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
                      ),
                    ],
                  ),
                ),
              ],
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
    return GestureDetector(
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
    );
  }

  Widget _buildControlToggle() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _useManualControls = !_useManualControls;
            // Reset state when switching control modes
            _isInNeutralPosition = true;
            _hasTriggeredAction = false;
            _lastActionTime = null;
            _actionLocked = false;

            if (!_useManualControls && !_isCalibrated) {
              _calibrateAccelerometer();
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
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Icon(
            _useManualControls ? Icons.touch_app : Icons.screen_rotation,
            color: Colors.white,
            size: 20,
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
          _buildScoreItem(
            icon: Icons.check_circle,
            count: correct,
            color: AppTheme.successColor,
          ),
          const SizedBox(width: 32),
          _buildScoreItem(
            icon: Icons.skip_next,
            count: passed,
            color: AppTheme.warningColor,
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
        final opacity = progress < 0.5
            ? Curves.easeOut.transform(progress * 2)
            : Curves.easeIn.transform(1.0 - (progress - 0.5) * 2);

        return Positioned.fill(
          child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: _feedbackColor == AppTheme.successColor
                      ? Alignment.topCenter
                      : Alignment.centerRight,
                  end: _feedbackColor == AppTheme.successColor
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
