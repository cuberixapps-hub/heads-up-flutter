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
  late AnimationController _cardFlipController;
  late AnimationController _feedbackController;
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
  String _feedbackText = '';
  Color _feedbackColor = Colors.transparent;
  IconData? _feedbackIcon;

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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardFlipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    // Play sound for initial "3"
    _audioService.playCountdown();
    _hapticService.lightImpact();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
        });
        _countdownController.forward(from: 0);
        _audioService.playCountdown();
        _hapticService.lightImpact();
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
        });
        _startGame();
      }
    });
  }

  void _startGame() async {
    debugPrint('=== GAME START ===');
    debugPrint('Deck name: ${widget.deck.name}');
    debugPrint('Deck cards: ${widget.deck.cards}');
    debugPrint('Deck cards count: ${widget.deck.cards.length}');
    
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

        if (recordingStarted) {
          // Log the first word shown
          final gameProvider = context.read<GameProvider>();
          final currentWord = gameProvider.currentSession?.currentCard ?? '';
          if (currentWord.isNotEmpty) {
            _cameraRecording.logGameEvent(
              type: 'word_shown',
              word: currentWord,
              score: 0,
              remainingTime: gameProvider.remainingTime,
            );
            debugPrint('Logged first word: $currentWord');
          }
        }
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

    // Show feedback
    _showFeedback('CORRECT!', AppTheme.successColor, Icons.check_circle);

    // Play effects
    _audioService.playCorrect();
    _hapticService.lightImpact(); // Light haptic for correct [[memory:7008710]]

    // Animate card flip
    _cardFlipController.forward().then((_) {
      _cardFlipController.reverse();
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

    // Show feedback
    _showFeedback('PASS', AppTheme.warningColor, Icons.skip_next);

    // Play effects
    _audioService.playPass();
    _hapticService.selection(); // Very light haptic for pass [[memory:7008710]]

    // Animate card flip
    _cardFlipController.forward().then((_) {
      _cardFlipController.reverse();
      _prepareNextCard();
    });

    // Unlock after cooldown
    Future.delayed(_minTimeBetweenActions, () {
      _actionLocked = false;
    });
  }

  void _showFeedback(String text, Color color, IconData icon) {
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
      _feedbackIcon = icon;
    });

    _feedbackController.forward().then((_) {
      // Immediately reverse without delay for snappier feel
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
        debugPrint('=== WORD SHOWN EVENT ===');
        debugPrint('Current card index: ${gameProvider.currentSession?.currentCardIndex}');
        debugPrint('Current word from session: $currentWord');
        debugPrint('All cards: ${gameProvider.currentSession?.cards}');
        
        if (_isRecordingVideo && currentWord.isNotEmpty) {
          _cameraRecording.logGameEvent(
            type: 'word_shown',
            word: currentWord,
            score: gameProvider.currentSession?.correctCount ?? 0,
            remainingTime: gameProvider.remainingTime,
          );
          debugPrint('Logged word_shown event: $currentWord');
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
                borderRadius: BorderRadius.circular(28),
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
    _cardFlipController.dispose();
    _feedbackController.dispose();
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
    return Center(
      child: AnimatedBuilder(
        animation: _countdownController,
        builder: (context, child) {
          final scale = 1.0 + (_countdownController.value * 0.5);
          final opacity = 1.0 - (_countdownController.value * 0.3);

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _countdownValue.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GET READY',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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

        // Card area
        Expanded(
          child: Stack(
            children: [
              // Main card with animation
              Center(
                child: AnimatedBuilder(
                  animation: _cardFlipController,
                  builder: (context, child) {
                    final angle = _cardFlipController.value * math.pi;

                    // Choose rotation axis based on orientation
                    Matrix4 getTransform(double rotationAngle) {
                      final matrix = Matrix4.identity()..setEntry(3, 2, 0.001);
                      if (_isLandscapeMode) {
                        // In landscape, rotate around X-axis (up/down)
                        matrix.rotateX(rotationAngle);
                      } else {
                        // In portrait, rotate around Y-axis (left/right)
                        matrix.rotateY(rotationAngle);
                      }
                      return matrix;
                    }

                    if (angle >= math.pi / 2) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: getTransform(math.pi),
                        child: _buildCardBack(),
                      );
                    } else {
                      return Transform(
                        alignment: Alignment.center,
                        transform: getTransform(angle),
                        child: _buildCardFront(currentCard),
                      );
                    }
                  },
                ),
              ),

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
          AnimatedBuilder(
            animation: _timerPulseController,
            builder: (context, child) {
              final scale = 1.0 + (_timerPulseController.value * 0.05);
              final remainingTime =
                  gameProvider.currentSession?.remainingTime.inSeconds ?? 60;
              final isLowTime = remainingTime <= 10;

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
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${remainingTime}s',
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

          // Team indicator (if team mode)
          if (widget.isTeamMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.teamNames![widget.currentTeamIndex!],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
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

  Widget _buildCardBack() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: widget.deck.color.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.deck.color, widget.deck.color.withOpacity(0.8)],
            ),
          ),
          child: Stack(
            children: [
              // Pattern overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardPatternPainter(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.deck.icon,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Next Card',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
      top: 16,
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
            borderRadius: BorderRadius.circular(12),
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
    return AnimatedBuilder(
      animation: _feedbackController,
      builder: (context, child) {
        if (_feedbackController.value == 0) {
          return const SizedBox.shrink();
        }

        // Simple fade animation only
        final opacity = _feedbackController.value;

        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: _feedbackColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _feedbackColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_feedbackIcon != null)
                        Icon(_feedbackIcon, size: 28, color: Colors.white),
                      if (_feedbackIcon != null) const SizedBox(width: 12),
                      Text(
                        _feedbackText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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

// Custom painter for card pattern
class _CardPatternPainter extends CustomPainter {
  final Color color;

  _CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    // Draw geometric pattern
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);

        if (x + spacing < size.width) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x + spacing, y),
            paint..color = color.withOpacity(0.5),
          );
        }

        if (y + spacing < size.height) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, y + spacing),
            paint..color = color.withOpacity(0.5),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
