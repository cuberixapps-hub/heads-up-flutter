import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../models/game_session.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../services/ad_service.dart';
import '../services/purchases_service.dart';
import '../services/share_service.dart';
import '../services/video_processing_manager.dart';
import '../utils/responsive.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/video_section.dart';
import 'deck_details_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();
  final _adService = AdService();
  final _videoSectionKey = GlobalKey<VideoSectionState>();

  late AnimationController _scoreController;
  late AnimationController _statsController;
  late AnimationController _celebrationController;
  late ConfettiController _confettiController;

  bool _showDetails = false;
  bool _hasDoubledScore = false;
  bool _videoUnlocked = false;
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

    _videoUnlocked = PurchasesService().isPremium;

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

    // Increment game count for ad tracking
    _adService.incrementGameCount();
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

  Future<void> _showInterstitialWithLoader(
    VoidCallback onComplete, {
    required String location,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(28.s),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20.s),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36.s,
                      height: 36.s,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.s),
                    Text(
                      'Loading...',
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    // Wait a moment to show the loader
    await Future.delayed(const Duration(milliseconds: 500));

    // Close the loader
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show interstitial ad with forced method (no frequency restrictions)
    await _adService.showInterstitialAdForced(location: location);

    // Execute the callback after ad is shown/dismissed
    if (mounted) {
      onComplete();
    }
  }

  void _handleVideoUnlock() {
    _hapticService.mediumImpact();

    if (!_adService.isRewardedAdReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20.s),
              SizedBox(width: 8.s),
              Text(
                'Ad is loading, please try again shortly',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.s),
          ),
        ),
      );
      _adService.loadRewardedAd();
      return;
    }

    _adService.showRewardedAd(
      rewardType: 'video_unlock',
      onUserEarnedReward: (amount) {
        if (mounted) {
          setState(() => _videoUnlocked = true);
          _hapticService.success();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock_open_rounded, color: Colors.white, size: 20.s),
                  SizedBox(width: 8.s),
                  Text(
                    'Video unlocked! Tap to play.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1C1C1E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.s),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Cancel video processing before navigating
          _videoSectionKey.currentState?.cancelVideoProcessing();
          VideoProcessingManager.instance.cancelCurrentProcessing(
            reason: 'Back button pressed on results screen',
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: BottomBannerAd(
        widgetKey: 'results_screen',
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              final session = gameProvider.currentSession;
              if (session == null) {
                return const Center(
                  child: Text(
                    'No game data',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
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
              final size = MediaQuery.of(context).size;

              return Stack(
                children: [
                  // Premium dark gradient background
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: size.height * 0.55,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.0,
                          colors: [
                            session.deck.color.withOpacity(0.35),
                            session.deck.color.withOpacity(0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
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
                        _buildModernHeader(session),

                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 24.s),
                            child: Column(
                              children: [
                                SizedBox(height: 28.s),
                                _buildScoreSection(
                                  session,
                                  points,
                                  accuracy,
                                  isHighScore,
                                ),
                                SizedBox(height: 16.s),
                                if (!_hasDoubledScore)
                                  _buildDoubleScoreButton(session),
                                SizedBox(height: 28.s),
                                VideoSection(
                                  key: _videoSectionKey,
                                  isLocked: !_videoUnlocked,
                                  onLockedTap: _handleVideoUnlock,
                                ),
                                SizedBox(height: 28.s),
                                _buildStatsGrid(session, timeInSeconds),
                                SizedBox(height: 28.s),
                                _buildWordsSection(session),
                                SizedBox(height: 88.s),
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
      ),
    );
  }

  Widget _buildModernHeader(GameSession session) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 16.s),
          child: Row(
            children: [
              GestureDetector(
                    onTap: () {
                      _videoSectionKey.currentState?.cancelVideoProcessing();
                      VideoProcessingManager.instance.cancelCurrentProcessing(
                        reason: 'Close button pressed on results screen',
                      );
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Container(
                      width: 40.s,
                      height: 40.s,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20.s,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
              SizedBox(width: 16.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GAME COMPLETE',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2.s),
                    Text(
                      session.deck.name,
                      style: GoogleFonts.poppins(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                    onTap: () => _shareResults(session),
                    child: Container(
                      width: 40.s,
                      height: 40.s,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 20.s,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 80.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.08, end: 0);
  }

  Widget _buildScoreSection(
    GameSession session,
    int points,
    int accuracy,
    bool isHighScore,
  ) {
    final totalCards = session.correctCount + session.passCount;
    final avgTimePerCard =
        totalCards > 0
            ? (session.roundDuration.inSeconds / totalCards).toStringAsFixed(1)
            : '0';
    final streak = _calculateBestStreak(session);
    final deckColor = session.deck.color;

    return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24.s),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(24.s, 32.s, 24.s, 28.s),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      deckColor.withOpacity(0.18),
                      deckColor.withOpacity(0.06),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.s),
                    topRight: Radius.circular(24.s),
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1200),
                          builder: (context, value, child) {
                            return Container(
                              width: 180.s * value,
                              height: 180.s * value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    deckColor.withOpacity(0.12 * value),
                                    deckColor.withOpacity(0.04 * value),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.3, 0.6, 1.0],
                                ),
                              ),
                            );
                          },
                        ),
                        Column(
                          children: [
                            Container(
                                  width: 56.s,
                                  height: 56.s,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(16.s),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 1,
                                    ),
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
                                                  child: Icon(
                                                    FontAwesomeIcons.crown,
                                                    color:
                                                        Colors.amber.shade400,
                                                    size: 26.s,
                                                  ),
                                                );
                                              },
                                            )
                                            : Icon(
                                              accuracy >= 80
                                                  ? FontAwesomeIcons.star
                                                  : accuracy >= 60
                                                  ? FontAwesomeIcons.award
                                                  : FontAwesomeIcons
                                                      .certificate,
                                              color: deckColor,
                                              size: 26.s,
                                            ),
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 500.ms)
                                .slideY(
                                  begin: -0.2,
                                  end: 0,
                                  curve: Curves.easeOutQuart,
                                ),
                            SizedBox(height: 18.s),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: session.correctCount.toDouble()),
                              duration: const Duration(milliseconds: 1800),
                              curve: Curves.easeOutExpo,
                              builder: (context, value, child) {
                                return Column(
                                  children: [
                                    Text(
                                      value.toInt().toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 64.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1,
                                        letterSpacing: -2,
                                      ),
                                    ),
                                    SizedBox(height: 10.s),
                                    Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.s,
                                            vertical: 8.s,
                                          ),
                                          decoration: BoxDecoration(
                                            color: deckColor.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(
                                              20.s,
                                            ),
                                            border: Border.all(
                                              color: deckColor.withOpacity(0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'CORRECT ANSWERS',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white.withOpacity(
                                                0.95,
                                              ),
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        )
                                        .animate()
                                        .fadeIn(
                                          delay: 1000.ms,
                                          duration: 500.ms,
                                        )
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
                      SizedBox(height: 18.s),
                      Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.s,
                              vertical: 8.s,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16.s),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FontAwesomeIcons.fire,
                                  color: Colors.amber.shade300,
                                  size: 14.s,
                                ),
                                SizedBox(width: 8.s),
                                Text(
                                  'NEW HIGH SCORE!',
                                  style: GoogleFonts.poppins(
                                    color: Colors.amber.shade200,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.sp,
                                    letterSpacing: 0.3,
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
              Container(
                padding: EdgeInsets.all(20.s),
                child: Column(
                  children: [
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
                        SizedBox(width: 12.s),
                        Expanded(
                          child: _buildQuickStat(
                            icon: FontAwesomeIcons.fire,
                            value: streak.toString(),
                            label: 'Best Streak',
                            color: Colors.orange,
                            delay: 200,
                          ),
                        ),
                        SizedBox(width: 12.s),
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
                    SizedBox(height: 18.s),
                    _buildPerformanceBreakdown(session),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildPerformanceBreakdown(GameSession session) {
    final total = session.correctCount + session.passCount;
    final correctPct =
        total > 0 ? (session.correctCount / total * 100).toInt() : 0;
    final passPct = total > 0 ? (session.passCount / total * 100).toInt() : 0;

    return Container(
          padding: EdgeInsets.all(18.s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18.s),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36.s,
                    height: 36.s,
                    decoration: BoxDecoration(
                      color: session.deck.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10.s),
                    ),
                    child: Icon(
                      FontAwesomeIcons.chartSimple,
                      size: 16.s,
                      color: session.deck.color,
                    ),
                  ),
                  SizedBox(width: 12.s),
                  Text(
                    'Performance',
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.s),
              Container(
                height: 44.s,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(22.s),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22.s),
                  child: Row(
                    children: [
                      if (session.correctCount > 0)
                        Expanded(
                          flex: session.correctCount,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1200),
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
                                        AppTheme.successColor.withOpacity(0.85),
                                      ],
                                    ),
                                    borderRadius:
                                        session.passCount == 0
                                            ? BorderRadius.circular(22.s)
                                            : const BorderRadius.only(
                                              topLeft: Radius.circular(22),
                                              bottomLeft: Radius.circular(22),
                                              topRight: Radius.circular(6),
                                              bottomRight: Radius.circular(6),
                                            ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.circleCheck,
                                          color: Colors.white,
                                          size: 14.s,
                                        ),
                                        SizedBox(width: 6.s),
                                        Text(
                                          '${session.correctCount}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                      if (session.passCount > 0)
                        Expanded(
                          flex: session.passCount,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1400),
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
                                        AppTheme.warningColor.withOpacity(0.85),
                                      ],
                                    ),
                                    borderRadius:
                                        session.correctCount == 0
                                            ? BorderRadius.circular(22.s)
                                            : const BorderRadius.only(
                                              topRight: Radius.circular(22),
                                              bottomRight: Radius.circular(22),
                                              topLeft: Radius.circular(6),
                                              bottomLeft: Radius.circular(6),
                                            ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.forward,
                                          color: Colors.white,
                                          size: 14.s,
                                        ),
                                        SizedBox(width: 6.s),
                                        Text(
                                          '${session.passCount}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                ),
              ),
              if (session.correctCards.isNotEmpty || session.passedCards.isNotEmpty) ...[
                SizedBox(height: 16.s),
                _buildPerformanceWords(session),
              ],
              SizedBox(height: 14.s),
              Row(
                children: [
                  Expanded(
                    child: Container(
                          padding: EdgeInsets.all(12.s),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12.s),
                            border: Border.all(
                              color: AppTheme.successColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.thumbsUp,
                                color: AppTheme.successColor,
                                size: 16.s,
                              ),
                              SizedBox(width: 10.s),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Correct',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    Text(
                                      '$correctPct%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
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
                        .fadeIn(delay: 800.ms)
                        .slideX(begin: -0.05, end: 0),
                  ),
                  SizedBox(width: 12.s),
                  Expanded(
                    child: Container(
                          padding: EdgeInsets.all(12.s),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12.s),
                            border: Border.all(
                              color: AppTheme.warningColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.arrowRight,
                                color: AppTheme.warningColor,
                                size: 16.s,
                              ),
                              SizedBox(width: 10.s),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Passed',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    Text(
                                      '$passPct%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
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
                        .fadeIn(delay: 900.ms)
                        .slideX(begin: 0.05, end: 0),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 600.ms, duration: 500.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutQuart);
  }

  /// Words answered (correct + passed) shown inside the Performance section.
  Widget _buildPerformanceWords(GameSession session) {
    final correctWords = session.correctCards.map((c) => c.word).toList();
    final passedWords = session.passedCards.map((c) => c.word).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (correctWords.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                FontAwesomeIcons.circleCheck,
                size: 12.s,
                color: AppTheme.successColor,
              ),
              SizedBox(width: 6.s),
              Text(
                'Correct',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successColor.withOpacity(0.95),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.s),
          Wrap(
            spacing: 6.s,
            runSpacing: 6.s,
            children: correctWords
                .map(
                  (word) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 6.s),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10.s),
                      border: Border.all(
                        color: AppTheme.successColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      word,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 12.s),
        ],
        if (passedWords.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                FontAwesomeIcons.forward,
                size: 12.s,
                color: AppTheme.warningColor,
              ),
              SizedBox(width: 6.s),
              Text(
                'Passed',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningColor.withOpacity(0.95),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.s),
          Wrap(
            spacing: 6.s,
            runSpacing: 6.s,
            children: passedWords
                .map(
                  (word) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 6.s),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10.s),
                      border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      word,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 400.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required int delay,
  }) {
    return Container(
          padding: EdgeInsets.symmetric(vertical: 14.s, horizontal: 10.s),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: color.withOpacity(0.25), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 36.s,
                height: 36.s,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 1),
                ),
                child: Icon(icon, color: Colors.white, size: 18.s),
              ),
              SizedBox(height: 10.s),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2.s),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.65),
                ),
              ),
            ],
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
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ).animate().fadeIn(duration: 400.ms),
        SizedBox(height: 16.s),
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
            SizedBox(width: 12.s),
            Expanded(
              child: _buildStatCard(
                icon: FontAwesomeIcons.forward,
                iconColor: AppTheme.warningColor,
                value: session.passCount.toString(),
                label: 'Passed',
                delay: 200,
              ),
            ),
            SizedBox(width: 12.s),
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
    final numValue =
        double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return Container(
          padding: EdgeInsets.symmetric(vertical: 20.s, horizontal: 12.s),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18.s),
            border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 44.s,
                height: 44.s,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12.s),
                  border: Border.all(
                    color: iconColor.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 20.s),
              ),
              SizedBox(height: 12.s),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: numValue),
                duration: Duration(milliseconds: 1000 + delay),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, child) {
                  return Text(
                    value.contains('s')
                        ? '${animValue.toInt()}s'
                        : animValue.toInt().toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              SizedBox(height: 4.s),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (400 + delay).ms, duration: 500.ms)
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
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20.s),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20.s),
            child: InkWell(
              onTap: () {
                setState(() => _showDetails = !_showDetails);
                _hapticService.lightImpact();
              },
              borderRadius: BorderRadius.circular(20.s),
              child: Padding(
                padding: EdgeInsets.all(20.s),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40.s,
                              height: 40.s,
                              decoration: BoxDecoration(
                                color: session.deck.color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12.s),
                              ),
                              child: Icon(
                                FontAwesomeIcons.rectangleList,
                                color: session.deck.color,
                                size: 18.s,
                              ),
                            ),
                            SizedBox(width: 12.s),
                            Text(
                              'Word Details',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        AnimatedRotation(
                          turns: _showDetails ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 34.s,
                            height: 34.s,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10.s),
                            ),
                            child: Icon(
                              Icons.expand_more_rounded,
                              color: Colors.white.withOpacity(0.8),
                              size: 20.s,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        children: [
                          SizedBox(height: 20.s),
                          if (correctWords.isNotEmpty) ...[
                            _buildWordsList(
                              'Correct Words',
                              correctWords,
                              AppTheme.successColor,
                              FontAwesomeIcons.circleCheck,
                              session.deck.color,
                            ),
                            if (passedWords.isNotEmpty) SizedBox(height: 16.s),
                          ],
                          if (passedWords.isNotEmpty)
                            _buildWordsList(
                              'Passed Words',
                              passedWords,
                              AppTheme.warningColor,
                              FontAwesomeIcons.forward,
                              session.deck.color,
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
        .fadeIn(delay: 600.ms, duration: 500.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildWordsList(
    String title,
    List<String> words,
    Color color,
    IconData icon,
    Color deckColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32.s,
              height: 32.s,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.s),
              ),
              child: Icon(icon, color: color, size: 16.s),
            ),
            SizedBox(width: 10.s),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8.s),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 4.s),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.s),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Text(
                '${words.length}',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.s),
        Wrap(
          spacing: 8.s,
          runSpacing: 8.s,
          children:
              words
                  .map(
                    (word) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.s,
                        vertical: 8.s,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12.s),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        word,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
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
    final deckColor = session.deck.color;
    return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24.s,
                  14.s,
                  24.s,
                  2.0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              _hapticService.lightImpact();
                              _videoSectionKey.currentState
                                  ?.cancelVideoProcessing();
                              VideoProcessingManager.instance
                                  .cancelCurrentProcessing(
                                    reason:
                                        'Home button pressed on results screen',
                                  );
                              await _showInterstitialWithLoader(() {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }, location: 'results_home_button');
                            },
                            borderRadius: BorderRadius.circular(16.s),
                            child: Container(
                              height: 56.s,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16.s),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.house,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 20.s,
                                  ),
                                  SizedBox(width: 10.s),
                                  Text(
                                    'Home',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.s),
                      Expanded(
                        flex: 2,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              _hapticService.lightImpact();
                              _videoSectionKey.currentState
                                  ?.cancelVideoProcessing();
                              VideoProcessingManager.instance
                                  .cancelCurrentProcessing(
                                    reason:
                                        'Play Again button pressed on results screen',
                                  );
                              await _showInterstitialWithLoader(() {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            DeckDetailsScreen(
                                              deck: session.deck,
                                            ),
                                  ),
                                );
                              }, location: 'results_play_again_button');
                            },
                            borderRadius: BorderRadius.circular(16.s),
                            child: Container(
                              height: 56.s,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    deckColor,
                                    deckColor.withOpacity(0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16.s),
                                boxShadow: [
                                  BoxShadow(
                                    color: deckColor.withOpacity(0.4),
                                    blurRadius: 20.s,
                                    offset: Offset(0, 8.s),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.arrowRotateRight,
                                    color: Colors.white,
                                    size: 20.s,
                                  ),
                                  SizedBox(width: 10.s),
                                  Text(
                                    'Play Again',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
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
          ),
        )
        .animate()
        .fadeIn(delay: 800.ms, duration: 500.ms)
        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic);
  }

  void _shareResults(GameSession session) {
    _hapticService.lightImpact();
    // Use ShareService for deep link sharing
    ShareService().shareGameResults(
      session,
      context,
      deckName: session.deck.name,
    );
  }

  Widget _buildDoubleScoreButton(GameSession session) {
    return Container(
          width: double.infinity,
          height: 56.s,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade600, Colors.amber.shade700],
            ),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.35),
                blurRadius: 20.s,
                offset: Offset(0, 8.s),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                _hapticService.mediumImpact();
                await _adService.showRewardedAd(
                  rewardType: 'double_score',
                  onUserEarnedReward: (amount) {
                    setState(() => _hasDoubledScore = true);
                    final gameProvider = context.read<GameProvider>();
                    gameProvider.doubleLastGameScore();
                    _hapticService.success();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.star_rounded, color: Colors.white),
                            SizedBox(width: 8.s),
                            Text(
                              'Score doubled! +${session.correctCount * 10} bonus points',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1C1C1E),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.s),
                        ),
                      ),
                    );
                  },
                );
              },
              borderRadius: BorderRadius.circular(16.s),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled_rounded,
                      color: Colors.white,
                      size: 24.s,
                    ),
                    SizedBox(width: 12.s),
                    Text(
                      'Watch Ad to Double Score',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 10.s),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.s,
                        vertical: 4.s,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8.s),
                      ),
                      child: Text(
                        '2x',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 500.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic)
        .shimmer(
          delay: 1600.ms,
          duration: 1500.ms,
          color: Colors.white.withOpacity(0.25),
        );
  }
}
