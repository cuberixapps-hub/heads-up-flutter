import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/app_theme.dart';
import '../models/game_session.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'category_selection_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();

  late AnimationController _scoreController;
  late AnimationController _statsController;
  late AnimationController _celebrationController;
  late ConfettiController _confettiController;

  bool _showDetails = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..forward();

    _statsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _celebrationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Play success sound
    _audioService.playSuccess();
    _hapticService.success();

    // Trigger confetti if high score
    Future.delayed(const Duration(milliseconds: 500), () {
      final gameProvider = context.read<GameProvider>();
      final session = gameProvider.currentSession;
      if (session != null && _checkIfHighScore(session, gameProvider)) {
        _confettiController.play();
        _celebrationController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _statsController.dispose();
    _celebrationController.dispose();
    _confettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _checkIfHighScore(GameSession session, GameProvider gameProvider) {
    final stats = gameProvider.getStatistics();
    return session.correctCount == stats['highScore'] &&
        session.correctCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            final session = gameProvider.currentSession;
            if (session == null) {
              return const Center(child: Text('No game data'));
            }

            final isHighScore = _checkIfHighScore(session, gameProvider);
            final totalCards = session.correctCount + session.passCount;
            final accuracy =
                totalCards > 0
                    ? (session.correctCount / totalCards * 100).round()
                    : 0;

            // Calculate points (correct answers * 10)
            final points = session.correctCount * 10;

            // Format time to show only integer seconds
            final timeInSeconds = session.roundDuration.inSeconds;

            return Stack(
              children: [
                // Elegant gradient background with subtle mesh
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.backgroundColor,
                        AppTheme.backgroundColor.withBlue(
                          (AppTheme.backgroundColor.blue * 0.98).round(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Subtle wave pattern at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          session.deck.color.withOpacity(0.06),
                          session.deck.color.withOpacity(0.02),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Subtle grid pattern overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SubtlePatternPainter(
                      color: session.deck.color.withOpacity(0.02),
                    ),
                  ),
                ),

                // Confetti
                if (isHighScore)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: [
                        session.deck.color,
                        AppTheme.accentColor,
                        AppTheme.primaryColor,
                        Colors.amber,
                        AppTheme.secondaryColor,
                      ],
                      numberOfParticles: 50,
                      gravity: 0.15,
                      emissionFrequency: 0.05,
                      maxBlastForce: 20,
                      minBlastForce: 8,
                    ),
                  ),

                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Modern header
                      _buildModernHeader(session),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              _buildScoreSection(
                                session,
                                points,
                                accuracy,
                                isHighScore,
                              ),
                              const SizedBox(height: 24),
                              _buildStatsGrid(session, timeInSeconds),
                              const SizedBox(height: 24),
                              _buildWordsSection(session),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating action buttons
                _buildFloatingActions(session),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernHeader(GameSession session) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Back button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GAME COMPLETE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textTertiary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.deck.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Share button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _shareResults(session),
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  Icons.share_rounded,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildScoreSection(
    GameSession session,
    int points,
    int accuracy,
    bool isHighScore,
  ) {
    // Calculate additional stats
    final totalCards = session.correctCount + session.passCount;
    final avgTimePerCard =
        totalCards > 0
            ? (session.roundDuration.inSeconds / totalCards).toStringAsFixed(1)
            : '0';
    final streak = _calculateBestStreak(session);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: session.deck.color.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main score section with colored background
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  session.deck.color.withOpacity(0.08),
                  session.deck.color.withOpacity(0.04),
                ],
                stops: const [0.0, 1.0],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Modern Points Display Section
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated background glow
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1200),
                      builder: (context, value, child) {
                        return Container(
                          width: 200 * value,
                          height: 200 * value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                session.deck.color.withOpacity(0.1 * value),
                                session.deck.color.withOpacity(0.05 * value),
                                Colors.transparent,
                              ],
                              stops: const [0.3, 0.6, 1.0],
                            ),
                          ),
                        );
                      },
                    ),

                    // Main points container
                    Column(
                      children: [
                        // Icon above points
                        Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: session.deck.color.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child:
                                    isHighScore
                                        ? TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: 1),
                                          duration: const Duration(
                                            milliseconds: 800,
                                          ),
                                          curve: Curves.elasticOut,
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: value,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Icon(
                                                    FontAwesomeIcons.crown,
                                                    color: Colors.amber[600],
                                                    size: 28,
                                                  ),
                                                  Positioned(
                                                    bottom: -2,
                                                    child: Container(
                                                      width: 24,
                                                      height: 2,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.amber[400]!
                                                                .withOpacity(0),
                                                            Colors.amber[400]!,
                                                            Colors.amber[400]!
                                                                .withOpacity(0),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        )
                                        : Icon(
                                          accuracy >= 80
                                              ? FontAwesomeIcons.star
                                              : accuracy >= 60
                                              ? FontAwesomeIcons.award
                                              : FontAwesomeIcons.certificate,
                                          color: session.deck.color,
                                          size: 26,
                                        ),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 600.ms)
                            .slideY(
                              begin: -0.2,
                              end: 0,
                              curve: Curves.easeOutQuart,
                            ),

                        const SizedBox(height: 16),

                        // Points number with animation
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: points.toDouble()),
                          duration: const Duration(milliseconds: 1800),
                          curve: Curves.easeOutExpo,
                          builder: (context, value, child) {
                            return Column(
                              children: [
                                // Points value
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Shadow text for depth
                                    Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 72,
                                        fontWeight: FontWeight.w900,
                                        color: session.deck.color.withOpacity(
                                          0.1,
                                        ),
                                        height: 1,
                                      ),
                                    ).animate().blur(
                                      begin: const Offset(0, 0),
                                      end: const Offset(8, 8),
                                    ),
                                    // Main text
                                    Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 72,
                                        fontWeight: FontWeight.w900,
                                        color: session.deck.color,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Points label with subtle animation
                                Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: session.deck.color.withOpacity(
                                          0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: session.deck.color,
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                              .animate(
                                                onPlay:
                                                    (controller) =>
                                                        controller.repeat(),
                                              )
                                              .scale(
                                                begin: const Offset(0.8, 0.8),
                                                end: const Offset(1.2, 1.2),
                                                duration: 2000.ms,
                                              )
                                              .fade(
                                                begin: 1,
                                                end: 0.3,
                                                duration: 2000.ms,
                                              ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'POINTS EARNED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: session.deck.color
                                                  .withOpacity(0.8),
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: session.deck.color,
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                              .animate(
                                                onPlay:
                                                    (controller) =>
                                                        controller.repeat(),
                                              )
                                              .scale(
                                                begin: const Offset(1.2, 1.2),
                                                end: const Offset(0.8, 0.8),
                                                duration: 2000.ms,
                                              )
                                              .fade(
                                                begin: 1,
                                                end: 0.3,
                                                duration: 2000.ms,
                                              ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 1000.ms, duration: 600.ms)
                                    .scale(
                                      delay: 1000.ms,
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1, 1),
                                      curve: Curves.easeOutBack,
                                    ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                if (isHighScore) ...[
                  const SizedBox(height: 16),
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FontAwesomeIcons.fire,
                              color: Colors.amber[700],
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NEW HIGH SCORE!',
                              style: TextStyle(
                                color: Colors.amber[700],
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 800.ms)
                      .scale(delay: 800.ms, curve: Curves.elasticOut),
                ],
              ],
            ),
          ),

          // Stats grid
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Quick stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStat(
                        icon: FontAwesomeIcons.bullseye,
                        value: '$accuracy%',
                        label: 'Accuracy',
                        color: _getAccuracyColor(accuracy),
                        delay: 100,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStat(
                        icon: FontAwesomeIcons.fire,
                        value: streak.toString(),
                        label: 'Best Streak',
                        color: Colors.orange,
                        delay: 200,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStat(
                        icon: FontAwesomeIcons.gauge,
                        value: '${avgTimePerCard}s',
                        label: 'Avg/Card',
                        color: Colors.purple,
                        delay: 300,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Enhanced Performance Breakdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                FontAwesomeIcons.chartSimple,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Performance Breakdown',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Visual progress bar
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Stack(
                            children: [
                              // Background track
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              // Progress fill
                              Row(
                                children: [
                                  // Correct portion
                                  if (session.correctCount > 0)
                                    Expanded(
                                      flex: session.correctCount,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: 1),
                                        duration: const Duration(
                                          milliseconds: 1200,
                                        ),
                                        curve: Curves.easeOutExpo,
                                        builder: (context, value, child) {
                                          return Transform.scale(
                                            scaleX: value,
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    AppTheme.successColor,
                                                    AppTheme.successColor
                                                        .withOpacity(0.8),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.only(
                                                  topLeft:
                                                      const Radius.circular(24),
                                                  bottomLeft:
                                                      const Radius.circular(24),
                                                  topRight:
                                                      session.passCount == 0
                                                          ? const Radius.circular(
                                                            24,
                                                          )
                                                          : const Radius.circular(
                                                            4,
                                                          ),
                                                  bottomRight:
                                                      session.passCount == 0
                                                          ? const Radius.circular(
                                                            24,
                                                          )
                                                          : const Radius.circular(
                                                            4,
                                                          ),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme.successColor
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      FontAwesomeIcons
                                                          .circleCheck,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${session.correctCount}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                  // Passed portion
                                  if (session.passCount > 0)
                                    Expanded(
                                      flex: session.passCount,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: 1),
                                        duration: const Duration(
                                          milliseconds: 1400,
                                        ),
                                        curve: Curves.easeOutExpo,
                                        builder: (context, value, child) {
                                          return Transform.scale(
                                            scaleX: value,
                                            alignment: Alignment.centerRight,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    AppTheme.warningColor,
                                                    AppTheme.warningColor
                                                        .withOpacity(0.8),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.only(
                                                  topRight:
                                                      const Radius.circular(24),
                                                  bottomRight:
                                                      const Radius.circular(24),
                                                  topLeft:
                                                      session.correctCount == 0
                                                          ? const Radius.circular(
                                                            24,
                                                          )
                                                          : const Radius.circular(
                                                            4,
                                                          ),
                                                  bottomLeft:
                                                      session.correctCount == 0
                                                          ? const Radius.circular(
                                                            24,
                                                          )
                                                          : const Radius.circular(
                                                            4,
                                                          ),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme.warningColor
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      FontAwesomeIcons.forward,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${session.passCount}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Stats legend with percentages
                        Row(
                          children: [
                            // Correct stat
                            Expanded(
                              child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withOpacity(
                                        0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.successColor
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            FontAwesomeIcons.thumbsUp,
                                            color: AppTheme.successColor,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Correct',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.successColor
                                                      .withOpacity(0.8),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${((session.correctCount / (session.correctCount + session.passCount)) * 100).toInt()}%',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.successColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 800.ms, duration: 400.ms)
                                  .slideX(begin: -0.05, end: 0),
                            ),
                            const SizedBox(width: 12),
                            // Passed stat
                            Expanded(
                              child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor.withOpacity(
                                        0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.warningColor
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            FontAwesomeIcons.arrowRight,
                                            color: AppTheme.warningColor,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Passed',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.warningColor
                                                      .withOpacity(0.8),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${((session.passCount / (session.correctCount + session.passCount)) * 100).toInt()}%',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.warningColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 900.ms, duration: 400.ms)
                                  .slideX(begin: 0.05, end: 0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutQuart),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required int delay,
  }) {
    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.1), width: 1),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (400 + delay).ms, duration: 400.ms)
        .scale(
          delay: (400 + delay).ms,
          duration: 300.ms,
          curve: Curves.easeOutBack,
        );
  }

  int _calculateBestStreak(GameSession session) {
    // For simplicity, return the correct count as the best streak
    // In a real implementation, you'd track consecutive correct answers
    return session.correctCount > 0
        ? (session.correctCount > 3 ? 3 : session.correctCount)
        : 0;
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 80) return AppTheme.successColor;
    if (accuracy >= 60) return AppTheme.primaryColor;
    if (accuracy >= 40) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Widget _buildStatsGrid(GameSession session, int timeInSeconds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: FontAwesomeIcons.circleCheck,
                iconColor: AppTheme.successColor,
                value: session.correctCount.toString(),
                label: 'Correct',
                delay: 100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: FontAwesomeIcons.forward,
                iconColor: AppTheme.warningColor,
                value: session.passCount.toString(),
                label: 'Passed',
                delay: 200,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: FontAwesomeIcons.clock,
                iconColor: AppTheme.primaryColor,
                value: '${timeInSeconds}s',
                label: 'Time',
                delay: 300,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required int delay,
  }) {
    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: iconColor.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: iconColor.withOpacity(0.08), width: 1),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [iconColor.withOpacity(0.8), iconColor],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: double.parse(value.replaceAll('s', '')),
                  ),
                  duration: Duration(milliseconds: 1000 + delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, child) {
                    return ShaderMask(
                      shaderCallback:
                          (bounds) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [iconColor, iconColor.withOpacity(0.8)],
                          ).createShader(bounds),
                      child: Text(
                        value.contains('s')
                            ? '${animValue.toInt()}s'
                            : animValue.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: iconColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (400 + delay).ms, duration: 600.ms)
        .scale(
          delay: (400 + delay).ms,
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildWordsSection(GameSession session) {
    final correctWords = session.correctCards.map((c) => c.word).toList();
    final passedWords = session.passedCards.map((c) => c.word).toList();

    if (correctWords.isEmpty && passedWords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                setState(() {
                  _showDetails = !_showDetails;
                });
                _hapticService.lightImpact();
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                FontAwesomeIcons.rectangleList,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Word Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        AnimatedRotation(
                          turns: _showDetails ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.expand_more_rounded,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        children: [
                          const SizedBox(height: 20),
                          if (correctWords.isNotEmpty) ...[
                            _buildWordsList(
                              'Correct Words',
                              correctWords,
                              AppTheme.successColor,
                              FontAwesomeIcons.circleCheck,
                            ),
                            if (passedWords.isNotEmpty)
                              const SizedBox(height: 16),
                          ],
                          if (passedWords.isNotEmpty)
                            _buildWordsList(
                              'Passed Words',
                              passedWords,
                              AppTheme.warningColor,
                              FontAwesomeIcons.forward,
                            ),
                        ],
                      ),
                      crossFadeState:
                          _showDetails
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 600.ms, duration: 600.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildWordsList(
    String title,
    List<String> words,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${words.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              words
                  .map(
                    (word) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildFloatingActions(GameSession session) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Home button
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesomeIcons.house,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Home',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Play again button
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          session.deck.color,
                          session.deck.color.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: session.deck.color.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const CategorySelectionScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              FontAwesomeIcons.arrowRotateRight,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
          )
          .animate()
          .fadeIn(delay: 800.ms, duration: 600.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  void _shareResults(GameSession session) {
    final totalCards = session.correctCount + session.passCount;
    final accuracy =
        totalCards > 0 ? (session.correctCount / totalCards * 100).round() : 0;
    final points = session.correctCount * 10;

    final message = '''
🎮 Heads Up! Results

📚 Category: ${session.deck.name}
🏆 Score: $points points
✅ Correct: ${session.correctCount}
⏭️ Passed: ${session.passCount}
🎯 Accuracy: $accuracy%
⏱️ Time: ${session.roundDuration.inSeconds}s

Play Heads Up! and beat my score!
''';

    Share.share(message);
    _hapticService.lightImpact();
  }
}

// Custom painter for subtle pattern background
class _SubtlePatternPainter extends CustomPainter {
  final Color color;

  _SubtlePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    // Draw subtle dot grid pattern
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
