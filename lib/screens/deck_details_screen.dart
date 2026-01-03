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
import '../utils/premium_utils.dart';
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
  
  // Multi-deck selection
  List<Deck> _additionalDecks = [];
  
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
  
  /// Get all selected decks (primary + additional)
  List<Deck> get _allSelectedDecks => [_deck, ..._additionalDecks];
  
  /// Get total card count based on selected difficulty across all decks
  int _getTotalCardCount() {
    int total = 0;
    for (final deck in _allSelectedDecks) {
      total += deck.getCardCountByDifficulty(_selectedDifficulty);
    }
    return total;
  }
  
  /// Add a deck to the selection
  void _addDeck(Deck deck) {
    if (!_additionalDecks.any((d) => d.id == deck.id) && deck.id != _deck.id) {
      setState(() {
        _additionalDecks.add(deck);
      });
      HapticService().lightImpact();
    }
  }
  
  /// Remove a deck from the selection
  void _removeDeck(Deck deck) {
    setState(() {
      _additionalDecks.removeWhere((d) => d.id == deck.id);
    });
    HapticService().lightImpact();
  }
  
  /// Get combined cards from all selected decks
  List<String> _getCombinedCards() {
    final allCards = <String>[];
    for (final deck in _allSelectedDecks) {
      allCards.addAll(deck.getCardsByDifficulty(_selectedDifficulty));
    }
    allCards.shuffle();
    return allCards;
  }
  
  /// Create a combined deck for gameplay
  Deck _createCombinedDeck() {
    if (_additionalDecks.isEmpty) {
      return _deck;
    }
    
    final combinedCards = _getCombinedCards();
    final deckNames = _allSelectedDecks.map((d) => d.name).join(' + ');
    
    return Deck(
      id: 'combined_${DateTime.now().millisecondsSinceEpoch}',
      name: deckNames.length > 40 ? '${deckNames.substring(0, 37)}...' : deckNames,
      description: '${_allSelectedDecks.length} decks combined',
      icon: _deck.icon,
      color: _deck.color,
      cards: combinedCards,
      imageUrl: _deck.imageUrl,
    );
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
    // Check if any selected deck is premium and user doesn't have premium access
    final anyPremiumDeck = _allSelectedDecks.any((d) => d.isPremium);
    
    // If any deck is premium and user doesn't have premium, show paywall
    if (anyPremiumDeck && !PremiumUtils.hasPremium) {
      _showPaywall();
      return;
    }
    
    // User has access - start game directly with selected difficulty
    _startGameWithDifficulty();
  }
  
  void _startGameWithDifficulty() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Create combined deck if multiple decks are selected
    final deckToPlay = _createCombinedDeck();
    
    // Start game with selected difficulty and timer
    gameProvider.startGame(
      deck: deckToPlay,
      difficulty: _selectedDifficulty,
      customDuration: _selectedTimer, // 0 = unlimited
    );
    
    // Navigate to gameplay screen
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameplayScreen(
          deck: deckToPlay,
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
      // If we can pop (came from another screen), pop
      // Otherwise go to home (came from deep link)
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
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
        width: 210.s,
        height: 280.s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.s),
          boxShadow: [
            BoxShadow(
              color: _deck.color.withOpacity(0.3),
              blurRadius: 40.s,
              spreadRadius: -5,
              offset: Offset(0, 20.s),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.s),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or gradient
              if (_deck.imageUrl != null && _deck.imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: _deck.imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: (210 * Responsive.scale).toInt(),
                  memCacheHeight: (280 * Responsive.scale).toInt(),
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
                        size: 100.s,
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
                      size: 100.s,
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
                    width: 80.s,
                    height: 80.s,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 50.s,
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.s,
                              vertical: 16.s,
                            ),
                            child: Row(
                              children: [
                                // Back button - minimalist design
                                GestureDetector(
                                      onTap: () {
                                        hapticService.lightImpact();
                                        // If we can pop (came from another screen), pop
                                        // Otherwise go to home (came from deep link)
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        } else {
                                          context.go('/home');
                                        }
                                      },
                                      child: Container(
                                        width: 40.s,
                                        height: 40.s,
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
                                        child: Icon(
                                          Icons.arrow_back_rounded,
                                          color: Colors.white,
                                          size: 20.s,
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
                                        width: 40.s,
                                        height: 40.s,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.05),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.share_rounded,
                                          color: Colors.white,
                                          size: 20.s,
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
                                
                                SizedBox(width: 12.s),

                                // More options button
                                GestureDetector(
                                      onTap: () {
                                        hapticService.lightImpact();
                                        _showOptionsSheet(context);
                                      },
                                      child: Container(
                                        width: 40.s,
                                        height: 40.s,
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
                                        child: Icon(
                                          Icons.more_horiz_rounded,
                                          color: Colors.white,
                                          size: 20.s,
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
                              SizedBox(height: 30.s),

                              // Hero card with deck image
                              Center(
                                child: _buildHeroCard(),
                              ),

                              SizedBox(height: 40.s),

                              // Title and description
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 30.s,
                                ),
                                child: Column(
                                  children: [
                                    // Deck name with elegant typography
                                    Text(
                                          _deck.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 28.sp,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1.15,
                                            letterSpacing: -0.5,
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

                                    SizedBox(height: 14.s),

                                    // Description with subtle styling
                                    Text(
                                      _deck.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.65),
                                        height: 1.5,
                                        letterSpacing: 0.1,
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

                              SizedBox(height: 40.s),

                              // Modern stats grid
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 30.s,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernStatCard(
                                        icon: Icons.style_rounded,
                                        value: '${_getTotalCardCount()}',
                                        label: _additionalDecks.isEmpty ? 'Cards' : 'Total',
                                        color: _deck.color,
                                        index: 0,
                                      ),
                                    ),
                                    SizedBox(width: 12.s),
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
                                    SizedBox(width: 12.s),
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

                              SizedBox(height: 36.s),
                              
                              // Premium Multi-deck section
                              _buildPremiumMultiDeckSection(),

                              SizedBox(height: 32.s),

                              // Features section with elegant cards
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 30.s,
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
                                      delay: 550.ms,
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

                              SizedBox(height: 100.s),
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
                        padding: EdgeInsets.fromLTRB(30.s, 20.s, 30.s, 30.s),
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
                                      height: 56.s,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _deck.color,
                                            _deck.color.withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16.s),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _deck.color
                                                .withOpacity(0.4),
                                            blurRadius: 20.s,
                                            offset: Offset(0, 8.s),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 28.s,
                                          ),
                                          SizedBox(width: 12.s),
                                          Text(
                                            _additionalDecks.isEmpty 
                                                ? 'Start Game'
                                                : 'Play ${_allSelectedDecks.length} Decks',
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
          padding: EdgeInsets.all(24.s),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.s)),
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
                width: 40.s,
                height: 4.s,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.s),
                ),
              ),
              SizedBox(height: 24.s),
              
              // Title
              Text(
                'Round Timer',
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8.s),
              Text(
                'Choose how long each round lasts',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              SizedBox(height: 28.s),
              
              // Timer options grid
              Wrap(
                spacing: 12.s,
                runSpacing: 12.s,
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
                      width: 72.s,
                      height: 72.s,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? _deck.color.withOpacity(0.15)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16.s),
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
                              size: 24.s,
                              color: isSelected 
                                  ? _deck.color 
                                  : Colors.white.withOpacity(0.6),
                            )
                          else
                            Text(
                              '$seconds',
                              style: GoogleFonts.poppins(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? Colors.white 
                                    : Colors.white.withOpacity(0.7),
                              ),
                            ),
                          SizedBox(height: 2.s),
                          Text(
                            isUnlimited ? 'No limit' : 'sec',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
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
              
              SizedBox(height: 28.s),
              
              // Done button
              GestureDetector(
                onTap: () {
                  HapticService().lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 52.s,
                  decoration: BoxDecoration(
                    color: _deck.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14.s),
                    border: Border.all(
                      color: _deck.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
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
          padding: EdgeInsets.fromLTRB(24.s, 24.s, 24.s, MediaQuery.of(context).padding.bottom + 16.s),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.s)),
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
                width: 40.s,
                height: 4.s,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.s),
                ),
              ),
              SizedBox(height: 20.s),
              
              // Title
              Text(
                'Difficulty',
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6.s),
              Text(
                'Choose your challenge level',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              SizedBox(height: 20.s),
              
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
                    margin: EdgeInsets.only(bottom: 8.s),
                    padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? _deck.color.withOpacity(0.15)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12.s),
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
                          width: 36.s,
                          height: 36.s,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? _deck.color.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10.s),
                          ),
                          child: Icon(
                            d.$3,
                            size: 18.s,
                            color: !isAvailable 
                                ? Colors.white.withOpacity(0.2)
                                : isSelected 
                                    ? _deck.color 
                                    : Colors.white.withOpacity(0.6),
                          ),
                        ),
                        SizedBox(width: 12.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                d.$2,
                                style: GoogleFonts.inter(
                                  fontSize: 15.sp,
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
                                  fontSize: 12.sp,
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
                            size: 20.s,
                            color: _deck.color,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              
              SizedBox(height: 12.s),
              
              // Done button
              GestureDetector(
                onTap: () {
                  HapticService().lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 48.s,
                  decoration: BoxDecoration(
                    color: _deck.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.s),
                    border: Border.all(
                      color: _deck.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
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

  void _showDeckSelector() {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final availableDecks = deckProvider.allDecks
        .where((d) => d.id != _deck.id && !_additionalDecks.any((ad) => ad.id == d.id))
        .toList();
    
    // Track temporarily selected decks (before confirming)
    final Set<String> tempSelectedIds = {};
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StatefulBuilder(
          builder: (context, setModalState) => Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            body: Stack(
              children: [
                // Background gradient
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 300,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.2,
                        colors: [
                          _deck.color.withOpacity(0.3),
                          _deck.color.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                SafeArea(
                  child: Column(
                    children: [
                      // App bar
                      Padding(
                        padding: EdgeInsets.fromLTRB(8.s, 8.s, 16.s, 0),
                        child: Row(
                          children: [
                            // Back button
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                padding: EdgeInsets.all(8.s),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.s),
                                ),
                                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22.s),
                              ),
                            ),
                            SizedBox(width: 8.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Decks',
                                    style: GoogleFonts.poppins(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Tap to select, then confirm',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Selection count badge
                            if (tempSelectedIds.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_deck.color, _deck.color.withOpacity(0.8)],
                                  ),
                                  borderRadius: BorderRadius.circular(20.s),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _deck.color.withOpacity(0.4),
                                      blurRadius: 12.s,
                                      offset: Offset(0, 4.s),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${tempSelectedIds.length} selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16.s),
                      
                      // Available decks count
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.s),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10.s),
                              decoration: BoxDecoration(
                                color: _deck.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.s),
                              ),
                              child: Icon(Icons.grid_view_rounded, size: 20.s, color: _deck.color),
                            ),
                            SizedBox(width: 12.s),
                            Text(
                              '${availableDecks.length} decks available',
                              style: GoogleFonts.inter(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16.s),
                      
                      // Grid of decks
                      Expanded(
                        child: availableDecks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 80.s, height: 80.s,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(24.s),
                                      ),
                                      child: Icon(Icons.check_circle_outline_rounded, size: 40.s, color: Colors.white.withOpacity(0.2)),
                                    ),
                                    SizedBox(height: 20.s),
                                    Text('All decks added!', style: GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4))),
                                    SizedBox(height: 8.s),
                                    Text('You\'ve already added all available decks', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withOpacity(0.3))),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 120.s),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10.s,
                                  mainAxisSpacing: 10.s,
                                  childAspectRatio: 0.68,
                                ),
                                itemCount: availableDecks.length,
                                itemBuilder: (context, index) {
                                  final deck = availableDecks[index];
                                  final isSelected = tempSelectedIds.contains(deck.id);
                                  return _buildSelectableDeckCard(
                                    deck: deck,
                                    index: index,
                                    isSelected: isSelected,
                                    onTap: () {
                                      HapticService().lightImpact();
                                      setModalState(() {
                                        if (isSelected) {
                                          tempSelectedIds.remove(deck.id);
                                        } else {
                                          tempSelectedIds.add(deck.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom CTA
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20.s, 16.s, 20.s, MediaQuery.of(context).padding.bottom + 16.s),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0A0A0A).withOpacity(0.9),
                          const Color(0xFF0A0A0A),
                        ],
                        stops: const [0.0, 0.3, 1.0],
                      ),
                    ),
                    child: Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: 54.s,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14.s),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.s),
                        // Add selected button
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: tempSelectedIds.isEmpty ? null : () {
                              HapticService().mediumImpact();
                              // Add all selected decks
                              for (final id in tempSelectedIds) {
                                final deck = availableDecks.firstWhere((d) => d.id == id);
                                _addDeck(deck);
                              }
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 54.s,
                              decoration: BoxDecoration(
                                gradient: tempSelectedIds.isEmpty
                                    ? null
                                    : LinearGradient(
                                        colors: [_deck.color, _deck.color.withOpacity(0.8)],
                                      ),
                                color: tempSelectedIds.isEmpty ? Colors.white.withOpacity(0.1) : null,
                                borderRadius: BorderRadius.circular(14.s),
                                boxShadow: tempSelectedIds.isEmpty ? null : [
                                  BoxShadow(
                                    color: _deck.color.withOpacity(0.4),
                                    blurRadius: 16.s,
                                    offset: Offset(0, 6.s),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: tempSelectedIds.isEmpty ? Colors.white.withOpacity(0.4) : Colors.white,
                                      size: 22.s,
                                    ),
                                    SizedBox(width: 8.s),
                                    Text(
                                      tempSelectedIds.isEmpty
                                          ? 'Select Decks'
                                          : 'Add ${tempSelectedIds.length} Deck${tempSelectedIds.length > 1 ? 's' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: tempSelectedIds.isEmpty ? Colors.white.withOpacity(0.4) : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }
  
  /// Build a selectable deck card for the full-screen selector
  Widget _buildSelectableDeckCard({
    required Deck deck,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14.s),
          border: Border.all(
            color: isSelected ? _deck.color : Colors.white.withOpacity(0.08),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: _deck.color.withOpacity(0.3),
              blurRadius: 16.s,
              offset: Offset(0, 4.s),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8.s,
              offset: Offset(0, 4.s),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13.s),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or gradient
              if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: deck.imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 180,
                  memCacheHeight: 260,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [deck.color, deck.color.withOpacity(0.7)],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [deck.color, deck.color.withOpacity(0.7)],
                      ),
                    ),
                    child: Center(child: Icon(deck.icon, color: Colors.white, size: 32.s)),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [deck.color, deck.color.withOpacity(0.7)],
                    ),
                  ),
                  child: Center(child: Icon(deck.icon, color: Colors.white, size: 32.s)),
                ),
              
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              
              // Selection overlay when selected
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    color: _deck.color.withOpacity(0.3),
                  ),
                ),
              
              // Check mark when selected
              if (isSelected)
                Positioned(
                  top: 8.s,
                  right: 8.s,
                  child: Container(
                    width: 28.s,
                    height: 28.s,
                    decoration: BoxDecoration(
                      color: _deck.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _deck.color.withOpacity(0.5),
                          blurRadius: 8.s,
                          offset: Offset(0, 2.s),
                        ),
                      ],
                    ),
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 18.s),
                  ),
                ),
              
              // Premium badge
              if (deck.isPremium)
                Positioned(
                  top: 8.s,
                  left: 8.s,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 3.s),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(6.s),
                    ),
                    child: Icon(Icons.workspace_premium_rounded, size: 12.s, color: Colors.black),
                  ),
                ),
              
              // Deck info at bottom
              Positioned(
                bottom: 8.s,
                left: 8.s,
                right: 8.s,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      deck.name,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.s),
                    Text(
                      '${deck.cards.length} cards',
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(delay: (index * 40).ms, duration: 300.ms)
      .scale(
        begin: const Offset(0.92, 0.92),
        end: const Offset(1, 1),
        delay: (index * 40).ms,
        duration: 300.ms,
        curve: Curves.easeOutBack,
      );
  }
  
  /// Build the premium multi-deck section with list of selected decks
  Widget _buildPremiumMultiDeckSection() {
    return Column(
      children: [
        // Section header with premium styling
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.s),
          child: Row(
            children: [
              // Glowing icon
              Container(
                width: 36.s,
                height: 36.s,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _deck.color.withOpacity(0.25),
                      _deck.color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10.s),
                  boxShadow: [
                    BoxShadow(
                      color: _deck.color.withOpacity(0.2),
                      blurRadius: 12.s,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 18.s,
                  color: _deck.color,
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mix & Match',
                      style: GoogleFonts.poppins(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _additionalDecks.isEmpty 
                          ? 'Combine decks for more variety'
                          : '${_allSelectedDecks.length} decks • ${_getTotalCardCount()} cards',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Add button
              GestureDetector(
                onTap: () {
                  HapticService().lightImpact();
                  _showDeckSelector();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _deck.color.withOpacity(0.2),
                        _deck.color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20.s),
                    border: Border.all(
                      color: _deck.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16.s,
                        color: _deck.color,
                      ),
                      SizedBox(width: 4.s),
                      Text(
                        'Add',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: _deck.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
        
        SizedBox(height: 16.s),
        
        // Show selected decks list with remove option
        if (_additionalDecks.isNotEmpty)
          _buildSelectedDecksList().animate()
            .fadeIn(delay: 480.ms, duration: 400.ms)
        else
          _buildAddDecksCTA().animate()
            .fadeIn(delay: 480.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0, delay: 480.ms, duration: 400.ms),
      ],
    );
  }
  
  /// Build horizontal list of selected decks with remove buttons
  Widget _buildSelectedDecksList() {
    // Card dimensions matching hero card ratio (210:280 = 3:4) - scaled for responsiveness
    final cardWidth = 95.s;
    final cardHeight = 127.s; // 95 * (280/210) = ~127
    final buttonOverhang = 14.s; // Space for remove button at top
    final shadowPadding = 16.s; // Space for shadow at bottom
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal scroll of selected deck cards
        SizedBox(
          height: cardHeight + buttonOverhang + shadowPadding,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none, // Allow shadows to extend beyond bounds
            padding: EdgeInsets.only(left: 30.s, right: 30.s, top: buttonOverhang),
            itemCount: _additionalDecks.length + 1, // +1 for add more button
            itemBuilder: (context, index) {
              if (index == _additionalDecks.length) {
                // Add more button at the end
                return _buildAddMoreDeckButton(cardWidth, cardHeight);
              }
              final deck = _additionalDecks[index];
              return _buildRemovableDeckCard(deck, index, cardWidth, cardHeight);
            },
          ),
        ),
      ],
    );
  }
  
  /// Build a deck card with remove button
  Widget _buildRemovableDeckCard(Deck deck, int index, double cardWidth, double cardHeight) {
    final buttonSize = 28.s;
    
    return Padding(
      padding: EdgeInsets.only(right: 14.s),
      child: SizedBox(
        width: cardWidth + buttonSize / 2, // Extra space for button overhang
        height: cardHeight + buttonSize / 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Deck card
            Positioned(
              left: 0,
              top: buttonSize / 2, // Offset to make room for button
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.s),
                  boxShadow: [
                    BoxShadow(
                      color: deck.color.withOpacity(0.35),
                      blurRadius: 14.s,
                      spreadRadius: -2,
                      offset: Offset(0, 6.s),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8.s,
                      offset: Offset(0, 3.s),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14.s),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background
                      if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: deck.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: (95 * 2 * Responsive.scale).toInt(),
                          memCacheHeight: (127 * 2 * Responsive.scale).toInt(),
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [deck.color, deck.color.withOpacity(0.7)],
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [deck.color, deck.color.withOpacity(0.7)],
                              ),
                            ),
                            child: Icon(deck.icon, color: Colors.white, size: 28.s),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [deck.color, deck.color.withOpacity(0.7)],
                            ),
                          ),
                          child: Icon(deck.icon, color: Colors.white, size: 28.s),
                        ),
                      
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.85),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                      
                      // Deck info at bottom
                      Positioned(
                        bottom: 8.s,
                        left: 8.s,
                        right: 8.s,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              deck.name,
                              style: GoogleFonts.poppins(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3.s),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.s, vertical: 2.s),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5.s),
                              ),
                              child: Text(
                                '${deck.cards.length} cards',
                                style: GoogleFonts.inter(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Remove button - positioned at top right corner of the card
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticService().mediumImpact();
                  _removeDeck(deck);
                },
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade400,
                        Colors.red.shade600,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 8.s,
                        spreadRadius: 0,
                        offset: Offset(0, 2.s),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4.s,
                        offset: Offset(0, 1.s),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16.s,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(delay: (index * 60).ms, duration: 350.ms)
      .slideX(begin: 0.15, end: 0, delay: (index * 60).ms, duration: 350.ms, curve: Curves.easeOutCubic);
  }
  
  /// Build the "Add More" button for the deck list
  Widget _buildAddMoreDeckButton(double cardWidth, double cardHeight) {
    return GestureDetector(
      onTap: () {
        HapticService().lightImpact();
        _showDeckSelector();
      },
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14.s),
          border: Border.all(
            color: _deck.color.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _deck.color.withOpacity(0.15),
              blurRadius: 10.s,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40.s,
              height: 40.s,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _deck.color.withOpacity(0.25),
                    _deck.color.withOpacity(0.15),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _deck.color.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: _deck.color,
                size: 24.s,
              ),
            ),
            SizedBox(height: 10.s),
            Text(
              'Add More',
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: _deck.color,
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(delay: (_additionalDecks.length * 60 + 100).ms, duration: 350.ms)
      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), delay: (_additionalDecks.length * 60 + 100).ms, duration: 350.ms);
  }
  
  /// Build the CTA for adding decks when none are selected
  Widget _buildAddDecksCTA() {
    return GestureDetector(
      onTap: () {
        HapticService().lightImpact();
        _showDeckSelector();
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 30.s),
        padding: EdgeInsets.all(20.s),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.04),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(20.s),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Animated deck stack illustration
            SizedBox(
              width: 56.s,
              height: 56.s,
              child: Stack(
                children: [
                  Positioned(
                    left: 8.s,
                    top: 4.s,
                    child: Container(
                      width: 40.s,
                      height: 48.s,
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8.s),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4.s,
                    top: 2.s,
                    child: Container(
                      width: 40.s,
                      height: 48.s,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8.s),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 40.s,
                      height: 48.s,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _deck.color,
                            _deck.color.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8.s),
                        boxShadow: [
                          BoxShadow(
                            color: _deck.color.withOpacity(0.3),
                            blurRadius: 8.s,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 20.s,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Combine Multiple Decks',
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2.s),
                  Text(
                    'Add more decks to play them all together',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 24.s,
              color: Colors.white.withOpacity(0.4),
            ),
          ],
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
            padding: EdgeInsets.all(20.s),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.s)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.s,
                  height: 5.s,
                  margin: EdgeInsets.only(bottom: 20.s),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.5.s),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.share_rounded, color: Colors.white, size: 24.s),
                  title: Text(
                    'Share Deck',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16.sp),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    HapticService().lightImpact();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 24.s,
                  ),
                  title: Text(
                    'Add to Favorites',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16.sp),
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
          padding: EdgeInsets.all(20.s),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28.s),
              SizedBox(height: 12.s),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              SizedBox(height: 4.s),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
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
          margin: EdgeInsets.only(bottom: 12.s),
          padding: EdgeInsets.all(16.s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48.s,
                height: 48.s,
                decoration: BoxDecoration(
                  color: _deck.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.s),
                ),
                child: Icon(icon, color: _deck.color, size: 24.s),
              ),
              SizedBox(width: 16.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.s),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
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
