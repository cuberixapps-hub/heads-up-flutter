import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:ui';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController mainController;
  late AnimationController particleController;
  late AnimationController geometryController;
  late AnimationController waveController;

  final List<Particle> particles = [];
  final int particleCount = 50;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    geometryController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Start main animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) mainController.forward();
    });
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < particleCount; i++) {
      particles.add(
        Particle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 3 + 1,
          speedX: (random.nextDouble() - 0.5) * 0.002,
          speedY: (random.nextDouble() - 0.5) * 0.002,
          opacity: random.nextDouble() * 0.5 + 0.3,
        ),
      );
    }
  }

  void _startSplashSequence() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        final destination = hasSeenOnboarding ? '/home' : '/onboarding';

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
    mainController.dispose();
    particleController.dispose();
    geometryController.dispose();
    waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? const Color(0xFF0A0E27) : const Color(0xFFF5F7FA);
    final accentColor =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF5B67CA);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Particle System
          AnimatedBuilder(
            animation: particleController,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: ParticlePainter(
                  particles: particles,
                  progress: particleController.value,
                  color: accentColor.withOpacity(0.3),
                ),
              );
            },
          ),

          // Geometric Background Pattern
          _buildGeometricPattern(screenSize, accentColor),

          // Wave Animation
          _buildWaveAnimation(screenSize, accentColor),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with Modern Animation
                _buildModernLogo(accentColor),

                const SizedBox(height: 50),

                // App Title with Typewriter Effect
                _buildModernTitle(isDarkMode),

                const SizedBox(height: 20),

                // Tagline with Slide Animation
                _buildModernTagline(isDarkMode),

                const SizedBox(height: 80),

                // Modern Loading Animation
                _buildModernLoadingIndicator(accentColor),
              ],
            ),
          ),

          // Floating Geometric Shapes
          _buildFloatingShapes(screenSize, accentColor),
        ],
      ),
    );
  }

  Widget _buildGeometricPattern(Size screenSize, Color accentColor) {
    return AnimatedBuilder(
      animation: geometryController,
      builder: (context, child) {
        return CustomPaint(
          size: screenSize,
          painter: GeometricPatternPainter(
            progress: geometryController.value,
            color: accentColor.withOpacity(0.05),
          ),
        );
      },
    );
  }

  Widget _buildWaveAnimation(Size screenSize, Color accentColor) {
    return Positioned(
      bottom: 0,
      child: AnimatedBuilder(
        animation: waveController,
        builder: (context, child) {
          return ClipPath(
            clipper: WaveClipper(progress: waveController.value),
            child: Container(
              width: screenSize.width,
              height: screenSize.height * 0.3,
              decoration: BoxDecoration(color: accentColor.withOpacity(0.03)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernLogo(Color accentColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating Hexagon Background
        AnimatedBuilder(
          animation: geometryController,
          builder: (context, child) {
            return Transform.rotate(
              angle: geometryController.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(140, 140),
                painter: HexagonPainter(
                  color: accentColor.withOpacity(0.1),
                  strokeColor: accentColor.withOpacity(0.3),
                ),
              ),
            );
          },
        ),

        // Logo Container
        Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.videogame_asset_rounded,
                size: 50,
                color: accentColor,
              ),
            )
            .animate(controller: mainController)
            .scale(
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              duration: 1200.ms,
              curve: Curves.elasticOut,
            )
            .rotate(
              begin: -0.5,
              end: 0,
              duration: 1200.ms,
              curve: Curves.easeOutBack,
            ),
      ],
    );
  }

  Widget _buildModernTitle(bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          'Heads Up!'.split('').asMap().entries.map((entry) {
            final index = entry.key;
            final letter = entry.value;

            return Text(
                  letter,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 2,
                  ),
                )
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 800 + (index * 100)),
                  duration: 600.ms,
                )
                .slideY(
                  begin: -0.5,
                  end: 0,
                  delay: Duration(milliseconds: 800 + (index * 100)),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                )
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  delay: Duration(milliseconds: 800 + (index * 100)),
                  duration: 600.ms,
                );
          }).toList(),
    );
  }

  Widget _buildModernTagline(bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white70 : const Color(0xFF5A6C8C);

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: textColor.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            'The Ultimate Party Game',
            style: TextStyle(
              fontSize: 16,
              color: textColor,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w300,
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 1600.ms, duration: 800.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          delay: 1600.ms,
          duration: 800.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildModernLoadingIndicator(Color accentColor) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (index) {
          final size = 20.0 + (index * 15.0);
          final delay = index * 200;

          return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withOpacity(0.3 - (index * 0.1)),
                    width: 2,
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
                duration: 1500.ms,
                delay: Duration(milliseconds: delay),
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                begin: const Offset(1.2, 1.2),
                end: const Offset(0.8, 0.8),
                duration: 1500.ms,
                curve: Curves.easeInOut,
              );
        }),
      ),
    ).animate().fadeIn(delay: 2000.ms, duration: 600.ms);
  }

  Widget _buildFloatingShapes(Size screenSize, Color accentColor) {
    return Stack(
      children: List.generate(6, (index) {
        final isLeft = index % 2 == 0;
        final size = 60.0 + (index * 20.0);
        final duration = Duration(seconds: 10 + (index * 2));
        final delay = Duration(milliseconds: index * 500);

        return Positioned(
          left: isLeft ? -size : null,
          right: isLeft ? null : -size,
          top: screenSize.height * (0.1 + (index * 0.15)),
          child: Transform.rotate(
                angle: index * 0.5,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: accentColor.withOpacity(0.1),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(
                      index % 2 == 0 ? 12 : size / 2,
                    ),
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .slideX(
                begin: isLeft ? 0 : 1,
                end: isLeft ? 1 : 0,
                duration: duration,
                curve: Curves.linear,
                delay: delay,
              )
              .rotate(
                begin: 0,
                end: isLeft ? 1 : -1,
                duration: duration,
                curve: Curves.linear,
                delay: delay,
              ),
        );
      }),
    );
  }
}

// Particle class
class Particle {
  double x;
  double y;
  final double size;
  final double speedX;
  final double speedY;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
  });

  void update() {
    x += speedX;
    y += speedY;

    if (x < 0) x = 1;
    if (x > 1) x = 0;
    if (y < 0) y = 1;
    if (y > 1) y = 0;
  }
}

// Particle Painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final Color color;

  ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    for (var particle in particles) {
      particle.update();

      final x = particle.x * size.width;
      final y = particle.y * size.height;

      paint.color = color.withOpacity(particle.opacity);
      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Geometric Pattern Painter
class GeometricPatternPainter extends CustomPainter {
  final double progress;
  final Color color;

  GeometricPatternPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final gridSize = 50.0;
    final offset = progress * gridSize;

    for (double x = -gridSize; x < size.width + gridSize; x += gridSize) {
      for (double y = -gridSize; y < size.height + gridSize; y += gridSize) {
        final adjustedX = x + offset;
        final adjustedY = y + offset;

        // Draw diamond shapes
        final path =
            Path()
              ..moveTo(adjustedX, adjustedY - gridSize / 4)
              ..lineTo(adjustedX + gridSize / 4, adjustedY)
              ..lineTo(adjustedX, adjustedY + gridSize / 4)
              ..lineTo(adjustedX - gridSize / 4, adjustedY)
              ..close();

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Hexagon Painter
class HexagonPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;

  HexagonPainter({required this.color, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final fillPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final strokePaint =
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Wave Clipper
class WaveClipper extends CustomClipper<Path> {
  final double progress;

  WaveClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.7 +
          math.sin((x / size.width * 2 * math.pi) + (progress * 2 * math.pi)) *
              size.height *
              0.1;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
