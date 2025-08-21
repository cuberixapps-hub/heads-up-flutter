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
import 'dart:ui';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
          // Modern Sliver App Bar with solid color
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                _hapticService.lightImpact();
                Navigator.pop(context);
              },
              icon: Container(
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
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.primaryColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Category',
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3),
                        const SizedBox(height: 6),
                        Text(
                              'Pick your favorite deck',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 600.ms)
                            .slideY(begin: 0.3),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(child: _buildSearchBar()),

          // Tab Bar
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Free'),
                    Tab(text: 'Custom'),
                  ],
                ),
              ),
            ),
          ),

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.softShadow,
        ),
        child: TextField(
          controller: _searchTextController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
              _isSearching = value.isNotEmpty;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search categories...',
            hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppTheme.textSecondary,
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      onPressed: () {
                        _searchTextController.clear();
                        setState(() {
                          _searchQuery = '';
                          _isSearching = false;
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.clear_rounded,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.2);
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
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
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
                  child: FadeInAnimation(
                    child: _buildDeckCard(deck, isUnlocked, index),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDeckCard(Deck deck, bool isUnlocked, int index) {
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
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            // Card Background with solid color
            Container(
              decoration: BoxDecoration(
                color: deck.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: deck.color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: FaIcon(deck.icon, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text(
                    deck.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    deck.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Card count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${deck.cards.length} cards',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Lock overlay with blur effect
            if (deck.isPremium && !isUnlocked)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: AppTheme.textPrimary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Custom badge
            if (deck.isCustom)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CUSTOM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          if (type == DeckType.custom) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _hapticService.lightImpact();
                _showCreateCustomDeck();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create Custom Deck'),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeckOptions(Deck deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildDeckOptionsSheet(deck),
    );
  }

  Widget _buildDeckOptionsSheet(Deck deck) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Deck preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: deck.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: deck.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FaIcon(deck.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${deck.cards.length} exciting cards',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Play button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.buttonShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _hapticService.mediumImpact();
                      Navigator.pop(context);
                      _startGame(deck);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Start Game',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (deck.isCustom) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _editCustomDeck(deck);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteCustomDeck(deck);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        label: const Text('Delete'),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: AppTheme.errorColor,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Premium Deck',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    deck.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: deck.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    deck.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '🎬 Watch an ad to unlock for one game\n💎 Or purchase to unlock forever!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _watchAdToUnlock(deck);
                          },
                          icon: const Icon(Icons.play_circle_outline, size: 16),
                          label: const Text('Watch Ad'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _purchaseDeck(deck);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Center(
                            child: Text(
                              '✨ Purchase Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }

  void _startGame(Deck deck) {
    context.read<DeckProvider>().addToRecentDecks(deck.id);
    context.read<GameProvider>().startGame(deck: deck);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameplayScreen(deck: deck)),
    );
  }

  void _showCreateCustomDeck() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom deck creation coming soon!')),
    );
  }

  void _editCustomDeck(Deck deck) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Edit ${deck.name} coming soon!')));
  }

  void _deleteCustomDeck(Deck deck) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Deck'),
            content: Text('Are you sure you want to delete "${deck.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  context.read<DeckProvider>().deleteCustomDeck(deck.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${deck.name} deleted')),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
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
