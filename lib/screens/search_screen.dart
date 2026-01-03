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
import '../l10n/app_localizations.dart';
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
                          height: 20,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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

              const SizedBox(width: 16),

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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
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
                                      blurRadius: 10 + (10 * easedProgress),
                                      offset: const Offset(0, 3),
                                    ),
                                    if (easedProgress > 0.3)
                                      BoxShadow(
                                        color: searchColor.withOpacity(
                                          0.15 * (easedProgress - 0.3) / 0.7,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                                child: SizedBox(
                                  height: 24,
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
                                          child: const Icon(
                                            Icons.search_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      if (progress > 0.2)
                                        Flexible(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 16.0,
                                            ),
                                            child: Opacity(
                                              opacity: (progress - 0.2) / 0.8,
                                              child: Text(
                                                AppLocalizations.of(context)!.searchForDecks,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  fontSize: 16,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
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
                                    blurRadius:
                                        10 + (10 * _heroAnimation.value),
                                    offset: const Offset(0, 3),
                                  ),
                                  if (_heroAnimation.value > 0.3)
                                    BoxShadow(
                                      color: searchColor.withOpacity(
                                        0.15 *
                                            (_heroAnimation.value - 0.3) /
                                            0.7,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: SizedBox(
                                height: 24,
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
                                            child: const Icon(
                                              Icons.search_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    const SizedBox(width: 16),

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
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: 0.2,
                                                height: 1.0,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: AppLocalizations.of(context)!.searchForDecks,
                                                hintStyle: GoogleFonts.inter(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                              cursorColor: searchColor,
                                              cursorWidth: 2,
                                              cursorHeight: 20,
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
                                                      BorderRadius.circular(12),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      color: searchColor
                                                          .withOpacity(0.7),
                                                      size: 18,
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending searches section
          Text(
                AppLocalizations.of(context)!.trendingSearches,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms, duration: 600.ms)
              .slideY(begin: 0.1, end: 0, duration: 600.ms),

          const SizedBox(height: 4),

          Text(
            AppLocalizations.of(context)!.popularCategoriesRightNow,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 600.ms),

          const SizedBox(height: 24),

          // Category pills
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: _cardColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14),
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
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  category['text'] as String,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
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

          const SizedBox(height: 40),

          // Recent searches header with clear button
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.recentSearches,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearAllRecentSearches,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.clearAll,
                        style: GoogleFonts.inter(
                          color: _primaryAccent.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

            const SizedBox(height: 16),

            // Recent search items
            ..._buildRecentSearchItems(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRecentSearchItems() {
    return _recentSearches.asMap().entries.map((entry) {
      final index = entry.key;
      final search = entry.value;

      return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _hapticService.selection();
                  _searchController.text = search;
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          search,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Remove button
                      GestureDetector(
                        onTap: () => _removeRecentSearch(search),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.25),
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.north_east_rounded,
                        color: Colors.white.withOpacity(0.2),
                        size: 16,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern empty state illustration
            Container(
                  width: 120,
                  height: 120,
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
                      width: 80,
                      height: 80,
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
                        size: 40,
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

            const SizedBox(height: 32),

            Text(
                  AppLocalizations.of(context)!.noResultsFound,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 600.ms),

            const SizedBox(height: 8),

            Text(
              AppLocalizations.of(context)!.tryAdjustingYourSearch,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

            const SizedBox(height: 32),

            // Suggestion button
            Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearSearch,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primaryAccent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.clearSearch,
                        style: GoogleFonts.inter(
                          color: _primaryAccent,
                          fontSize: 14,
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
                            child: Icon(deck.icon, color: deck.color, size: 40),
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Skeleton background
            Container(color: Colors.white.withOpacity(0.03)),

            // Skeleton text at bottom
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skeleton title
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Skeleton subtitle
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),

            // Skeleton play icon at top right
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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

    return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1C), Color(0xFF141416)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 40,
                spreadRadius: 0,
                offset: const Offset(0, -8),
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
                      margin: const EdgeInsets.only(top: 14, bottom: 6),
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 8,
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

                const SizedBox(height: 12),

                // Premium deck preview
                _buildPremiumDeckPreview(deck),

                const SizedBox(height: 20),

                // Elegant separator with gradient
                Container(
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
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

                const SizedBox(height: 20),

                // Premium action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      const SizedBox(height: 10),
                      _buildPremiumActionButton(
                        icon: Icons.ios_share_rounded,
                        label: 'Share Deck',
                        subtitle: 'Send to friends',
                        gradient: const [Color(0xFF667EEA), Color(0xFF6B5DD3)],
                        onTap: () => _shareDeck(deck),
                        index: 1,
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
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

                const SizedBox(height: 28),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.03),
                  Colors.white.withOpacity(0.01),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                // Premium deck thumbnail with glow
                Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            deck.color.withOpacity(0.2),
                            deck.color.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: deck.color.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: deck.color.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child:
                          deck.imageUrl != null && deck.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
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
                                        size: 32,
                                      ),
                                    );
                                  },
                                ),
                              )
                              : Center(
                                child: Icon(
                                  deck.icon,
                                  color: deck.color,
                                  size: 32,
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

                const SizedBox(width: 18),

                // Deck information with elegant typography
                Expanded(
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Deck name
                          Text(
                            deck.name,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Card count and badges
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
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
                                      size: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${deck.cards.length}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.7),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (deck.isPremium) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFA500,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 12,
                                        color: Colors.black87,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'PRO',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
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
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _hapticService.mediumImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(18),
            splashColor: gradient[0].withOpacity(0.1),
            highlightColor: gradient[0].withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.01),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: -3,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Premium icon with gradient glow
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradient[0].withOpacity(0.18),
                          gradient[1].withOpacity(0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: gradient[0].withOpacity(0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradient[0].withOpacity(0.25),
                          blurRadius: 12,
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
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Label and subtitle with elegant typography
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
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
                    size: 20,
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

    // Show share sheet
    Future.delayed(const Duration(milliseconds: 200), () {
      _showSuccessToast('Share feature coming soon! 📤');
      // TODO: Implement actual share functionality
      // Share.share('Check out this deck: ${deck.name}');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D9B1), Color(0xFF00A88E)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D9B1).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
        duration: const Duration(milliseconds: 2500),
        elevation: 0,
      ),
    );
  }
}
