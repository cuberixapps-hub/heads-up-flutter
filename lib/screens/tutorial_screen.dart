import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import '../constants/app_theme.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'category_selection_screen.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();

  // Tutorial state
  int _currentStep = 0;
  bool _isInteractive = false;

  // Animation controllers
  late AnimationController _phoneAnimationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _checkmarkController;

  // Accelerometer for practice mode
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _currentTilt = 0.0;
  bool _isDetectingTilt = false;
  int _correctTilts = 0;
  int _skipTilts = 0;

  // Practice mode state
  String _currentPracticeWord = "Pizza";
  bool _showFeedback = false;
  String _feedbackMessage = "";
  Color _feedbackColor = AppTheme.successColor;

  final List<TutorialStep> _tutorialSteps = [
    TutorialStep(
      title: "Welcome to Heads Up!",
      description:
          "The hilarious party game where you guess the word on your head while your friends give you clues!",
      icon: FontAwesomeIcons.gamepad,
      animation: TutorialAnimation.welcome,
      isInteractive: false,
    ),
    TutorialStep(
      title: "How to Play",
      description:
          "Hold your phone to your forehead. Your friends will see the word and give you clues. You have 60 seconds to guess as many words as possible!",
      icon: FontAwesomeIcons.mobileAlt,
      animation: TutorialAnimation.phonePosition,
      isInteractive: false,
    ),
    TutorialStep(
      title: "Correct Answer",
      description:
          "When you guess correctly, tilt your phone DOWN. The card will turn green and you'll hear a success sound!",
      icon: FontAwesomeIcons.checkCircle,
      animation: TutorialAnimation.tiltDown,
      isInteractive: false,
    ),
    TutorialStep(
      title: "Skip Word",
      description:
          "Too hard? Tilt your phone UP to skip. The card will turn orange and move to the next word!",
      icon: FontAwesomeIcons.forward,
      animation: TutorialAnimation.tiltUp,
      isInteractive: false,
    ),
    TutorialStep(
      title: "Practice Time!",
      description:
          "Let's practice the tilt gestures. Try tilting DOWN for correct and UP to skip. Complete 3 of each!",
      icon: FontAwesomeIcons.dumbbell,
      animation: TutorialAnimation.practice,
      isInteractive: true,
    ),
    TutorialStep(
      title: "Choose Categories",
      description:
          "Pick from dozens of fun categories like Movies, Animals, Celebrities, and more! Each category has unique words to guess.",
      icon: FontAwesomeIcons.layerGroup,
      animation: TutorialAnimation.categories,
      isInteractive: false,
    ),
    TutorialStep(
      title: "Track Your Score",
      description:
          "After each round, see how many words you guessed correctly. Challenge yourself to beat your high score!",
      icon: FontAwesomeIcons.trophy,
      animation: TutorialAnimation.score,
      isInteractive: false,
    ),
    TutorialStep(
      title: "You're Ready!",
      description:
          "That's all you need to know! Gather your friends and start playing. The more people, the more fun!",
      icon: FontAwesomeIcons.rocket,
      animation: TutorialAnimation.complete,
      isInteractive: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkTutorialCompletion();
  }

  void _initializeAnimations() {
    _phoneAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  Future<void> _checkTutorialCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.getBool('tutorial_completed') ?? false;
    // Can be used for future features
  }

  Future<void> _markTutorialComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
  }

  @override
  void dispose() {
    _phoneAnimationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _checkmarkController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _startPracticeMode() {
    setState(() {
      _isDetectingTilt = true;
      _correctTilts = 0;
      _skipTilts = 0;
    });

    _accelerometerSubscription = accelerometerEvents.listen((event) {
      if (!_isDetectingTilt) return;

      setState(() {
        _currentTilt = event.x;
      });

      // Detect tilt down (correct) - phone tilted forward
      if (event.x > 4.0 && !_showFeedback) {
        _handleCorrectGesture();
      }
      // Detect tilt up (skip) - phone tilted backward
      else if (event.x < -4.0 && !_showFeedback) {
        _handleSkipGesture();
      }
    });
  }

  void _handleCorrectGesture() {
    setState(() {
      _correctTilts++;
      _showFeedback = true;
      _feedbackMessage = "Great! You got it right!";
      _feedbackColor = AppTheme.successColor;
    });
    _hapticService.mediumImpact();
    _audioService.playSuccess();

    Timer(const Duration(seconds: 1), () {
      setState(() {
        _showFeedback = false;
        _updatePracticeWord();
        _checkPracticeCompletion();
      });
    });
  }

  void _handleSkipGesture() {
    setState(() {
      _skipTilts++;
      _showFeedback = true;
      _feedbackMessage = "Good! You skipped it!";
      _feedbackColor = AppTheme.warningColor;
    });
    _hapticService.lightImpact();
    _audioService.playClick();

    Timer(const Duration(seconds: 1), () {
      setState(() {
        _showFeedback = false;
        _updatePracticeWord();
        _checkPracticeCompletion();
      });
    });
  }

  void _updatePracticeWord() {
    final words = [
      "Pizza",
      "Dancing",
      "Superman",
      "Elephant",
      "Guitar",
      "Birthday",
    ];
    setState(() {
      _currentPracticeWord = words[(_correctTilts + _skipTilts) % words.length];
    });
  }

  void _checkPracticeCompletion() {
    if (_correctTilts >= 3 && _skipTilts >= 3) {
      _accelerometerSubscription?.cancel();
      setState(() {
        _isDetectingTilt = false;
      });
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    'Excellent!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ve mastered the gestures!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _nextStep();
                    },
                    child: Container(
                      width: 160,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _nextStep();
                          },
                          borderRadius: BorderRadius.circular(26),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  void _nextStep() {
    if (_currentStep < _tutorialSteps.length - 1) {
      setState(() {
        _currentStep++;
        _isInteractive = _tutorialSteps[_currentStep].isInteractive;
      });
      _slideController.forward(from: 0);

      if (_isInteractive && _currentStep == 4) {
        _startPracticeMode();
      }
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _isInteractive = _tutorialSteps[_currentStep].isInteractive;
      });
      _slideController.forward(from: 0);

      if (_accelerometerSubscription != null) {
        _accelerometerSubscription?.cancel();
        setState(() {
          _isDetectingTilt = false;
        });
      }
    }
  }

  void _completeTutorial() {
    _markTutorialComplete();
    _checkmarkController.forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                  ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  Text(
                    'Tutorial Complete!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You\'re all set to play Heads Up! with your friends.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Home',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const CategorySelectionScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Play Now',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _tutorialSteps[_currentStep];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.backgroundColor,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header with progress
                _buildHeader(),

                // Main content
                Expanded(
                  child:
                      _isInteractive && _currentStep == 4
                          ? _buildPracticeMode()
                          : _buildStepContent(currentStep),
                ),

                // Navigation buttons
                _buildNavigationButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                iconSize: 28,
                color: AppTheme.textPrimary,
              ),
              Text(
                'Tutorial',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed:
                    _currentStep == _tutorialSteps.length - 1
                        ? null
                        : () {
                          setState(() {
                            _currentStep = _tutorialSteps.length - 1;
                          });
                        },
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color:
                        _currentStep == _tutorialSteps.length - 1
                            ? Colors.transparent
                            : AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress indicator
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:
                          constraints.maxWidth *
                          ((_currentStep + 1) / _tutorialSteps.length),
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of ${_tutorialSteps.length}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(TutorialStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Animation based on step
          _buildAnimation(step.animation),
          const SizedBox(height: 40),
          // Step icon
          Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(step.icon, color: Colors.white, size: 36),
              )
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 1500.ms, delay: 500.ms),
          const SizedBox(height: 32),
          // Title
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          // Description
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildAnimation(TutorialAnimation animation) {
    switch (animation) {
      case TutorialAnimation.welcome:
        return _buildWelcomeAnimation();
      case TutorialAnimation.phonePosition:
        return _buildPhonePositionAnimation();
      case TutorialAnimation.tiltDown:
        return _buildTiltAnimation(isDown: true);
      case TutorialAnimation.tiltUp:
        return _buildTiltAnimation(isDown: false);
      case TutorialAnimation.categories:
        return _buildCategoriesAnimation();
      case TutorialAnimation.score:
        return _buildScoreAnimation();
      case TutorialAnimation.complete:
        return _buildCompleteAnimation();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeAnimation() {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated circles
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale =
                    1.0 + (_pulseController.value * 0.3 * (index + 1));
                final opacity = 1.0 - (_pulseController.value * 0.3);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(opacity * 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          // Center icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.gamepad,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhonePositionAnimation() {
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _phoneAnimationController,
        builder: (context, child) {
          final angle =
              math.sin(_phoneAnimationController.value * 2 * math.pi) * 0.1;
          return Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(angle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Phone
                Container(
                  width: 120,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.phone_android_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PIZZA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Forehead indicator
                Positioned(
                  top: 0,
                  child: Icon(
                    Icons.face_rounded,
                    size: 48,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTiltAnimation({required bool isDown}) {
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _phoneAnimationController,
        builder: (context, child) {
          final progress = _phoneAnimationController.value;
          final angle =
              isDown
                  ? math.sin(progress * 2 * math.pi) * 0.5
                  : -math.sin(progress * 2 * math.pi) * 0.5;

          return Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(angle),
            child: Container(
              width: 120,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      isDown
                          ? [
                            AppTheme.successColor,
                            AppTheme.successColor.withOpacity(0.8),
                          ]
                          : [
                            AppTheme.warningColor,
                            AppTheme.warningColor.withOpacity(0.8),
                          ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isDown
                            ? AppTheme.successColor
                            : AppTheme.warningColor)
                        .withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDown
                        ? Icons.check_circle_rounded
                        : Icons.skip_next_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDown ? 'CORRECT!' : 'SKIP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    isDown
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 32,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesAnimation() {
    final categories = [
      {'icon': FontAwesomeIcons.film, 'color': AppTheme.primaryColor},
      {'icon': FontAwesomeIcons.paw, 'color': AppTheme.secondaryColor},
      {'icon': FontAwesomeIcons.music, 'color': AppTheme.accentColor},
      {'icon': FontAwesomeIcons.utensils, 'color': AppTheme.warningColor},
    ];

    return SizedBox(
      height: 200,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            decoration: BoxDecoration(
              color: (category['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (category['color'] as Color).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              category['icon'] as IconData,
              color: category['color'] as Color,
              size: 32,
            ),
          ).animate().scale(
            delay: Duration(milliseconds: index * 100),
            duration: 600.ms,
            curve: Curves.elasticOut,
          );
        },
      ),
    );
  }

  Widget _buildScoreAnimation() {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Trophy icon
          Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.warningColor,
                      AppTheme.warningColor.withOpacity(0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.trophy,
                  color: Colors.white,
                  size: 36,
                ),
              )
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .then()
              .shake(duration: 500.ms, hz: 2),
          const SizedBox(height: 20),
          // Score display
          Text(
            '15/20',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ).animate().fadeIn(delay: 400.ms),
          Text(
            'Great job!',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildCompleteAnimation() {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti effect
          ...List.generate(6, (index) {
            final angle = (index * 60) * math.pi / 180;
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final distance = _pulseController.value * 80;
                return Transform.translate(
                  offset: Offset(
                    math.cos(angle) * distance,
                    math.sin(angle) * distance,
                  ),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                        AppTheme.accentColor,
                        AppTheme.warningColor,
                        AppTheme.successColor,
                        AppTheme.errorColor,
                      ][index].withOpacity(1.0 - _pulseController.value),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
          // Rocket icon
          Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.rocket,
                  color: Colors.white,
                  size: 48,
                ),
              )
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .then()
              .shake(duration: 500.ms, rotation: 0.05),
        ],
      ),
    );
  }

  Widget _buildPracticeMode() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Practice Mode',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hold your phone and practice the gestures',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Practice card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(_currentTilt * 0.05),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      _showFeedback
                          ? [_feedbackColor, _feedbackColor.withOpacity(0.8)]
                          : [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_showFeedback
                            ? _feedbackColor
                            : AppTheme.primaryColor)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_showFeedback) ...[
                    Icon(
                      _feedbackColor == AppTheme.successColor
                          ? Icons.check_circle_rounded
                          : Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _feedbackMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _currentPracticeWord,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tilt DOWN = Correct',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tilt UP = Skip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Progress indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressIndicator(
                'Correct',
                _correctTilts,
                3,
                AppTheme.successColor,
                Icons.check_circle_rounded,
              ),
              _buildProgressIndicator(
                'Skip',
                _skipTilts,
                3,
                AppTheme.warningColor,
                Icons.skip_next_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    String label,
    int current,
    int total,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              '$current/$total',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final bool isPracticeMode = _isInteractive && _currentStep == 4;
    final bool canProceed =
        !isPracticeMode || (_correctTilts >= 3 && _skipTilts >= 3);
    final bool isLastStep = _currentStep == _tutorialSteps.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          // Progress indicators
          Container(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _tutorialSteps.length,
                (index) => _buildStepIndicator(index),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Navigation section
          if (!isLastStep)
            // Regular navigation for non-final pages
            Stack(
              alignment: Alignment.center,
              children: [
                // Back button - positioned absolutely
                if (_currentStep > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildMinimalBackButton(onPressed: _previousStep),
                  ),

                // Center-aligned next button
                _buildModernContinueButton(
                  onPressed: canProceed ? _nextStep : null,
                  isDisabled: !canProceed,
                ),
              ],
            )
          else
            // Final page - Finish button
            _buildFinishButton(onPressed: _completeTutorial),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int index) {
    final isActive = _currentStep == index;
    final isPast = index < _currentStep;
    final Color indicatorColor = AppTheme.primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color:
            isActive
                ? indicatorColor
                : isPast
                ? indicatorColor.withOpacity(0.3)
                : indicatorColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildMinimalBackButton({required VoidCallback onPressed}) {
    return GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.primaryColor.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    color: AppTheme.primaryColor.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: -0.1, curve: Curves.easeOut);
  }

  Widget _buildModernContinueButton({
    required VoidCallback? onPressed,
    bool isDisabled = false,
  }) {
    return GestureDetector(
          onTap: isDisabled ? null : onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 160,
            height: 52,
            decoration: BoxDecoration(
              color:
                  isDisabled
                      ? AppTheme.primaryColor.withOpacity(0.3)
                      : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow:
                  isDisabled
                      ? []
                      : [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDisabled ? null : onPressed,
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white.withOpacity(
                            isDisabled ? 0.6 : 1.0,
                          ),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            isDisabled ? 0.1 : 0.2,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withOpacity(
                            isDisabled ? 0.6 : 1.0,
                          ),
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut);
  }

  Widget _buildFinishButton({required VoidCallback onPressed}) {
    return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.successColor.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Complete Tutorial',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    // Arrow indicator on the right
                    Positioned(
                      right: 24,
                      child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(
                            duration: 2000.ms,
                            color: Colors.white.withOpacity(0.3),
                          )
                          .then()
                          .animate()
                          .slideX(
                            begin: 0,
                            end: 0.1,
                            duration: 1000.ms,
                            curve: Curves.easeInOut,
                          )
                          .then()
                          .slideX(
                            begin: 0.1,
                            end: 0,
                            duration: 1000.ms,
                            curve: Curves.easeInOut,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutBack)
        .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOut);
  }
}

// Tutorial step model
class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final TutorialAnimation animation;
  final bool isInteractive;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.animation,
    required this.isInteractive,
  });
}

// Animation types
enum TutorialAnimation {
  welcome,
  phonePosition,
  tiltDown,
  tiltUp,
  practice,
  categories,
  score,
  complete,
}
