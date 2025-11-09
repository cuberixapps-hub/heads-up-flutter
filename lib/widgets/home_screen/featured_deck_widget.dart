import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck.dart';
import '../../services/haptic_service.dart';

class FeaturedDeckWidget extends StatelessWidget {
  final List<Deck> availableDecks;
  final int currentFeaturedIndex;
  final Function(int direction) onNavigateToDeck;
  final Function(Deck deck) onPlayDeck;
  final void Function(Deck deck, {required String heroTag}) onShowDeckDetails;
  final GlobalKey? tutorialKey;
  final HapticService hapticService;

  const FeaturedDeckWidget({
    super.key,
    required this.availableDecks,
    required this.currentFeaturedIndex,
    required this.onNavigateToDeck,
    required this.onPlayDeck,
    required this.onShowDeckDetails,
    this.tutorialKey,
    required this.hapticService,
  });

  @override
  Widget build(BuildContext context) {
    if (availableDecks.isEmpty) {
      return const SizedBox();
    }

    // Get current featured deck based on index
    final featuredDeck =
        availableDecks[currentFeaturedIndex % availableDecks.length];

    // Use test image URL or fallback to gradient
    const testImageUrl =
        'https://resizing.flixster.com/ZUhHpJCOJmPu7ro7DxecAetusnE=/ems.cHJkLWVtcy1hc3NldHMvdHZzZXJpZXMvNmI5OGY3ZWMtYjY1Mi00NGEwLTgxYmEtNjUyNjRmNGE2MDQ5LmpwZw==';
    final imageUrl = featuredDeck.imageUrl ?? testImageUrl;

    return Container(
      key: tutorialKey,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 500) {
              // Swipe right - go to previous deck
              hapticService.lightImpact();
              onNavigateToDeck(-1);
            } else if (details.primaryVelocity! < -500) {
              // Swipe left - go to next deck
              hapticService.lightImpact();
              onNavigateToDeck(1);
            }
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 650),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (
            Widget? currentChild,
            List<Widget> previousChildren,
          ) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            // Smooth entrance with refined curves
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
              ),
            );

            // Elegant scale with subtle spring effect
            final scaleAnimation = Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.85, curve: Curves.easeOutBack),
              ),
            );

            // Smooth horizontal slide
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: ScaleTransition(scale: scaleAnimation, child: child),
              ),
            );
          },
          child: Container(
            key: ValueKey(featuredDeck.id),
            height: 580,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 52.5,
                  offset: const Offset(19.5, 16.5),
                  spreadRadius: 1.88,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image or gradient with gentle zoom animation
                  if (imageUrl.isNotEmpty)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('zoom_${featuredDeck.id}'),
                      tween: Tween<double>(begin: 1.0, end: 1.08),
                      duration: const Duration(seconds: 12),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      featuredDeck.color,
                                      featuredDeck.color.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  else
                    TweenAnimationBuilder<double>(
                      key: ValueKey('zoom_gradient_${featuredDeck.id}'),
                      tween: Tween<double>(begin: 1.0, end: 1.08),
                      duration: const Duration(seconds: 12),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  featuredDeck.color,
                                  featuredDeck.color.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Gradient overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.0, 0.15, 0.4, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Inner glass border effect
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 0.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.white.withOpacity(0.02),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Game info badges
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Row(
                      children: [
                        // Player count badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '2-10',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Time badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '60s',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Difficulty badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Easy',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Deck name
                          Text(
                            featuredDeck.name,
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.05,
                              letterSpacing: -1,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Tags row
                          Row(
                            children: [
                              Text(
                                'Fun',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Text(
                                'Exciting',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Text(
                                'Party Game',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Action buttons with elegant styling
                          Row(
                            children: [
                              // Play button - Premium Netflix style
                              Expanded(
                                child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ),
                                      elevation: 0,
                                      child: InkWell(
                                        onTap: () {
                                          hapticService.lightImpact();
                                          onPlayDeck(featuredDeck);
                                        },
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                        splashColor: Colors.grey.shade200,
                                        highlightColor:
                                            Colors.grey.shade100,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.play_arrow_rounded,
                                                size: 28,
                                                color: Colors.black,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Play',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 17,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: Colors.black,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(
                                      delay: 650.ms,
                                      duration: 500.ms,
                                      curve: Curves.easeOut,
                                    )
                                    .slideY(
                                      begin: 0.15,
                                      end: 0,
                                      delay: 650.ms,
                                      duration: 500.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1, 1),
                                      delay: 650.ms,
                                      duration: 500.ms,
                                      curve: Curves.easeOutBack,
                                    ),
                              ),

                              const SizedBox(width: 10),

                              // Info button - Elegant glass morphism
                              Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(
                                          0.25,
                                        ),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            0.2,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          hapticService.lightImpact();
                                          final heroTag =
                                              'deck_featured_${featuredDeck.id}_${DateTime.now().millisecondsSinceEpoch}';
                                          onShowDeckDetails(
                                            featuredDeck,
                                            heroTag: heroTag,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                        splashColor: Colors.white
                                            .withOpacity(0.1),
                                        highlightColor: Colors.white
                                            .withOpacity(0.05),
                                        child: const Center(
                                          child: Icon(
                                            Icons.info_outline_rounded,
                                            size: 26,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: 750.ms,
                                    duration: 500.ms,
                                    curve: Curves.easeOut,
                                  )
                                  .slideY(
                                    begin: 0.15,
                                    end: 0,
                                    delay: 750.ms,
                                    duration: 500.ms,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .scale(
                                    begin: const Offset(0.95, 0.95),
                                    end: const Offset(1, 1),
                                    delay: 750.ms,
                                    duration: 500.ms,
                                    curve: Curves.easeOutBack,
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
