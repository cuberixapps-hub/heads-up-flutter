import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// Tutorial step model
class TutorialStep {
  final String title;
  final String description;
  final GlobalKey targetKey;

  TutorialStep({
    required this.title,
    required this.description,
    required this.targetKey,
  });
}

// Tutorial overlay widget
class TutorialOverlay extends StatelessWidget {
  final List<TutorialStep> tutorialSteps;
  final int currentStep;
  final VoidCallback onNextStep;
  final VoidCallback onSkipTutorial;

  const TutorialOverlay({
    super.key,
    required this.tutorialSteps,
    required this.currentStep,
    required this.onNextStep,
    required this.onSkipTutorial,
  });

  @override
  Widget build(BuildContext context) {
    if (currentStep >= tutorialSteps.length) {
      return const SizedBox();
    }

    final step = tutorialSteps[currentStep];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Advance to next step on tap
        onNextStep();
      },
      child: Stack(
        children: [
          // Dark overlay with cutout
          CustomPaint(
            size: Size.infinite,
            painter: SpotlightPainter(
              targetKey: step.targetKey,
              backgroundColor: Colors.black.withOpacity(0.8),
            ),
          ),

          // Tutorial content
          Positioned(
                left: 0,
                right: 0,
                bottom: 100,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Step indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            tutorialSteps.length,
                            (index) => Container(
                              width: index == currentStep ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color:
                                    index == currentStep
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          step.title,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          step.description,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          children: [
                            // Skip button
                            TextButton(
                              onPressed: onSkipTutorial,
                              child: Text(
                                'Skip Tutorial',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Next/Done button
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: onNextStep,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    currentStep == tutorialSteps.length - 1
                                        ? 'Done'
                                        : 'Next',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }
}

// Custom painter for spotlight effect
class SpotlightPainter extends CustomPainter {
  final GlobalKey targetKey;
  final Color backgroundColor;

  SpotlightPainter({required this.targetKey, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;

    // Draw background
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Try to find the target widget's position and size
    final renderObject = targetKey.currentContext?.findRenderObject();
    if (renderObject != null && renderObject is RenderBox) {
      final targetSize = renderObject.size;
      final targetPosition = renderObject.localToGlobal(Offset.zero);

      // Create a rounded rectangle cutout with padding
      const padding = 12.0;
      final cutoutRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          targetPosition.dx - padding,
          targetPosition.dy - padding,
          targetSize.width + padding * 2,
          targetSize.height + padding * 2,
        ),
        const Radius.circular(20),
      );

      // Subtract the cutout from the path
      path.addRRect(cutoutRect);
      path.fillType = PathFillType.evenOdd;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetKey != targetKey ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
