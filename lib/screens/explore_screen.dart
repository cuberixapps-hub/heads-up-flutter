import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import 'deck_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  final String? category;
  
  ExploreScreen({super.key, this.category});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    // Add search listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A1C), Color(0xFF000000)],
                stops: [0.0, 0.5],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom app bar with search
                SliverToBoxAdapter(child: _buildHeader()),

                // Category sections or single category grid
                Consumer<DeckProvider>(
                  builder: (context, deckProvider, _) {
                    // If a specific category is selected, show filtered/sorted decks
                    if (widget.category != null) {
                      final decks = _getFilteredDecksForCategory(widget.category!, deckProvider);
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final deck = decks[index];
                              return _buildDeckCard(deck, 0, index);
                            },
                            childCount: decks.length,
                          ),
                        ),
                      );
                    }
                    
                    // Show all categories or search results
                    if (_searchQuery.isNotEmpty) {
                      // Show search results in grid
                      final searchResults = deckProvider.allDecks
                          .where((deck) => _matchesSearch(deck))
                          .toList();
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final deck = searchResults[index];
                              return _buildDeckCard(deck, 0, index);
                            },
                            childCount: searchResults.length,
                          ),
                        ),
                      );
                    }
                    
                    // Show all categories
                    return SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildCategorySection(
                            'Trending Now',
                            Icons.local_fire_department_rounded,
                            _getTrendingDecks(deckProvider),
                            const Color(0xFFFF6B6B),
                            0,
                          ),
                          _buildCategorySection(
                            'Popular This Week',
                            Icons.star_rounded,
                            _getPopularDecks(deckProvider),
                            const Color(0xFFFFB800),
                            1,
                          ),
                          _buildCategorySection(
                            'New Releases',
                            Icons.auto_awesome,
                            _getNewReleases(deckProvider),
                            const Color(0xFF00D4FF),
                            2,
                          ),
                          _buildCategorySection(
                            'Premium Collection',
                            Icons.workspace_premium_rounded,
                            _getPremiumDecks(deckProvider),
                            const Color(0xFF7C3AED),
                            3,
                          ),
                          _buildCategorySection(
                            'Family Fun',
                            Icons.family_restroom_rounded,
                            _getFamilyFunDecks(deckProvider),
                            const Color(0xFF10B981),
                            4,
                          ),
                          _buildCategorySection(
                            'Party Games',
                            Icons.celebration_rounded,
                            _getPartyGamesDecks(deckProvider),
                            const Color(0xFFF59E0B),
                            5,
                          ),
                          const SizedBox(height: 100), // Bottom padding
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          // Header with back button and title
          Row(
            children: [
              // Back button
              Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _hapticService.lightImpact();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.2, end: 0, duration: 500.ms),

              const SizedBox(width: 16),

              // Title
              Expanded(
                child: Text(
                      widget.category ?? 'Explore',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 600.ms)
                    .slideY(begin: -0.2, end: 0, duration: 600.ms),
              ),

              // Filter button (only show when not viewing a specific category)
              if (widget.category == null)
                Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _hapticService.lightImpact();
                          // TODO: Implement filter
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.2, end: 0, duration: 500.ms),
            ],
          ),

          const SizedBox(height: 20),

          // Search bar
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
           height: 48,
           padding: const EdgeInsets.symmetric(horizontal: 16),
           decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(20),
             gradient: LinearGradient(
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
               colors: [
                 const Color(0xFF9B59B6).withOpacity(0.18),
                 const Color(0xFF9B59B6).withOpacity(0.08),
               ],
             ),
             border: Border.all(
               color: const Color(0xFF9B59B6).withOpacity(0.4),
               width: 1.2,
             ),
           ),
           child: Row(
             children: [
               ShaderMask(
                 shaderCallback:
                     (bounds) => LinearGradient(
                       colors: [
                         const Color(0xFF9B59B6).withOpacity(0.9),
                         const Color(0xFF9B59B6).withOpacity(0.6),
                       ],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                     ).createShader(bounds),
                 child: const Icon(
                   Icons.search_rounded,
                   color: Colors.white,
                   size: 20,
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: TextField(
                   controller: _searchController,
                   focusNode: _searchFocusNode,
                   style: GoogleFonts.inter(
                     color: Colors.white,
                     fontSize: 15,
                     fontWeight: FontWeight.w400,
                   ),
                   decoration: InputDecoration(
                     hintText: 'Search for decks',
                     hintStyle: GoogleFonts.inter(
                       color: Colors.white.withOpacity(0.4),
                       fontSize: 15,
                       fontWeight: FontWeight.w400,
                     ),
                     border: InputBorder.none,
                     contentPadding: EdgeInsets.zero,
                     isDense: true,
                   ),
                   cursorColor: const Color(0xFF9B59B6),
                 ),
               ),
               if (_searchQuery.isNotEmpty)
                 Material(
                   color: Colors.transparent,
                   child: InkWell(
                     onTap: () {
                       _hapticService.lightImpact();
                       _searchController.clear();
                     },
                     borderRadius: BorderRadius.circular(12),
                     child: Padding(
                       padding: const EdgeInsets.all(4),
                       child: Icon(
                         Icons.close_rounded,
                         color: Colors.white.withOpacity(0.6),
                         size: 18,
                       ),
                     ),
                   ),
                 ),
             ],
           ),
         )
         .animate()
         .fadeIn(delay: 200.ms, duration: 600.ms)
         .scale(
           begin: const Offset(0.95, 0.95),
           end: const Offset(1, 1),
           duration: 500.ms,
           curve: Curves.easeOutCubic,
         );
  }

  Widget _buildCategorySection(
    String title,
    IconData icon,
    List<Deck> decks,
    Color accentColor,
    int sectionIndex,
  ) {
    if (decks.isEmpty) return const SizedBox.shrink();

    return Container(
          margin: const EdgeInsets.only(bottom: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              _buildSectionHeader(title, icon, accentColor, sectionIndex),

              const SizedBox(height: 20),

              // Deck grid
              _buildDeckGrid(decks.take(6).toList(), sectionIndex),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (300 + sectionIndex * 100).ms, duration: 600.ms)
        .slideY(
          begin: 0.1,
          end: 0,
          delay: (300 + sectionIndex * 100).ms,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color accentColor,
    int sectionIndex,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Icon with glow
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
            ),
            child: Center(child: Icon(icon, color: accentColor, size: 18)),
          ),

          const SizedBox(width: 10),

          // Title
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // See all button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hapticService.lightImpact();
                // Navigate to category screen with filtered decks
                context.push('/categories');
              },
              borderRadius: BorderRadius.circular(16),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckGrid(List<Deck> decks, int sectionIndex) {
    return SizedBox(
      height: 320, // Fixed height for 2 rows
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: decks.length,
        itemBuilder: (context, index) {
          final deck = decks[index];
          return _buildDeckCard(deck, sectionIndex, index);
        },
      ),
    );
  }

  Widget _buildDeckCard(Deck deck, int sectionIndex, int cardIndex) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final isUnlocked = deckProvider.isDeckUnlocked(deck.id);
    final isPremium = deck.isPremium;
    
    // Create unique hero tag
    final heroTag = 'explore_deck_${deck.id}_${sectionIndex}_$cardIndex';

    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
           onTap: () {
             _hapticService.selection();
             _navigateToDeckDetails(deck, heroTag: heroTag);
           },
           child: Container(
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
                  if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                    Image.network(
                      deck.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: deck.color.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Icon(deck.icon, color: deck.color, size: 40),
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
                        child: Icon(deck.icon, color: deck.color, size: 40),
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
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),

                  // Deck info
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
                              color: const Color(0xFFFFC107).withOpacity(0.3),
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
                      ),
                    ),
                 ],
               ),
             ),
           ).animate()
           .fadeIn(
             delay: (400 + sectionIndex * 100 + cardIndex * 50).ms,
             duration: 500.ms,
           )
           .scale(
             begin: const Offset(0.9, 0.9),
             end: const Offset(1, 1),
             delay: (400 + sectionIndex * 100 + cardIndex * 50).ms,
             duration: 500.ms,
             curve: Curves.easeOutCubic,
           ),
        ),
      ),
    );
  }

  void _navigateToDeckDetails(Deck deck, {required String heroTag}) {
    _hapticService.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => DeckDetailsScreen(
              deck: deck,
              heroTag: heroTag,
              onPlay: () {
                Navigator.of(context).pop();
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.02);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation.drive(
                Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // Category filtering methods with search support
  List<Deck> _getFilteredDecksForCategory(String category, DeckProvider provider) {
    // Get category-specific decks
    final categoryDecks = _getDecksForCategory(category, provider);
    
    // If no search query, return category decks
    if (_searchQuery.isEmpty) {
      return categoryDecks;
    }
    
    // Filter category decks by search query
    final filteredCategoryDecks = categoryDecks.where((deck) => _matchesSearch(deck)).toList();
    
    // Get other decks that match search but aren't in category
    final categoryDeckIds = categoryDecks.map((d) => d.id).toSet();
    final otherMatchingDecks = provider.allDecks
        .where((deck) => !categoryDeckIds.contains(deck.id) && _matchesSearch(deck))
        .toList();
    
    // Return category decks first, then other matching decks
    return [...filteredCategoryDecks, ...otherMatchingDecks];
  }
  
  bool _matchesSearch(Deck deck) {
    final lowerName = deck.name.toLowerCase();
    final lowerDesc = deck.description.toLowerCase();
    final lowerTags = deck.tags.map((t) => t.toLowerCase()).toList();
    
    return lowerName.contains(_searchQuery) ||
        lowerDesc.contains(_searchQuery) ||
        lowerTags.any((tag) => tag.contains(_searchQuery)) ||
        deck.cards.any((card) => card.toLowerCase().contains(_searchQuery));
  }
  
  List<Deck> _getDecksForCategory(String category, DeckProvider provider) {
    switch (category) {
      case 'Trending Now':
        return _getTrendingDecks(provider);
      case 'Popular This Week':
        return _getPopularDecks(provider);
      case 'New Releases':
        return _getNewReleases(provider);
      case 'Premium Collection':
        return _getPremiumDecks(provider);
      case 'Family Fun':
        return _getFamilyFunDecks(provider);
      case 'Party Games':
        return _getPartyGamesDecks(provider);
      default:
        return provider.allDecks;
    }
  }

  List<Deck> _getTrendingDecks(DeckProvider provider) {
    return provider.allDecks
        .where((deck) => deck.country == 'TRENDING' || deck.priority <= 10)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  List<Deck> _getPopularDecks(DeckProvider provider) {
    // For now, return top-rated decks based on priority
    return provider.allDecks
        .where((deck) => deck.priority <= 20 && deck.priority > 10)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  List<Deck> _getNewReleases(DeckProvider provider) {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    return provider.allDecks
        .where((deck) => deck.createdAt.isAfter(cutoffDate))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Deck> _getPremiumDecks(DeckProvider provider) {
    return provider.allDecks.where((deck) => deck.isPremium).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  List<Deck> _getFamilyFunDecks(DeckProvider provider) {
    // Filter by tags or specific deck names
    final familyKeywords = ['family', 'kids', 'disney', 'animal', 'cartoon'];
    return provider.allDecks.where((deck) {
      final lowerName = deck.name.toLowerCase();
      final lowerDesc = deck.description.toLowerCase();
      final lowerTags = deck.tags.map((t) => t.toLowerCase()).toList();

      return familyKeywords.any(
        (keyword) =>
            lowerName.contains(keyword) ||
            lowerDesc.contains(keyword) ||
            lowerTags.contains(keyword),
      );
    }).toList();
  }

  List<Deck> _getPartyGamesDecks(DeckProvider provider) {
    // Filter by party-related keywords
    final partyKeywords = ['party', 'adult', 'drinking', 'fun', 'crazy'];
    return provider.allDecks.where((deck) {
      final lowerName = deck.name.toLowerCase();
      final lowerDesc = deck.description.toLowerCase();
      final lowerTags = deck.tags.map((t) => t.toLowerCase()).toList();

      return partyKeywords.any(
        (keyword) =>
            lowerName.contains(keyword) ||
            lowerDesc.contains(keyword) ||
            lowerTags.contains(keyword),
      );
    }).toList();
  }
}
