import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'gameplay_screen.dart';
import 'custom_deck_screen.dart';
import 'dart:ui';

class CategorySelectionScreen extends StatefulWidget {
  final bool isTeamMode;
  final List<String>? teamNames;
  final List<Color>? teamColors;
  final int? roundsPerTeam;
  final int? roundDuration;
  final bool? isTournamentMode;
  final String? tournamentType;

  const CategorySelectionScreen({
    super.key,
    this.isTeamMode = false,
    this.teamNames,
    this.teamColors,
    this.roundsPerTeam,
    this.roundDuration,
    this.isTournamentMode,
    this.tournamentType,
  });

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();
  late TabController _tabController;
  late AnimationController _searchController;
  late AnimationController _floatingController;
  final TextEditingController _searchTextController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _floatingController.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Clean Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: SafeArea(
              child: Row(
                children: [
                  // Back button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _hapticService.lightImpact();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Select Category',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Consumer<DeckProvider>(
                          builder: (context, provider, _) {
                            return Text(
                              '${provider.allDecks.length} categories available',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Filter button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _hapticService.lightImpact();
                        // Filter functionality
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.95),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle pattern overlay
                    Positioned(
                      top: -100,
                      right: -100,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.03),
                            width: 50,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Container(
                color: AppTheme.backgroundColor,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Modern segmented tab bar
                    AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          child: Stack(
                            children: [
                              // Background track
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              // Custom tab bar
                              SizedBox(
                                height: 48,
                                child: TabBar(
                                  controller: _tabController,
                                  indicator: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicatorPadding: const EdgeInsets.all(4),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: AppTheme.textSecondary,
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  splashBorderRadius: BorderRadius.circular(10),
                                  tabs: [
                                    Tab(
                                      child: Consumer<DeckProvider>(
                                        builder: (context, provider, _) {
                                          return Container(
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.dashboard_rounded,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text('All'),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _tabController.index ==
                                                                0
                                                            ? Colors.white
                                                                .withOpacity(
                                                                  0.2,
                                                                )
                                                            : Colors.grey
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${provider.allDecks.length}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Tab(
                                      child: Consumer<DeckProvider>(
                                        builder: (context, provider, _) {
                                          return Container(
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.lock_open_rounded,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text('Free'),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _tabController.index ==
                                                                1
                                                            ? Colors.white
                                                                .withOpacity(
                                                                  0.2,
                                                                )
                                                            : Colors.grey
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${provider.freeDecks.length}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Tab(
                                      child: Consumer<DeckProvider>(
                                        builder: (context, provider, _) {
                                          final hasCustom =
                                              provider.customDecks.isNotEmpty;
                                          return Container(
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.star_rounded,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text('Custom'),
                                                if (hasCustom) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          _tabController
                                                                      .index ==
                                                                  2
                                                              ? Colors.white
                                                                  .withOpacity(
                                                                    0.2,
                                                                  )
                                                              : Colors.grey
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${provider.customDecks.length}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(child: _buildSearchBar()),

          // Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeckGrid(DeckType.all),
                _buildDeckGrid(DeckType.free),
                _buildDeckGrid(DeckType.custom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern search field with enhanced design
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _isSearching
                        ? AppTheme.primaryColor.withOpacity(0.4)
                        : Colors.grey.shade200,
                width: _isSearching ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _isSearching
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.black.withOpacity(0.04),
                  blurRadius: _isSearching ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Enhanced search icon
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          _isSearching
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color:
                          _isSearching
                              ? AppTheme.primaryColor
                              : Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                ),
                // Text field with better typography
                Expanded(
                  child: TextField(
                    controller: _searchTextController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                        _isSearching = value.isNotEmpty;
                      });
                    },
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search for categories...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                // Results count or clear button
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child:
                      _searchQuery.isNotEmpty
                          ? Row(
                            children: [
                              // Results count
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_getFilteredCount()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              // Clear button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _searchTextController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _isSearching = false;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                          : const SizedBox(width: 16),
                ),
              ],
            ),
          ),
          // Enhanced quick filter chips
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Quick Filters',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildEnhancedFilterChip(
                    'Trending',
                    Icons.local_fire_department_rounded,
                    Colors.orange,
                  ),
                  _buildEnhancedFilterChip(
                    'Popular',
                    Icons.star_rounded,
                    Colors.amber,
                  ),
                  _buildEnhancedFilterChip(
                    'New',
                    Icons.new_releases_rounded,
                    Colors.blue,
                  ),
                  _buildEnhancedFilterChip(
                    'Fun',
                    Icons.mood_rounded,
                    Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.03);
  }

  Widget _buildEnhancedFilterChip(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _searchTextController.text = label.toLowerCase();
            setState(() {
              _searchQuery = label.toLowerCase();
              _isSearching = true;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.9),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getFilteredCount() {
    final provider = context.read<DeckProvider>();
    List<Deck> decks = [];

    switch (_tabController.index) {
      case 0:
        decks = provider.allDecks;
        break;
      case 1:
        decks = provider.freeDecks;
        break;
      case 2:
        decks = provider.customDecks;
        break;
    }

    if (_searchQuery.isNotEmpty) {
      decks =
          decks.where((deck) {
            return deck.name.toLowerCase().contains(_searchQuery) ||
                deck.description.toLowerCase().contains(_searchQuery);
          }).toList();
    }

    return decks.length;
  }

  Widget _buildDeckGrid(DeckType type) {
    return Consumer<DeckProvider>(
      builder: (context, deckProvider, child) {
        List<Deck> decks = [];

        switch (type) {
          case DeckType.all:
            decks = deckProvider.allDecks;
            break;
          case DeckType.free:
            decks = deckProvider.freeDecks;
            break;
          case DeckType.custom:
            decks = deckProvider.customDecks;
            break;
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          decks =
              decks.where((deck) {
                return deck.name.toLowerCase().contains(_searchQuery) ||
                    deck.description.toLowerCase().contains(_searchQuery);
              }).toList();
        }

        if (decks.isEmpty) {
          return _buildEmptyState(type);
        }

        return AnimationLimiter(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75, // Adjusted to give more height to cards
            ),
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              final isUnlocked = deckProvider.isDeckUnlocked(deck.id);

              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 600),
                columnCount: 2,
                child: ScaleAnimation(
                  scale: 0.9,
                  child: FadeInAnimation(
                    child: _buildModernDeckCard(deck, isUnlocked, index),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildModernDeckCard(Deck deck, bool isUnlocked, int index) {
    // Modern card design inspired by Apple App Store and Spotify
    return GestureDetector(
      onTap: () {
        _hapticService.lightImpact();
        _audioService.playClick();

        if (isUnlocked) {
          _showDeckOptions(deck);
        } else {
          _showUnlockDialog(deck);
        }
      },
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          final floatOffset =
              (index % 4 == 0 || index % 4 == 3)
                  ? _floatingController.value * 1.5 - 0.75
                  : -_floatingController.value * 1.5 + 0.75;

          return Transform.translate(
            offset: Offset(0, floatOffset),
            child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: deck.color.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Main content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top colored section with icon
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: deck.color,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    deck.color,
                                    deck.color.withOpacity(0.85),
                                  ],
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Decorative circles
                                  Positioned(
                                    top: -20,
                                    right: -20,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -30,
                                    left: -15,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withOpacity(0.05),
                                      ),
                                    ),
                                  ),
                                  // Icon
                                  Center(
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: FaIcon(
                                          deck.icon,
                                          color: deck.color,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bottom white section with details
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title and description
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deck.name,
                                            style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Flexible(
                                            child: Text(
                                              deck.description,
                                              style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 11,
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Card count chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: deck.color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.layers_rounded,
                                            size: 12,
                                            color: deck.color,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${deck.cards.length}',
                                            style: TextStyle(
                                              color: deck.color,
                                              fontSize: 11,
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
                          ],
                        ),

                        // Premium lock overlay
                        if (deck.isPremium && !isUnlocked)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: deck.color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.lock_rounded,
                                            color: deck.color,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Premium',
                                        style: TextStyle(
                                          color: deck.color,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Custom badge
                        if (deck.isCustom)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 11,
                                    color: AppTheme.warningColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'CUSTOM',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.warningColor,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Play indicator for unlocked cards
                        if (isUnlocked && !deck.isCustom)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: deck.color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: deck.color.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: (100 + index * 50).ms, duration: 500.ms)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutCubic,
                ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(DeckType type) {
    String message;
    String subtitle;
    IconData icon;

    switch (type) {
      case DeckType.all:
        message = 'No categories found';
        subtitle = 'Try adjusting your search';
        icon = Icons.search_off_rounded;
        break;
      case DeckType.free:
        message = 'No free categories';
        subtitle = 'Check out other tabs';
        icon = Icons.lock_open_rounded;
        break;
      case DeckType.custom:
        message = 'No custom decks yet';
        subtitle = 'Create your first deck!';
        icon = Icons.add_circle_outline_rounded;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(icon, size: 56, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          if (type == DeckType.custom) ...[
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _hapticService.lightImpact();
                    _showCreateCustomDeck();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Create Custom Deck',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  void _showDeckOptions(Deck deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildModernDeckOptionsSheet(deck),
    );
  }

  Widget _buildModernDeckOptionsSheet(Deck deck) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Deck preview card with solid color
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: deck.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: deck.color.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: deck.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: deck.color.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FaIcon(deck.icon, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.name,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.style_rounded,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${deck.cards.length} exciting cards',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Play button with solid color
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _hapticService.mediumImpact();
                      Navigator.pop(context);
                      _startGame(deck);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start Game',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (deck.isCustom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _editCustomDeck(deck);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.errorColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _deleteCustomDeck(deck);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_rounded,
                                    color: AppTheme.errorColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontWeight: FontWeight.w600,
                                    ),
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockDialog(Deck deck) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: deck.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: deck.color.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock_rounded,
                        color: deck.color,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Premium Deck',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: deck.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      deck.name,
                      style: TextStyle(
                        color: deck.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    deck.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Watch an ad to unlock for one game',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.diamond_rounded,
                              color: AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Purchase to unlock forever',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.warningColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _purchaseDeck(deck);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Get Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _watchAdToUnlock(deck);
                          },
                          icon: Icon(Icons.play_circle_outline, size: 18),
                          label: Text('Watch Ad'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _startGame(Deck deck) {
    context.read<DeckProvider>().addToRecentDecks(deck.id);

    // Start game with team mode if applicable
    if (widget.isTeamMode) {
      context.read<GameProvider>().startGame(
        deck: deck,
        isTeamMode: true,
        teamNames: widget.teamNames,
        totalRounds: widget.roundsPerTeam ?? 1,
      );

      // Update round duration if specified
      if (widget.roundDuration != null) {
        context.read<GameProvider>().updateRoundDuration(widget.roundDuration!);
      }
    } else {
      context.read<GameProvider>().startGame(deck: deck);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GameplayScreen(
              deck: deck,
              isTeamMode: widget.isTeamMode,
              teamNames: widget.teamNames,
              teamColors: widget.teamColors,
              isTournamentMode: widget.isTournamentMode ?? false,
              tournamentType: widget.tournamentType,
            ),
      ),
    );
  }

  void _showCreateCustomDeck() async {
    _hapticService.mediumImpact();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CustomDeckScreen()),
    );

    if (result == true && mounted) {
      _hapticService.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Custom deck created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Switch to custom tab to show the new deck
      _tabController.animateTo(2);
    }
  }

  void _editCustomDeck(Deck deck) async {
    _hapticService.mediumImpact();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomDeckScreen(existingDeck: deck),
      ),
    );

    if (result == true && mounted) {
      _hapticService.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Deck updated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _deleteCustomDeck(Deck deck) {
    _hapticService.mediumImpact();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                const Text('Delete Deck'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to delete "${deck.name}"?'),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _hapticService.error();

                  final success = await context
                      .read<DeckProvider>()
                      .deleteCustomDeck(deck.id);

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${deck.name} deleted'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _watchAdToUnlock(Deck deck) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ad integration coming soon!')),
    );
  }

  void _purchaseDeck(Deck deck) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('In-app purchases coming soon!')),
    );
  }
}

enum DeckType { all, free, custom }
