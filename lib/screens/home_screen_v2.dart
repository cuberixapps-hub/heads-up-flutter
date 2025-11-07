import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../services/daily_deck_service.dart';
import '../models/daily_deck.dart';
import 'gameplay_screen.dart';
import 'deck_details_screen.dart';

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();
  final _dailyDeckService = DailyDeckService();

  DailyDeck? _todaysDeck;
  bool _hasPlayedDaily = false;
  List<Deck> _recentDecks = [];
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'Trending';

  // Gradient fade configuration
  static const double _gradientFadeDistance =
      200.0; // Pixels to scroll for complete fade

  // Gradient colors that will transition to black
  Color _gradientColor1 = const Color(0xFF84292D);
  Color _gradientColor2 = const Color(0xFF601F20);
  Color _gradientColor3 = const Color(0xFF000000);

  // Featured deck rotation
  int _currentFeaturedIndex = 0;
  Timer? _deckRotationTimer;
  static const Duration _rotationInterval = Duration(seconds: 5);
  bool _isAutoRotationPaused = false;

  // Streak badge collapse state
  bool _streakBadgeExpanded = true;
  Timer? _badgeCollapseTimer;

  @override
  void initState() {
    super.initState();
    _loadDailyDeck();
    _loadRecentDecks();
    _scrollController.addListener(_onScroll);
    _startDeckRotation();
    _startBadgeCollapseTimer();

    // Initialize gradient with first deck's color after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final deckProvider = Provider.of<DeckProvider>(context, listen: false);
        final availableDecks =
            deckProvider.freeDecks.isNotEmpty
                ? deckProvider.freeDecks
                : deckProvider.allDecks;
        if (availableDecks.isNotEmpty) {
          _updateGradientColors(availableDecks.first.color);
        }
      }
    });
  }

  void _startBadgeCollapseTimer() {
    // Collapse the streak badge after 3.5 seconds to save space
    _badgeCollapseTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _streakBadgeExpanded = false;
        });
      }
    });
  }

  void _onScroll() {
    // Fade gradient colors to black as user scrolls
    final offset = _scrollController.offset;
    final fadeProgress = (offset / _gradientFadeDistance).clamp(0.0, 1.0);

    // Apply easing curve for smoother transition
    final easedProgress = Curves.easeOutCubic.transform(fadeProgress);

    // Original colors
    const originalColor1 = Color(0xFF84292D);
    const originalColor2 = Color(0xFF601F20);
    const originalColor3 = Color(0xFF120506);
    const targetColor = Color(0xFF000000); // Black

    // Interpolate colors with eased progress
    final newColor1 = Color.lerp(originalColor1, targetColor, easedProgress)!;
    final newColor2 = Color.lerp(originalColor2, targetColor, easedProgress)!;
    final newColor3 = Color.lerp(originalColor3, targetColor, easedProgress)!;

    // Throttle setState calls - only update if there's a meaningful change
    if ((_gradientColor1.value - newColor1.value).abs() > 2 ||
        (_gradientColor2.value - newColor2.value).abs() > 2 ||
        (_gradientColor3.value - newColor3.value).abs() > 2) {
      setState(() {
        _gradientColor1 = newColor1;
        _gradientColor2 = newColor2;
        _gradientColor3 = newColor3;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _deckRotationTimer?.cancel();
    _badgeCollapseTimer?.cancel();
    super.dispose();
  }

  void _startDeckRotation() {
    _deckRotationTimer = Timer.periodic(_rotationInterval, (timer) {
      if (mounted && !_isAutoRotationPaused) {
        final deckProvider = Provider.of<DeckProvider>(context, listen: false);
        final availableDecks =
            deckProvider.freeDecks.isNotEmpty
                ? deckProvider.freeDecks
                : deckProvider.allDecks;

        if (availableDecks.isNotEmpty) {
          final nextIndex = (_currentFeaturedIndex + 1) % availableDecks.length;
          final nextDeck = availableDecks[nextIndex];

          setState(() {
            _currentFeaturedIndex = nextIndex;
            // Update gradient colors based on the new deck
            _updateGradientColors(nextDeck.color);
          });
        }
      }
    });
  }

  void _navigateToDeck(int direction, List<Deck> availableDecks) {
    if (availableDecks.isEmpty) return;

    final newIndex =
        (_currentFeaturedIndex + direction) % availableDecks.length;
    final nextDeck =
        availableDecks[newIndex < 0 ? availableDecks.length - 1 : newIndex];

    setState(() {
      _currentFeaturedIndex =
          newIndex < 0 ? availableDecks.length - 1 : newIndex;
      _updateGradientColors(nextDeck.color);
    });

    // Pause auto-rotation temporarily when user manually swipes
    _isAutoRotationPaused = true;
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isAutoRotationPaused = false;
        });
      }
    });
  }

  void _updateGradientColors(Color deckColor) {
    // Don't update gradient if user has scrolled
    if (_scrollController.hasClients && _scrollController.offset > 50) {
      return;
    }

    // Create gradient colors from deck color
    setState(() {
      _gradientColor1 = Color.lerp(deckColor, deckColor.withOpacity(0.8), 0.3)!;
      _gradientColor2 = Color.lerp(deckColor, Colors.black, 0.5)!;
      _gradientColor3 = const Color(0xFF000000);
    });
  }

  Future<void> _loadDailyDeck() async {
    try {
      final deck = await _dailyDeckService.getTodaysDeck();
      final hasPlayed = await _dailyDeckService.hasPlayedToday();

      if (mounted) {
        setState(() {
          _todaysDeck = deck;
          _hasPlayedDaily = hasPlayed;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily deck: $e');
    }
  }

  Future<void> _loadRecentDecks() async {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final recent = await deckProvider.getRecentDecks();

    if (mounted) {
      setState(() {
        _recentDecks = recent.take(10).toList();
      });
    }
  }

  void _playDeck(Deck deck) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);

    _hapticService.lightImpact();
    _audioService.playCorrect();

    gameProvider.startGame(deck: deck);
    deckProvider.addToRecentDecks(deck.id);

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => GameplayScreen(deck: deck)));
  }

  List<Deck> _getFilteredDecks(List<Deck> decks) {
    switch (_selectedCategory) {
      case 'Trending':
        // Show decks with more cards (popular ones)
        final trending = decks.where((d) => d.cards.length >= 10).toList();
        return trending.isEmpty ? decks : trending;
      case 'Quick Play':
        // Show decks with fewer cards for quick games
        final quickPlay = decks.where((d) => d.cards.length <= 15).toList();
        return quickPlay.isEmpty ? decks : quickPlay;
      case 'Multiplayer':
        // Show decks with more cards (better for groups)
        final multiplayer = decks.where((d) => d.cards.length >= 15).toList();
        return multiplayer.isEmpty ? decks : multiplayer;
      default:
        return decks;
    }
  }

  String _getCategoryTitle() {
    switch (_selectedCategory) {
      case 'Trending':
        return 'Trending Now';
      case 'Quick Play':
        return 'Quick Play Decks';
      case 'Multiplayer':
        return 'Perfect for Groups';
      default:
        return 'Recommended for You';
    }
  }

  IconData _getCategoryIcon() {
    switch (_selectedCategory) {
      case 'Trending':
        return Icons.trending_up_rounded;
      case 'Quick Play':
        return Icons.bolt_rounded;
      case 'Multiplayer':
        return Icons.people_outline_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (_selectedCategory) {
      case 'Trending':
        return Colors.orange;
      case 'Quick Play':
        return Colors.yellow;
      case 'Multiplayer':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const SmoothScrollBehavior(),
      child: Consumer<DeckProvider>(
        builder: (context, deckProvider, _) {
          // Show error state if decks failed to load
          if (deckProvider.hasError && !deckProvider.isInitialized) {
            return _buildErrorState(context, deckProvider);
          }

          return Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            body: Stack(
              children: [
                // Black background
                Container(color: Colors.black),
                // Gradient overlay with fixed height - animates smoothly
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOut,
                    height: 780,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _gradientColor1, // Dark red at top
                          _gradientColor2, // Medium red
                          _gradientColor3, // Almost black
                        ],
                        stops: const [0.0, 0.61, 1.0],
                      ),
                    ),
                  ),
                ),
                // Content with subtle top fade
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0x00FFFFFF),
                        Color(0x33FFFFFF),
                        Color(0x99FFFFFF),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.003, 0.008, 0.012],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Content
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with user greeting
                            _buildHeader(),

                            const SizedBox(height: 20),

                            // Featured deck
                            _buildFeaturedDeck(),

                            const SizedBox(height: 8),

                            // Category chips
                            _buildCategoryChips(),

                            const SizedBox(height: 30),

                            // Daily deck section
                            if (_todaysDeck != null) ...[
                              _buildDailyDeckSection(),
                              const SizedBox(height: 30),
                            ],

                            // Continue playing section with larger cards
                            if (_recentDecks.isNotEmpty) ...[
                              _buildContinueWatchingSection(),
                              const SizedBox(height: 24),
                            ],

                            // Quick stats banner
                            _buildStatsSection(),

                            const SizedBox(height: 24),

                            // Recommended for you (filtered by category)
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                final filteredDecks = _getFilteredDecks(
                                  deckProvider.freeDecks,
                                );
                                if (filteredDecks.isEmpty &&
                                    deckProvider.isInitialized) {
                                  return _buildNoDecksMessage();
                                }
                                return _buildSection(
                                  title: _getCategoryTitle(),
                                  decks: filteredDecks.take(10).toList(),
                                  icon: _getCategoryIcon(),
                                  iconColor: _getCategoryColor(),
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Party favorites
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                return _buildSection(
                                  title: 'Party Favorites',
                                  decks:
                                      deckProvider.freeDecks
                                          .where((d) => d.cards.length > 15)
                                          .toList(),
                                  icon: Icons.celebration_rounded,
                                  iconColor: Colors.pink,
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Custom decks with better presentation
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                if (deckProvider.customDecks.isEmpty) {
                                  return _buildCreateCustomDeckPrompt();
                                }
                                return _buildSection(
                                  title: 'Your Creations',
                                  decks: deckProvider.customDecks,
                                  icon: Icons.create_rounded,
                                  iconColor: Colors.blue,
                                  showSeeAll: true,
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Premium decks with better presentation
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                if (deckProvider.premiumDecks.isNotEmpty) {
                                  return _buildSection(
                                    title: 'Unlock More Fun',
                                    decks: deckProvider.premiumDecks,
                                    icon: Icons.star_rounded,
                                    iconColor: Colors.amber,
                                    isPremium: true,
                                  );
                                }
                                return const SizedBox();
                              },
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 8,
        24,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting section with elegant icon
              Expanded(
                child: Row(
                  children: [
                    // Animated wave icon container
                    Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.waving_hand_rounded,
                            color: Color(0xFFFFD700),
                            size: 24,
                          ),
                        )
                        .animate(
                          onPlay:
                              (controller) => controller.repeat(reverse: true),
                        )
                        .rotate(
                          begin: 0,
                          end: 0.05,
                          duration: 1200.ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .rotate(
                          begin: 0.05,
                          end: -0.05,
                          duration: 1200.ms,
                          curve: Curves.easeInOut,
                        ),

                    const SizedBox(width: 16),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                                'Welcome back',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                ),
                              )
                              .animate()
                              .fadeIn(
                                delay: 100.ms,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              )
                              .slideX(
                                begin: -0.2,
                                end: 0,
                                delay: 100.ms,
                                duration: 600.ms,
                                curve: Curves.easeOutCubic,
                              ),

                          const SizedBox(height: 4),

                          ShaderMask(
                                shaderCallback:
                                    (bounds) => LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.8),
                                        Colors.white.withOpacity(0.5),
                                      ],
                                    ).createShader(bounds),
                                child: Text(
                                  'What would you like to play today?',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    letterSpacing: -0.1,
                                    height: 1.3,
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 250.ms, duration: 700.ms)
                              .slideX(
                                begin: -0.2,
                                end: 0,
                                delay: 250.ms,
                                duration: 700.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Elegant stats badge with glow effect (collapsible)
              GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  setState(() {
                    _streakBadgeExpanded = !_streakBadgeExpanded;
                    _badgeCollapseTimer?.cancel();
                  });
                },
                child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      margin: const EdgeInsets.only(left: 12),
                      padding: EdgeInsets.symmetric(
                        horizontal: _streakBadgeExpanded ? 14 : 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFFB800).withOpacity(0.2),
                            const Color(0xFFFF8C00).withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                                Icons.local_fire_department_rounded,
                                color: const Color(0xFFFFD700),
                                size: 18,
                              )
                              .animate(
                                onPlay: (controller) => controller.repeat(),
                              )
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.15, 1.15),
                                duration: 1000.ms,
                                curve: Curves.easeInOut,
                              )
                              .then()
                              .scale(
                                begin: const Offset(1.15, 1.15),
                                end: const Offset(1, 1),
                                duration: 1000.ms,
                                curve: Curves.easeInOut,
                              ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                            child:
                                _streakBadgeExpanded
                                    ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 7),
                                        Text(
                                          '5 day streak',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFFFD700),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 6),
                                        Text(
                                          '5',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFFFD700),
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 700.ms)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1, 1),
                      delay: 500.ms,
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    )
                    .shimmer(
                      delay: 1500.ms,
                      duration: 1500.ms,
                      color: Colors.white.withOpacity(0.3),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      {
        'name': 'Trending',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFFF6B9D),
      },
      {
        'name': 'Quick Play',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFFFD700),
      },
      {
        'name': 'Multiplayer',
        'icon': Icons.people_outline_rounded,
        'color': const Color(0xFF66D9EF),
      },
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Fixed search bubble on the left
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 12),
            child: _buildSearchChip(),
          ),

          // Elegant vertical divider
          Container(
                margin: const EdgeInsets.only(
                  left: 0,
                  right: 12,
                  top: 6,
                  bottom: 6,
                ),
                width: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(1.0, 0.0),
                end: const Offset(1.0, 1.0),
                delay: 350.ms,
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),

          // Scrollable category chips with elegant gradient mask
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Color(0x00FFFFFF),
                    Color(0x44FFFFFF),
                    Color(0xDDFFFFFF),
                    Colors.white,
                    Colors.white,
                    Color(0xDDFFFFFF),
                    Color(0x44FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: const [0.0, 0.015, 0.03, 0.05, 0.95, 0.97, 0.985, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final categoryName = category['name'] as String;
                  final categoryColor = category['color'] as Color;
                  final isSelected = _selectedCategory == categoryName;

                  return _buildCategoryChip(
                    categoryName: categoryName,
                    categoryIcon: category['icon'] as IconData,
                    categoryColor: categoryColor,
                    isSelected: isSelected,
                    index: index,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String categoryName,
    required IconData categoryIcon,
    required Color categoryColor,
    required bool isSelected,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hapticService.selection();
                setState(() {
                  _selectedCategory = categoryName;
                });
              },
              borderRadius: BorderRadius.circular(24),
              splashColor: categoryColor.withOpacity(0.1),
              highlightColor: categoryColor.withOpacity(0.05),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient:
                      isSelected
                          ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              categoryColor.withOpacity(0.25),
                              categoryColor.withOpacity(0.15),
                            ],
                          )
                          : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.06),
                  border: Border.all(
                    color:
                        isSelected
                            ? categoryColor.withOpacity(0.5)
                            : Colors.white.withOpacity(0.12),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: categoryColor.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                          : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        categoryIcon,
                        color:
                            isSelected
                                ? categoryColor
                                : Colors.white.withOpacity(0.7),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      categoryName,
                      style: GoogleFonts.poppins(
                        color:
                            isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .animate()
          .fadeIn(
            delay: (100 + 50 * index).ms,
            duration: 500.ms,
            curve: Curves.easeOut,
          )
          .slideX(
            begin: 0.3,
            end: 0,
            delay: (100 * index).ms,
            duration: 400.ms,
            curve: Curves.easeOutQuart,
          ),
    );
  }

  Widget _buildSearchChip() {
    const searchColor = Color(0xFF9B59B6); // Elegant purple

    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _hapticService.selection();
              // TODO: Navigate to search screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Search coming soon!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: searchColor,
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            splashColor: searchColor.withOpacity(0.1),
            highlightColor: searchColor.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    searchColor.withOpacity(0.18),
                    searchColor.withOpacity(0.08),
                  ],
                ),
                border: Border.all(
                  color: searchColor.withOpacity(0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: searchColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Elegant search icon with subtle animation
                  ShaderMask(
                        shaderCallback:
                            (bounds) => LinearGradient(
                              colors: [
                                searchColor.withOpacity(0.9),
                                searchColor.withOpacity(0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                      .animate(
                        onPlay:
                            (controller) => controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.08, 1.08),
                        duration: 2000.ms,
                        curve: Curves.easeInOut,
                      ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 350.ms, duration: 500.ms, curve: Curves.easeOut)
        .slideX(
          begin: 0.3,
          end: 0,
          delay: 300.ms,
          duration: 400.ms,
          curve: Curves.easeOutQuart,
        )
        .shimmer(
          delay: 800.ms,
          duration: 1200.ms,
          color: searchColor.withOpacity(0.3),
        );
  }

  Widget _buildFeaturedDeck() {
    return Consumer<DeckProvider>(
      builder: (context, deckProvider, _) {
        if (deckProvider.allDecks.isEmpty) {
          return const SizedBox();
        }

        // Get available decks for rotation
        final availableDecks =
            deckProvider.freeDecks.isNotEmpty
                ? deckProvider.freeDecks
                : deckProvider.allDecks;

        // Get current featured deck based on index
        final featuredDeck =
            availableDecks[_currentFeaturedIndex % availableDecks.length];

        // Use test image URL or fallback to gradient
        const testImageUrl =
            'https://resizing.flixster.com/ZUhHpJCOJmPu7ro7DxecAetusnE=/ems.cHJkLWVtcy1hc3NldHMvdHZzZXJpZXMvNmI5OGY3ZWMtYjY1Mi00NGEwLTgxYmEtNjUyNjRmNGE2MDQ5LmpwZw==';
        final imageUrl = featuredDeck.imageUrl ?? testImageUrl;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! > 500) {
                  // Swipe right - go to previous deck
                  _hapticService.lightImpact();
                  _navigateToDeck(-1, availableDecks);
                } else if (details.primaryVelocity! < -500) {
                  // Swipe left - go to next deck
                  _hapticService.lightImpact();
                  _navigateToDeck(1, availableDecks);
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

                // Add subtle blur effect during transition
                final blurAnimation = Tween<double>(
                  begin: 4.0,
                  end: 0.0,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
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
                                              _hapticService.lightImpact();
                                              _playDeck(featuredDeck);
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
                                              _hapticService.lightImpact();
                                              final heroTag =
                                                  'deck_featured_${featuredDeck.id}_${DateTime.now().millisecondsSinceEpoch}';
                                              _showDeckDetails(
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
      },
    );
  }

  Widget _buildDailyDeckSection() {
    if (_todaysDeck == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with subtle styling
        Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Daily Challenge',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 500.ms),

        // Daily challenge card
        Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      _hasPlayedDaily
                          ? null
                          : () {
                            _hapticService.lightImpact();
                            // TODO: Play daily deck
                          },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Icon container with subtle glow
                        Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFC107,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Icon(
                                  FontAwesomeIcons.trophy,
                                  color: const Color(0xFFFFC107),
                                  size: 26,
                                ),
                              ),
                            )
                            .animate(
                              onPlay:
                                  (controller) =>
                                      controller.repeat(reverse: true),
                            )
                            .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.05, 1.05),
                              duration: 2000.ms,
                              curve: Curves.easeInOut,
                            ),

                        const SizedBox(width: 16),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _todaysDeck!.title.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Play today\'s special deck!',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: -0.1,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Play button
                        Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    _hasPlayedDaily
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFFC107),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_hasPlayedDaily
                                            ? const Color(0xFF34C759)
                                            : const Color(0xFFFFC107))
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _hasPlayedDaily
                                    ? Icons.check_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 500.ms)
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1, 1),
                              delay: 400.ms,
                              duration: 500.ms,
                              curve: Curves.easeOutBack,
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms)
            .slideY(begin: 0.3, end: 0, delay: 300.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildContinueWatchingSection() {
    if (_recentDecks.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Continue Playing',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  Color(0x00FFFFFF),
                  Color(0x55FFFFFF),
                  Color(0xEEFFFFFF),
                  Colors.white,
                  Colors.white,
                  Color(0xEEFFFFFF),
                  Color(0x55FFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: const [0.0, 0.02, 0.04, 0.06, 0.94, 0.96, 0.98, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _recentDecks.length,
              itemBuilder: (context, index) {
                return _buildContinueCard(_recentDecks[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueCard(Deck deck) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _hapticService.lightImpact();
            _playDeck(deck);
          },
          splashColor: deck.color.withOpacity(0.3),
          highlightColor: deck.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [deck.color, deck.color.withOpacity(0.7)],
                    ),
                  ),
                ),

                // Image if available
                if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      deck.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),

                // Play button
                Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                // Info button (bottom left)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),

                // More button (bottom right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSection({
    required String title,
    required List<Deck> decks,
    IconData? icon,
    Color? iconColor,
    bool showSeeAll = false,
    bool isPremium = false,
  }) {
    if (decks.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (iconColor ?? Colors.white).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? Colors.white,
                        size: 20,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      delay: 200.ms,
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(width: 12),
              ],
              Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 500.ms)
                  .slideY(begin: 0.2, end: 0, delay: 250.ms, duration: 500.ms),
              const Spacer(),
              if (showSeeAll)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _hapticService.lightImpact();
                      if (title.contains('Creations')) {
                        context.push('/custom-decks');
                      } else {
                        context.push('/categories');
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See All',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withOpacity(0.6),
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
            ],
          ),
        ),

        // Deck cards scroll view with elegant gradient mask
        SizedBox(
          height: 200,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  Color(0x00FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0xEEFFFFFF),
                  Colors.white,
                  Colors.white,
                  Color(0xEEFFFFFF),
                  Color(0x66FFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: const [0.0, 0.025, 0.05, 0.08, 0.92, 0.95, 0.975, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20, right: 12),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: decks.length,
              itemBuilder: (context, index) {
                return _buildDeckCard(
                  decks[index],
                  isPremium: isPremium,
                  index: index,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeckCard(Deck deck, {bool isPremium = false, int index = 0}) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final isUnlocked = deckProvider.isDeckUnlocked(deck.id);

    // Create unique hero tag for this specific card instance
    final heroTag =
        'deck_card_${deck.id}_${DateTime.now().millisecondsSinceEpoch}_$index';

    return Hero(
          tag: heroTag,
          createRectTween: (begin, end) {
            return MaterialRectArcTween(begin: begin, end: end);
          },
          child: Container(
            width: 150,
            margin: const EdgeInsets.only(right: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: deck.color.withOpacity(0.2),
                highlightColor: deck.color.withOpacity(0.1),
                onTap: () {
                  _hapticService.lightImpact();
                  if (isPremium && !isUnlocked) {
                    _showPremiumDialog(deck);
                  } else {
                    _showDeckDetails(deck, heroTag: heroTag);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card container
                    Container(
                      height: 200,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background image or color
                            if (deck.imageUrl != null &&
                                deck.imageUrl!.isNotEmpty)
                              Image.network(
                                deck.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: deck.color.withOpacity(0.2),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        deck.icon,
                                        color: deck.color,
                                        size: 40,
                                      ),
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: deck.color.withOpacity(0.15),
                                ),
                                child: Center(
                                  child: Icon(
                                    deck.icon,
                                    color: deck.color,
                                    size: 40,
                                  ),
                                ),
                              ),

                            // Subtle gradient overlay for depth
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.2),
                                  ],
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                            ),

                            // Deck info overlay
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    deck.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${deck.cards.length} cards',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.6),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Premium lock overlay
                            if (isPremium && !isUnlocked)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(
                                          0xFFFFC107,
                                        ).withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      color: Color(0xFFFFC107),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),

                            // Play icon hint (top right)
                            if (!isPremium || isUnlocked)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: deck.color,
                                        size: 20,
                                      ),
                                    )
                                    .animate(delay: (500 + index * 100).ms)
                                    .fadeIn(duration: 300.ms)
                                    .scale(
                                      begin: const Offset(0.6, 0.6),
                                      end: const Offset(1, 1),
                                      duration: 300.ms,
                                      curve: Curves.easeOutBack,
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
          ),
        )
        .animate()
        .fadeIn(delay: (300 + index * 50).ms, duration: 500.ms)
        .slideX(
          begin: 0.3,
          end: 0,
          delay: (300 + index * 50).ms,
          duration: 500.ms,
          curve: Curves.easeOutQuart,
        );
  }

  void _showDeckDetails(Deck deck, {required String heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => DeckDetailsScreen(
              deck: deck,
              heroTag: heroTag,
              onPlay: () => _playDeck(deck),
            ),
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.6),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Premium iOS-style spring animation
          const curve = Curves.fastOutSlowIn;

          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: curve,
            reverseCurve: curve,
          );

          // Subtle slide from bottom (iOS style)
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curvedAnimation);

          // Gentle scale for depth
          final scaleAnimation = Tween<double>(
            begin: 0.96,
            end: 1.0,
          ).animate(curvedAnimation);

          // Smooth fade for elegance
          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curvedAnimation);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          );
        },
      ),
    );
  }

  void _showPremiumDialog(Deck deck) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a1a),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.workspace_premium, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Premium Deck',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Unlock "${deck.name}" and all premium content!',
              style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Implement unlock functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Premium unlock coming soon!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Unlock',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.0),
            Colors.black.withOpacity(0.95),
            Colors.black,
          ],
          stops: const [0.0, 0.2, 1.0],
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: true,
                  onTap: () {},
                ),
                _buildNavItem(
                  icon: Icons.explore_outlined,
                  label: 'New & Hot',
                  isSelected: false,
                  onTap: () {
                    _hapticService.lightImpact();
                    context.push('/categories');
                  },
                ),
                _buildNavItem(
                  icon: Icons.account_circle_outlined,
                  label: 'My Games',
                  isSelected: false,
                  onTap: () {
                    _hapticService.lightImpact();
                    context.push('/custom-decks');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  Icons.emoji_events_rounded,
                  '12',
                  'Games Won',
                  const Color(0xFFFFC107),
                  0,
                ),
                _buildStatDivider(),
                _buildStatItem(
                  Icons.local_fire_department_rounded,
                  '3',
                  'Win Streak',
                  const Color(0xFFFF6B35),
                  1,
                ),
                _buildStatDivider(),
                _buildStatItem(
                  Icons.groups_rounded,
                  '48',
                  'Players Met',
                  const Color(0xFF0A84FF),
                  2,
                ),
                _buildStatDivider(),
                _buildStatItem(
                  Icons.star_rounded,
                  '4.8',
                  'Avg Score',
                  const Color(0xFFBF5AF2),
                  3,
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 500.ms, duration: 700.ms)
        .slideY(begin: 0.2, end: 0, delay: 500.ms, duration: 700.ms);
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
    int index,
  ) {
    return Expanded(
      child: Column(
        children: [
          // Icon with subtle background
          Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              )
              .animate()
              .fadeIn(delay: (600 + index * 100).ms, duration: 500.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                delay: (600 + index * 100).ms,
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),

          const SizedBox(height: 12),

          // Value
          Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              )
              .animate()
              .fadeIn(delay: (650 + index * 100).ms, duration: 500.ms)
              .slideY(
                begin: 0.3,
                end: 0,
                delay: (650 + index * 100).ms,
                duration: 500.ms,
              ),

          const SizedBox(height: 4),

          // Label
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 0.2,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ).animate().fadeIn(delay: (700 + index * 100).ms, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildCreateCustomDeckPrompt() {
    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hapticService.mediumImpact();
                context.push('/custom-deck-create');
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.05),
              highlightColor: Colors.white.withOpacity(0.02),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF1C1C1E),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Subtle gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF3B82F6).withOpacity(0.05),
                              const Color(0xFF8B5CF6).withOpacity(0.08),
                              const Color(0xFF1C1C1E),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        child: Column(
                          children: [
                            // Icon with elegant animation
                            Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFF3B82F6,
                                        ).withOpacity(0.15),
                                        const Color(
                                          0xFF8B5CF6,
                                        ).withOpacity(0.15),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withOpacity(0.15),
                                        blurRadius: 16,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                )
                                .animate(
                                  onPlay:
                                      (controller) =>
                                          controller.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.08, 1.08),
                                  duration: 2000.ms,
                                  curve: Curves.easeInOut,
                                )
                                .then()
                                .shimmer(
                                  duration: 1500.ms,
                                  color: Colors.white.withOpacity(0.1),
                                ),

                            const SizedBox(height: 16),

                            // Title with premium typography
                            Text(
                                  'Create Your Own Deck',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 600.ms)
                                .slideY(
                                  begin: 0.2,
                                  end: 0,
                                  delay: 200.ms,
                                  duration: 600.ms,
                                  curve: Curves.easeOutCubic,
                                ),

                            const SizedBox(height: 8),

                            // Subtitle with elegant opacity
                            Text(
                                  'Make custom decks with your own words and categories!',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.6),
                                    letterSpacing: -0.1,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                                .animate()
                                .fadeIn(delay: 300.ms, duration: 600.ms)
                                .slideY(
                                  begin: 0.2,
                                  end: 0,
                                  delay: 300.ms,
                                  duration: 600.ms,
                                  curve: Curves.easeOutCubic,
                                ),

                            const SizedBox(height: 18),

                            // Premium CTA button
                            Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 0,
                                  child: InkWell(
                                    onTap: () {
                                      _hapticService.lightImpact();
                                      context.push('/custom-deck-create');
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    splashColor: Colors.black.withOpacity(0.1),
                                    highlightColor: Colors.black.withOpacity(
                                      0.05,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.create_rounded,
                                            color: Colors.black,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Create Deck',
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 400.ms, duration: 600.ms)
                                .slideY(
                                  begin: 0.3,
                                  end: 0,
                                  delay: 400.ms,
                                  duration: 600.ms,
                                  curve: Curves.easeOutBack,
                                )
                                .then()
                                .shimmer(
                                  delay: 1000.ms,
                                  duration: 1800.ms,
                                  color: Colors.white.withOpacity(0.3),
                                ),

                            const SizedBox(height: 12),

                            // Feature highlights
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildFeatureTag(
                                  icon: Icons.speed_rounded,
                                  label: 'Quick Setup',
                                  delay: 500,
                                ),
                                const SizedBox(width: 8),
                                _buildFeatureTag(
                                  icon: Icons.palette_outlined,
                                  label: 'Customize',
                                  delay: 600,
                                ),
                                const SizedBox(width: 8),
                                _buildFeatureTag(
                                  icon: Icons.share_rounded,
                                  label: 'Share',
                                  delay: 700,
                                ),
                              ],
                            ),
                          ],
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
        .fadeIn(delay: 100.ms, duration: 800.ms)
        .slideY(
          begin: 0.1,
          end: 0,
          delay: 100.ms,
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          delay: 100.ms,
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildFeatureTag({
    required IconData icon,
    required String label,
    required int delay,
  }) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.7), size: 13),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: delay.ms, duration: 600.ms)
        .slideY(
          begin: 0.3,
          end: 0,
          delay: delay.ms,
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildErrorState(BuildContext context, DeckProvider deckProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a1a), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unable to Load Decks',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please check your internet connection and try again',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      _hapticService.selection();
                      deckProvider.retryLoading();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded),
                        const SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildNoDecksMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No decks available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom scroll behavior for smooth, elegant scrolling
class SmoothScrollBehavior extends ScrollBehavior {
  const SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Remove the default overscroll glow effect for a cleaner look
    return child;
  }
}
