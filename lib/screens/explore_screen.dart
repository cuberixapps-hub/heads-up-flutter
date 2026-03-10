import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import '../utils/premium_utils.dart';
import '../utils/responsive.dart';
import 'deck_details_screen.dart';

// Shimmer loading widget for skeleton placeholders
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.1));
  }
}

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

  /// Get localized display title for a category key
  String _getCategoryDisplayTitle(String? categoryKey) {
    if (categoryKey == null) return AppLocalizations.of(context)!.explore;

    final l10n = AppLocalizations.of(context)!;

    switch (categoryKey) {
      case 'Trending':
        return l10n.trendingNow;
      case 'Party':
        return l10n.partyMode;
      case 'Quick':
        return l10n.quickGames;
      case 'For You':
        return 'Picked For You'; // Could add to localization
      case 'Favorites':
        return l10n.myFavorites;
      case 'My Decks':
        return l10n.yourCreations;
      case 'Party Favorites':
        return l10n.partyFavorites;
      case 'Premium':
        return l10n.unlockMoreFun;
      default:
        // If it's already a localized title, return as-is
        return categoryKey;
    }
  }

  /// Get icon for a category key
  IconData _getCategoryIcon(String? categoryKey) {
    switch (categoryKey) {
      case 'Trending':
        return Icons.local_fire_department_rounded;
      case 'Party':
        return Icons.celebration_rounded;
      case 'Quick':
        return Icons.bolt_rounded;
      case 'For You':
        return Icons.auto_awesome_rounded;
      case 'Favorites':
        return Icons.star_rounded;
      case 'My Decks':
        return Icons.create_rounded;
      case 'Party Favorites':
        return Icons.celebration_rounded;
      case 'Premium':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  /// Get accent color for a category key
  Color _getCategoryAccentColor(String? categoryKey) {
    switch (categoryKey) {
      case 'Trending':
        return const Color(0xFFFF6B35);
      case 'Party':
        return const Color(0xFFE91E63);
      case 'Quick':
        return const Color(0xFFFFC107);
      case 'For You':
        return const Color(0xFF7C3AED);
      case 'Favorites':
        return const Color(0xFFFFD700);
      case 'My Decks':
        return const Color(0xFF00BCD4);
      case 'Party Favorites':
        return Colors.pink;
      case 'Premium':
        return const Color(0xFFFFB800);
      default:
        return Colors.purple;
    }
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
                    // Show loading skeleton while data is being fetched
                    if (deckProvider.isLoading &&
                        deckProvider.allDecks.isEmpty) {
                      return SliverToBoxAdapter(child: _buildLoadingSkeleton());
                    }

                    // If a specific category is selected, show filtered/sorted decks
                    if (widget.category != null) {
                      final decks = _getFilteredDecksForCategory(
                        widget.category!,
                        deckProvider,
                      );

                      if (decks.isEmpty) {
                        return SliverToBoxAdapter(child: _buildEmptyState());
                      }

                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(20.s, 20.s, 20.s, 100.s),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12.s,
                                mainAxisSpacing: 12.s,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final deck = decks[index];
                            return _buildDeckCard(deck, 0, index);
                          }, childCount: decks.length),
                        ),
                      );
                    }

                    // Show all categories or search results
                    if (_searchQuery.isNotEmpty) {
                      // Show search results in grid
                      final searchResults =
                          deckProvider.allDecks
                              .where((deck) => _matchesSearch(deck))
                              .toList();

                      if (searchResults.isEmpty) {
                        return SliverToBoxAdapter(
                          child: _buildEmptySearchState(),
                        );
                      }

                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(20.s, 20.s, 20.s, 100.s),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12.s,
                                mainAxisSpacing: 12.s,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final deck = searchResults[index];
                            return _buildDeckCard(deck, 0, index);
                          }, childCount: searchResults.length),
                        ),
                      );
                    }

                    // Show all categories
                    final l10n = AppLocalizations.of(context)!;
                    return SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildCategorySection(
                            l10n.trendingNow,
                            Icons.local_fire_department_rounded,
                            _getTrendingDecks(deckProvider),
                            const Color(0xFFFF6B6B),
                            0,
                          ),
                          _buildCategorySection(
                            l10n.popularThisWeek,
                            Icons.star_rounded,
                            _getPopularDecks(deckProvider),
                            const Color(0xFFFFB800),
                            1,
                          ),
                          _buildCategorySection(
                            l10n.newReleases,
                            Icons.auto_awesome,
                            _getNewReleases(deckProvider),
                            const Color(0xFF00D4FF),
                            2,
                          ),
                          _buildCategorySection(
                            l10n.premiumCollection,
                            Icons.workspace_premium_rounded,
                            _getPremiumDecks(deckProvider),
                            const Color(0xFF7C3AED),
                            3,
                          ),
                          _buildCategorySection(
                            l10n.familyFun,
                            Icons.family_restroom_rounded,
                            _getFamilyFunDecks(deckProvider),
                            const Color(0xFF10B981),
                            4,
                          ),
                          _buildCategorySection(
                            l10n.partyGames,
                            Icons.celebration_rounded,
                            _getPartyGamesDecks(deckProvider),
                            const Color(0xFFF59E0B),
                            5,
                          ),
                          SizedBox(height: 100.s), // Bottom padding
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
      padding: EdgeInsets.fromLTRB(20.s, 16.s, 20.s, 24.s),
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
                      borderRadius: BorderRadius.circular(16.s),
                      child: Container(
                        width: 44.s,
                        height: 44.s,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16.s),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                            width: 1.s,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                          size: 20.s,
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.2, end: 0, duration: 500.ms),

              SizedBox(width: 16.s),

              // Category icon (only show when viewing a specific category)
              if (widget.category != null) ...[
                Container(
                      width: 36.s,
                      height: 36.s,
                      decoration: BoxDecoration(
                        color: _getCategoryAccentColor(
                          widget.category,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10.s),
                      ),
                      child: Icon(
                        _getCategoryIcon(widget.category),
                        color: _getCategoryAccentColor(widget.category),
                        size: 20.s,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 500.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      delay: 100.ms,
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                SizedBox(width: 12.s),
              ],

              // Title
              Expanded(
                child: Text(
                      _getCategoryDisplayTitle(widget.category),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24.sp,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Filter coming soon'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16.s),
                        child: Container(
                          width: 44.s,
                          height: 44.s,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16.s),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1.s,
                            ),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: Colors.white.withOpacity(0.7),
                            size: 20.s,
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.2, end: 0, duration: 500.ms),
            ],
          ),

          SizedBox(height: 20.s),

          // Search bar
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
          height: 48.s,
          padding: EdgeInsets.symmetric(horizontal: 16.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.s),
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
              width: 1.2.s,
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
                child: Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 20.s,
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchForDecks,
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.transparent,
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
                    borderRadius: BorderRadius.circular(12.s),
                    child: Padding(
                      padding: EdgeInsets.all(4.s),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.6),
                        size: 18.s,
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
          margin: EdgeInsets.only(bottom: 48.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              _buildSectionHeader(title, icon, accentColor, sectionIndex),

              SizedBox(height: 20.s),

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
      padding: EdgeInsets.symmetric(horizontal: 20.s),
      child: Row(
        children: [
          // Icon with glow
          Container(
            width: 32.s,
            height: 32.s,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8.s),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1.s,
              ),
            ),
            child: Center(child: Icon(icon, color: accentColor, size: 18.s)),
          ),

          SizedBox(width: 10.s),

          // Title
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(width: 8.s),

          // See all button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hapticService.lightImpact();
                // Navigate to category screen with filtered decks
                context.push('/categories');
              },
              borderRadius: BorderRadius.circular(16.s),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.seeAll,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4.s),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 14.s,
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
      height: 320.s, // Fixed height for 2 rows
      child: GridView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20.s),
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12.s,
          mainAxisSpacing: 12.s,
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
    final isPremium = deck.isPremium;
    // Deck is unlocked if: not premium, OR user has premium subscription, OR individually unlocked
    final isUnlocked =
        !isPremium ||
        PremiumUtils.hasPremium ||
        deckProvider.isDeckUnlocked(deck.id);

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
                  borderRadius: BorderRadius.circular(16.s),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.s,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16.s,
                      offset: Offset(0, 6.s),
                      spreadRadius: -4.s,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15.s),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image or color
                      if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: deck.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          memCacheHeight: 400,
                          maxWidthDiskCache: 600,
                          maxHeightDiskCache: 800,
                          placeholder:
                              (context, url) => _buildImagePlaceholder(deck),
                          fadeInDuration: const Duration(milliseconds: 200),
                          fadeOutDuration: const Duration(milliseconds: 100),
                          errorWidget: (context, url, error) {
                            return _buildImageFallback(deck);
                          },
                        )
                      else
                        _buildImageFallback(deck),

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
                        bottom: 12.s,
                        left: 12.s,
                        right: 12.s,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              deck.name,
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.s),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.cardsCount(deck.cards.length),
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
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
                              padding: EdgeInsets.all(16.s),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFFFFC107,
                                  ).withOpacity(0.3),
                                  width: 2.s,
                                ),
                              ),
                              child: Icon(
                                Icons.lock_rounded,
                                color: Color(0xFFFFC107),
                                size: 24.s,
                              ),
                            ),
                          ),
                        ),

                      // Play icon hint (top right)
                      if (!isPremium || isUnlocked)
                        Positioned(
                          top: 8.s,
                          right: 8.s,
                          child: Container(
                            width: 32.s,
                            height: 32.s,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8.s),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: deck.color,
                              size: 20.s,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
              .animate()
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

  // Image placeholder with shimmer effect
  Widget _buildImagePlaceholder(Deck deck) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deck.color.withOpacity(0.2), deck.color.withOpacity(0.1)],
        ),
      ),
      child: Stack(
        children: [
          // Shimmer overlay
          Positioned.fill(
            child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(
                  duration: 1200.ms,
                  color: Colors.white.withOpacity(0.15),
                ),
          ),
          // Icon hint
          Center(
            child: FaIcon(
              deck.icon,
              color: deck.color.withOpacity(0.3),
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  // Image fallback when loading fails or no image
  Widget _buildImageFallback(Deck deck) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deck.color.withOpacity(0.25), deck.color.withOpacity(0.1)],
        ),
      ),
      child: Center(
        child: FaIcon(deck.icon, color: deck.color.withOpacity(0.8), size: 40),
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

  // Loading skeleton widget
  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (sectionIndex) {
        return Container(
          margin: const EdgeInsets.only(bottom: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header skeleton
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _ShimmerBox(width: 32, height: 32, borderRadius: 8),
                    const SizedBox(width: 10),
                    _ShimmerBox(width: 140, height: 24, borderRadius: 6),
                    const Spacer(),
                    _ShimmerBox(width: 60, height: 20, borderRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Grid skeleton
              SizedBox(
                height: 320,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) => _buildSkeletonCard(),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // Skeleton card widget
  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Stack(
        children: [
          // Background shimmer
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.03),
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.03),
                        ],
                      ),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    duration: 1500.ms,
                    color: Colors.white.withOpacity(0.05),
                  ),
            ),
          ),
          // Text placeholders at bottom
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: 80, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                _ShimmerBox(width: 50, height: 10, borderRadius: 4),
              ],
            ),
          ),
          // Play icon placeholder
          Positioned(
            top: 8,
            right: 8,
            child: _ShimmerBox(width: 32, height: 32, borderRadius: 8),
          ),
        ],
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noDecksFound,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noDecksInCategory,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Empty search state widget
  Widget _buildEmptySearchState() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noResultsFound,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tryDifferentKeywords,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Category filtering methods with search support
  List<Deck> _getFilteredDecksForCategory(
    String category,
    DeckProvider provider,
  ) {
    // Get category-specific decks
    final categoryDecks = _getDecksForCategory(category, provider);

    // If no search query, return category decks
    if (_searchQuery.isEmpty) {
      return categoryDecks;
    }

    // Filter category decks by search query
    final filteredCategoryDecks =
        categoryDecks.where((deck) => _matchesSearch(deck)).toList();

    // Get other decks that match search but aren't in category
    final categoryDeckIds = categoryDecks.map((d) => d.id).toSet();
    final otherMatchingDecks =
        provider.allDecks
            .where(
              (deck) =>
                  !categoryDeckIds.contains(deck.id) && _matchesSearch(deck),
            )
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
    final l10n = AppLocalizations.of(context)!;

    // Handle category keys from home screen
    if (category == 'Trending' || category == l10n.trendingNow) {
      return _getTrendingDecks(provider);
    } else if (category == 'Party' || category == l10n.partyMode) {
      return _getPartyModeDecks(provider);
    } else if (category == 'Quick' || category == l10n.quickGames) {
      return _getQuickDecks(provider);
    } else if (category == 'For You') {
      return _getForYouDecks(provider);
    } else if (category == 'Favorites' || category == l10n.myFavorites) {
      return provider.favoriteDecksAsList;
    } else if (category == 'My Decks' || category == l10n.yourCreations) {
      return provider.customDecks;
    } else if (category == 'Party Favorites' ||
        category == l10n.partyFavorites) {
      return _getPartyFavoritesDecks(provider);
    } else if (category == 'Premium' ||
        category == l10n.premiumCollection ||
        category == l10n.unlockMoreFun) {
      return _getPremiumDecks(provider);
    } else if (category == l10n.popularThisWeek) {
      return _getPopularDecks(provider);
    } else if (category == l10n.newReleases) {
      return _getNewReleases(provider);
    } else if (category == l10n.familyFun) {
      return _getFamilyFunDecks(provider);
    } else if (category == l10n.partyGames) {
      return _getPartyGamesDecks(provider);
    } else {
      return provider.allDecks;
    }
  }

  List<Deck> _getPartyModeDecks(DeckProvider provider) {
    // Filter by party-related keywords for party mode
    final partyKeywords = ['party', 'fun', 'group', 'social', 'friends'];
    final List<Deck> partyDecks =
        provider.allDecks.where((deck) {
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

    // Also include decks with many cards (good for parties)
    final largeDecks =
        provider.allDecks.where((d) => d.cards.length > 20).toList();
    // Combine using a Set to remove duplicates, then convert back to List
    final Set<Deck> combinedSet = {...partyDecks, ...largeDecks};
    final List<Deck> combinedDecks = combinedSet.toList();
    combinedDecks.sort((a, b) => a.priority.compareTo(b.priority));
    return combinedDecks;
  }

  List<Deck> _getQuickDecks(DeckProvider provider) {
    // Quick games are those with fewer cards (faster to play)
    return provider.allDecks.where((deck) => deck.cards.length <= 15).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  List<Deck> _getForYouDecks(DeckProvider provider) {
    // Personalized recommendations based on user's country and preferences
    final userCountry = provider.userCountryCode;
    final List<Deck> forYouDecks = [];

    // First, add country-specific decks
    for (final deck in provider.allDecks) {
      if (deck.effectiveCountries.contains(userCountry)) {
        forYouDecks.add(deck);
      }
    }

    // Then add universal decks
    for (final deck in provider.allDecks) {
      if (!forYouDecks.contains(deck) &&
          deck.effectiveCountries.contains('UNIVERSAL')) {
        forYouDecks.add(deck);
      }
    }

    // Sort by priority
    forYouDecks.sort((a, b) => a.priority.compareTo(b.priority));
    return forYouDecks;
  }

  List<Deck> _getPartyFavoritesDecks(DeckProvider provider) {
    // Party favorites: free decks with more than 15 cards
    return provider.freeDecks.where((d) => d.cards.length > 15).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
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
