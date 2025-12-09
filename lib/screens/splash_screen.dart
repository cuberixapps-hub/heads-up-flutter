import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/responsive.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  
  // Elegant blue color palette
  static const Color _primaryBlue = Color(0xFF1E88E5);
  static const Color _softBlue = Color(0xFF42A5F5);
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    // Single slow breathing animation - elegant and subtle
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _startSplashSequence() {
    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        final useV2 = prefs.getBool('use_home_v2') ?? false;
        
        final homeRoute = useV2 ? '/home-v2' : '/home';
        final destination = hasSeenOnboarding ? homeRoute : '/onboarding';

        if (mounted) {
          context.go(destination);
        }
      } catch (e) {
        debugPrint('❌ Navigation error: $e');
        if (mounted) context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
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
          // Elegant gradient background
          _buildElegantBackground(),
          
          // Subtle ambient glow
          _buildAmbientGlow(),
          
          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Hero logo section
                  _buildHeroLogo(),
                  
                  SizedBox(height: 48.s),
                  
                  // App name
                  _buildAppName(),
                  
                  SizedBox(height: 12.s),
                  
                  // Tagline
                  _buildTagline(),
                  
                  const Spacer(flex: 3),
                  
                  // Minimal loading indicator
                  _buildMinimalLoader(),
                  
                  SizedBox(height: 60.s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantBackground() {
    return Container(
      decoration: const BoxDecoration(
        // Simple, elegant dark gradient
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D1B2A), // Dark navy
            Color(0xFF070D15), // Darker
            Color(0xFF000000), // Black
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        // Subtle breathing opacity
        final glowOpacity = 0.12 + (_glowController.value * 0.08);
        
        return Center(
          child: Container(
            width: 350.s,
            height: 350.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _primaryBlue.withOpacity(glowOpacity),
                  _primaryBlue.withOpacity(glowOpacity * 0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroLogo() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = 0.4 + (_glowController.value * 0.3);
        
        return Container(
              width: 160.s,
              height: 160.s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36.s),
                boxShadow: [
                  // Soft outer glow
                  BoxShadow(
                    color: _primaryBlue.withOpacity(glowIntensity * 0.5),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36.s),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 800.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 1000.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildAppName() {
    return Text(
          'Heads Up!',
          style: GoogleFonts.poppins(
            fontSize: 48.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -1.5,
          ),
        )
        .animate()
        .fadeIn(delay: 400.ms, duration: 800.ms)
        .slideY(
          begin: 0.15,
          end: 0,
          delay: 400.ms,
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildTagline() {
    return Text(
          'The Ultimate Party Game',
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: _softBlue.withOpacity(0.9),
            letterSpacing: 2,
          ),
        )
        .animate()
        .fadeIn(delay: 700.ms, duration: 800.ms);
  }

  Widget _buildMinimalLoader() {
    return SizedBox(
          width: 100.s,
          height: 2.s,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                _softBlue.withOpacity(0.7),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 600.ms);
  }
}
