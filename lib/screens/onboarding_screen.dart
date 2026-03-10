import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

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
  
  // Animation controllers for custom illustrations
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _tiltController;
  
  // Gradient colors for each page - Netflix-inspired dark theme
  final List<List<Color>> _pageGradients = [
    [const Color(0xFF1A0A0F), const Color(0xFF0D0507), const Color(0xFF000000)], // Deep burgundy
    [const Color(0xFF0A1628), const Color(0xFF050C16), const Color(0xFF000000)], // Deep navy
    [const Color(0xFF0A1A14), const Color(0xFF050D0A), const Color(0xFF000000)], // Deep forest
    [const Color(0xFF1A1408), const Color(0xFF0D0A04), const Color(0xFF000000)], // Deep gold
  ];

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to\nHeads Up!',
      subtitle: 'THE ULTIMATE PARTY GAME',
      description:
          'Get ready for endless laughter and unforgettable moments with friends and family.',
      accentColor: const Color(0xFFE50914),
      secondaryColor: const Color(0xFFFF6B6B),
    ),
    OnboardingPage(
      title: 'How to Play',
      subtitle: 'IT\'S SIMPLE & FUN',
      description:
          'Hold your phone to your forehead. Your friends give you clues. Guess the word before time runs out!',
      accentColor: const Color(0xFF0A84FF),
      secondaryColor: const Color(0xFF5AC8FA),
    ),
    OnboardingPage(
      title: 'Intuitive\nControls',
      subtitle: 'TILT TO PLAY',
      description:
          'Tilt down for correct ✓\nTilt up to pass ✗\nNo buttons needed!',
      accentColor: const Color(0xFF30D158),
      secondaryColor: const Color(0xFF34C759),
    ),
    OnboardingPage(
      title: 'Ready to\nPlay?',
      subtitle: 'LET\'S GET STARTED',
      description:
          'Choose from dozens of fun categories or create your own custom decks.',
      accentColor: const Color(0xFFFFD700),
      secondaryColor: const Color(0xFFFFA500),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Slower, smoother animations for premium feel
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);
    
    _tiltController = AnimationController(
      duration: const Duration(milliseconds: 4500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      final hasSetPreferences = prefs.getBool('has_set_preferences') ?? false;
      final hasAskedNotifications = prefs.getBool('has_asked_notification_permission') ?? false;
      
      if (!hasSetPreferences) {
        // Navigate to preference selection first
        context.go('/preference-selection');
      } else if (!hasAskedNotifications) {
        context.go('/notification-permission');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _pageGradients[_currentPage],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Decorative elements
          _buildBackgroundDecorations(),

          // Main content
          SafeArea(
            child: Column(
                children: [
                _buildTopBar(),
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
                _buildBottomNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    final page = _pages[_currentPage];
    return Stack(
      children: [
        // Ambient glow - top
                  Positioned(
          top: -150.s,
          left: -100.s,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: 400.s,
            height: 400.s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.accentColor.withOpacity(0.15),
                  page.accentColor.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Ambient glow - bottom right
                  Positioned(
          bottom: -100.s,
          right: -100.s,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: 350.s,
            height: 350.s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.secondaryColor.withOpacity(0.1),
                  page.secondaryColor.withOpacity(0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Subtle vignette
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.s, vertical: 16.s),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
          // Premium progress indicator
                            Container(
                padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 10.s),
                              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24.s),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.s,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_pages.length, (index) {
                    final isActive = index == _currentPage;
                    final isPast = index < _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.only(right: index < _pages.length - 1 ? 8.s : 0),
                      width: isActive ? 28.s : 10.s,
                      height: 10.s,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5.s),
                        gradient: isActive
                            ? LinearGradient(
                                colors: [
                                  _pages[_currentPage].accentColor,
                                  _pages[_currentPage].secondaryColor,
                                ],
                              )
                            : null,
                        color: isActive
                            ? null
                            : isPast
                                ? Colors.white.withOpacity(0.4)
                                : Colors.white.withOpacity(0.15),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: _pages[_currentPage].accentColor.withOpacity(0.5),
                                  blurRadius: 12.s,
                                  spreadRadius: 2.s,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: -0.5, duration: 700.ms, curve: Curves.easeOutCubic),

                            // Skip button
                            if (_currentPage < _pages.length - 1)
            Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _completeOnboarding,
                    borderRadius: BorderRadius.circular(24.s),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 10.s),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(24.s),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.s,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                                  'Skip',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                          SizedBox(width: 4.s),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withOpacity(0.4),
                            size: 12.s,
                              ),
                          ],
                        ),
                      ),
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: -0.5, duration: 700.ms, curve: Curves.easeOutCubic)
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    final isCurrentPage = index == _currentPage;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.s),
      child: Column(
        children: [
          SizedBox(height: 20.s),
          
          // Custom illustration for each page
                      Expanded(
            flex: 5,
            child: Center(
              child: _buildCustomIllustration(index, page, isCurrentPage),
            ),
          ),
          
          // Content section
          Expanded(
            flex: 4,
                        child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                // Subtitle badge
                Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 10.s),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            page.accentColor.withOpacity(0.2),
                            page.secondaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30.s),
                        border: Border.all(
                          color: page.accentColor.withOpacity(0.3),
                          width: 1.5.s,
                        ),
                      ),
                      child: Text(
                        page.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: page.accentColor,
                          letterSpacing: 2,
                        ),
                      ),
                    )
                    .animate(target: isCurrentPage ? 1 : 0)
                    .fadeIn(duration: 500.ms, delay: 300.ms)
                    .slideY(begin: 0.3, duration: 500.ms, curve: Curves.easeOutCubic),

                SizedBox(height: 20.s),

                // Title
                ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: Text(
                        page.title,
                        style: GoogleFonts.poppins(
                          fontSize: 38.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: -1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                    .animate(target: isCurrentPage ? 1 : 0)
                    .fadeIn(duration: 600.ms, delay: 400.ms)
                    .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutCubic),

                SizedBox(height: 20.s),

                // Description
                Container(
                      constraints: BoxConstraints(maxWidth: 320.s),
                      child: Text(
                        page.description,
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                    .animate(target: isCurrentPage ? 1 : 0)
                    .fadeIn(duration: 600.ms, delay: 500.ms)
                    .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomIllustration(int index, OnboardingPage page, bool isCurrentPage) {
    switch (index) {
      case 0:
        return _buildWelcomeIllustration(page, isCurrentPage);
      case 1:
        return _buildHowToPlayIllustration(page, isCurrentPage);
      case 2:
        return _buildControlsIllustration(page, isCurrentPage);
      case 3:
        return _buildReadyIllustration(page, isCurrentPage);
      default:
        return const SizedBox();
    }
  }

  // Page 1: Welcome - Celebration with floating elements
  Widget _buildWelcomeIllustration(OnboardingPage page, bool isCurrentPage) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        // Gentler, slower floating motion
        final floatValue = math.sin(_floatingController.value * math.pi * 2) * 4;
        final pulseValue = 0.97 + (_pulseController.value * 0.05);
        
        return SizedBox(
          width: 300.s,
          height: 300.s,
          child: Center(
            child: Stack(
                                alignment: Alignment.center,
              clipBehavior: Clip.none,
                                children: [
                // Outer glow ring
                Transform.scale(
                  scale: pulseValue,
                  child: Container(
                    width: 220.s,
                    height: 220.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          page.accentColor.withOpacity(0.0),
                          page.accentColor.withOpacity(0.12),
                          page.accentColor.withOpacity(0.0),
                        ],
                        stops: const [0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Main circle
                Container(
                  width: 160.s,
                  height: 160.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        page.accentColor.withOpacity(0.3),
                        page.secondaryColor.withOpacity(0.15),
                      ],
                    ),
                    border: Border.all(
                      color: page.accentColor.withOpacity(0.5),
                      width: 2.s,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: page.accentColor.withOpacity(0.4),
                        blurRadius: 50.s,
                        spreadRadius: 5.s,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.celebration_rounded,
                      size: 70.s,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                // Floating elements - positioned relative to center with gentle motion
                _buildFloatingParticle(
                  icon: Icons.star_rounded,
                  color: page.accentColor,
                  size: 18.s,
                  angle: -45,
                  distance: 115.s,
                  floatOffset: floatValue * 0.8,
                ),
                _buildFloatingParticle(
                  icon: Icons.auto_awesome,
                  color: page.accentColor,
                  size: 16.s,
                  angle: 30,
                  distance: 110.s,
                  floatOffset: -floatValue * 0.6,
                ),
                _buildFloatingParticle(
                  icon: Icons.favorite_rounded,
                  color: page.accentColor,
                  size: 15.s,
                  angle: 150,
                  distance: 105.s,
                  floatOffset: floatValue * 0.5,
                ),
                _buildFloatingParticle(
                  icon: Icons.star_rounded,
                  color: page.accentColor,
                  size: 14.s,
                  angle: -130,
                  distance: 108.s,
                  floatOffset: -floatValue * 0.5,
                ),
                _buildFloatingParticle(
                  icon: Icons.auto_awesome,
                  color: page.accentColor,
                  size: 20.s,
                  angle: 90,
                  distance: 100.s,
                  floatOffset: floatValue * 0.4,
                ),
              ],
            ),
          ),
        )
        .animate(target: isCurrentPage ? 1 : 0)
        .fadeIn(duration: 800.ms)
        .scale(begin: const Offset(0.8, 0.8), duration: 800.ms, curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildFloatingParticle({
    required IconData icon,
    required Color color,
    required double size,
    required double angle,
    required double distance,
    required double floatOffset,
  }) {
    final radians = angle * (math.pi / 180);
    final x = math.cos(radians) * distance;
    final y = math.sin(radians) * distance + floatOffset;
    
    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        padding: EdgeInsets.all(10.s),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5.s,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 15.s,
                              ),
                          ],
                        ),
        child: Icon(
          icon,
          color: color,
          size: size,
        ),
      ),
    );
  }

  // Page 2: How to Play - Phone on forehead visualization
  Widget _buildHowToPlayIllustration(OnboardingPage page, bool isCurrentPage) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = 0.97 + (_pulseController.value * 0.05);
        
        return SizedBox(
          width: 300.s,
          height: 300.s,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Glow background
                Transform.scale(
                  scale: pulseValue,
                  child: Container(
                    width: 200.s,
                    height: 200.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          page.accentColor.withOpacity(0.25),
                          page.accentColor.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Head circle
                Container(
                  width: 120.s,
                  height: 120.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.06),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2.s,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 60.s,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
                
                // Phone on forehead
                Transform.translate(
                  offset: Offset(0, -75.s),
                  child: Container(
                        width: 80.s,
                        height: 50.s,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [page.accentColor, page.secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(14.s),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2.5.s,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: page.accentColor.withOpacity(0.5),
                              blurRadius: 25.s,
                              spreadRadius: 3.s,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 55.s,
                            height: 28.s,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.s),
                            ),
                            child: Center(
                              child: Text(
                                '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: page.accentColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: 0, end: -3, duration: 2500.ms, curve: Curves.easeInOut),
                ),
                
                // Speech bubbles - positioned using Transform
                Transform.translate(
                  offset: Offset(-95.s, 10.s),
                  child: _buildSpeechBubble('Movie!', page, 0),
                ),
                Transform.translate(
                  offset: Offset(95.s, 30.s),
                  child: _buildSpeechBubble('Action!', page, 200),
                ),
                Transform.translate(
                  offset: Offset(-80.s, 70.s),
                  child: _buildSpeechBubble('Actor!', page, 400),
                ),
              ],
            ),
          ),
        )
        .animate(target: isCurrentPage ? 1 : 0)
        .fadeIn(duration: 800.ms)
        .scale(begin: const Offset(0.8, 0.8), duration: 800.ms, curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildSpeechBubble(String text, OnboardingPage page, int delay) {
    return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.s),
            border: Border.all(
              color: page.accentColor.withOpacity(0.3),
              width: 1.5.s,
            ),
            boxShadow: [
              BoxShadow(
                color: page.accentColor.withOpacity(0.15),
                blurRadius: 10.s,
              ),
            ],
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fadeIn(delay: delay.ms, duration: 800.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.03, 1.03),
          duration: 2200.ms,
          curve: Curves.easeInOut,
        );
  }

  // Page 3: Controls - Tilt demonstration
  Widget _buildControlsIllustration(OnboardingPage page, bool isCurrentPage) {
    return AnimatedBuilder(
      animation: _tiltController,
      builder: (context, child) {
        // Gentler tilt for smoother feel
        final tiltAngle = math.sin(_tiltController.value * math.pi * 2) * 0.08;
        
        return SizedBox(
          width: 300.s,
          height: 300.s,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Background glow
                Container(
                  width: 180.s,
                  height: 180.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        page.accentColor.withOpacity(0.2),
                        page.accentColor.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                
                // Phone with tilt
                Transform.rotate(
                  angle: tiltAngle,
                  child: Container(
                    width: 90.s,
                    height: 145.s,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF3A3A3C),
                          const Color(0xFF1C1C1E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18.s),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 3.s,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 30.s,
                          offset: Offset(0, 12.s),
                        ),
                        BoxShadow(
                          color: page.accentColor.withOpacity(0.2),
                          blurRadius: 20.s,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.swap_vert_rounded,
                        size: 45.s,
                        color: page.accentColor,
                      ),
                    ),
                  ),
                ),
                
                // Correct indicator (top - tilt down)
                Transform.translate(
                  offset: Offset(0, -115.s),
                  child: _buildTiltIndicator(
                    icon: Icons.check_circle_rounded,
                    label: 'Correct',
                    color: page.accentColor,
                    arrowUp: false,
                  ),
                ),
                
                // Pass indicator (bottom - tilt up)
                Transform.translate(
                  offset: Offset(0, 115.s),
                  child: _buildTiltIndicator(
                    icon: Icons.cancel_rounded,
                    label: 'Pass',
                    color: const Color(0xFFFF453A),
                    arrowUp: true,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(target: isCurrentPage ? 1 : 0)
        .fadeIn(duration: 800.ms)
        .scale(begin: const Offset(0.8, 0.8), duration: 800.ms, curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildTiltIndicator({
    required IconData icon,
    required String label,
    required Color color,
    required bool arrowUp,
  }) {
    return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 10.s),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(25.s),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1.5.s,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12.s,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(6.s),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  arrowUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color,
                  size: 16.s,
                ),
              ),
              SizedBox(width: 10.s),
              Icon(icon, color: color, size: 20.s),
              SizedBox(width: 6.s),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(
          begin: arrowUp ? 2 : -2,
          end: arrowUp ? -2 : 2,
          duration: 2500.ms,
          curve: Curves.easeInOut,
        );
  }

  // Page 4: Ready - Launch/play visualization
  Widget _buildReadyIllustration(OnboardingPage page, bool isCurrentPage) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        // Gentle, premium floating motion
        final floatValue = math.sin(_floatingController.value * math.pi * 2) * 5;
        final pulseValue = 0.96 + (_pulseController.value * 0.08);
        
        return SizedBox(
          width: 300.s,
          height: 300.s,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Outer ring pulse
                Transform.scale(
                  scale: pulseValue,
                  child: Container(
                    width: 220.s,
                    height: 220.s,
      decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: page.accentColor.withOpacity(0.25),
                        width: 2.s,
                      ),
                    ),
                  ),
                ),
                
                // Middle glow ring
                Container(
                  width: 180.s,
                  height: 180.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        page.accentColor.withOpacity(0.2),
                        page.accentColor.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                
                // Main play button
                Transform.translate(
                  offset: Offset(0, floatValue),
                  child: Container(
                    width: 130.s,
                    height: 130.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [page.accentColor, page.secondaryColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.accentColor.withOpacity(0.5),
                          blurRadius: 45.s,
                          spreadRadius: 8.s,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 65.s,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                // Floating category icons using Transform
                ..._buildCategoryIcons(page, floatValue),
              ],
            ),
          ),
        )
        .animate(target: isCurrentPage ? 1 : 0)
        .fadeIn(duration: 800.ms)
        .scale(begin: const Offset(0.8, 0.8), duration: 800.ms, curve: Curves.easeOutBack);
      },
    );
  }

  List<Widget> _buildCategoryIcons(OnboardingPage page, double floatValue) {
    final icons = [
      Icons.movie_rounded,
      Icons.music_note_rounded,
      Icons.sports_basketball_rounded,
      Icons.public_rounded,
      Icons.psychology_rounded,
    ];
    
    // Position icons in a circle around the center using angles
    final angles = [-60.0, 20.0, 160.0, -140.0, 90.0];
    final distances = [105.s, 100.s, 100.s, 105.s, 95.s];
    // Gentler float multipliers for smoother motion
    final floatMultipliers = [0.6, -0.5, 0.4, -0.5, 0.3];
    
    return List.generate(icons.length, (i) {
      final radians = angles[i] * (math.pi / 180);
      final x = math.cos(radians) * distances[i];
      final y = math.sin(radians) * distances[i] + (floatValue * floatMultipliers[i]);
      
      return Transform.translate(
        offset: Offset(x, y),
          child: Container(
              padding: EdgeInsets.all(12.s),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: page.accentColor.withOpacity(0.4),
                  width: 1.5.s,
                ),
                boxShadow: [
                  BoxShadow(
                    color: page.accentColor.withOpacity(0.25),
                    blurRadius: 15.s,
                  ),
                ],
              ),
              child: Icon(
                icons[i],
                color: Colors.white.withOpacity(0.85),
                size: 20.s,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              begin: const Offset(0.96, 0.96),
              end: const Offset(1.04, 1.04),
              duration: Duration(milliseconds: 2800 + (i * 200)),
              curve: Curves.easeInOut,
            ),
      );
    });
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.s, 0, 24.s, 32.s),
      child: _currentPage < _pages.length - 1
          ? _buildNavigationRow()
          : _buildGetStartedButton(),
    );
  }

  Widget _buildNavigationRow() {
    return Row(
      children: [
        if (_currentPage > 0)
          Expanded(child: _buildBackButton())
        else
          const Expanded(child: SizedBox()),
        SizedBox(width: 16.s),
        Expanded(flex: 2, child: _buildContinueButton()),
        if (_currentPage == 0) ...[
          SizedBox(width: 16.s),
          const Expanded(child: SizedBox()),
        ],
      ],
    );
  }

  Widget _buildBackButton() {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
              );
              _hapticService.lightImpact();
            },
            borderRadius: BorderRadius.circular(18.s),
            child: Container(
              height: 58.s,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18.s),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5.s,
                ),
              ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                    color: Colors.white.withOpacity(0.6),
                    size: 20.s,
                ),
                  SizedBox(width: 8.s),
                Text(
                  'Back',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.2, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildContinueButton() {
    final page = _pages[_currentPage];
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
              );
              _hapticService.lightImpact();
            },
            borderRadius: BorderRadius.circular(18.s),
          child: Container(
              height: 58.s,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [page.accentColor, page.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(18.s),
              boxShadow: [
                BoxShadow(
                    color: page.accentColor.withOpacity(0.4),
                    blurRadius: 24.s,
                  offset: Offset(0, 8.s),
                    spreadRadius: -4.s,
                ),
              ],
            ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(
                        'Continue',
                    style: GoogleFonts.inter(
                          color: Colors.white,
                      fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                  SizedBox(width: 10.s),
                      Container(
                    padding: EdgeInsets.all(6.s),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                    child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                      size: 16.s,
                        ),
                      ),
                    ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildGetStartedButton() {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _completeOnboarding();
              _hapticService.mediumImpact();
            },
            borderRadius: BorderRadius.circular(22.s),
          child: Container(
            width: double.infinity,
              height: 68.s,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                borderRadius: BorderRadius.circular(22.s),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.4),
                    blurRadius: 30.s,
                  offset: Offset(0, 12.s),
                  spreadRadius: -4.s,
                ),
              ],
            ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 32.s,
                      ),
                      SizedBox(width: 10.s),
                      Text(
                          'Let\'s Play!',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                    right: 20.s,
                      child: Container(
                          padding: EdgeInsets.all(12.s),
                            decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                          child: Icon(
                              Icons.arrow_forward_rounded,
                            color: Colors.black,
                            size: 20.s,
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 3000.ms, color: Colors.white.withOpacity(0.25)),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 700.ms, delay: 200.ms)
        .slideY(begin: 0.4, duration: 700.ms, curve: Curves.easeOutBack)
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: 700.ms,
          curve: Curves.easeOutBack,
        )
        .then()
        .shimmer(delay: 2000.ms, duration: 2500.ms, color: Colors.white.withOpacity(0.12));
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final Color accentColor;
  final Color secondaryColor;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.accentColor,
    required this.secondaryColor,
  });
}
