import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../services/daily_deck_service.dart';
import '../services/streak_service.dart';
import '../models/daily_deck.dart';
import 'gameplay_screen.dart';
import 'deck_details_screen.dart';
import 'search_screen.dart';
import '../widgets/home_screen/featured_deck_widget.dart';
import '../widgets/home_screen/streak_widget.dart';
import '../widgets/home_screen/daily_deck_widget.dart';
import '../widgets/home_screen/tutorial_overlay.dart';
import '../widgets/home_screen/home_screen_utils.dart';

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _hapticService = HapticService();
  final _audioService = AudioService();
  final _dailyDeckService = DailyDeckService();
  final _streakService = StreakService();

  DailyDeck? _todaysDeck;
  bool _hasPlayedDaily = false;
  List<Deck> _recentDecks = [];
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryChipsScrollController = ScrollController();
  String _selectedCategory = 'Trending';

  // GlobalKey for tracking the category content position
  final GlobalKey _categoryContentKey = GlobalKey();

  // Tutorial element keys
  final GlobalKey _featuredDeckKey = GlobalKey();
  final GlobalKey _categoryChipsKey = GlobalKey();
  final GlobalKey _dailyChallengeKey = GlobalKey();
  final GlobalKey _continuePlayingKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();

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

  // Streak data
  int _currentStreak = 0;
  bool _hasPlayedToday = false;
  List<bool> _weeklyProgress = List.filled(7, false);
  StreakMilestone? _nextMilestone;

  // Tutorial state
  bool _hasSeenTutorial = false;
  bool _showTutorial = false;
  int _tutorialStep = 0;
  OverlayEntry? _tutorialOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDailyDeck();
    _loadRecentDecks();
    _loadStreakData();
    _checkFirstTimeUser();
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
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _categoryChipsScrollController.dispose();
    _deckRotationTimer?.cancel();
    _badgeCollapseTimer?.cancel();
    _tutorialOverlay?.remove();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh daily deck and streak data when app resumes
      debugPrint('🔄 App resumed - refreshing data');
      _loadDailyDeck();
      _loadStreakData();
    }
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

  Future<void> _loadStreakData() async {
    try {
      final streak = await _streakService.getCurrentStreak();
      final playedToday = await _streakService.hasPlayedToday();
      final weekProgress = await _streakService.getWeeklyProgress();
      final milestone = await _streakService.getNextMilestone();

      if (mounted) {
        setState(() {
          _currentStreak = streak;
          _hasPlayedToday = playedToday;
          _weeklyProgress = weekProgress;
          _nextMilestone = milestone;
        });
      }
    } catch (e) {
      debugPrint('Error loading streak data: $e');
    }
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSeenTutorial = prefs.getBool('tutorial_completed') ?? false;

    // Show tutorial for first-time users after a delay
    if (!_hasSeenTutorial && mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_showTutorial) {
          _startTutorial();
        }
      });
    }
  }

  void _startTutorial() {
    setState(() {
      _showTutorial = true;
      _tutorialStep = 0;
    });
    _showTutorialOverlay();
  }

  void _nextTutorialStep() {
    if (_tutorialStep < 4) {
      setState(() {
        _tutorialStep++;
      });
      _updateTutorialOverlay();
    } else {
      _completeTutorial();
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);

    _tutorialOverlay?.remove();
    _tutorialOverlay = null;

    setState(() {
      _showTutorial = false;
      _hasSeenTutorial = true;
    });
  }

  void _showTutorialOverlay() {
    _tutorialOverlay?.remove();

    _tutorialOverlay = OverlayEntry(
      builder: (context) {
        final tutorialSteps = [
          TutorialStep(
            title: 'Welcome to Heads Up!',
            description:
                'This is your featured deck. Swipe left or right to explore different decks, or tap to see details.',
            targetKey: _featuredDeckKey,
          ),
          TutorialStep(
            title: 'Browse Categories',
            description:
                'Explore different categories or search for specific decks using these chips.',
            targetKey: _categoryChipsKey,
          ),
          TutorialStep(
            title: 'Daily Challenge',
            description:
                'Complete a new challenge every day to maintain your streak!',
            targetKey: _dailyChallengeKey,
          ),
          TutorialStep(
            title: 'Continue Playing',
            description: 'Your recent games appear here for quick access.',
            targetKey: _continuePlayingKey,
          ),
          TutorialStep(
            title: 'Navigation',
            description:
                'Access home, explore new content, view your games, or change settings using the bottom navigation.',
            targetKey: _bottomNavKey,
          ),
        ];

        return TutorialOverlay(
          tutorialSteps: tutorialSteps,
          currentStep: _tutorialStep,
          onNextStep: _nextTutorialStep,
          onSkipTutorial: _skipTutorial,
        );
      },
    );

    Overlay.of(context).insert(_tutorialOverlay!);
  }

  void _updateTutorialOverlay() {
    _tutorialOverlay?.markNeedsBuild();
  }

  void _playDeck(Deck deck) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);

    _hapticService.lightImpact();
    _audioService.playCorrect();

    gameProvider.startGame(deck: deck);
    deckProvider.addToRecentDecks(deck.id);

    // Record play for streak tracking
    await _streakService.recordPlay();
    // Reload streak data to update UI
    await _loadStreakData();

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => GameplayScreen(deck: deck)));
  }

  List<Deck> _getFilteredDecks(List<Deck> decks) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);

    switch (_selectedCategory) {
      case 'Trending':
        return _getTrendingDecks(decks);
      case 'Quick':
        return _getQuickDecks(decks);
      case 'Party':
        return _getPartyDecks(decks);
      case 'My Decks':
        return deckProvider.customDecks;
      case 'Favorites':
        final favorites = deckProvider.favoriteDecksAsList;
        return favorites.isNotEmpty ? favorites : decks.take(3).toList();
      default:
        return decks;
    }
  }

  String _getCategoryTitle() {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);

    switch (_selectedCategory) {
      case 'Trending':
        return 'Trending Now';
      case 'Quick':
        return 'Quick Games';
      case 'Party':
        return 'Party Mode';
      case 'My Decks':
        final count = deckProvider.customDecks.length;
        return count > 0 ? 'Your Creations' : 'No Custom Decks Yet';
      case 'Favorites':
        final count = deckProvider.favoriteDecks.length;
        return count > 0 ? 'My Favorites' : 'No Favorites Yet';
      default:
        return 'All Decks';
    }
  }

  IconData _getCategoryIcon() {
    switch (_selectedCategory) {
      case 'Trending':
        return Icons.local_fire_department_rounded;
      case 'Quick':
        return Icons.bolt_rounded;
      case 'Party':
        return Icons.celebration_rounded;
      case 'My Decks':
        return Icons.create_rounded;
      case 'Favorites':
        return Icons.star_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (_selectedCategory) {
      case 'Trending':
        return const Color(0xFFFF6B35);
      case 'Quick':
        return const Color(0xFFFFC107);
      case 'Party':
        return const Color(0xFFE91E63);
      case 'My Decks':
        return const Color(0xFF00BCD4);
      case 'Favorites':
        return const Color(0xFFFFD700);
      default:
        return Colors.purple;
    }
  }

  /// Get dynamic category data with counts, new indicators, and metadata
  List<Map<String, dynamic>> _getDynamicCategories(BuildContext context) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final allDecks = deckProvider.allDecks;
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    // Calculate filtered deck counts
    final trendingDecks = _getTrendingDecks(allDecks);
    final quickDecks = _getQuickDecks(allDecks);
    final partyDecks = _getPartyDecks(allDecks);
    final favoriteCount = deckProvider.favoriteDecks.length;
    final customDecksCount = deckProvider.customDecks.length;

    // Check for new content (decks created within 3 days)
    final newTrendingCount =
        trendingDecks.where((d) => d.createdAt.isAfter(threeDaysAgo)).length;
    final newPartyCount =
        partyDecks.where((d) => d.createdAt.isAfter(threeDaysAgo)).length;

    return [
      {
        'name': 'Trending',
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFFF6B35),
        'count': trendingDecks.length,
        'hasNew': newTrendingCount > 0,
        'newCount': newTrendingCount,
      },
      {
        'name': 'Quick',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFFFC107),
        'count': quickDecks.length,
        'hasNew': false,
      },
      {
        'name': 'Party',
        'icon': Icons.celebration_rounded,
        'color': const Color(0xFFE91E63),
        'count': partyDecks.length,
        'hasNew': newPartyCount > 0,
        'newCount': newPartyCount,
      },
      {
        'name': 'My Decks',
        'icon':
            customDecksCount > 0
                ? Icons.create_rounded
                : Icons.add_circle_outline_rounded,
        'color':
            customDecksCount > 0
                ? const Color(0xFF00BCD4)
                : const Color(0xFF666666),
        'count': customDecksCount,
        'isEmpty': customDecksCount == 0,
        'hasNew': false,
      },
      {
        'name': 'Favorites',
        'icon':
            favoriteCount > 0 ? Icons.star_rounded : Icons.star_outline_rounded,
        'color':
            favoriteCount > 0
                ? const Color(0xFFFFD700)
                : const Color(0xFF666666),
        'count': favoriteCount,
        'isEmpty': favoriteCount == 0,
        'hasNew': false,
      },
    ];
  }

  /// Get trending decks with smart scoring algorithm
  /// Combines priority, recency, and card count sweet spot
  List<Deck> _getTrendingDecks(List<Deck> decks) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return (List<Deck>.from(decks)..sort((a, b) {
      // Calculate trending score for each deck
      int scoreA = (10 - a.priority) * 100;
      int scoreB = (10 - b.priority) * 100;

      // Boost new decks created within last 7 days
      if (a.createdAt.isAfter(sevenDaysAgo)) scoreA += 500;
      if (b.createdAt.isAfter(sevenDaysAgo)) scoreB += 500;

      // Favor sweet spot card count (10-30 cards)
      if (a.cards.length >= 10 && a.cards.length <= 30) scoreA += 200;
      if (b.cards.length >= 10 && b.cards.length <= 30) scoreB += 200;

      return scoreB.compareTo(scoreA);
    })).take(15).toList();
  }

  /// Get quick play decks (5-12 cards for 3-8 minute games)
  List<Deck> _getQuickDecks(List<Deck> decks) {
    final quick =
        decks.where((d) => d.cards.length >= 5 && d.cards.length <= 12).toList()
          ..sort((a, b) => a.cards.length.compareTo(b.cards.length));
    return quick.isNotEmpty ? quick : decks.take(10).toList();
  }

  /// Get party decks (20-40 cards OR party-related tags)
  List<Deck> _getPartyDecks(List<Deck> decks) {
    const partyKeywords = [
      'party',
      'group',
      'family',
      'multiplayer',
      'friends',
      'fun',
      'acting',
      'charades',
    ];

    return decks.where((d) {
        final goodLength = d.cards.length >= 20 && d.cards.length <= 40;
        final hasPartyTag = d.tags.any(
          (tag) => partyKeywords.any(
            (keyword) => tag.toLowerCase().contains(keyword),
          ),
        );
        return goodLength || hasPartyTag;
      }).toList()
      ..sort((a, b) => b.cards.length.compareTo(a.cards.length));
  }

  /// Smoothly scrolls to the category content section
  void _scrollToCategoryContent() {
    // Use a post-frame callback to ensure the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final RenderBox? renderBox =
          _categoryContentKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox != null && _scrollController.hasClients) {
        // Get the position of the category content relative to the viewport
        final position = renderBox.localToGlobal(Offset.zero);

        // Calculate target scroll offset
        // We want to position the content just below the category chips
        // Account for the app bar height and category chips height
        final targetOffset =
            _scrollController.offset +
            position.dy -
            MediaQuery.of(context).padding.top -
            150; // 150 accounts for header + chips

        // Clamp the target to valid scroll range
        final maxScroll = _scrollController.position.maxScrollExtent;
        final clampedOffset = targetOffset.clamp(0.0, maxScroll);

        // Animate to the target position with smooth easing
        _scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  /// Centers the selected category chip in the horizontal scroll view
  void _centerSelectedChip(int selectedIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_categoryChipsScrollController.hasClients) return;

      // Calculate approximate chip width (including padding)
      // Each chip is approximately 120-150 pixels wide with 12px right padding
      const double estimatedChipWidth = 132.0;

      // Get the screen width to find the center point
      final double screenWidth = MediaQuery.of(context).size.width;

      // Calculate the position where the selected chip should be
      // to be centered on screen
      final double chipPosition = selectedIndex * estimatedChipWidth;

      // Account for the fixed search chip and divider on the left
      // Search chip (~90px) + divider (~1.5px) + padding (~36px) ≈ 127px
      const double leftOffset = 127.0;

      // Calculate target scroll position to center the chip
      // We want the chip center to align with screen center
      final double targetScroll =
          chipPosition -
          (screenWidth / 2) +
          (estimatedChipWidth / 2) +
          leftOffset;

      // Clamp to valid scroll range
      final double maxScroll =
          _categoryChipsScrollController.position.maxScrollExtent;
      final double minScroll =
          _categoryChipsScrollController.position.minScrollExtent;
      final double clampedScroll = targetScroll.clamp(minScroll, maxScroll);

      // Animate to center position with smooth easing
      _categoryChipsScrollController.animateTo(
        clampedScroll,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
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
            bottomNavigationBar: _buildBottomNav(),
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
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                final availableDecks =
                                    deckProvider.freeDecks.isNotEmpty
                                        ? deckProvider.freeDecks
                                        : deckProvider.allDecks;

                                return FeaturedDeckWidget(
                                  availableDecks: availableDecks,
                                  currentFeaturedIndex: _currentFeaturedIndex,
                                  onNavigateToDeck:
                                      (direction) => _navigateToDeck(
                                        direction,
                                        availableDecks,
                                      ),
                                  onPlayDeck: _playDeck,
                                  onShowDeckDetails:
                                      (deck, {required heroTag}) =>
                                          _showDeckDetails(
                                            deck,
                                            heroTag: heroTag,
                                          ),
                                  tutorialKey: _featuredDeckKey,
                                  hapticService: _hapticService,
                                );
                              },
                            ),

                            const SizedBox(height: 0),

                            // Category chips
                            _buildCategoryChips(),

                            const SizedBox(height: 16),

                            // Daily deck section
                            if (_todaysDeck != null) ...[
                              DailyDeckWidget(
                                todaysDeck: _todaysDeck,
                                hasPlayedDaily: _hasPlayedDaily,
                                onPlayDeck: (dailyDeck) {
                                  final deck = Deck(
                                    id: dailyDeck.id,
                                    name: dailyDeck.title,
                                    description: dailyDeck.description,
                                    icon: Icons.today_rounded,
                                    cards:
                                        dailyDeck.cards
                                            .map((c) => c.word)
                                            .toList(),
                                    imageUrl: dailyDeck.imageUrl,
                                    color: Color(dailyDeck.color),
                                    createdAt: DateTime.now(),
                                  );
                                  _playDeck(deck);
                                },
                                onShowPremium: () {
                                  if (_todaysDeck != null) {
                                    final deck = Deck(
                                      id: _todaysDeck!.id,
                                      name: _todaysDeck!.title,
                                      description: _todaysDeck!.description,
                                      icon: Icons.today_rounded,
                                      cards:
                                          _todaysDeck!.cards
                                              .map((c) => c.word)
                                              .toList(),
                                      imageUrl: _todaysDeck!.imageUrl,
                                      color: Color(_todaysDeck!.color),
                                      createdAt: DateTime.now(),
                                    );
                                    _showPremiumDialog(deck);
                                  }
                                },
                                hapticService: _hapticService,
                                tutorialKey: _dailyChallengeKey,
                              ),
                              const SizedBox(height: 30),
                            ],

                            // Continue playing section with larger cards
                            if (_recentDecks.isNotEmpty) ...[
                              _buildContinueWatchingSection(),
                              const SizedBox(height: 24),
                            ],

                            // Recommended for you (filtered by category)
                            // Wrapped with key to track position for smooth scrolling
                            Container(
                              key: _categoryContentKey,
                              child: Consumer<DeckProvider>(
                                builder: (context, deckProvider, _) {
                                  final filteredDecks = _getFilteredDecks(
                                    deckProvider.freeDecks,
                                  );

                                  // Special handling for empty Favorites
                                  if (_selectedCategory == 'Favorites' &&
                                      deckProvider.favoriteDecks.isEmpty) {
                                    return _buildEmptyFavoritesState(
                                      deckProvider,
                                    );
                                  }

                                  // Special handling for empty My Decks
                                  if (_selectedCategory == 'My Decks' &&
                                      deckProvider.customDecks.isEmpty) {
                                    return _buildCreateCustomDeckPrompt();
                                  }

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
                            ),

                            const SizedBox(height: 32),

                            // Enhanced streak widget
                            StreakWidget(
                              currentStreak: _currentStreak,
                              hasPlayedToday: _hasPlayedToday,
                              weeklyProgress: _weeklyProgress,
                              nextMilestone: _nextMilestone,
                              onPlayToday: () {
                                context.push('/categories');
                              },
                              hapticService: _hapticService,
                            ),

                            const SizedBox(height: 32),

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

                            // Quick stats banner
                            _buildStatsSection(),

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
                          Row(
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
                              Consumer<DeckProvider>(
                                builder: (context, deckProvider, _) {
                                  final hasUnlockedPremium = deckProvider
                                      .unlockedDecks
                                      .any((deck) => deck.isPremium);
                                  if (!hasUnlockedPremium) {
                                    return const SizedBox();
                                  }
                                  return Container(
                                        margin: const EdgeInsets.only(left: 12),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFFFFD700),
                                              const Color(0xFFFFA500),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFFD700,
                                              ).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.workspace_premium_rounded,
                                              size: 14,
                                              color: Colors.black,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'VIP',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: 300.ms, duration: 600.ms)
                                      .scale(
                                        begin: const Offset(0.8, 0.8),
                                        end: const Offset(1, 1),
                                        delay: 300.ms,
                                        duration: 400.ms,
                                        curve: Curves.easeOutBack,
                                      )
                                      .shimmer(
                                        duration: 2000.ms,
                                        delay: 1000.ms,
                                        color: Colors.white.withOpacity(0.5),
                                      );
                                },
                              ),
                            ],
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
                                          '$_currentStreak day${_currentStreak == 1 ? '' : 's'}',
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
                                          '$_currentStreak',
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
    final categories = _getDynamicCategories(context);

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: 42,
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
                      right: 0,
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
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(
                    delay: 400.ms,
                    duration: 600.ms,
                    curve: Curves.easeOut,
                  )
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
                      stops: const [
                        0.0,
                        0.015,
                        0.03,
                        0.05,
                        0.95,
                        0.97,
                        0.985,
                        1.0,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    controller: _categoryChipsScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryName = category['name'] as String;
                      final categoryColor = category['color'] as Color;
                      final isSelected = _selectedCategory == categoryName;
                      final count = category['count'] as int?;
                      final hasNew = category['hasNew'] as bool? ?? false;
                      final isEmpty = category['isEmpty'] as bool? ?? false;
                      final newCount = category['newCount'] as int? ?? 0;

                      return _buildCategoryChip(
                        categoryName: categoryName,
                        categoryIcon: category['icon'] as IconData,
                        categoryColor: categoryColor,
                        isSelected: isSelected,
                        index: index,
                        count: count,
                        hasNew: hasNew,
                        isEmpty: isEmpty,
                        newCount: newCount,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String categoryName,
    required IconData categoryIcon,
    required Color categoryColor,
    required bool isSelected,
    required int index,
    int? count,
    bool hasNew = false,
    bool isEmpty = false,
    int newCount = 0,
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
                // Center the selected chip in view
                _centerSelectedChip(index);
                // Scroll to category content smoothly
                _scrollToCategoryContent();
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
                  color:
                      isSelected
                          ? null
                          : isEmpty
                          ? Colors.white.withOpacity(0.03)
                          : Colors.white.withOpacity(0.06),
                  border: Border.all(
                    color:
                        isSelected
                            ? categoryColor.withOpacity(0.5)
                            : isEmpty && !isSelected
                            ? Colors.white.withOpacity(0.08)
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
                                : isEmpty && !isSelected
                                ? Colors.white.withOpacity(0.4)
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
                                : isEmpty && !isSelected
                                ? Colors.white.withOpacity(0.4)
                                : Colors.white.withOpacity(0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                    // Show "NEW" badge for categories with new content
                    if (hasNew && newCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'NEW',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ]
                    // Show count badge if no NEW badge
                    else if (count != null && count > 0 && !hasNew) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildEmptyFavoritesState(DeckProvider deckProvider) {
    // Get suggested decks to get started
    final suggestedDecks =
        _getTrendingDecks(deckProvider.allDecks).take(3).toList();

    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main empty state card with modern design
              Container(
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
                              const Color(0xFFFFD700).withOpacity(0.05),
                              const Color(0xFFFFA500).withOpacity(0.08),
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
                          vertical: 32,
                        ),
                        child: Column(
                          children: [
                            // Icon with elegant animation
                            Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFFFFD700,
                                        ).withOpacity(0.2),
                                        const Color(
                                          0xFFFFA500,
                                        ).withOpacity(0.15),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFFD700,
                                      ).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFD700,
                                        ).withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: const Color(0xFFFFD700),
                                    size: 32,
                                  ),
                                )
                                .animate(
                                  onPlay:
                                      (controller) =>
                                          controller.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.1, 1.1),
                                  duration: 2000.ms,
                                  curve: Curves.easeInOut,
                                )
                                .then()
                                .shimmer(
                                  duration: 1500.ms,
                                  color: Colors.white.withOpacity(0.2),
                                ),

                            const SizedBox(height: 20),

                            // Title with premium typography
                            Text(
                                  'No Favorites Yet',
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
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

                            const SizedBox(height: 12),

                            // Subtitle with elegant opacity
                            Text(
                                  'Tap the star icon on any deck to add it to your favorites for quick access anytime!',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.6),
                                    letterSpacing: -0.1,
                                    height: 1.6,
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

                            const SizedBox(height: 24),

                            // Feature highlights
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildFeatureTag(
                                  icon: Icons.favorite_rounded,
                                  label: 'Quick Access',
                                  delay: 400,
                                ),
                                const SizedBox(width: 8),
                                _buildFeatureTag(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Track Favorites',
                                  delay: 500,
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

              // Suggested decks to get started
              if (suggestedDecks.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFF6B35),
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
                    Text(
                          'Suggested to Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 250.ms, duration: 500.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          delay: 250.ms,
                          duration: 500.ms,
                        ),
                  ],
                ),
                const SizedBox(height: 16),
                // Horizontal scrolling deck cards like other sections
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
                        stops: const [
                          0.0,
                          0.025,
                          0.05,
                          0.08,
                          0.92,
                          0.95,
                          0.975,
                          1.0,
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: suggestedDecks.length,
                      itemBuilder: (context, index) {
                        return _buildDeckCard(
                          suggestedDecks[index],
                          index: index,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
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

  Widget _buildSearchChip() {
    const searchColor = Color(0xFF9B59B6); // Elegant purple

    return Hero(
      tag: 'search_chip',
      placeholderBuilder: (context, heroSize, child) {
        // Return a placeholder that matches the child during hero flight
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
            border: Border.all(color: searchColor.withOpacity(0.4), width: 1.2),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _hapticService.selection();
            // Navigate to search screen with premium Hero transition
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const SearchScreen(),
                transitionDuration: const Duration(milliseconds: 600),
                reverseTransitionDuration: const Duration(milliseconds: 500),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  // Multi-layer animation for premium feel
                  const curve = Curves.easeInOutCubic;

                  // Fade animation
                  final fadeAnimation = Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).chain(CurveTween(curve: curve)).animate(animation);

                  // Scale animation for subtle zoom effect
                  final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0)
                      .chain(CurveTween(curve: Curves.easeOutCubic))
                      .animate(animation);

                  // Slide animation for directional movement
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0.0, 0.02),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: curve)).animate(animation);

                  // Combine all animations for premium transition
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: fadeAnimation,
                        child: SlideTransition(
                          position: slideAnimation,
                          child: ScaleTransition(
                            scale: scaleAnimation,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: child,
                  );
                },
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
                      onPlay: (controller) => controller.repeat(reverse: true),
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
      ),
    );
  }

  Widget _buildContinueWatchingSection() {
    if (_recentDecks.isEmpty) return const SizedBox();

    return Column(
      key: _continuePlayingKey,
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
    final deckProvider = Provider.of<DeckProvider>(context, listen: true);

    // Show skeleton loader when data is loading
    if (deckProvider.isLoading) {
      return _buildSectionSkeleton(
        title: title,
        icon: icon,
        iconColor: iconColor,
      );
    }

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
              // Premium "Explore more" for Trending Now
              if (title == 'Trending Now')
                GestureDetector(
                      onTap: () {
                        _hapticService.lightImpact();
                        context.push(
                          '/explore?category=${Uri.encodeComponent('Trending Now')}',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explore',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white.withOpacity(0.85),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 600.ms)
                    .slideX(
                      begin: 0.3,
                      end: 0,
                      delay: 300.ms,
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .shimmer(
                      delay: 800.ms,
                      duration: 1500.ms,
                      color: Colors.white.withOpacity(0.1),
                    ),
              // Original "See All" for other sections
              if (showSeeAll && title != 'Trending Now')
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
                    // Card container with premium styling
                    Container(
                      height: 200,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isPremium && !isUnlocked
                                  ? const Color(0xFFFFD700).withOpacity(0.5)
                                  : isPremium && isUnlocked
                                  ? const Color(0xFFFFD700).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.08),
                          width: isPremium ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isPremium)
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: -2,
                            ),
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

                            // Premium badge
                            if (isPremium)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFFFD700),
                                            const Color(0xFFFFA500),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.workspace_premium_rounded,
                                            size: 12,
                                            color: Colors.black,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'PREMIUM',
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 200.ms)
                                    .scale(
                                      begin: const Offset(0.8, 0.8),
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
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with deck preview
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            deck.color.withOpacity(0.8),
                            deck.color.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Subtle pattern overlay
                          Positioned.fill(
                            child: CustomPaint(
                              painter: DotPatternPainter(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  deck.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFFD700),
                                      const Color(0xFFFFA500),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Unlock Premium',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Benefits list
                          ...[
                            _buildBenefitItem(
                              Icons.all_inclusive_rounded,
                              'Unlimited access to all ${deck.cards.length} cards',
                            ),
                            _buildBenefitItem(
                              Icons.star_rounded,
                              'Exclusive premium content',
                            ),
                            _buildBenefitItem(
                              Icons.update_rounded,
                              'Regular updates with new cards',
                            ),
                            _buildBenefitItem(
                              Icons.offline_pin_rounded,
                              'Play offline anytime',
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Price
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'One-time purchase',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '\$2.99',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // CTA Buttons
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _hapticService.mediumImpact();
                                  // TODO: Implement unlock functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Premium unlock coming soon!',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: const Color(0xFFFFD700),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFFD700),
                                        const Color(0xFFFFA500),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFD700,
                                        ).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Unlock Now',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Secondary actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Maybe Later',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  // TODO: Implement restore purchases
                                },
                                child: Text(
                                  'Restore Purchases',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 14,
                                  ),
                                ),
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
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFFFD700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      key: _bottomNavKey,
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
                _buildNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: false,
                  onTap: () {
                    _hapticService.lightImpact();
                    context.push('/settings');
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

  Widget _buildSectionSkeleton({
    required String title,
    IconData? icon,
    Color? iconColor,
  }) {
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
                  child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
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
              ),
            ],
          ),
        ),

        // Skeleton cards scroll view
        SizedBox(
          height: 200,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 20, right: 12),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return _buildDeckCardSkeleton(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeckCardSkeleton(int index) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton card container
          Container(
                height: 200,
                width: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skeleton icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      // Skeleton text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 100,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 1500.ms,
                color: Colors.white.withOpacity(0.05),
                angle: 0,
              ),
        ],
      ),
    );
  }
}
