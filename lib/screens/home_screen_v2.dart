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
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _loadDailyDeck();
    _loadRecentDecks();
    
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showTitle) {
        setState(() => _showTitle = true);
      } else if (_scrollController.offset <= 200 && _showTitle) {
        setState(() => _showTitle = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameplayScreen(deck: deck),
      ),
    );
  }

  void _quickPlay() {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    
    // Get a random deck from free decks
    if (deckProvider.freeDecks.isNotEmpty) {
      final randomIndex = DateTime.now().millisecondsSinceEpoch % deckProvider.freeDecks.length;
      final randomDeck = deckProvider.freeDecks[randomIndex];
      
      _hapticService.mediumImpact();
      _playDeck(randomDeck);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No decks available',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Custom app bar
              SliverAppBar(
                expandedHeight: 0,
                pinned: true,
                backgroundColor: _showTitle 
                    ? Colors.black.withOpacity(0.95)
                    : Colors.transparent,
                elevation: 0,
                title: AnimatedOpacity(
                  opacity: _showTitle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    'Heads Up!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                actions: [
                  // Quick Play button - Most useful for a party game
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        _hapticService.lightImpact();
                        _quickPlay();
                      },
                      icon: const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      label: Text(
                        'Quick Play',
                        style: GoogleFonts.poppins(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: Colors.amber.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  // Profile/Stats button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
                    ),
                    onPressed: () {
                      _hapticService.lightImpact();
                      // TODO: Navigate to profile/stats
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with user greeting
                    _buildHeader(),
                    
                    const SizedBox(height: 20),
                    
                    // Category chips
                    _buildCategoryChips(),
                    
                    const SizedBox(height: 20),
                    
                    // Featured deck
                    _buildFeaturedDeck(),
                    
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
                    
                    // Recommended for you
                    Consumer<DeckProvider>(
                      builder: (context, deckProvider, _) {
                        return _buildSection(
                          title: 'Recommended for You',
                          decks: deckProvider.freeDecks.take(5).toList(),
                          icon: Icons.auto_awesome_rounded,
                          iconColor: Colors.purple,
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Party favorites
                    Consumer<DeckProvider>(
                      builder: (context, deckProvider, _) {
                        return _buildSection(
                          title: 'Party Favorites',
                          decks: deckProvider.freeDecks.where((d) => d.cards.length > 15).toList(),
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
          
          // Bottom navigation bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back!',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready for another game?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Stats widget
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '5 Streak',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      {
        'name': 'Popular', 
        'icon': Icons.whatshot_rounded,
        'color': Colors.orange,
      },
      {
        'name': 'Quick Games',
        'icon': Icons.timer_rounded,
        'color': Colors.blue,
      },
      {
        'name': 'Team Play',
        'icon': Icons.groups_rounded,
        'color': Colors.green,
      },
      {
        'name': 'Kids Safe',
        'icon': Icons.child_care_rounded,
        'color': Colors.purple,
      },
    ];
    
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: () {
                  _hapticService.lightImpact();
                  // TODO: Filter by category
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: (category['color'] as Color).withOpacity(0.4),
                      width: 1,
                    ),
                    color: (category['color'] as Color).withOpacity(0.1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        color: category['color'] as Color,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category['name'] as String,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedDeck() {
    return Consumer<DeckProvider>(
      builder: (context, deckProvider, _) {
        if (deckProvider.allDecks.isEmpty) {
          return const SizedBox();
        }
        
        // Get a random featured deck (or the first one)
        final featuredDeck = deckProvider.freeDecks.isNotEmpty 
            ? deckProvider.freeDecks.first
            : deckProvider.allDecks.first;
        
        // Use test image URL or fallback to gradient
        const testImageUrl = 'https://resizing.flixster.com/ZUhHpJCOJmPu7ro7DxecAetusnE=/ems.cHJkLWVtcy1hc3NldHMvdHZzZXJpZXMvNmI5OGY3ZWMtYjY1Mi00NGEwLTgxYmEtNjUyNjRmNGE2MDQ5LmpwZw==';
        final imageUrl = featuredDeck.imageUrl ?? testImageUrl;
        
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 580,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image or gradient
                  if (imageUrl.isNotEmpty)
                    Image.network(
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
                    )
                  else
                    Container(
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
                  
                  // Gradient overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.0, 0.4, 0.65, 0.85, 1.0],
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_rounded, color: Colors.white, size: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_rounded, color: Colors.white, size: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withOpacity(0.4), width: 1),
                          ),
                          child: Text(
                            'Easy',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
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
                                padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () => _playDeck(featuredDeck),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 32,
                                            color: Colors.black,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Play',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).animate()
                                  .fadeIn(delay: 600.ms, duration: 400.ms)
                                  .slideY(begin: 0.1, end: 0, delay: 600.ms, duration: 400.ms),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // My List button - Elegant glass morphism
                              Expanded(
                                child: Material(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () {
                                      _hapticService.lightImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Added to My List',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          duration: const Duration(seconds: 1),
                                          backgroundColor: Colors.black.withOpacity(0.8),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          margin: const EdgeInsets.all(20),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.add,
                                            size: 28,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'My List',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).animate()
                                  .fadeIn(delay: 700.ms, duration: 400.ms)
                                  .slideY(begin: 0.1, end: 0, delay: 700.ms, duration: 400.ms),
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
        ).animate()
          .fadeIn(duration: 1000.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.97, 0.97), 
            end: const Offset(1, 1),
            duration: 1200.ms,
            curve: Curves.easeOutCubic,
          );
      },
    );
  }


  Widget _buildDailyDeckSection() {
    if (_todaysDeck == null) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Daily Challenge',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.withOpacity(0.25),
                Colors.orange.withOpacity(0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.trophy,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _todaysDeck!.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Play today\'s special deck!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _hasPlayedDaily
                    ? null
                    : () {
                        _hapticService.lightImpact();
                        // TODO: Play daily deck
                      },
                icon: Icon(
                  _hasPlayedDaily ? Icons.check_circle : Icons.play_circle_filled,
                  color: _hasPlayedDaily ? Colors.green : Colors.amber,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
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
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _recentDecks.length,
            itemBuilder: (context, index) {
              return _buildContinueCard(_recentDecks[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContinueCard(Deck deck) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          _hapticService.lightImpact();
          _playDeck(deck);
        },
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
                    colors: [
                      deck.color,
                      deck.color.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              
              // Image if available
              if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    deck.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
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
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? Colors.white).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor ?? Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (showSeeAll)
                TextButton(
                  onPressed: () {
                    _hapticService.lightImpact();
                    if (title.contains('Creations')) {
                      context.push('/custom-decks');
                    } else {
                      context.push('/categories');
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withOpacity(0.6),
                        size: 16,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: decks.length,
            itemBuilder: (context, index) {
              return _buildDeckCard(decks[index], isPremium: isPremium);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeckCard(Deck deck, {bool isPremium = false}) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final isUnlocked = deckProvider.isDeckUnlocked(deck.id);
    
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          _hapticService.lightImpact();
          if (isPremium && !isUnlocked) {
            _showPremiumDialog(deck);
          } else {
            _showDeckDetails(deck);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card image/icon with elegant rounded corners
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 180,
                width: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      deck.color.withOpacity(0.9),
                      deck.color.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: deck.color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // If deck has imageUrl, show it
                    if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                      Image.network(
                        deck.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              deck.icon,
                              color: Colors.white,
                              size: 48,
                            ),
                          );
                        },
                      )
                    else
                      Center(
                        child: Icon(
                          deck.icon,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    
                    // Premium lock badge
                    if (isPremium && !isUnlocked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.amber,
                            size: 16,
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
    ).animate().fadeIn(duration: 400.ms, delay: (30 * deck.cards.length % 300).ms);
  }

  void _showDeckDetails(Deck deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              deck.color.withOpacity(0.95),
              deck.color.withOpacity(0.85),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(deck.icon, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              deck.name,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deck.description,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${deck.cards.length} cards',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _playDeck(deck);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: deck.color,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Play Now',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumDialog(Deck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement unlock functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premium unlock coming soon!')),
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
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.2),
            Colors.blue.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.emoji_events_rounded, '12', 'Games Won', Colors.amber),
          _buildStatItem(Icons.local_fire_department_rounded, '3', 'Win Streak', Colors.orange),
          _buildStatItem(Icons.groups_rounded, '48', 'Players Met', Colors.blue),
          _buildStatItem(Icons.star_rounded, '4.8', 'Avg Score', Colors.purple),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms);
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateCustomDeckPrompt() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.2),
            Colors.purple.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Create Your Own Deck',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make custom decks with your own words and categories!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _hapticService.lightImpact();
              context.push('/custom-deck-create');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              'Create Deck',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

