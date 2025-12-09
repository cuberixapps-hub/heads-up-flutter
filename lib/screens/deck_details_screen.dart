import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/share_service.dart';
import '../utils/responsive.dart';
import 'paywall_screen.dart';
import 'gameplay_screen.dart';

/// Screen to display deck details when opened from deep link (by ID)
class DeckDetailsScreen extends StatefulWidget {
  final String? deckId;
  final Deck? deck;
  final String? heroTag;
  final VoidCallback? onPlay;

  const DeckDetailsScreen({
    super.key,
    this.deckId,
    this.deck,
    this.heroTag,
    this.onPlay,
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
  
  // Difficulty selection
  DeckDifficulty _selectedDifficulty = DeckDifficulty.mixed;
  
  // Timer selection (in seconds, 0 = unlimited)
  int _selectedTimer = 60;
  
  // Available timer options
  static const List<int> _timerOptions = [30, 45, 60, 90, 120, 0]; // 0 = unlimited
  
  // Deck loaded from ID (for deep link support)
  Deck? _loadedDeck;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Share service
  final _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }
  
  /// Load deck - either from widget.deck or fetch by ID
  Future<void> _loadDeck() async {
    if (widget.deck != null) {
      // Deck provided directly
      setState(() {
        _loadedDeck = widget.deck;
        _isLoading = false;
      });
      return;
    }
    
    // Try to fetch by ID (for deep link case)
    if (widget.deckId != null && widget.deckId!.isNotEmpty) {
      try {
        final deckProvider = Provider.of<DeckProvider>(context, listen: false);
        
        // If decks aren't loaded yet, wait and retry
        if (deckProvider.allDecks.isEmpty && !deckProvider.isLoading) {
          await deckProvider.refreshData();
        }
        
        // Try to find deck by ID or name hash
        final deck = deckProvider.allDecks.firstWhere(
          (d) => d.id == widget.deckId || d.name.hashCode.toString() == widget.deckId,
          orElse: () => throw Exception('Deck not found'),
        );
        
        setState(() {
          _loadedDeck = deck;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Could not find this deck. It may have been removed.';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Invalid deck link';
        _isLoading = false;
      });
    }
  }
  
  /// Get the active deck (from widget or loaded)
  Deck get _deck => _loadedDeck ?? widget.deck!;
  
  /// Get card count based on selected difficulty
  int _getSelectedCardCount() {
    return _deck.getCardCountByDifficulty(_selectedDifficulty);
  }
  
  /// Get icon for selected difficulty
  IconData _getDifficultyIcon() {
    switch (_selectedDifficulty) {
      case DeckDifficulty.easy:
        return Icons.sentiment_satisfied_rounded;
      case DeckDifficulty.medium:
        return Icons.speed_rounded;
      case DeckDifficulty.hard:
        return Icons.local_fire_department_rounded;
      case DeckDifficulty.mixed:
        return Icons.shuffle_rounded;
    }
  }
  
  /// Get label for selected difficulty
  String _getDifficultyLabel() {
    switch (_selectedDifficulty) {
      case DeckDifficulty.easy:
        return 'Easy';
      case DeckDifficulty.medium:
        return 'Med';
      case DeckDifficulty.hard:
        return 'Hard';
      case DeckDifficulty.mixed:
        return 'All';
    }
  }
  
  void _handlePlayTap() {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final hasPremium = deckProvider.unlockedDecks.any((d) => d.isPremium);
    
    // Show paywall for non-premium users
    if (!hasPremium) {
      _showPaywall();
      return;
    }
    
    // User has premium - start game directly with selected difficulty
    _startGameWithDifficulty();
  }
  
  void _startGameWithDifficulty() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Start game with selected difficulty and timer
    gameProvider.startGame(
      deck: _deck,
      difficulty: _selectedDifficulty,
      customDuration: _selectedTimer, // 0 = unlimited
    );
    
    // Navigate to gameplay screen
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameplayScreen(
          deck: _deck,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
  
  void _showPaywall() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PaywallScreen(
          selectedDeck: _deck,
          onWatchAd: () {
            Navigator.pop(context); // Pop paywall
            // Start game with selected difficulty
            _startGameWithDifficulty();
          },
          onPurchasePremium: () {
            Navigator.pop(context);
            // Show premium purchase coming soon
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Colors.black),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Premium purchase coming soon! Watch an ad to play.',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFFFD700),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 3),
              ),
            );
          },
          onClose: () {
            Navigator.pop(context);
          },
        ),
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeInOutCubic;
          
          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: curve)).animate(animation);
          
          final scaleAnimation = Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
      ),
    );
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

  /// Share this deck
  void _shareDeck() {
    _shareService.shareDeck(_deck, context);
  }
  
  /// Build the hero card widget
  Widget _buildHeroCard() {
    final cardContent = Material(
      color: Colors.transparent,
      child: Container(
        width: 210,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _deck.color.withOpacity(0.3),
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
              if (_deck.imageUrl != null && _deck.imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: _deck.imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 210,
                  memCacheHeight: 280,
                  maxWidthDiskCache: 600,
                  maxHeightDiskCache: 800,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _deck.color,
                          _deck.color.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white.withOpacity(0.5),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  fadeInDuration: const Duration(milliseconds: 300),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _deck.color,
                          _deck.color.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _deck.icon,
                        color: Colors.white,
                        size: 100,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _deck.color,
                        _deck.color.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _deck.icon,
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
                      Colors.black.withOpacity(0.2),
                    ],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
              // Play button overlay (subtle)
              if (_deck.imageUrl != null && _deck.imageUrl!.isNotEmpty)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
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
    );
    
    // Use Hero only when we have a heroTag (not from deep link)
    if (widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: cardContent,
      );
    }
    return cardContent;
  }

  @override
  Widget build(BuildContext context) {
    // Handle loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading deck...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }
    
    // Handle error state
    if (_errorMessage != null || (_loadedDeck == null && widget.deck == null)) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Deck not found',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }
    
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
                          _deck.color.withOpacity(0.3),
                          _deck.color.withOpacity(0.1),
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
                                
                                // Share button
                                GestureDetector(
                                      onTap: () {
                                        hapticService.lightImpact();
                                        _shareDeck();
                                      },
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.05),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.share_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 400.ms, delay: 100.ms)
                                    .scale(
                                      begin: const Offset(0.8, 0.8),
                                      end: const Offset(1, 1),
                                      duration: 400.ms,
                                      curve: Curves.easeOutBack,
                                    ),
                                
                                const SizedBox(width: 12),

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
                                child: _buildHeroCard(),
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
                                          _deck.name,
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
                                      _deck.description,
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
                                        value: '${_getSelectedCardCount()}',
                                        label: 'Cards',
                                        color: _deck.color,
                                        index: 0,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticService().lightImpact();
                                          _showTimerPicker();
                                        },
                                        child: _buildModernStatCard(
                                          icon: _selectedTimer == 0 
                                              ? Icons.all_inclusive_rounded 
                                              : Icons.timer_rounded,
                                          value: _selectedTimer == 0 
                                              ? '∞' 
                                              : '${_selectedTimer}s',
                                          label: 'Timer',
                                          color: _deck.color,
                                          index: 1,
                                          isEditable: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticService().lightImpact();
                                          _showDifficultyPicker();
                                        },
                                        child: _buildModernStatCard(
                                          icon: _getDifficultyIcon(),
                                          value: _getDifficultyLabel(),
                                          label: 'Difficulty',
                                          color: _deck.color,
                                          index: 2,
                                          isEditable: true,
                                        ),
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
                                      icon: Icons.group_rounded,
                                      title: '2-10 Players',
                                      description:
                                          'Perfect for parties and gatherings',
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
                                      _handlePlayTap();
                                    },
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _deck.color,
                                            _deck.color.withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _deck.color
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

  void _showTimerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Round Timer',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how long each round lasts',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 28),
              
              // Timer options grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _timerOptions.map((seconds) {
                  final isSelected = _selectedTimer == seconds;
                  final isUnlimited = seconds == 0;
                  
                  return GestureDetector(
                    onTap: () {
                      HapticService().lightImpact();
                      setModalState(() {});
                      setState(() {
                        _selectedTimer = seconds;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? _deck.color.withOpacity(0.15)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? _deck.color.withOpacity(0.4)
                              : Colors.white.withOpacity(0.06),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isUnlimited)
                            Icon(
                              Icons.all_inclusive_rounded,
                              size: 24,
                              color: isSelected 
                                  ? _deck.color 
                                  : Colors.white.withOpacity(0.6),
                            )
                          else
                            Text(
                              '$seconds',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? Colors.white 
                                    : Colors.white.withOpacity(0.7),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            isUnlimited ? 'No limit' : 'sec',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isSelected 
                                  ? _deck.color.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 28),
              
              // Done button
              GestureDetector(
                onTap: () {
                  HapticService().lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _deck.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _deck.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDifficultyPicker() {
    // Check if deck has difficulty modes
    final hasDifficultyModes = _deck.hasDifficultyModes && 
        _deck.cardsByDifficulty != null &&
        _deck.cardsByDifficulty!.isNotEmpty;
    
    final difficulties = [
      (DeckDifficulty.mixed, 'All Levels', Icons.shuffle_rounded, _deck.cards.length, true),
      (DeckDifficulty.easy, 'Easy', Icons.sentiment_satisfied_rounded, 
          hasDifficultyModes ? _deck.cardsByDifficulty!.easy.length : 0, 
          hasDifficultyModes && _deck.cardsByDifficulty!.easy.isNotEmpty),
      (DeckDifficulty.medium, 'Medium', Icons.speed_rounded, 
          hasDifficultyModes ? _deck.cardsByDifficulty!.medium.length : 0, 
          hasDifficultyModes && _deck.cardsByDifficulty!.medium.isNotEmpty),
      (DeckDifficulty.hard, 'Hard', Icons.local_fire_department_rounded, 
          hasDifficultyModes ? _deck.cardsByDifficulty!.hard.length : 0, 
          hasDifficultyModes && _deck.cardsByDifficulty!.hard.isNotEmpty),
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Difficulty',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your challenge level',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
              
              // Difficulty options
              ...difficulties.map((d) {
                final isSelected = _selectedDifficulty == d.$1;
                final isAvailable = d.$5;
                
                return GestureDetector(
                  onTap: isAvailable ? () {
                    HapticService().lightImpact();
                    setModalState(() {});
                    setState(() {
                      _selectedDifficulty = d.$1;
                    });
                  } : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? _deck.color.withOpacity(0.15)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? _deck.color.withOpacity(0.4)
                            : Colors.white.withOpacity(0.06),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? _deck.color.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            d.$3,
                            size: 18,
                            color: !isAvailable 
                                ? Colors.white.withOpacity(0.2)
                                : isSelected 
                                    ? _deck.color 
                                    : Colors.white.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                d.$2,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: !isAvailable 
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.white,
                                ),
                              ),
                              Text(
                                isAvailable && d.$4 > 0 
                                    ? '${d.$4} cards' 
                                    : 'Coming soon',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(isAvailable ? 0.4 : 0.25),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: _deck.color,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 12),
              
              // Done button
              GestureDetector(
                onTap: () {
                  HapticService().lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _deck.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _deck.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    bool isEditable = false,
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
                  color: Colors.white.withOpacity(isEditable ? 0.7 : 0.6),
                  decoration: isEditable ? TextDecoration.underline : null,
                  decorationColor: Colors.white.withOpacity(0.3),
                  decorationStyle: TextDecorationStyle.dotted,
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
                  color: _deck.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _deck.color, size: 24),
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
