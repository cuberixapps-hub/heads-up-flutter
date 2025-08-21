import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import '../constants/app_theme.dart';
import '../models/deck.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../widgets/tutorial_hint_overlay.dart';
import 'results_screen.dart';
import 'team_results_screen.dart';

class GameplayScreen extends StatefulWidget {
  final Deck deck;
  final bool isTeamMode;
  final List<String>? teamNames;
  final List<Color>? teamColors;
  final bool isTournamentMode;
  final String? tournamentType;

  const GameplayScreen({
    super.key,
    required this.deck,
    this.isTeamMode = false,
    this.teamNames,
    this.teamColors,
    this.isTournamentMode = false,
    this.tournamentType,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();

  // Animation controllers
  late AnimationController _countdownController;
  late AnimationController _cardFlipController;
  late AnimationController _feedbackController;
  late AnimationController _timerPulseController;

  // Accelerometer
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _currentTilt = 0.0;
  bool _canDetectTilt = false;
  bool _hasTriggeredAction = false;

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkTutorialHints();
    _startCountdown();
  }

  Future<void> _checkTutorialHints() async {
    final prefs = await SharedPreferences.getInstance();
    _gamesPlayed = prefs.getInt('games_played') ?? 0;

    // Show hints for first 3 games or if tutorial wasn't completed
    final tutorialCompleted = prefs.getBool('tutorial_completed') ?? false;
    if (_gamesPlayed < 3 || !tutorialCompleted) {
      setState(() {
        _showTutorialHints = true;
      });
    }

    // Increment games played
    await prefs.setInt('games_played', _gamesPlayed + 1);
  }

  void _initializeAnimations() {
    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _cardFlipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _timerPulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _startCountdown() {
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

  void _startGame() {
    _canDetectTilt = true;
    _startAccelerometer();
    _audioService.playClick();
    _hapticService.mediumImpact();
  }

  void _startAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!_canDetectTilt || _hasTriggeredAction) return;

      // Calculate tilt angle (in degrees)
      // event.y represents forward/backward tilt
      // Positive y = tilt down (correct), Negative y = tilt up (pass)
      final tiltAngle = math.atan2(event.y, event.z) * (180 / math.pi);

      setState(() {
        _currentTilt = tiltAngle;
      });

      // Threshold for triggering actions
      const threshold = 30.0;

      if (tiltAngle > threshold) {
        // Tilted down - Correct
        _handleCorrect();
      } else if (tiltAngle < -threshold) {
        // Tilted up - Pass
        _handlePass();
      }
    });
  }

  void _handleCorrect() {
    if (_hasTriggeredAction) return;

    _hasTriggeredAction = true;
    _canDetectTilt = false;

    // Update game state
    context.read<GameProvider>().markCorrect();

    // Show feedback
    _showFeedback('CORRECT!', AppTheme.successColor, Icons.check_circle);

    // Play effects
    _audioService.playCorrect();
    _hapticService.success();

    // Animate card flip
    _cardFlipController.forward().then((_) {
      _cardFlipController.reverse();
      _prepareNextCard();
    });
  }

  void _handlePass() {
    if (_hasTriggeredAction) return;

    _hasTriggeredAction = true;
    _canDetectTilt = false;

    // Update game state
    context.read<GameProvider>().markPass();

    // Show feedback
    _showFeedback('PASS', AppTheme.warningColor, Icons.skip_next);

    // Play effects
    _audioService.playPass();
    _hapticService.warning();

    // Animate card flip
    _cardFlipController.forward().then((_) {
      _cardFlipController.reverse();
      _prepareNextCard();
    });
  }

  void _showFeedback(String text, Color color, IconData icon) {
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
      _feedbackIcon = icon;
    });

    _feedbackController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _feedbackController.reverse();
      });
    });
  }

  void _prepareNextCard() {
    Future.delayed(const Duration(milliseconds: 600), () {
      final gameProvider = context.read<GameProvider>();

      // Check if game is over
      if (!gameProvider.isGameActive ||
          gameProvider.currentSession?.isComplete == true) {
        _navigateToResults();
      } else {
        // Reset for next card
        setState(() {
          _hasTriggeredAction = false;
          _canDetectTilt = true;
        });
      }
    });
  }

  void _navigateToResults() {
    _accelerometerSubscription?.cancel();

    if (widget.isTeamMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => TeamResultsScreen(teamColors: widget.teamColors),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ResultsScreen()),
      );
    }
  }

  void _handleManualCorrect() {
    if (!_hasTriggeredAction && !_isCountingDown) {
      _handleCorrect();
    }
  }

  void _handleManualPass() {
    if (!_hasTriggeredAction && !_isCountingDown) {
      _handlePass();
    }
  }

  void _pauseGame() {
    context.read<GameProvider>().togglePause();
    _canDetectTilt = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Game Paused'),
            content: const Text('Take a break! Tap resume when ready.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Exit game
                },
                child: const Text('Quit Game'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<GameProvider>().togglePause();
                  _canDetectTilt = true;
                },
                child: const Text('Resume'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _countdownController.dispose();
    _cardFlipController.dispose();
    _feedbackController.dispose();
    _timerPulseController.dispose();
    _countdownTimer?.cancel();
    _accelerometerSubscription?.cancel();
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
        body: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            final session = gameProvider.currentSession;
            final currentCard = session?.currentCard ?? '';
            final remainingTime = gameProvider.remainingTime;

            // Check if time is running out
            final isTimeRunningOut = remainingTime.inSeconds <= 10;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.deck.color.withOpacity(0.8),
                    widget.deck.color,
                  ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Main content
                    if (_isCountingDown)
                      _buildCountdown()
                    else
                      _buildGameplay(
                        currentCard,
                        remainingTime,
                        isTimeRunningOut,
                      ),

                    // Feedback overlay
                    _buildFeedbackOverlay(),

                    // Tilt indicator
                    if (!_isCountingDown) _buildTiltIndicator(),

                    // Tutorial hints overlay
                    TutorialHintOverlay(
                      showHints: _showTutorialHints && !_isCountingDown,
                      onDismiss: () {
                        setState(() {
                          _showTutorialHints = false;
                        });
                      },
                    ),

                    // Pause button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        onPressed: _pauseGame,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pause, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final gameProvider = context.read<GameProvider>();
    final currentTeam = gameProvider.currentSession?.currentTeam;
    final currentTeamIndex = gameProvider.currentSession?.currentTeamIndex ?? 0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Show team name in team mode
          if (widget.isTeamMode && currentTeam != null) ...[
            Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.teamColors?[currentTeamIndex %
                                (widget.teamColors?.length ?? 1)] ??
                            AppTheme.primaryColor,
                        (widget.teamColors?[currentTeamIndex %
                                    (widget.teamColors?.length ?? 1)] ??
                                AppTheme.primaryColor)
                            .withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.teamColors?[currentTeamIndex %
                                    (widget.teamColors?.length ?? 1)] ??
                                AppTheme.primaryColor)
                            .withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        currentTeam.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Get Ready!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 40),
          ],

          const Icon(
                Icons.phone_android_rounded,
                size: 100,
                color: Colors.white,
              )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 1.seconds, begin: -0.05, end: 0.05)
              .then()
              .rotate(duration: 1.seconds, begin: 0.05, end: -0.05),
          const SizedBox(height: 40),
          Text(
            'Place on forehead!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _countdownController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_countdownController.value * 0.3),
                child: Text(
                  _countdownValue.toString(),
                  style: TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(
                      1.0 - (_countdownController.value * 0.3),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameplay(
    String currentCard,
    Duration remainingTime,
    bool isTimeRunningOut,
  ) {
    final gameProvider = context.read<GameProvider>();
    final currentTeam = gameProvider.currentSession?.currentTeam;
    final currentTeamIndex = gameProvider.currentSession?.currentTeamIndex ?? 0;

    return Column(
      children: [
        // Team indicator (only in team mode)
        if (widget.isTeamMode && currentTeam != null) ...[
          Container(
            margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.teamColors?[currentTeamIndex %
                          (widget.teamColors?.length ?? 1)] ??
                      AppTheme.primaryColor,
                  (widget.teamColors?[currentTeamIndex %
                              (widget.teamColors?.length ?? 1)] ??
                          AppTheme.primaryColor)
                      .withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (widget.teamColors?[currentTeamIndex %
                              (widget.teamColors?.length ?? 1)] ??
                          AppTheme.primaryColor)
                      .withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  '${currentTeam.name}\'s Turn',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: ${currentTeam.score}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        ],

        // Timer
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color:
                isTimeRunningOut
                    ? Colors.red.withOpacity(0.3)
                    : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: AnimatedBuilder(
            animation:
                isTimeRunningOut ? _timerPulseController : _countdownController,
            builder: (context, child) {
              return Transform.scale(
                scale:
                    isTimeRunningOut
                        ? 1.0 + (_timerPulseController.value * 0.1)
                        : 1.0,
                child: Text(
                  '${remainingTime.inSeconds}s',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isTimeRunningOut ? Colors.white : Colors.white,
                  ),
                ),
              );
            },
          ),
        ),

        // Card
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _cardFlipController,
              builder: (context, child) {
                final angle = _cardFlipController.value * math.pi;
                if (angle >= math.pi / 2) {
                  return Transform(
                    alignment: Alignment.center,
                    transform:
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(math.pi),
                    child: _buildCardBack(),
                  );
                } else {
                  return Transform(
                    alignment: Alignment.center,
                    transform:
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                    child: _buildCardFront(currentCard),
                  );
                }
              },
            ),
          ),
        ),

        // Manual buttons
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pass button
              GestureDetector(
                onTap: _handleManualPass,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 28,
                      ),
                      Text(
                        'PASS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Correct button
              GestureDetector(
                onTap: _handleManualCorrect,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.arrow_downward,
                        color: Colors.white,
                        size: 28,
                      ),
                      Text(
                        'CORRECT',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardFront(String word) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          word,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: widget.deck.color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.deck.color.withOpacity(0.8), widget.deck.color],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.phone_android_rounded, size: 80, color: Colors.white),
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

        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Transform.scale(
                scale: _feedbackController.value,
                child: Opacity(
                  opacity: _feedbackController.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: _feedbackColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_feedbackIcon != null)
                          Icon(_feedbackIcon, size: 60, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          _feedbackText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTiltIndicator() {
    return Positioned(
      bottom: 100,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.screen_rotation,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Tilt: ${_currentTilt.toStringAsFixed(0)}°',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
