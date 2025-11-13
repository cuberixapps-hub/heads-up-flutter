import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../models/deck.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

class DeckDetailsScreen extends StatefulWidget {
  final Deck deck;
  final String heroTag;
  final VoidCallback onPlay;

  const DeckDetailsScreen({
    super.key,
    required this.deck,
    required this.heroTag,
    required this.onPlay,
  });

  @override
  State<DeckDetailsScreen> createState() => _DeckDetailsScreenState();
}

class _DeckDetailsScreenState extends State<DeckDetailsScreen> {
  double _dragOffsetY = 0;
  double _dragOffsetX = 0;
  double _dragScale = 1.0;
  double _borderRadius = 0;
  bool _isDragging = false;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  Offset? _initialPosition;
  double _accumulatedDrag = 0;
  bool _hasScrolledDown = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _initialPosition = event.position;
    _accumulatedDrag = 0;
    _isScrolling = false;

    // Track if we've scrolled down in the content
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _hasScrolledDown = true;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_initialPosition == null) return;

    _accumulatedDrag += event.delta.dy;

    // Get current scroll state
    final isAtTop =
        _scrollController.hasClients ? _scrollController.offset <= 0 : true;
    final isDraggingDown = event.delta.dy > 0;

    // If already dismissing, continue
    if (_isDragging) {
      setState(() {
        _dragOffsetY += event.delta.dy;
        _dragOffsetX += event.delta.dx;
        _dragOffsetY = _dragOffsetY.clamp(0, double.infinity);

        final scaleReduction = (_dragOffsetY / 400).clamp(0.0, 0.30);
        _dragScale = 1.0 - scaleReduction;
        _borderRadius = (_dragOffsetY / 200 * 24).clamp(0.0, 24.0);
      });
      return;
    }

    // If we've scrolled down before, don't dismiss on upward scroll
    if (_hasScrolledDown && !isAtTop) {
      // Let the scroll view handle it
      _isScrolling = true;
      return;
    }

    // Only start dismiss if:
    // 1. We're at the top AND dragging down significantly
    // 2. OR we haven't scrolled and made a large downward gesture
    if (isAtTop && isDraggingDown && _accumulatedDrag > 10) {
      // We're at top and dragging down - start dismiss
      setState(() {
        _isDragging = true;
      });
    } else if (!_hasScrolledDown && _accumulatedDrag > 30 && !_isScrolling) {
      // Large downward drag from initial position - start dismiss
      setState(() {
        _isDragging = true;
      });
    } else if (_accumulatedDrag < -5) {
      // Scrolling up - mark as scrolling
      _isScrolling = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_dragOffsetY > 120) {
      // Dismiss if dragged down more than 120px
      HapticService().lightImpact();
      Navigator.of(context).pop();
    } else {
      // Snap back with animation
      setState(() {
        _isDragging = false;
        _dragOffsetY = 0;
        _dragOffsetX = 0;
        _dragScale = 1.0;
        _borderRadius = 0;
      });
    }

    // Reset state
    _initialPosition = null;
    _isScrolling = false;

    // Reset scroll tracking when at top
    if (_scrollController.hasClients && _scrollController.offset <= 0) {
      _hasScrolledDown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hapticService = HapticService();
    final size = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      child: Transform(
        transform:
            Matrix4.identity()
              ..translate(_dragOffsetX, _dragOffsetY, 0.0)
              ..scale(_dragScale, _dragScale, 1.0),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration:
              _isDragging ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            extendBodyBehindAppBar: true,
            body: Stack(
              children: [
                // Background gradient effect
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.0,
                        colors: [
                          widget.deck.color.withOpacity(0.3),
                          widget.deck.color.withOpacity(0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Custom app bar with blur effect
                      ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                // Back button - minimalist design
                                GestureDetector(
                                      onTap: () {
                                        hapticService.lightImpact();
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.05,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_back_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 400.ms)
                                    .scale(
                                      begin: const Offset(0.8, 0.8),
                                      end: const Offset(1, 1),
                                      duration: 400.ms,
                                      curve: Curves.easeOutBack,
                                    ),

                                const Spacer(),

                                // More options button
                                GestureDetector(
                                      onTap: () {
                                        hapticService.lightImpact();
                                        _showOptionsSheet(context);
                                      },
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.05,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.more_horiz_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 400.ms, delay: 50.ms)
                                    .scale(
                                      begin: const Offset(0.8, 0.8),
                                      end: const Offset(1, 1),
                                      duration: 400.ms,
                                      delay: 50.ms,
                                      curve: Curves.easeOutBack,
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics:
                              _isDragging
                                  ? const NeverScrollableScrollPhysics()
                                  : const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                          child: Column(
                            children: [
                              const SizedBox(height: 30),

                              // Hero card with deck image
                              Center(
                                child: Hero(
                                  tag: widget.heroTag,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      width:
                                          210, // Larger but same aspect ratio (0.75)
                                      height:
                                          280, // Maintains 3:4 ratio like home screen
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.deck.color
                                                .withOpacity(0.3),
                                            blurRadius: 40,
                                            spreadRadius: -5,
                                            offset: const Offset(0, 20),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Background image or gradient
                                            if (widget.deck.imageUrl != null &&
                                                widget
                                                    .deck
                                                    .imageUrl!
                                                    .isNotEmpty)
                                              Image.network(
                                                widget.deck.imageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end:
                                                            Alignment
                                                                .bottomRight,
                                                        colors: [
                                                          widget.deck.color,
                                                          widget.deck.color
                                                              .withOpacity(0.7),
                                                        ],
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        widget.deck.icon,
                                                        color: Colors.white,
                                                        size: 100,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            else
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      widget.deck.color,
                                                      widget.deck.color
                                                          .withOpacity(0.7),
                                                    ],
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    widget.deck.icon,
                                                    color: Colors.white,
                                                    size: 100,
                                                  ),
                                                ),
                                              ),

                                            // Subtle overlay gradient for depth
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(
                                                      0.2,
                                                    ),
                                                  ],
                                                  stops: const [0.7, 1.0],
                                                ),
                                              ),
                                            ),

                                            // Play button overlay (subtle)
                                            if (widget.deck.imageUrl != null &&
                                                widget
                                                    .deck
                                                    .imageUrl!
                                                    .isNotEmpty)
                                              Center(
                                                child: Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.4),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: 50,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Title and description
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                ),
                                child: Column(
                                  children: [
                                    // Deck name with elegant typography
                                    Text(
                                          widget.deck.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 32.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        )
                                        .animate()
                                        .fadeIn(delay: 200.ms, duration: 500.ms)
                                        .slideY(
                                          begin: 0.2,
                                          end: 0,
                                          delay: 200.ms,
                                          duration: 500.ms,
                                          curve: Curves.easeOutCubic,
                                        ),

                                    SizedBox(height: 12.s),

                                    // Description with subtle styling
                                    Text(
                                      widget.deck.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.7),
                                        height: 1.6,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ).animate().fadeIn(
                                      delay: 300.ms,
                                      duration: 500.ms,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Modern stats grid
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernStatCard(
                                        icon: Icons.style_rounded,
                                        value: '${widget.deck.cards.length}',
                                        label: 'Cards',
                                        color: widget.deck.color,
                                        index: 0,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildModernStatCard(
                                        icon: Icons.timer_rounded,
                                        value: '60s',
                                        label: 'Timer',
                                        color: widget.deck.color,
                                        index: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildModernStatCard(
                                        icon: Icons.group_rounded,
                                        value: '2-10',
                                        label: 'Players',
                                        color: widget.deck.color,
                                        index: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Features section with elegant cards
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Game Features',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ).animate().fadeIn(
                                      delay: 500.ms,
                                      duration: 500.ms,
                                    ),

                                    SizedBox(height: 16.s),

                                    _buildFeatureCard(
                                      icon: Icons.celebration_rounded,
                                      title: 'Party Mode',
                                      description:
                                          'Perfect for groups and celebrations',
                                      index: 0,
                                    ),
                                    _buildFeatureCard(
                                      icon: Icons.speed_rounded,
                                      title: 'Fast Gameplay',
                                      description:
                                          'Quick rounds keep everyone engaged',
                                      index: 1,
                                    ),
                                    _buildFeatureCard(
                                      icon: Icons.emoji_events_rounded,
                                      title: 'Score Tracking',
                                      description:
                                          'Compete and track your progress',
                                      index: 2,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating bottom action area with blur
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.0),
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Primary Play button with gradient
                              GestureDetector(
                                    onTap: () {
                                      HapticService().mediumImpact();
                                      Navigator.pop(context);
                                      widget.onPlay();
                                    },
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            widget.deck.color,
                                            widget.deck.color.withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.deck.color
                                                .withOpacity(0.4),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Start Game',
                                            style: GoogleFonts.poppins(
                                              fontSize: 17.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 700.ms, duration: 400.ms)
                                  .slideY(
                                    begin: 0.3,
                                    end: 0,
                                    delay: 700.ms,
                                    duration: 400.ms,
                                    curve: Curves.easeOutCubic,
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
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Colors.white),
                  title: Text(
                    'Share Deck',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    HapticService().lightImpact();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    'Add to Favorites',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    HapticService().lightImpact();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required int index,
  }) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (400 + index * 100).ms, duration: 500.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          delay: (400 + index * 100).ms,
          duration: 500.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required int index,
  }) {
    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.deck.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: widget.deck.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (600 + index * 100).ms, duration: 500.ms)
        .slideX(
          begin: -0.1,
          end: 0,
          delay: (600 + index * 100).ms,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
