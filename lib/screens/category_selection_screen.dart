import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/banner_ad_widget.dart';
import 'gameplay_screen.dart';
import 'custom_deck_screen.dart';
import 'dart:ui';
import '../services/camera_recording_service.dart';

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
  bool _isCameraEnabled = false;

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
    return BottomBannerAd(
      widgetKey: 'category_selection_screen',
      child: Scaffold(
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
              scrolledUnderElevation: 0,
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
                preferredSize: const Size.fromHeight(70),
                child: Container(
                  color: AppTheme.backgroundColor,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Modern minimal tab bar
                      Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            height: 46,
                            child: Stack(
                              children: [
                                // Background track
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(23),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                // Custom tab implementation
                                AnimatedBuilder(
                                  animation: _tabController.animation!,
                                  builder: (context, child) {
                                    return Consumer<DeckProvider>(
                                      builder: (context, provider, _) {
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            final tabWidth =
                                                constraints.maxWidth / 3;
                                            final animValue =
                                                _tabController.animation!.value;
                                            return Stack(
                                              children: [
                                                // Animated indicator
                                                Positioned(
                                                  left:
                                                      animValue * tabWidth + 3,
                                                  top: 3,
                                                  bottom: 3,
                                                  width: tabWidth - 6,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppTheme
                                                              .primaryColor
                                                              .withOpacity(
                                                                0.15,
                                                              ),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                // Tab items
                                                Row(
                                                  children: [
                                                    _buildModernTab(
                                                      icon:
                                                          Icons
                                                              .grid_view_rounded,
                                                      label: 'All',
                                                      count:
                                                          provider
                                                              .allDecks
                                                              .length,
                                                      index: 0,
                                                      isSelected:
                                                          _tabController
                                                              .index ==
                                                          0,
                                                      onTap:
                                                          () => _tabController
                                                              .animateTo(0),
                                                    ),
                                                    _buildModernTab(
                                                      icon:
                                                          Icons
                                                              .card_giftcard_rounded,
                                                      label: 'Free',
                                                      count:
                                                          provider
                                                              .freeDecks
                                                              .length,
                                                      index: 1,
                                                      isSelected:
                                                          _tabController
                                                              .index ==
                                                          1,
                                                      onTap:
                                                          () => _tabController
                                                              .animateTo(1),
                                                    ),
                                                    _buildModernTab(
                                                      icon:
                                                          Icons.palette_rounded,
                                                      label: 'Custom',
                                                      count:
                                                          provider
                                                              .customDecks
                                                              .length,
                                                      index: 2,
                                                      isSelected:
                                                          _tabController
                                                              .index ==
                                                          2,
                                                      onTap:
                                                          () => _tabController
                                                              .animateTo(2),
                                                      showBadge:
                                                          provider
                                                              .customDecks
                                                              .isNotEmpty,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .scale(
                            begin: const Offset(0.95, 0.95),
                            curve: Curves.easeOutCubic,
                          ),
                      const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ultra-modern search field
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: 56,
            decoration: BoxDecoration(
              color: _isSearching ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color:
                      _isSearching
                          ? AppTheme.primaryColor.withOpacity(0.08)
                          : Colors.black.withOpacity(0.03),
                  blurRadius: _isSearching ? 24 : 12,
                  offset: Offset(0, _isSearching ? 8 : 4),
                  spreadRadius: _isSearching ? 2 : 0,
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated search icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _isSearching ? 1 : 0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Container(
                      margin: const EdgeInsets.only(left: 20, right: 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background glow
                          if (_isSearching)
                            Container(
                              width: 32 + (value * 4),
                              height: 32 + (value * 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(
                                  0.1 * value,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          // Icon
                          Icon(
                            _isSearching ? Icons.search : Icons.search,
                            color: Color.lerp(
                              Colors.grey.shade400,
                              AppTheme.primaryColor,
                              value,
                            ),
                            size: 22,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Text field with smooth animations
                Expanded(
                  child: TextField(
                    controller: _searchTextController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                        _isSearching = value.isNotEmpty;
                      });
                      if (value.isNotEmpty) {
                        HapticFeedback.selectionClick();
                      }
                    },
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.3,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What would you like to play?',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                // Animated clear button and results
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child:
                      _searchQuery.isNotEmpty
                          ? Container(
                            key: const ValueKey('search-actions'),
                            margin: const EdgeInsets.only(right: 8),
                            child: Row(
                              children: [
                                // Animated results badge
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primaryColor.withOpacity(
                                                0.15,
                                              ),
                                              AppTheme.primaryColor.withOpacity(
                                                0.1,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.auto_awesome,
                                              size: 14,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_getFilteredCount()}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Modern clear button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _searchTextController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _isSearching = false;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      margin: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.clear_rounded,
                                        size: 20,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          : const SizedBox(width: 20, key: ValueKey('empty')),
                ),
              ],
            ),
          ),
          // Modern quick filter section
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child:
                _searchQuery.isEmpty
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Quick Filters',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildModernFilterChip(
                                'Trending',
                                Icons.local_fire_department_rounded,
                                const Color(0xFFFF5757),
                                const Color(0xFFFFEBEB),
                              ),
                              _buildModernFilterChip(
                                'Popular',
                                Icons.star_rounded,
                                const Color(0xFFFFB800),
                                const Color(0xFFFFF7E6),
                              ),
                              _buildModernFilterChip(
                                'New',
                                Icons.auto_awesome,
                                const Color(0xFF00D4FF),
                                const Color(0xFFE6F9FF),
                              ),
                              _buildModernFilterChip(
                                'Fun',
                                Icons.emoji_emotions_rounded,
                                const Color(0xFF7C3AED),
                                const Color(0xFFF3E8FF),
                              ),
                              _buildModernFilterChip(
                                'Classic',
                                Icons.workspace_premium_rounded,
                                const Color(0xFF10B981),
                                const Color(0xFFECFDF5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.03);
  }

  Widget _buildModernTab({
    required IconData icon,
    required String label,
    required int count,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
    bool showBadge = true,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isSelected ? 1 : 0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated icon with glow effect
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow effect for selected state
                        if (isSelected)
                          Container(
                            width: 24 + (value * 4),
                            height: 24 + (value * 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryColor.withOpacity(
                                    0.2 * value,
                                  ),
                                  AppTheme.primaryColor.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        // Icon
                        Transform.scale(
                          scale: 1 + (value * 0.1),
                          child: Icon(
                            icon,
                            size: 20,
                            color: Color.lerp(
                              Colors.grey.shade500,
                              AppTheme.primaryColor,
                              value,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Label with animated weight
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: Color.lerp(
                          Colors.grey.shade600,
                          AppTheme.primaryColor,
                          value,
                        ),
                        letterSpacing: isSelected ? 0.3 : 0,
                      ),
                      child: Text(label),
                    ),
                    // Count badge with spring animation
                    if (showBadge && count > 0) ...[
                      const SizedBox(width: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 600 + (index * 100)),
                        curve: Curves.elasticOut,
                        builder: (context, bounceValue, child) {
                          return Transform.scale(
                            scale: bounceValue,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    isSelected
                                        ? LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor.withOpacity(
                                              0.9,
                                            ),
                                            AppTheme.primaryColor,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                        : null,
                                color: isSelected ? null : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFilterChip(
    String label,
    IconData icon,
    Color iconColor,
    Color bgColor,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (label.length * 20)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _searchTextController.text = label.toLowerCase();
                    setState(() {
                      _searchQuery = label.toLowerCase();
                      _isSearching = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  splashColor: iconColor.withOpacity(0.1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: iconColor.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(icon, size: 14, color: iconColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: iconColor.withOpacity(0.9),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
                            // Top section with image or colored background
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: deck.color,
                                gradient:
                                    deck.imageUrl == null
                                        ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            deck.color,
                                            deck.color.withOpacity(0.85),
                                          ],
                                        )
                                        : null,
                                image:
                                    deck.imageUrl != null
                                        ? DecorationImage(
                                          image: NetworkImage(deck.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child: Stack(
                                children: [
                                  // Gradient overlay for images
                                  if (deck.imageUrl != null)
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.4),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Decorative circles (only for non-image decks)
                                  if (deck.imageUrl == null) ...[
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
                                  ],
                                  // Icon badge
                                  Center(
                                    child: Container(
                                      width: deck.imageUrl != null ? 48 : 56,
                                      height: deck.imageUrl != null ? 48 : 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(
                                          deck.imageUrl != null ? 0.9 : 0.95,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              deck.imageUrl != null ? 0.2 : 0.1,
                                            ),
                                            blurRadius:
                                                deck.imageUrl != null ? 12 : 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: FaIcon(
                                          deck.icon,
                                          color: deck.color,
                                          size: deck.imageUrl != null ? 22 : 26,
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
    // Reset camera toggle to false when showing deck options
    setState(() {
      _isCameraEnabled = false;
    });

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

              // Camera recording toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.dividerColor, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.videocam_rounded,
                          color:
                              _isCameraEnabled
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Reactions',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Capture fun moments',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isCameraEnabled,
                      onChanged: (value) async {
                        _hapticService.lightImpact();

                        if (value) {
                          // Request camera permissions when enabling
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (context) => const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                          );

                          final cameraService = CameraRecordingService.instance;
                          final initialized = await cameraService.initialize();

                          if (mounted) {
                            Navigator.pop(context); // Close loading dialog
                          }

                          if (initialized) {
                            setState(() {
                              _isCameraEnabled = true;
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Camera ready! Your reactions will be recorded.',
                                  ),
                                  backgroundColor: AppTheme.successColor,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            // Permission denied or camera failed
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Camera permission denied. Please enable in Settings.',
                                  ),
                                  backgroundColor: AppTheme.errorColor,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        } else {
                          // Just disable it
                          setState(() {
                            _isCameraEnabled = false;
                          });

                          // Release camera resources
                          final cameraService = CameraRecordingService.instance;
                          await cameraService.releaseCamera();
                        }
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
              isCameraEnabled: _isCameraEnabled,
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
