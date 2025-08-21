import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../constants/app_theme.dart';
import '../models/game_session.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../widgets/animated_gradient_background.dart';

class TeamResultsScreen extends StatefulWidget {
  final List<Color>? teamColors;

  const TeamResultsScreen({super.key, this.teamColors});

  @override
  State<TeamResultsScreen> createState() => _TeamResultsScreenState();
}

class _TeamResultsScreenState extends State<TeamResultsScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();

  late AnimationController _confettiController;
  late AnimationController _trophyController;
  late AnimationController _scoreRevealController;
  late AnimationController _floatingController;
  late List<AnimationController> _teamScoreControllers;

  List<_ConfettiParticle> _confettiParticles = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateConfetti();
    _playVictorySound();
  }

  void _initializeAnimations() {
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..forward();

    _trophyController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scoreRevealController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize team score controllers
    final session = context.read<GameProvider>().currentSession;
    final teamCount = session?.teams?.length ?? 2;
    _teamScoreControllers = List.generate(
      teamCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 800 + (index * 200)),
        vsync: this,
      )..forward(),
    );
  }

  void _generateConfetti() {
    final random = math.Random();
    _confettiParticles = List.generate(100, (index) {
      return _ConfettiParticle(
        x: random.nextDouble() * 400 - 200,
        y: random.nextDouble() * -100,
        rotation: random.nextDouble() * 360,
        size: random.nextDouble() * 10 + 5,
        color:
            [
              Colors.yellow,
              Colors.blue,
              Colors.red,
              Colors.green,
              Colors.purple,
              Colors.orange,
            ][random.nextInt(6)],
        speed: random.nextDouble() * 2 + 1,
      );
    });
  }

  void _playVictorySound() {
    _audioService.playVictory();
    _hapticService.success();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _trophyController.dispose();
    _scoreRevealController.dispose();
    _floatingController.dispose();
    for (var controller in _teamScoreControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          const AnimatedGradientBackground(child: SizedBox.expand()),

          // Confetti animation
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ConfettiPainter(
                  particles: _confettiParticles,
                  progress: _confettiController.value,
                ),
                child: child ?? Container(),
              );
            },
            child: Container(),
          ),

          // Main content
          SafeArea(
            child: Consumer<GameProvider>(
              builder: (context, gameProvider, child) {
                final session = gameProvider.currentSession;
                if (session == null || session.teams == null) {
                  return const Center(child: Text('No game data available'));
                }

                final teams = session.teams!;
                final sortedTeams = List.from(teams)
                  ..sort((a, b) => b.score.compareTo(a.score));
                final winningTeam = sortedTeams.first;
                final isDraw =
                    sortedTeams.length > 1 &&
                    sortedTeams[0].score == sortedTeams[1].score;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Winner announcement
                    SliverToBoxAdapter(
                      child: _buildWinnerSection(winningTeam, isDraw),
                    ),

                    // Team scores
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final team = sortedTeams[index];
                          final isWinner = index == 0 && !isDraw;
                          final teamColor =
                              widget.teamColors?[teams.indexOf(team) %
                                  (widget.teamColors?.length ?? 1)] ??
                              AppTheme.primaryColor;

                          return _buildTeamScoreCard(
                            team: team,
                            rank: index + 1,
                            isWinner: isWinner,
                            color: teamColor,
                            animationController:
                                _teamScoreControllers[teams.indexOf(team) %
                                    _teamScoreControllers.length],
                          );
                        }, childCount: sortedTeams.length),
                      ),
                    ),

                    // Action buttons
                    SliverToBoxAdapter(child: _buildActionButtons(context)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerSection(Team winningTeam, bool isDraw) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          // Trophy animation
          AnimatedBuilder(
                animation: _trophyController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_trophyController.value * 0.1),
                    child: Transform.rotate(
                      angle:
                          math.sin(_trophyController.value * math.pi * 2) * 0.1,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.amber.shade300,
                              Colors.amber.shade600,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          FontAwesomeIcons.trophy,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              )
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .shimmer(duration: 2.seconds, delay: 800.ms),

          const SizedBox(height: 30),

          // Winner text
          Text(
                isDraw ? 'It\'s a Draw!' : 'Winner!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          // Team name
          Text(
                isDraw ? 'Great game everyone!' : winningTeam.name,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              )
              .animate()
              .fadeIn(delay: 600.ms, duration: 800.ms)
              .scale(begin: const Offset(0.8, 0.8))
              .shimmer(delay: 1400.ms, duration: 2.seconds),

          if (!isDraw) ...[
            const SizedBox(height: 20),
            Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        FontAwesomeIcons.star,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${winningTeam.score} Points',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 1000.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamScoreCard({
    required Team team,
    required int rank,
    required bool isWinner,
    required Color color,
    required AnimationController animationController,
  }) {
    final medal =
        rank == 1
            ? FontAwesomeIcons.medal
            : rank == 2
            ? FontAwesomeIcons.award
            : rank == 3
            ? FontAwesomeIcons.certificate
            : FontAwesomeIcons.userGroup;

    final medalColor =
        rank == 1
            ? Colors.amber
            : rank == 2
            ? Colors.grey.shade400
            : rank == 3
            ? Colors.brown.shade400
            : color;

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - animationController.value) * 50),
          child: Opacity(
            opacity: animationController.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isWinner
                          ? [
                            Colors.amber.shade300.withOpacity(0.3),
                            Colors.amber.shade600.withOpacity(0.2),
                          ]
                          : [color.withOpacity(0.15), color.withOpacity(0.08)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isWinner
                          ? Colors.amber.withOpacity(0.5)
                          : color.withOpacity(0.3),
                  width: isWinner ? 2 : 1,
                ),
                boxShadow: [
                  if (isWinner)
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showTeamDetails(team),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: medalColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: medalColor.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: FaIcon(medal, color: medalColor, size: 28),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Team info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    team.name,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      shadows:
                                          isWinner
                                              ? [
                                                Shadow(
                                                  color: Colors.amber
                                                      .withOpacity(0.5),
                                                  blurRadius: 10,
                                                ),
                                              ]
                                              : null,
                                    ),
                                  ),
                                  if (isWinner) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber.shade400,
                                            Colors.amber.shade600,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'CHAMPION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rank #$rank',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Score
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${team.score}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows:
                                    isWinner
                                        ? [
                                          Shadow(
                                            color: Colors.amber.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 10,
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            Text(
                              'points',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
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

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Play Again button
          Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _playAgain,
                    borderRadius: BorderRadius.circular(16),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Play Again',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 1400.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 12),

          // Home button
          Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goHome,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 1600.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  void _showTeamDetails(Team team) {
    _hapticService.lightImpact();
    // Show detailed stats for the team
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('Score', '${team.score}', Icons.star),
                    _buildStatItem(
                      'Correct',
                      '${team.results.length}',
                      Icons.check_circle,
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  void _playAgain() {
    _hapticService.mediumImpact();
    _audioService.playClick();
    context.read<GameProvider>().playAgain();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goHome() {
    _hapticService.lightImpact();
    _audioService.playClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// Confetti particle class
class _ConfettiParticle {
  final double x;
  final double y;
  final double rotation;
  final double size;
  final Color color;
  final double speed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.rotation,
    required this.size,
    required this.color,
    required this.speed,
  });
}

// Confetti painter
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint =
          Paint()
            ..color = particle.color.withOpacity(1.0 - progress * 0.5)
            ..style = PaintingStyle.fill;

      final y = particle.y + (progress * size.height * particle.speed);
      final x =
          size.width / 2 + particle.x + math.sin(progress * math.pi * 2) * 20;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + progress * math.pi * 4);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.size,
        height: particle.size * 0.6,
      );

      canvas.drawRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
