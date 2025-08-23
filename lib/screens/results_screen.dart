import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
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
      }
    });
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _statsController.dispose();
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
        backgroundColor: Colors.grey[50],
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

            return Stack(
              children: [
                // Clean background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.grey[50]!],
                    ),
                  ),
                ),

                // Subtle pattern
                CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _MinimalBackgroundPainter(),
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
                      ],
                      numberOfParticles: 40,
                      gravity: 0.2,
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              _buildMainScoreCard(
                                session,
                                accuracy,
                                isHighScore,
                              ),
                              const SizedBox(height: 20),
                              _buildStatsSection(session),
                              const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GAME COMPLETE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.deck.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Share button
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _shareResults(session),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.ios_share,
                    size: 20,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard(
    GameSession session,
    int accuracy,
    bool isHighScore,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Score section with colored accent
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  session.deck.color.withOpacity(0.1),
                  session.deck.color.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Score animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: session.correctCount.toDouble()),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: session.deck.color,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'POINTS SCORED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: session.deck.color.withOpacity(0.7),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                if (isHighScore) ...[
                  const SizedBox(height: 20),
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'NEW RECORD!',
                              style: TextStyle(
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
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

          // Accuracy bar
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Accuracy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      '$accuracy%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _getAccuracyColor(accuracy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: accuracy / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getAccuracyColor(accuracy),
                    ),
                  ),
                ).animate().scaleX(
                  begin: 0,
                  end: 1,
                  delay: 500.ms,
                  duration: 1000.ms,
                  curve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0);
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 80) return Colors.green;
    if (accuracy >= 60) return AppTheme.primaryColor;
    if (accuracy >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatsSection(GameSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Game Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_rounded,
                iconColor: Colors.green,
                value: session.correctCount.toString(),
                label: 'Correct',
                delay: 100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.fast_forward_rounded,
                iconColor: Colors.orange,
                value: session.passCount.toString(),
                label: 'Passed',
                delay: 200,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.schedule_rounded,
                iconColor: Colors.blue,
                value: '${session.roundDuration}s',
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 600.ms)
        .scale(delay: Duration(milliseconds: delay), duration: 400.ms);
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
            border: Border.all(color: Colors.grey[200]!, width: 1),
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
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.list_alt_rounded,
                                color: Colors.grey[700],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Word Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        AnimatedRotation(
                          turns: _showDetails ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.expand_more_rounded,
                            color: Colors.grey[600],
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
                              Colors.green,
                              Icons.done_rounded,
                            ),
                            if (passedWords.isNotEmpty)
                              const SizedBox(height: 16),
                          ],
                          if (passedWords.isNotEmpty)
                            _buildWordsList(
                              'Passed Words',
                              passedWords,
                              Colors.orange,
                              Icons.skip_next_rounded,
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
        .fadeIn(delay: 400.ms, duration: 600.ms)
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
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${words.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
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
                          color: Colors.grey[800],
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
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
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
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              color: Colors.grey[700],
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Home',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
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
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: session.deck.color,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: session.deck.color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
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
                        borderRadius: BorderRadius.circular(14),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.replay_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
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
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(delay: 600.ms, duration: 600.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  void _shareResults(GameSession session) {
    final totalCards = session.correctCount + session.passCount;
    final accuracy =
        totalCards > 0 ? (session.correctCount / totalCards * 100).round() : 0;

    final message = '''
🎮 Heads Up! Results

📚 Category: ${session.deck.name}
✅ Correct: ${session.correctCount}
⏭️ Passed: ${session.passCount}
🎯 Accuracy: $accuracy%
⏱️ Duration: ${session.roundDuration}s

Play Heads Up! and beat my score!
''';

    Share.share(message);
    _hapticService.lightImpact();
  }
}

// Minimal background painter
class _MinimalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.grey.withOpacity(0.03);

    // Draw subtle dots pattern
    for (int i = 0; i < 20; i++) {
      for (int j = 0; j < 30; j++) {
        final x = size.width * (i / 20);
        final y = size.height * (j / 30);
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MinimalBackgroundPainter oldDelegate) => false;
}
