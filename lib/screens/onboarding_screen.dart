import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/app_theme.dart';
import '../services/haptic_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _hapticService = HapticService();
  late AnimationController _backgroundAnimationController;
  late Animation<double> _backgroundAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Heads Up!',
      subtitle: 'The Ultimate Party Game',
      description:
          'Get ready for endless laughter and unforgettable moments with friends and family',
      icon: FontAwesomeIcons.faceSmileBeam,
      illustration: '🎉',
      accentColor: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFFF0F1FF),
    ),
    OnboardingPage(
      title: 'How to Play',
      subtitle: 'It\'s Simple!',
      description:
          'Hold your phone to your forehead. Your friends give you clues. Guess the word before time runs out!',
      icon: FontAwesomeIcons.mobile,
      illustration: '📱',
      accentColor: const Color(0xFFEC4899),
      backgroundColor: const Color(0xFFFFF0F7),
    ),
    OnboardingPage(
      title: 'Intuitive Controls',
      subtitle: 'Tilt to Play',
      description:
          'Tilt down when you guess correctly ✓\nTilt up to skip and pass ✗\nNo buttons needed!',
      icon: FontAwesomeIcons.arrowsUpDown,
      illustration: '🎮',
      accentColor: const Color(0xFF10B981),
      backgroundColor: const Color(0xFFF0FDF4),
    ),
    OnboardingPage(
      title: 'Ready to Play?',
      subtitle: 'Let\'s Get Started!',
      description:
          'Choose from dozens of fun categories or create your own custom decks. The fun never ends!',
      icon: FontAwesomeIcons.rocket,
      illustration: '🚀',
      accentColor: const Color(0xFFF59E0B),
      backgroundColor: const Color(0xFFFFFBEB),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pages[_currentPage].backgroundColor,
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: _pages[_currentPage].backgroundColor,
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Decorative circles in background
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pages[_currentPage].accentColor.withOpacity(
                          0.05,
                        ),
                      ),
                    ).animate().scale(
                      duration: const Duration(seconds: 20),
                      curve: Curves.easeInOut,
                    ),
                  ),
                  Positioned(
                    bottom: -150,
                    left: -150,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pages[_currentPage].accentColor.withOpacity(
                          0.03,
                        ),
                      ),
                    ).animate().scale(
                      duration: const Duration(seconds: 25),
                      curve: Curves.easeInOut,
                    ),
                  ),

                  Column(
                    children: [
                      // Top bar with skip button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Progress indicator
                            Container(
                              width: 60,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _pages[_currentPage].accentColor
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  '${_currentPage + 1} / ${_pages.length}',
                                  style: TextStyle(
                                    color: _pages[_currentPage].accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            // Skip button
                            if (_currentPage < _pages.length - 1)
                              TextButton(
                                onPressed: _completeOnboarding,
                                style: TextButton.styleFrom(
                                  foregroundColor: _pages[_currentPage]
                                      .accentColor
                                      .withOpacity(0.7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Page content
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                            _hapticService.selection();
                            HapticFeedback.selectionClick();
                          },
                          itemCount: _pages.length,
                          itemBuilder: (context, index) {
                            return _buildPage(_pages[index], index);
                          },
                        ),
                      ),

                      // Bottom section with navigation
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Column(
                          children: [
                            // Modern page indicators
                            Container(
                              height: 40,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _pages.length,
                                  (index) => _buildModernIndicator(index),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Modern navigation section
                            if (_currentPage < _pages.length - 1)
                              // Regular navigation for non-final pages
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Back button - positioned absolutely
                                  if (_currentPage > 0)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildMinimalBackButton(
                                        onPressed: () {
                                          _pageController.previousPage(
                                            duration: const Duration(
                                              milliseconds: 400,
                                            ),
                                            curve: Curves.easeInOutCubic,
                                          );
                                          _hapticService.lightImpact();
                                        },
                                      ),
                                    ),

                                  // Center-aligned next button
                                  _buildModernContinueButton(
                                    onPressed: () {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        curve: Curves.easeInOutCubic,
                                      );
                                      _hapticService.lightImpact();
                                    },
                                  ),
                                ],
                              )
                            else
                              // Final page - Get Started button
                              _buildGetStartedButton(
                                onPressed: () {
                                  _completeOnboarding();
                                  _hapticService.lightImpact();
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernIndicator(int index) {
    final isActive = _currentPage == index;
    final isPast = index < _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color:
            isActive
                ? _pages[_currentPage].accentColor
                : isPast
                ? _pages[_currentPage].accentColor.withOpacity(0.3)
                : _pages[_currentPage].accentColor.withOpacity(0.15),
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
                  color: _pages[_currentPage].accentColor.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    color: _pages[_currentPage].accentColor.withOpacity(0.6),
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

  Widget _buildModernContinueButton({required VoidCallback onPressed}) {
    return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 160,
            height: 52,
            decoration: BoxDecoration(
              color: _pages[_currentPage].accentColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: _pages[_currentPage].accentColor.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
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

  Widget _buildGetStartedButton({required VoidCallback onPressed}) {
    return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: _pages[_currentPage].accentColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _pages[_currentPage].accentColor.withOpacity(0.3),
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
                          Icons.celebration_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Let\'s Play!',
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

  Widget _buildPage(OnboardingPage page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration emoji
          Text(page.illustration, style: const TextStyle(fontSize: 80))
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),

          const SizedBox(height: 32),

          // Modern icon container
          Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: page.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: FaIcon(page.icon, size: 36, color: page.accentColor),
                ),
              )
              .animate()
              .fadeIn(duration: 600.ms, delay: 300.ms)
              .slideY(begin: 0.2),

          const SizedBox(height: 32),

          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: page.accentColor.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

          const SizedBox(height: 8),

          // Title
          Text(
                page.title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: page.accentColor,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(delay: 500.ms, duration: 600.ms)
              .slideY(begin: 0.2),

          const SizedBox(height: 20),

          // Description card
          Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: page.accentColor.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  page.description,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
              .animate()
              .fadeIn(delay: 600.ms, duration: 600.ms)
              .slideY(begin: 0.3),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final String illustration;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.illustration,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });
}
