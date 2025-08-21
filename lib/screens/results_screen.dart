import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:math';
import '../constants/app_theme.dart';
import '../models/game_session.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'category_selection_screen.dart';
import 'gameplay_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();

  late AnimationController _confettiController;
  late AnimationController _scoreController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..forward();

    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    // Play success sound
    _audioService.playSuccess();
    _hapticService.success();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scoreController.dispose();
    super.dispose();
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
        body: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            final session = gameProvider.currentSession;
            if (session == null) {
              return const Center(child: Text('No game data'));
            }

            final isHighScore = _checkIfHighScore(session, gameProvider);

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    session.deck.color.withOpacity(0.8),
                    session.deck.color,
                  ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Confetti animation
                    if (isHighScore) _buildConfetti(),

                    // Main content
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildHeader(session),
                          const SizedBox(height: 32),
                          _buildScoreCard(session, isHighScore),
                          const SizedBox(height: 24),
                          _buildWordsList(session),
                          const SizedBox(height: 24),
                          _buildActionButtons(session),
                        ],
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

  bool _checkIfHighScore(GameSession session, GameProvider gameProvider) {
    final stats = gameProvider.getStatistics();
    return session.correctCount == stats['highScore'] &&
        session.correctCount > 0;
  }

  Widget _buildConfetti() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _confettiController,
        builder: (context, child) {
          return CustomPaint(
            painter: ConfettiPainter(
              animation: _confettiController,
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                AppTheme.accentColor,
                AppTheme.warningColor,
                AppTheme.successColor,
              ],
            ),
            child: Container(),
          );
        },
      ),
    );
  }

  Widget _buildHeader(GameSession session) {
    return Column(
      children: [
        Text(
          'Game Over!',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
        const SizedBox(height: 8),
        Text(
          session.deck.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildScoreCard(GameSession session, bool isHighScore) {
    return Container(
          padding: const EdgeInsets.all(24),
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
          child: Column(
            children: [
              if (isHighScore) ...[
                ElasticIn(
                  delay: const Duration(milliseconds: 800),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'NEW HIGH SCORE!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Score animation
              AnimatedBuilder(
                animation: _scoreController,
                builder: (context, child) {
                  final score =
                      (_scoreController.value * session.correctCount).round();
                  return Column(
                    children: [
                      Text(
                        score.toString(),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: session.deck.color,
                        ),
                      ),
                      Text(
                        'Correct Answers',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    Icons.check_circle,
                    session.correctCount.toString(),
                    'Correct',
                    AppTheme.successColor,
                  ),
                  Container(width: 1, height: 40, color: AppTheme.dividerColor),
                  _buildStatItem(
                    Icons.skip_next,
                    session.passCount.toString(),
                    'Passed',
                    AppTheme.warningColor,
                  ),
                  Container(width: 1, height: 40, color: AppTheme.dividerColor),
                  _buildStatItem(
                    Icons.timer,
                    '${session.roundDuration.inSeconds}s',
                    'Time',
                    AppTheme.primaryColor,
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 400.ms, duration: 600.ms)
        .slideY(begin: 0.2)
        .scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildWordsList(GameSession session) {
    final correctWords = session.correctCards.map((c) => c.word).toList();
    final passedWords = session.passedCards.map((c) => c.word).toList();

    if (correctWords.isEmpty && passedWords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (correctWords.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Guessed Correctly',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  correctWords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final word = entry.value;
                    return FadeInLeft(
                      delay: Duration(milliseconds: 800 + (index * 50)),
                      child: Chip(
                        label: Text(word),
                        backgroundColor: AppTheme.successColor.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],

          if (passedWords.isNotEmpty) ...[
            if (correctWords.isNotEmpty) const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.skip_next, color: AppTheme.warningColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Passed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  passedWords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final word = entry.value;
                    return FadeInRight(
                      delay: Duration(milliseconds: 1000 + (index * 50)),
                      child: Chip(
                        label: Text(word),
                        backgroundColor: AppTheme.warningColor.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.2);
  }

  Widget _buildActionButtons(GameSession session) {
    return Column(
      children: [
        // Share button
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton.icon(
            onPressed: () => _shareResults(session),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: session.deck.color,
              padding: const EdgeInsets.all(16),
            ),
            icon: const Icon(Icons.share),
            label: const Text('Share Results', style: TextStyle(fontSize: 16)),
          ),
        ),

        // Action buttons row
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _playAgain(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Play Again', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _changeDeck(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('New Deck', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Home button
        TextButton(
          onPressed: () => _goHome(),
          child: Text(
            'Back to Home',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms, duration: 600.ms).slideY(begin: 0.2);
  }

  void _shareResults(GameSession session) {
    _hapticService.lightImpact();
    final text = '''
🎮 Heads Up! Results 🎮

Category: ${session.deck.name}
Score: ${session.correctCount} correct answers!
Time: ${session.roundDuration.inSeconds} seconds

✅ Correct: ${session.correctCount}
⏭️ Passed: ${session.passCount}

Play Heads Up! and beat my score!
''';
    Share.share(text);
  }

  void _playAgain() {
    _hapticService.lightImpact();
    context.read<GameProvider>().playAgain();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => GameplayScreen(
              deck: context.read<GameProvider>().currentSession!.deck,
            ),
      ),
    );
  }

  void _changeDeck() {
    _hapticService.lightImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CategorySelectionScreen()),
    );
  }

  void _goHome() {
    _hapticService.lightImpact();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// Confetti painter for celebration animation
class ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Color> colors;
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.animation, required this.colors})
    : particles = List.generate(
        50,
        (index) => ConfettiParticle(
          color: colors[index % colors.length],
          x: Random().nextDouble(),
          y: Random().nextDouble() * -1,
          size: Random().nextDouble() * 10 + 5,
          velocity: Random().nextDouble() * 2 + 1,
          angle: Random().nextDouble() * 360,
        ),
      ),
      super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;

    for (final particle in particles) {
      final paint =
          Paint()
            ..color = particle.color.withOpacity(1 - progress * 0.5)
            ..style = PaintingStyle.fill;

      final y = (particle.y + particle.velocity * progress) * size.height;
      final x =
          particle.x * size.width +
          sin(progress * pi * 2 + particle.angle) * 20;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * pi * 4 + particle.angle);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ConfettiParticle {
  final Color color;
  final double x;
  final double y;
  final double size;
  final double velocity;
  final double angle;

  ConfettiParticle({
    required this.color,
    required this.x,
    required this.y,
    required this.size,
    required this.velocity,
    required this.angle,
  });
}
