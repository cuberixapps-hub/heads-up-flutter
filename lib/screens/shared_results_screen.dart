import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/deep_link_service.dart';
import '../services/haptic_service.dart';

/// Screen to display shared game results from a deep link
class SharedResultsScreen extends StatefulWidget {
  final DeepLinkData? linkData;

  const SharedResultsScreen({super.key, this.linkData});

  @override
  State<SharedResultsScreen> createState() => _SharedResultsScreenState();
}

class _SharedResultsScreenState extends State<SharedResultsScreen> {
  final _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _hapticService.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.linkData;
    final deckName = data?.deckName ?? 'Heads Up';
    final score = data?.score ?? 0;
    final correct = data?.correct ?? 0;
    final passed = data?.passed ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  const Color(0xFF0A0E21),
                  const Color(0xFF0A0E21),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Shared Score',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the close button
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Trophy icon
                        Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFFD700),
                                    const Color(0xFFFFA500),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.emoji_events_rounded,
                                size: 50,
                                color: Colors.white,
                              ),
                            )
                            .animate()
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                            ),

                        const SizedBox(height: 32),

                        // Title
                        Text(
                          'Someone scored',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms),

                        const SizedBox(height: 8),

                        // Score
                        Text(
                          '$score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideY(begin: 0.3),

                        Text(
                          'points',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 20,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 400.ms),

                        const SizedBox(height: 8),

                        // Deck name
                        Text(
                          'in "$deckName"',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 500.ms),

                        const SizedBox(height: 40),

                        // Stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard(
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF10B981),
                              value: correct.toString(),
                              label: 'Correct',
                            ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.3),
                            _buildStatCard(
                              icon: Icons.skip_next_rounded,
                              color: const Color(0xFFF59E0B),
                              value: passed.toString(),
                              label: 'Passed',
                            ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.3),
                          ],
                        ),

                        const SizedBox(height: 48),

                        // Challenge text
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '🔥 Can you beat this score?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Play the same deck and show them who\'s the champion!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 800.ms),

                        const SizedBox(height: 32),

                        // Play button
                        GestureDetector(
                          onTap: () {
                            _hapticService.mediumImpact();
                            context.go('/home');
                          },
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Play Now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 900.ms)
                            .slideY(begin: 0.3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}







