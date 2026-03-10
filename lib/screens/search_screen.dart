import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import '../services/local_storage_service.dart';
import '../services/share_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';
import 'deck_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final HapticService _hapticService = HapticService();
  final ScrollController _scrollController = ScrollController();
  final LocalStorageService _storageService = LocalStorageService();

  List<Deck> _filteredDecks = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  late AnimationController _animationController;
  late AnimationController _textFieldAnimationController;
  late Animation<double> _textFieldAnimation;
  late AnimationController _heroAnimationController;
  late Animation<double> _heroAnimation;

  // Design tokens
  static const _primaryAccent = Color(0xFF6366F1);
  static const _secondaryAccent = Color(0xFFA78BFA);
  static const _cardColor = Color(0xFF262626);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _textFieldAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _textFieldAnimation = CurvedAnimation(
      parent: _textFieldAnimationController,
      curve: Curves.easeOutCubic,
    );

    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _heroAnimation = CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Auto-focus with elegant delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
        _animationController.forward();
        _textFieldAnimationController.forward();
        _heroAnimationController.forward();
      }
    });

    _searchController.addListener(_onSearchChanged);

    // Initialize with trending decks and load recent searches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deckProvider = Provider.of<DeckProvider>(context, listen: false);
      setState(() {
        _filteredDecks = deckProvider.allDecks;
      });
      _loadRecentSearches();
    });
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _storageService.loadRecentSearches();
    if (mounted) {
      setState(() {
        _recentSearches = searches;
      });
    }
  }

  Future<void> _saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _storageService.addToRecentSearches(query.trim());
    await _loadRecentSearches();
  }

  Future<void> _removeRecentSearch(String query) async {
    _hapticService.lightImpact();
    await _storageService.removeFromRecentSearches(query);
    await _loadRecentSearches();
  }

  Future<void> _clearAllRecentSearches() async {
    _hapticService.mediumImpact();
    await _storageService.clearRecentSearches();
    await _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    _textFieldAnimationController.dispose();
    _heroAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);

    setState(() {
      _isSearching = query.isNotEmpty;

      if (query.isEmpty) {
        _filteredDecks = deckProvider.allDecks;
      } else {
        _filteredDecks =
            deckProvider.allDecks.where((deck) {
              // Search in name, description, tags, and cards
              final nameMatch = deck.name.toLowerCase().contains(query);
              final descriptionMatch = deck.description.toLowerCase().contains(
                query,
              );
              final tagsMatch = deck.tags.any(
                (tag) => tag.toLowerCase().contains(query),
              );
              final cardsMatch = deck.cards.any(
                (card) => card.toLowerCase().contains(query),
              );

              return nameMatch || descriptionMatch || tagsMatch || cardsMatch;
            }).toList();
      }
    });
  }

  void _clearSearch() {
    _hapticService.lightImpact();
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    _hapticService.lightImpact();
    _searchFocusNode.unfocus();
    Navigator.of(context).pop();
  }

  void _navigateToDeckDetails(Deck deck, {String? heroTag}) {
    _hapticService.mediumImpact();
    // Save the current search query if there is one
    if (_searchController.text.trim().isNotEmpty) {
      _saveSearch(_searchController.text);
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => DeckDetailsScreen(
              deck: deck,
              heroTag: heroTag ?? 'search_deck_${deck.id}',
              onPlay: () {
                Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: _primaryAccent,
          secondary: _secondaryAccent,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Subtle gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.5, -0.8),
                  radius: 1.5,
                  colors: [Color(0xFF0A0A0A), Colors.black],
                ),
              ),
            ),

            // Noise texture overlay
            Opacity(
              opacity: 0.03,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/noise.png'),
                    repeat: ImageRepeat.repeat,
                    opacity: 0.02,
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Modern search header
                  _buildModernSearchHeader(),

                  // Results with blur effect
                  Expanded(
                    child: Stack(
                      children: [
                        _buildSearchResults(),

                        // Top gradient fade
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 20.s,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black,
                                  Colors.black.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSearchHeader() {
    // Responsive values based on iPhone 16 Pro Max baseline
    final horizontalPadding = 20.s;
    final topPadding = 16.s;
    final bottomPadding = 20.s;
    final backButtonSize = 44.s;
    final backButtonRadius = 16.s;
    final backIconSize = 20.s;
    final spaceBetweenButtonAndField = 16.s;
    final searchFieldRadius = 24.s;
    final searchFieldHorizontalPadding = 16.s;
    final searchFieldVerticalPadding = 12.s;
    final searchFieldHeight = 24.s;
    final searchIconSize = 20.s;
    final searchTextSize = 16.sp;
    final clearButtonPadding = 6.s;
    final clearIconSize = 18.s;
    final iconToTextSpace = 16.s;
    
    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, bottomPadding),
      child: Column(
        children: [
          Row(
            children: [
              // Modern back button
              AnimatedBuilder(
                    animation: _textFieldAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.9 + (_textFieldAnimation.value * 0.1),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _closeSearch,
                            borderRadius: BorderRadius.circular(backButtonRadius),
                            child: Container(
                              width: backButtonSize,
                              height: backButtonSize,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(backButtonRadius),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white70,
                                size: backIconSize,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideX(
                    begin: -0.2,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),

              SizedBox(width: spaceBetweenButtonAndField),

              // Premium Hero search field with enhanced animations
              Expanded(
                    child: Hero(
                      tag: 'search_chip',
                      placeholderBuilder: (context, heroSize, child) {
                        // Return a placeholder that maintains visibility during hero flight
                        const searchColor = Color(0xFF9B59B6);
                        return Container(
                          width: heroSize.width,
                          height: heroSize.height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(searchFieldRadius),
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
                          ),
                        );
                      },
                      flightShuttleBuilder: (
                        BuildContext flightContext,
                        Animation<double> animation,
                        HeroFlightDirection flightDirection,
                        BuildContext fromHeroContext,
                        BuildContext toHeroContext,
                      ) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final double progress = animation.value;

                            // Custom easing for premium feel
                            final double easedProgress = Curves.easeInOutCubic
                                .transform(progress);
                            final double elasticProgress = Curves.elasticOut
                                .transform(progress);

                            // Match home screen chip color
                            const searchColor = Color(0xFF9B59B6);

                            return Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: searchFieldHorizontalPadding,
                                  vertical: searchFieldVerticalPadding,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(searchFieldRadius),
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
                                      blurRadius: 10.s + (10.s * easedProgress),
                                      offset: Offset(0, 3.s),
                                    ),
                                    if (easedProgress > 0.3)
                                      BoxShadow(
                                        color: searchColor.withOpacity(
                                          0.15 * (easedProgress - 0.3) / 0.7,
                                        ),
                                        blurRadius: 20.s,
                                        spreadRadius: 2.s,
                                      ),
                                  ],
                                ),
                                child: SizedBox(
                                  height: searchFieldHeight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Transform.scale(
                                        scale: 0.95 + (0.05 * elasticProgress),
                                        child: ShaderMask(
                                          shaderCallback:
                                              (bounds) => LinearGradient(
                                                colors: [
                                                  searchColor.withOpacity(0.9),
                                                  searchColor.withOpacity(0.6),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(bounds),
                                          child: Icon(
                                            Icons.search_rounded,
                                            color: Colors.white,
                                            size: searchIconSize,
                                          ),
                                        ),
                                      ),
                                      if (progress > 0.2)
                                        Flexible(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: iconToTextSpace,
                                            ),
                                            child: Opacity(
                                              opacity: (progress - 0.2) / 0.8,
                                              child: Text(
                                                AppLocalizations.of(context)!.searchForDecks,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  fontSize: searchTextSize,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _textFieldAnimation,
                            _heroAnimation,
                          ]),
                          builder: (context, child) {
                            // Match home screen chip color
                            const searchColor = Color(0xFF9B59B6);

                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: searchFieldHorizontalPadding,
                                vertical: searchFieldVerticalPadding,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(searchFieldRadius),
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
                                    blurRadius:
                                        10.s + (10.s * _heroAnimation.value),
                                    offset: Offset(0, 3.s),
                                  ),
                                  if (_heroAnimation.value > 0.3)
                                    BoxShadow(
                                      color: searchColor.withOpacity(
                                        0.15 *
                                            (_heroAnimation.value - 0.3) /
                                            0.7,
                                      ),
                                      blurRadius: 20.s,
                                      spreadRadius: 2.s,
                                    ),
                                ],
                              ),
                              child: SizedBox(
                                height: searchFieldHeight,
                                child: Row(
                                  children: [
                                    // Match home screen icon exactly
                                    AnimatedBuilder(
                                      animation: _heroAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale:
                                              0.95 +
                                              (0.05 * _heroAnimation.value),
                                          child: ShaderMask(
                                            shaderCallback:
                                                (bounds) => LinearGradient(
                                                  colors: [
                                                    searchColor.withOpacity(
                                                      0.9,
                                                    ),
                                                    searchColor.withOpacity(
                                                      0.6,
                                                    ),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ).createShader(bounds),
                                            child: Icon(
                                              Icons.search_rounded,
                                              color: Colors.white,
                                              size: searchIconSize,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    SizedBox(width: iconToTextSpace),

                                    // Search field with smooth fade-in
                                    Expanded(
                                      child: AnimatedBuilder(
                                        animation: _heroAnimation,
                                        builder: (context, child) {
                                          return Opacity(
                                            opacity: _heroAnimation.value,
                                            child: TextField(
                                              controller: _searchController,
                                              focusNode: _searchFocusNode,
                                              maxLines: 1,
                                              textAlignVertical:
                                                  TextAlignVertical.center,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: searchTextSize,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: 0.2,
                                                height: 1.0,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: AppLocalizations.of(context)!.searchForDecks,
                                                hintStyle: GoogleFonts.inter(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  fontSize: searchTextSize,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                              cursorColor: searchColor,
                                              cursorWidth: 2,
                                              cursorHeight: 20.s,
                                              cursorRadius:
                                                  const Radius.circular(2),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // Premium clear button
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      switchInCurve: Curves.easeOutBack,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child:
                                          _searchController.text.isNotEmpty
                                              ? Material(
                                                key: const ValueKey(
                                                  'clear_button',
                                                ),
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: _clearSearch,
                                                  borderRadius:
                                                      BorderRadius.circular(12.s),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.all(clearButtonPadding),
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      color: searchColor
                                                          .withOpacity(0.7),
                                                      size: clearIconSize,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              : const SizedBox.shrink(
                                                key: ValueKey('empty'),
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 500.ms)
                  .slideX(
                    begin: 0.1,
                    end: 0,
                    delay: 100.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    // Check if decks are still loading
    final deckProvider = Provider.of<DeckProvider>(context, listen: true);

    if (deckProvider.isLoading) {
      return _buildSkeletonLoader();
    }

    if (!_isSearching && _searchController.text.isEmpty) {
      return _buildModernSearchSuggestions();
    }

    if (_filteredDecks.isEmpty) {
      return _buildModernNoResults();
    }

    // Modern results grid with 3 items per row
    // Responsive values
    final gridHorizontalPadding = 20.s;
    final gridBottomPadding = 20.s;
    final gridCrossAxisSpacing = 12.s;
    final gridMainAxisSpacing = 12.s;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(gridHorizontalPadding, 0, gridHorizontalPadding, gridBottomPadding),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: gridCrossAxisSpacing,
            mainAxisSpacing: gridMainAxisSpacing,
          ),
          itemCount: _filteredDecks.length,
          itemBuilder: (context, index) {
            final deck = _filteredDecks[index];
            return _buildModernDeckGridCard(deck, index);
          },
        );
      },
    );
  }

  Widget _buildModernSearchSuggestions() {
    final l10n = AppLocalizations.of(context)!;
    
    // Responsive values based on iPhone 16 Pro Max baseline
    final horizontalPadding = 20.s;
    final bottomPadding = 20.s;
    final titleFontSize = 20.sp;
    final subtitleFontSize = 14.sp;
    final titleToSubtitleSpace = 4.s;
    final subtitleToPillsSpace = 24.s;
    final pillSpacing = 12.s;
    final pillRunSpacing = 12.s;
    final pillHeight = 48.s;
    final pillHorizontalPadding = 20.s;
    final pillBorderRadius = 14.s;
    final pillIconSize = 20.s;
    final pillIconToTextSpace = 10.s;
    final pillTextSize = 14.sp;
    final sectionSpacing = 40.s;
    final recentSearchesTitleSize = 18.sp;
    final clearAllTextSize = 13.sp;
    final clearAllHorizontalPadding = 12.s;
    final clearAllVerticalPadding = 6.s;
    final clearAllBorderRadius = 8.s;
    final recentToItemsSpace = 16.s;
    
    final categories = [
      {
        'icon': Icons.local_fire_department_rounded,
        'text': l10n.trending,
        'gradient': [const Color(0xFFFF6B6B), const Color(0xFFFF8C42)],
      },
      {
        'icon': Icons.movie_rounded,
        'text': l10n.movies,
        'gradient': [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      },
      {
        'icon': Icons.music_note_rounded,
        'text': l10n.music,
        'gradient': [const Color(0xFF06BEB6), const Color(0xFF48B1BF)],
      },
      {
        'icon': Icons.sports_esports_rounded,
        'text': l10n.gaming,
        'gradient': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      },
      {
        'icon': Icons.public_rounded,
        'text': l10n.world,
        'gradient': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      },
      {
        'icon': Icons.favorite_rounded,
        'text': l10n.romance,
        'gradient': [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      },
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending searches section
          Text(
                AppLocalizations.of(context)!.trendingSearches,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms, duration: 600.ms)
              .slideY(begin: 0.1, end: 0, duration: 600.ms),

          SizedBox(height: titleToSubtitleSpace),

          Text(
            AppLocalizations.of(context)!.popularCategoriesRightNow,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: subtitleFontSize,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 600.ms),

          SizedBox(height: subtitleToPillsSpace),

          // Category pills
          Wrap(
            spacing: pillSpacing,
            runSpacing: pillRunSpacing,
            children:
                categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;

                  return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _hapticService.selection();
                            _searchController.text = category['text'] as String;
                          },
                          borderRadius: BorderRadius.circular(pillBorderRadius),
                          child: Container(
                            height: pillHeight,
                            padding: EdgeInsets.symmetric(horizontal: pillHorizontalPadding),
                            decoration: BoxDecoration(
                              color: _cardColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(pillBorderRadius),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback:
                                      (bounds) => LinearGradient(
                                        colors:
                                            category['gradient'] as List<Color>,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                  child: Icon(
                                    category['icon'] as IconData,
                                    color: Colors.white,
                                    size: pillIconSize,
                                  ),
                                ),
                                SizedBox(width: pillIconToTextSpace),
                                Text(
                                  category['text'] as String,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: pillTextSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: (300 + index * 60).ms, duration: 600.ms)
                      .slideY(
                        begin: 0.1,
                        end: 0,
                        delay: (300 + index * 60).ms,
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                      );
                }).toList(),
          ),

          SizedBox(height: sectionSpacing),

          // Recent searches header with clear button
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.recentSearches,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: recentSearchesTitleSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearAllRecentSearches,
                    borderRadius: BorderRadius.circular(clearAllBorderRadius),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: clearAllHorizontalPadding,
                        vertical: clearAllVerticalPadding,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.clearAll,
                        style: GoogleFonts.inter(
                          color: _primaryAccent.withOpacity(0.8),
                          fontSize: clearAllTextSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

            SizedBox(height: recentToItemsSpace),

            // Recent search items
            ..._buildRecentSearchItems(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRecentSearchItems() {
    // Responsive values based on iPhone 16 Pro Max baseline
    final itemBottomMargin = 12.s;
    final itemBorderRadius = 12.s;
    final itemHorizontalPadding = 16.s;
    final itemVerticalPadding = 14.s;
    final historyIconSize = 18.s;
    final iconToTextSpace = 12.s;
    final searchTextSize = 15.sp;
    final textToCloseSpace = 8.s;
    final closeButtonPadding = 4.s;
    final closeIconSize = 16.s;
    final closeToArrowSpace = 4.s;
    final arrowIconSize = 16.s;
    
    return _recentSearches.asMap().entries.map((entry) {
      final index = entry.key;
      final search = entry.value;

      return Padding(
            padding: EdgeInsets.only(bottom: itemBottomMargin),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _hapticService.selection();
                  _searchController.text = search;
                },
                borderRadius: BorderRadius.circular(itemBorderRadius),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: itemHorizontalPadding,
                    vertical: itemVerticalPadding,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(itemBorderRadius),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: Colors.white.withOpacity(0.3),
                        size: historyIconSize,
                      ),
                      SizedBox(width: iconToTextSpace),
                      Expanded(
                        child: Text(
                          search,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: searchTextSize,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: textToCloseSpace),
                      // Remove button
                      GestureDetector(
                        onTap: () => _removeRecentSearch(search),
                        child: Container(
                          padding: EdgeInsets.all(closeButtonPadding),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.25),
                            size: closeIconSize,
                          ),
                        ),
                      ),
                      SizedBox(width: closeToArrowSpace),
                      Icon(
                        Icons.north_east_rounded,
                        color: Colors.white.withOpacity(0.2),
                        size: arrowIconSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .animate()
          .fadeIn(delay: (700 + index * 80).ms, duration: 600.ms)
          .slideX(
            begin: 0.05,
            end: 0,
            delay: (700 + index * 80).ms,
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          );
    }).toList();
  }

  Widget _buildModernNoResults() {
    // Responsive values based on iPhone 16 Pro Max baseline
    final containerPadding = 40.s;
    final outerCircleSize = 120.s;
    final innerCircleSize = 80.s;
    final searchOffIconSize = 40.s;
    final circleToTitleSpace = 32.s;
    final titleFontSize = 22.sp;
    final titleToSubtitleSpace = 8.s;
    final subtitleFontSize = 15.sp;
    final subtitleToButtonSpace = 32.s;
    final buttonBorderRadius = 12.s;
    final buttonHorizontalPadding = 24.s;
    final buttonVerticalPadding = 12.s;
    final buttonTextSize = 14.sp;
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(containerPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern empty state illustration
            Container(
                  width: outerCircleSize,
                  height: outerCircleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primaryAccent.withOpacity(0.1),
                        _secondaryAccent.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: innerCircleSize,
                      height: innerCircleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _primaryAccent.withOpacity(0.15),
                            _secondaryAccent.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: searchOffIconSize,
                        color: _primaryAccent.withOpacity(0.5),
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),

            SizedBox(height: circleToTitleSpace),

            Text(
                  AppLocalizations.of(context)!.noResultsFound,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 600.ms),

            SizedBox(height: titleToSubtitleSpace),

            Text(
              AppLocalizations.of(context)!.tryAdjustingYourSearch,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: subtitleFontSize,
                fontWeight: FontWeight.w400,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

            SizedBox(height: subtitleToButtonSpace),

            // Suggestion button
            Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearSearch,
                    borderRadius: BorderRadius.circular(buttonBorderRadius),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: buttonHorizontalPadding,
                        vertical: buttonVerticalPadding,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(buttonBorderRadius),
                        border: Border.all(
                          color: _primaryAccent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.clearSearch,
                        style: GoogleFonts.inter(
                          color: _primaryAccent,
                          fontSize: buttonTextSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.1, end: 0, delay: 500.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDeckGridCard(Deck deck, int index) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final isUnlocked = deckProvider.isDeckUnlocked(deck.id);
    final isPremium = deck.isPremium;

    // Create unique hero tag for this specific card instance
    final heroTag =
        'search_deck_card_${deck.id}_${DateTime.now().millisecondsSinceEpoch}_$index';

    // Responsive values based on iPhone 16 Pro Max baseline
    final cardBorderRadius = 16.s;
    final cardInnerRadius = 15.s;
    final cardBlurRadius = 16.s;
    final cardShadowOffsetY = 6.s;
    final cardShadowSpread = -4.s;
    final fallbackIconSize = 40.s;
    final infoBottomPadding = 12.s;
    final infoHorizontalPadding = 12.s;
    final deckNameSize = 14.sp;
    final cardCountSize = 11.sp;
    final nameToCountSpace = 4.s;
    final lockPadding = 16.s;
    final lockIconSize = 24.s;
    final playButtonSize = 32.s;
    final playButtonRadius = 8.s;
    final playIconSize = 20.s;
    final playButtonTop = 8.s;
    final playButtonRight = 8.s;

    return Hero(
          tag: heroTag,
          createRectTween: (begin, end) {
            return MaterialRectArcTween(begin: begin, end: end);
          },
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _hapticService.selection();
                _navigateToDeckDetails(deck, heroTag: heroTag);
              },
              onLongPress: () {
                _hapticService.heavyImpact();
                _showDeckQuickActions(deck);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(cardBorderRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: cardBlurRadius,
                      offset: Offset(0, cardShadowOffsetY),
                      spreadRadius: cardShadowSpread,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardInnerRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image or color
                      if (deck.imageUrl != null && deck.imageUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: deck.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 158,
                          memCacheHeight: 210,
                          maxWidthDiskCache: 600,
                          maxHeightDiskCache: 800,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              color: deck.color.withOpacity(0.15),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: deck.color.withOpacity(0.5),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          fadeInDuration: const Duration(milliseconds: 300),
                          errorWidget: (context, url, error) {
                            return Container(
                              decoration: BoxDecoration(
                                color: deck.color.withOpacity(0.2),
                              ),
                              child: Center(
                                child: Icon(
                                  deck.icon,
                                  color: deck.color,
                                  size: fallbackIconSize,
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
                            child: Icon(deck.icon, color: deck.color, size: fallbackIconSize),
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
                        bottom: infoBottomPadding,
                        left: infoHorizontalPadding,
                        right: infoHorizontalPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              deck.name,
                              style: GoogleFonts.inter(
                                fontSize: deckNameSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: nameToCountSpace),
                            Text(
                              '${deck.cards.length} cards',
                              style: GoogleFonts.inter(
                                fontSize: cardCountSize,
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
                              padding: EdgeInsets.all(lockPadding),
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
                              child: Icon(
                                Icons.lock_rounded,
                                color: const Color(0xFFFFC107),
                                size: lockIconSize,
                              ),
                            ),
                          ),
                        ),

                      // Play icon hint (top right)
                      if (!isPremium || isUnlocked)
                        Positioned(
                          top: playButtonTop,
                          right: playButtonRight,
                          child: Container(
                                width: playButtonSize,
                                height: playButtonSize,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(playButtonRadius),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: deck.color,
                                  size: playIconSize,
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
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 50).ms, duration: 500.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          delay: (index * 50).ms,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildSkeletonLoader() {
    // Responsive values
    final gridHorizontalPadding = 20.s;
    final gridBottomPadding = 20.s;
    final gridCrossAxisSpacing = 12.s;
    final gridMainAxisSpacing = 12.s;
    
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(gridHorizontalPadding, 0, gridHorizontalPadding, gridBottomPadding),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: gridCrossAxisSpacing,
        mainAxisSpacing: gridMainAxisSpacing,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildSkeletonCard()
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 1500.ms,
              color: Colors.white.withOpacity(0.1),
              angle: 0,
            );
      },
    );
  }

  Widget _buildSkeletonCard() {
    // Responsive values based on iPhone 16 Pro Max baseline
    final cardBorderRadius = 16.s;
    final cardInnerRadius = 15.s;
    final infoBottomPadding = 12.s;
    final infoHorizontalPadding = 12.s;
    final titleHeight = 14.s;
    final titleRadius = 7.s;
    final titleToSubtitleSpace = 6.s;
    final subtitleWidth = 60.s;
    final subtitleHeight = 10.s;
    final subtitleRadius = 5.s;
    final playButtonSize = 32.s;
    final playButtonRadius = 8.s;
    final playButtonTop = 8.s;
    final playButtonRight = 8.s;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardInnerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Skeleton background
            Container(color: Colors.white.withOpacity(0.03)),

            // Skeleton text at bottom
            Positioned(
              bottom: infoBottomPadding,
              left: infoHorizontalPadding,
              right: infoHorizontalPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skeleton title
                  Container(
                    width: double.infinity,
                    height: titleHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(titleRadius),
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),

                  SizedBox(height: titleToSubtitleSpace),

                  // Skeleton subtitle
                  Container(
                    width: subtitleWidth,
                    height: subtitleHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(subtitleRadius),
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),

            // Skeleton play icon at top right
            Positioned(
              top: playButtonTop,
              right: playButtonRight,
              child: Container(
                width: playButtonSize,
                height: playButtonSize,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(playButtonRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // PREMIUM QUICK ACTIONS - Netflix-Style Experience
  // ============================================================================

  void _showDeckQuickActions(Deck deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.85),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: _buildPremiumQuickActionsSheet(deck),
          ),
    );
  }

  Widget _buildPremiumQuickActionsSheet(Deck deck) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final isFavorite = deckProvider.favoriteDecks.contains(deck.id);

    // Responsive values based on iPhone 16 Pro Max baseline
    final sheetBorderRadius = 32.s;
    final handleMarginTop = 14.s;
    final handleMarginBottom = 6.s;
    final handleWidth = 42.s;
    final handleHeight = 5.s;
    final handleRadius = 2.5.s;
    final handleToPreviewSpace = 12.s;
    final previewToSeparatorSpace = 20.s;
    final separatorHorizontalMargin = 24.s;
    final separatorToButtonsSpace = 20.s;
    final buttonsHorizontalPadding = 20.s;
    final buttonSpacing = 10.s;
    final bottomPadding = 28.s;

    return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1C), Color(0xFF141416)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(sheetBorderRadius)),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 40.s,
                spreadRadius: 0,
                offset: Offset(0, -8.s),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Elegant drag handle with pulsing animation
                Container(
                      margin: EdgeInsets.only(top: handleMarginTop, bottom: handleMarginBottom),
                      width: handleWidth,
                      height: handleHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(handleRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 8.s,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .fadeIn(duration: 300.ms)
                    .shimmer(
                      duration: 2000.ms,
                      color: Colors.white.withOpacity(0.1),
                    )
                    .scale(
                      begin: const Offset(0.95, 1),
                      end: const Offset(1.0, 1),
                      duration: 300.ms,
                      curve: Curves.easeOutBack,
                    ),

                SizedBox(height: handleToPreviewSpace),

                // Premium deck preview
                _buildPremiumDeckPreview(deck),

                SizedBox(height: previewToSeparatorSpace),

                // Elegant separator with gradient
                Container(
                      height: 0.5,
                      margin: EdgeInsets.symmetric(horizontal: separatorHorizontalMargin),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 500.ms)
                    .scale(begin: const Offset(0.8, 1), duration: 500.ms),

                SizedBox(height: separatorToButtonsSpace),

                // Premium action buttons
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: buttonsHorizontalPadding),
                  child: Column(
                    children: [
                      _buildPremiumActionButton(
                        icon:
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                        label:
                            isFavorite
                                ? 'Remove from Favorites'
                                : 'Add to Favorites',
                        subtitle:
                            isFavorite
                                ? 'Saved to your collection'
                                : 'Save for later',
                        gradient: const [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                        onTap: () => _toggleFavorite(deck),
                        index: 0,
                      ),
                      SizedBox(height: buttonSpacing),
                      _buildPremiumActionButton(
                        icon: Icons.ios_share_rounded,
                        label: 'Share Deck',
                        subtitle: 'Send to friends',
                        gradient: const [Color(0xFF667EEA), Color(0xFF6B5DD3)],
                        onTap: () => _shareDeck(deck),
                        index: 1,
                      ),
                      SizedBox(height: buttonSpacing),
                      _buildPremiumActionButton(
                        icon: Icons.info_outline_rounded,
                        label: 'View Details',
                        subtitle: 'See full description',
                        gradient: const [Color(0xFF00C9A7), Color(0xFF00B298)],
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 250), () {
                            _navigateToDeckDetails(deck);
                          });
                        },
                        index: 2,
                      ),
                      SizedBox(height: buttonSpacing),
                      _buildPremiumActionButton(
                        icon: Icons.shuffle_rounded,
                        label: 'Shuffle & Play',
                        subtitle: 'Random card order',
                        gradient: const [Color(0xFFF093FB), Color(0xFFE578F8)],
                        onTap: () => _shuffleAndPlay(deck),
                        index: 3,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: bottomPadding),
              ],
            ),
          ),
        )
        .animate()
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 550.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 350.ms);
  }

  Widget _buildPremiumDeckPreview(Deck deck) {
    // Responsive values based on iPhone 16 Pro Max baseline
    final horizontalPadding = 24.s;
    final containerPadding = 18.s;
    final containerRadius = 24.s;
    final thumbnailSize = 72.s;
    final thumbnailRadius = 16.s;
    final thumbnailInnerRadius = 15.s;
    final fallbackIconSize = 32.s;
    final thumbnailToInfoSpace = 18.s;
    final deckNameSize = 17.sp;
    final nameToTagsSpace = 6.s;
    final tagHorizontalPadding = 8.s;
    final tagVerticalPadding = 4.s;
    final tagBorderRadius = 6.s;
    final tagIconSize = 12.s;
    final tagIconToTextSpace = 4.s;
    final tagTextSize = 12.sp;
    final tagsSpacing = 8.s;
    final proTextSize = 10.sp;
    final proIconToTextSpace = 3.s;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.03),
                  Colors.white.withOpacity(0.01),
                ],
              ),
              borderRadius: BorderRadius.circular(containerRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20.s,
                  spreadRadius: -5.s,
                  offset: Offset(0, 10.s),
                ),
              ],
            ),
            child: Row(
              children: [
                // Premium deck thumbnail with glow
                Container(
                      width: thumbnailSize,
                      height: thumbnailSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            deck.color.withOpacity(0.2),
                            deck.color.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(thumbnailRadius),
                        border: Border.all(
                          color: deck.color.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: deck.color.withOpacity(0.3),
                            blurRadius: 15.s,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child:
                          deck.imageUrl != null && deck.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(thumbnailInnerRadius),
                                child: CachedNetworkImage(
                                  imageUrl: deck.imageUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 158,
                                  memCacheHeight: 210,
                                  maxWidthDiskCache: 600,
                                  maxHeightDiskCache: 800,
                                  placeholder: (context, url) => Container(
                                    color: deck.color.withOpacity(0.15),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: deck.color.withOpacity(0.5),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  errorWidget: (context, url, error) {
                                    return Center(
                                      child: Icon(
                                        deck.icon,
                                        color: deck.color,
                                        size: fallbackIconSize,
                                      ),
                                    );
                                  },
                                ),
                              )
                              : Center(
                                child: Icon(
                                  deck.icon,
                                  color: deck.color,
                                  size: fallbackIconSize,
                                ),
                              ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 400.ms)
                    .shimmer(
                      delay: 300.ms,
                      duration: 1500.ms,
                      color: Colors.white.withOpacity(0.1),
                    ),

                SizedBox(width: thumbnailToInfoSpace),

                // Deck information with elegant typography
                Expanded(
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Deck name
                          Text(
                            deck.name,
                            style: GoogleFonts.inter(
                              fontSize: deckNameSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: nameToTagsSpace),

                          // Card count and badges
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: tagHorizontalPadding,
                                  vertical: tagVerticalPadding,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(tagBorderRadius),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.layers_rounded,
                                      size: tagIconSize,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    SizedBox(width: tagIconToTextSpace),
                                    Text(
                                      '${deck.cards.length}',
                                      style: GoogleFonts.inter(
                                        fontSize: tagTextSize,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.7),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (deck.isPremium) ...[
                                SizedBox(width: tagsSpacing),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: tagHorizontalPadding,
                                    vertical: tagVerticalPadding,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(tagBorderRadius),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFA500,
                                        ).withOpacity(0.3),
                                        blurRadius: 8.s,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        size: tagIconSize,
                                        color: Colors.black87,
                                      ),
                                      SizedBox(width: proIconToTextSpace),
                                      Text(
                                        'PRO',
                                        style: GoogleFonts.inter(
                                          fontSize: proTextSize,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 500.ms)
                      .slideX(
                        begin: 0.08,
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ),
              ],
            ),
          )
          .animate()
          .scale(
            begin: const Offset(0.92, 0.92),
            duration: 450.ms,
            curve: Curves.easeOutCubic,
          )
          .fadeIn(duration: 400.ms),
    );
  }

  Widget _buildPremiumActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
    required int index,
  }) {
    // Responsive values based on iPhone 16 Pro Max baseline
    final buttonBorderRadius = 18.s;
    final buttonHorizontalPadding = 18.s;
    final buttonVerticalPadding = 18.s;
    final iconContainerSize = 50.s;
    final iconContainerRadius = 14.s;
    final iconSize = 24.s;
    final iconToTextSpace = 16.s;
    final labelFontSize = 15.sp;
    final labelToSubtitleSpace = 2.s;
    final subtitleFontSize = 12.sp;
    final chevronSize = 20.s;
    
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _hapticService.mediumImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(buttonBorderRadius),
            splashColor: gradient[0].withOpacity(0.1),
            highlightColor: gradient[0].withOpacity(0.05),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: buttonHorizontalPadding, vertical: buttonVerticalPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.01),
                  ],
                ),
                borderRadius: BorderRadius.circular(buttonBorderRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12.s,
                    spreadRadius: -3.s,
                    offset: Offset(0, 6.s),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Premium icon with gradient glow
                  Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradient[0].withOpacity(0.18),
                          gradient[1].withOpacity(0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(iconContainerRadius),
                      border: Border.all(
                        color: gradient[0].withOpacity(0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradient[0].withOpacity(0.25),
                          blurRadius: 12.s,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback:
                            (bounds) => LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradient,
                            ).createShader(bounds),
                        child: Icon(icon, color: Colors.white, size: iconSize),
                      ),
                    ),
                  ),

                  SizedBox(width: iconToTextSpace),

                  // Label and subtitle with elegant typography
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: labelFontSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: labelToSubtitleSpace),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.45),
                            letterSpacing: 0.1,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Subtle chevron
                  Icon(
                    Icons.chevron_right_rounded,
                    size: chevronSize,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 500.ms, curve: Curves.easeOut)
        .slideX(
          begin: 0.08,
          end: 0,
          delay: (index * 60).ms,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          delay: (index * 60).ms,
          duration: 500.ms,
          curve: Curves.easeOutBack,
        );
  }

  // ============================================================================
  // ACTION HANDLERS
  // ============================================================================

  void _toggleFavorite(Deck deck) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final isFavorite = deckProvider.favoriteDecks.contains(deck.id);

    if (isFavorite) {
      deckProvider.removeFromFavorites(deck.id);
      _showSuccessToast('Removed from favorites');
    } else {
      deckProvider.addToFavorites(deck.id);
      _showSuccessToast('Added to favorites ❤️');
    }

    Navigator.pop(context);
  }

  void _shareDeck(Deck deck) {
    Navigator.pop(context);
    _hapticService.lightImpact();

    Future.delayed(const Duration(milliseconds: 200), () {
      ShareService().shareDeck(deck, context);
    });
  }

  void _shuffleAndPlay(Deck deck) {
    Navigator.pop(context);
    _hapticService.heavyImpact();

    Future.delayed(const Duration(milliseconds: 200), () {
      _showSuccessToast('Shuffling deck... 🎲');
      // Navigate to deck details with shuffle flag
      _navigateToDeckDetails(deck);
    });
  }

  void _showSuccessToast(String message) {
    // Responsive values based on iPhone 16 Pro Max baseline
    final contentVerticalPadding = 8.s;
    final contentHorizontalPadding = 4.s;
    final iconContainerPadding = 8.s;
    final iconContainerRadius = 10.s;
    final checkIconSize = 20.s;
    final iconToTextSpace = 14.s;
    final messageFontSize = 14.sp;
    final snackBarRadius = 16.s;
    final snackBarHorizontalMargin = 20.s;
    final snackBarBottomMargin = 90.s;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: contentVerticalPadding, horizontal: contentHorizontalPadding),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconContainerPadding),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D9B1), Color(0xFF00A88E)],
                  ),
                  borderRadius: BorderRadius.circular(iconContainerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D9B1).withOpacity(0.3),
                      blurRadius: 8.s,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: checkIconSize,
                ),
              ),
              SizedBox(width: iconToTextSpace),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: messageFontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(snackBarRadius),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        margin: EdgeInsets.fromLTRB(snackBarHorizontalMargin, 0, snackBarHorizontalMargin, snackBarBottomMargin),
        duration: const Duration(milliseconds: 2500),
        elevation: 0,
      ),
    );
  }
}
