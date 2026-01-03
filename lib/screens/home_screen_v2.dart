import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
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
import 'paywall_screen.dart';
import '../widgets/home_screen/featured_deck_widget.dart';
import '../widgets/home_screen/streak_widget.dart';
import '../widgets/home_screen/daily_deck_widget.dart';
import '../widgets/home_screen/tutorial_overlay.dart';
import '../widgets/home_screen/home_screen_utils.dart';
import '../utils/premium_utils.dart';
import '../utils/responsive.dart';

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
        
        // 🌍 Debug print the user's country for engagement tracking
        _debugPrintUserCountryInfo(deckProvider);
        
        final availableDecks = _getCountryPrioritizedDecks(deckProvider);
        if (availableDecks.isNotEmpty) {
          _updateGradientColors(availableDecks.first.color);
        }
      }
    });
  }

  /// Debug prints user country information and deck prioritization stats
  void _debugPrintUserCountryInfo(DeckProvider deckProvider) {
    final userCountry = deckProvider.userCountryCode;
    final isManual = deckProvider.isUsingManualCountry;
    
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🌍 USER COUNTRY DETECTION');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📍 Country Code: $userCountry');
    debugPrint('🔧 Manual Override: ${isManual ? "YES" : "NO (auto-detected)"}');
    debugPrint('───────────────────────────────────────────────────────────');
    
    // Count decks by country match
    final allDecks = deckProvider.allDecks;
    int countrySpecificDecks = 0;
    int universalDecks = 0;
    int otherDecks = 0;
    
    for (final deck in allDecks) {
      if (deck.effectiveCountries.contains(userCountry)) {
        countrySpecificDecks++;
      } else if (deck.effectiveCountries.contains('UNIVERSAL')) {
        universalDecks++;
      } else {
        otherDecks++;
      }
    }
    
    debugPrint('📊 DECK DISTRIBUTION:');
    debugPrint('   • Country-specific ($userCountry): $countrySpecificDecks decks');
    debugPrint('   • Universal decks: $universalDecks decks');
    debugPrint('   • Regional/Other: $otherDecks decks');
    debugPrint('   • Total decks available: ${allDecks.length}');
    debugPrint('───────────────────────────────────────────────────────────');
    
    // Show top recommended decks for this country
    final topRecommended = deckProvider.getTopRecommendedDecks(limit: 5);
    debugPrint('🎯 TOP 5 RECOMMENDED DECKS FOR $userCountry:');
    for (int i = 0; i < topRecommended.length; i++) {
      final deck = topRecommended[i];
      final countries = deck.effectiveCountries.join(', ');
      debugPrint('   ${i + 1}. ${deck.name} [Countries: $countries]');
    }
    debugPrint('═══════════════════════════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧪 DEBUG ONLY: Country Selector for Testing Recommendations
  // This entire section is excluded from production builds via kDebugMode
  // ═══════════════════════════════════════════════════════════════════════════
  
  bool _debugPanelExpanded = false;
  
  /// Test countries for recommendation testing
  static const List<Map<String, String>> _testCountries = [
    {'code': 'US', 'name': '🇺🇸 United States', 'flag': '🇺🇸'},
    {'code': 'IN', 'name': '🇮🇳 India', 'flag': '🇮🇳'},
    {'code': 'GB', 'name': '🇬🇧 United Kingdom', 'flag': '🇬🇧'},
    {'code': 'JP', 'name': '🇯🇵 Japan', 'flag': '🇯🇵'},
    {'code': 'KR', 'name': '🇰🇷 South Korea', 'flag': '🇰🇷'},
    {'code': 'BR', 'name': '🇧🇷 Brazil', 'flag': '🇧🇷'},
    {'code': 'MX', 'name': '🇲🇽 Mexico', 'flag': '🇲🇽'},
    {'code': 'CN', 'name': '🇨🇳 China', 'flag': '🇨🇳'},
    {'code': 'AU', 'name': '🇦🇺 Australia', 'flag': '🇦🇺'},
    {'code': 'DE', 'name': '🇩🇪 Germany', 'flag': '🇩🇪'},
  ];

  Widget _buildDebugCountrySelector(DeckProvider deckProvider) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60.s,
      right: 16.s,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Toggle button
          GestureDetector(
            onTap: () {
              setState(() {
                _debugPanelExpanded = !_debugPanelExpanded;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 8.s),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20.s),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bug_report_rounded,
                    color: Colors.white,
                    size: 16.s,
                  ),
                  SizedBox(width: 6.s),
                  Text(
                    '🧪 ${deckProvider.userCountryCode}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4.s),
                  Icon(
                    _debugPanelExpanded 
                        ? Icons.expand_less_rounded 
                        : Icons.expand_more_rounded,
                    color: Colors.white,
                    size: 16.s,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded country list
          if (_debugPanelExpanded) ...[
            SizedBox(height: 8.s),
            Container(
              width: 200.s,
              constraints: BoxConstraints(maxHeight: 350.s),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16.s),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.s),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.3),
                            Colors.orange.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🧪 DEBUG MODE',
                            style: GoogleFonts.robotoMono(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 4.s),
                          Text(
                            'Test Country Recommendations',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Reset to auto-detect option
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await deckProvider.resetToAutoDetectedCountry();
                          setState(() {
                            _debugPanelExpanded = false;
                          });
                          _debugPrintUserCountryInfo(deckProvider);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.s,
                            vertical: 10.s,
                          ),
                          decoration: BoxDecoration(
                            color: deckProvider.isUsingManualCountry
                                ? Colors.transparent
                                : Colors.green.withOpacity(0.2),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 16.s,
                                color: Colors.green,
                              ),
                              SizedBox(width: 10.s),
                              Expanded(
                                child: Text(
                                  'Auto-detect',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: deckProvider.isUsingManualCountry
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (!deckProvider.isUsingManualCountry)
                                Icon(
                                  Icons.check_rounded,
                                  size: 16.s,
                                  color: Colors.green,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Country list
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _testCountries.length,
                        itemBuilder: (context, index) {
                          final country = _testCountries[index];
                          final isSelected = 
                              deckProvider.userCountryCode == country['code'] &&
                              deckProvider.isUsingManualCountry;
                          
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                debugPrint('🧪 Switching to test country: ${country['code']}');
                                await deckProvider.setUserCountry(country['code']);
                                setState(() {
                                  _debugPanelExpanded = false;
                                  _currentFeaturedIndex = 0; // Reset featured index
                                });
                                _debugPrintUserCountryInfo(deckProvider);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.s,
                                  vertical: 10.s,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.orange.withOpacity(0.2)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      country['flag']!,
                                      style: TextStyle(fontSize: 16.sp),
                                    ),
                                    SizedBox(width: 10.s),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            country['code']!,
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected 
                                                  ? Colors.orange 
                                                  : Colors.white,
                                            ),
                                          ),
                                          Text(
                                            country['name']!.replaceAll(RegExp(r'[^\w\s]'), '').trim(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10.sp,
                                              color: Colors.white.withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 16.s,
                                        color: Colors.orange,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Footer disclaimer
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10.s),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                      ),
                      child: Text(
                        '⚠️ Debug only - Hidden in production',
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          color: Colors.red.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // END DEBUG SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get decks prioritized by user's country for better engagement
  /// STRICT ORDER: Country-specific decks FIRST, then universal, then others
  List<Deck> _getCountryPrioritizedDecks(DeckProvider deckProvider) {
    final userCountry = deckProvider.userCountryCode;
    final decks = deckProvider.freeDecks.isNotEmpty
        ? deckProvider.freeDecks
        : deckProvider.allDecks;
    
    if (decks.isEmpty) return decks;

    // Separate decks into strict tiers
    final List<Deck> countrySpecificDecks = [];
    final List<Deck> universalDecks = [];
    final List<Deck> otherDecks = [];

    for (final deck in decks) {
      final countries = deck.effectiveCountries;
      if (countries.contains(userCountry)) {
        countrySpecificDecks.add(deck);
      } else if (countries.contains('UNIVERSAL')) {
        universalDecks.add(deck);
      } else {
        otherDecks.add(deck);
      }
    }

    // Sort each tier by priority
    countrySpecificDecks.sort((a, b) => a.priority.compareTo(b.priority));
    universalDecks.sort((a, b) => a.priority.compareTo(b.priority));
    otherDecks.sort((a, b) => a.priority.compareTo(b.priority));

    // Return with STRICT priority order
    return [
      ...countrySpecificDecks,
      ...universalDecks,
      ...otherDecks,
    ];
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
        // 🌍 Use country-prioritized decks for rotation
        final availableDecks = _getCountryPrioritizedDecks(deckProvider);

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
    // Scroll to the first target (featured deck) for better UX
    _scrollToTutorialTarget(0);
  }

  void _nextTutorialStep() {
    if (_tutorialStep < 3) {
      setState(() {
        _tutorialStep++;
      });
      _updateTutorialOverlay();
      // Scroll to the next target element for better UX
      _scrollToTutorialTarget(_tutorialStep);
    } else {
      _completeTutorial();
    }
  }

  /// Scrolls to make the current tutorial target visible
  void _scrollToTutorialTarget(int stepIndex) {
    GlobalKey? targetKey;
    
    switch (stepIndex) {
      case 0:
        targetKey = _featuredDeckKey;
        break;
      case 1:
        targetKey = _categoryChipsKey;
        break;
      case 2:
        targetKey = _dailyChallengeKey;
        break;
      case 3:
        targetKey = _continuePlayingKey;
        break;
    }
    
    if (targetKey == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      
      final renderObject = targetKey!.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderBox) {
        final targetPosition = renderObject.localToGlobal(Offset.zero);
        final screenHeight = MediaQuery.of(context).size.height;
        final targetHeight = renderObject.size.height;
        
        // Calculate the ideal scroll position to center the target
        // with some offset for the tutorial overlay at the bottom
        final targetCenterY = targetPosition.dy + (targetHeight / 2);
        final idealViewportCenterY = screenHeight * 0.35; // Slightly above center
        
        // Calculate how much we need to scroll
        final scrollDelta = targetCenterY - idealViewportCenterY;
        final newScrollOffset = _scrollController.offset + scrollDelta;
        
        // Clamp to valid scroll range
        final clampedOffset = newScrollOffset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        
        // Only scroll if the target is not already well-visible
        if ((targetPosition.dy < 100 || targetPosition.dy > screenHeight * 0.5)) {
          _scrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          ).then((_) {
            // Update the overlay after scrolling to refresh spotlight position
            if (mounted && _showTutorial) {
              _updateTutorialOverlay();
            }
          });
        } else {
          // Even if we don't scroll, update the overlay to ensure spotlight is correct
          if (mounted && _showTutorial) {
            _updateTutorialOverlay();
          }
        }
      }
    });
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
    // Check if deck is premium and user doesn't have premium access
    if (deck.isPremium && !PremiumUtils.hasPremium) {
      _showPaywall(deck);
      return;
    }
    
    // User has access - start game directly
    _startGameWithDeck(deck);
  }
  
  void _showPaywall(Deck deck) {
    _hapticService.lightImpact();
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PaywallScreen(
          selectedDeck: deck,
          onWatchAd: () {
            Navigator.pop(context);
            // Simulate ad watched - in production, integrate actual ad SDK
            _onAdWatched(deck);
          },
          onPurchasePremium: () {
            Navigator.pop(context);
            // Show premium purchase dialog
            _showPremiumPurchaseDialog(deck);
          },
          onClose: () {
            Navigator.pop(context);
          },
        ),
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeInOutCubic;
          
          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: curve)).animate(animation);
          
          final scaleAnimation = Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }
  
  void _onAdWatched(Deck deck) async {
    // Show loading indicator briefly
    _hapticService.mediumImpact();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Ad completed! Starting game...',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Small delay for UX, then start game
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _startGameWithDeck(deck);
    }
  }
  
  void _showPremiumPurchaseDialog(Deck deck) {
    // For now, show a coming soon message
    // In production, integrate with StoreKit/Play Billing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Premium purchase coming soon! For now, watch an ad to play.',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFD700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Show paywall again for user to watch ad
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showPaywall(deck);
      }
    });
  }
  
  void _startGameWithDeck(Deck deck) async {
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
    final l10n = AppLocalizations.of(context)!;

    switch (_selectedCategory) {
      case 'Trending':
        return l10n.trendingNow;
      case 'Quick':
        return l10n.quickGames;
      case 'Party':
        return l10n.partyMode;
      case 'My Decks':
        final count = deckProvider.customDecks.length;
        return count > 0 ? l10n.yourCreations : l10n.noCustomDecksYet;
      case 'Favorites':
        final count = deckProvider.favoriteDecks.length;
        return count > 0 ? l10n.myFavorites : l10n.noFavoritesYet;
      default:
        return l10n.allDecks;
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

  /// Translate category name to localized version
  String _getLocalizedCategoryName(String categoryName) {
    final l10n = AppLocalizations.of(context)!;
    switch (categoryName) {
      case 'Trending':
        return l10n.trending;
      case 'Quick':
        return l10n.quick;
      case 'Party':
        return l10n.party;
      case 'My Decks':
        return l10n.myDecks;
      case 'Favorites':
        return l10n.favorites;
      default:
        return categoryName;
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
  /// STRICTLY prioritizes user's country for better engagement
  List<Deck> _getTrendingDecks(List<Deck> decks) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final userCountry = deckProvider.userCountryCode;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    // Separate decks into tiers for strict prioritization
    final List<Deck> countrySpecificDecks = [];
    final List<Deck> universalDecks = [];
    final List<Deck> otherDecks = [];

    for (final deck in decks) {
      final countries = deck.effectiveCountries;
      if (countries.contains(userCountry)) {
        countrySpecificDecks.add(deck);
      } else if (countries.contains('UNIVERSAL')) {
        universalDecks.add(deck);
      } else {
        otherDecks.add(deck);
      }
    }

    // Sort each tier by secondary criteria
    int scoreDeck(Deck deck) {
      int score = (10 - deck.priority) * 100;
      
      // Boost new decks
      if (deck.createdAt.isAfter(sevenDaysAgo)) score += 300;
      
      // Favor sweet spot card count
      if (deck.cards.length >= 10 && deck.cards.length <= 30) score += 150;
      
      // Popularity boost
      score += (deck.playCount ~/ 10).clamp(0, 100);
      
      return score;
    }

    countrySpecificDecks.sort((a, b) => scoreDeck(b).compareTo(scoreDeck(a)));
    universalDecks.sort((a, b) => scoreDeck(b).compareTo(scoreDeck(a)));
    otherDecks.sort((a, b) => scoreDeck(b).compareTo(scoreDeck(a)));

    // Combine with STRICT priority: Country-specific FIRST, then Universal, then Others
    final sortedDecks = [
      ...countrySpecificDecks,
      ...universalDecks,
      ...otherDecks,
    ];

    return sortedDecks.take(15).toList();
  }

  /// Get quick play decks (5-12 cards for 3-8 minute games)
  List<Deck> _getQuickDecks(List<Deck> decks) {
    final quick =
        decks.where((d) => d.cards.length >= 5 && d.cards.length <= 12).toList()
          ..sort((a, b) => a.cards.length.compareTo(b.cards.length));
    return quick.isNotEmpty ? quick : decks.take(10).toList();
  }

  /// Get party decks (20-40 cards OR party-related tags)
  /// Prioritizes user's country for better engagement
  List<Deck> _getPartyDecks(List<Deck> decks) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final userCountry = deckProvider.userCountryCode;
    
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

    final partyDecks = decks.where((d) {
        final goodLength = d.cards.length >= 20 && d.cards.length <= 40;
        final hasPartyTag = d.tags.any(
          (tag) => partyKeywords.any(
            (keyword) => tag.toLowerCase().contains(keyword),
          ),
        );
        return goodLength || hasPartyTag;
      }).toList();
    
    // Sort with country prioritization
    partyDecks.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;
      
      // 🌍 Country-specific decks first
      if (a.effectiveCountries.contains(userCountry)) scoreA += 100;
      if (b.effectiveCountries.contains(userCountry)) scoreB += 100;
      
      // Universal decks second
      if (a.effectiveCountries.contains('UNIVERSAL')) scoreA += 50;
      if (b.effectiveCountries.contains('UNIVERSAL')) scoreB += 50;
      
      // Then by card count
      scoreA += a.cards.length;
      scoreB += b.cards.length;
      
      return scoreB.compareTo(scoreA);
    });
    
    return partyDecks;
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
            body: Stack(
              children: [
                // Black background
                Container(color: Colors.black),
                
                // 🧪 DEBUG ONLY: Country selector for testing recommendations
                // This will be automatically excluded in release builds
                if (kDebugMode) _buildDebugCountrySelector(deckProvider),
                // Gradient overlay with fixed height - animates smoothly
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOut,
                    height: 780.s,
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

                            SizedBox(height: 20.s),

                            // Featured deck - Country-prioritized for better engagement
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                // 🌍 Use country-prioritized decks for featured section
                                final availableDecks = _getCountryPrioritizedDecks(deckProvider);

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

                            SizedBox(height: 0.s),

                            // Category chips
                            _buildCategoryChips(),

                            SizedBox(height: 16.s),

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
                              SizedBox(height: 30.s),
                            ],

                            // Continue playing section with larger cards
                            // Always show during tutorial for highlighting, otherwise only when there are recent decks
                            if (_recentDecks.isNotEmpty || _showTutorial) ...[
                              _buildContinueWatchingSection(),
                              SizedBox(height: 24.s),
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

                            SizedBox(height: 32.s),

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

                            SizedBox(height: 32.s),

                            // Party favorites
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                return _buildSection(
                                  title:
                                      AppLocalizations.of(
                                        context,
                                      )!.partyFavorites,
                                  decks:
                                      deckProvider.freeDecks
                                          .where((d) => d.cards.length > 15)
                                          .toList(),
                                  icon: Icons.celebration_rounded,
                                  iconColor: Colors.pink,
                                );
                              },
                            ),

                            SizedBox(height: 24.s),

                            // Quick stats banner
                            _buildStatsSection(),

                            SizedBox(height: 16.s),

                            // Settings quick access
                            _buildSettingsCard(),

                            SizedBox(height: 24.s),

                            // Custom decks with better presentation
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                if (deckProvider.customDecks.isEmpty) {
                                  return _buildCreateCustomDeckPrompt();
                                }
                                return _buildSection(
                                  title:
                                      AppLocalizations.of(
                                        context,
                                      )!.yourCreations,
                                  decks: deckProvider.customDecks,
                                  icon: Icons.create_rounded,
                                  iconColor: Colors.blue,
                                  showSeeAll: true,
                                );
                              },
                            ),

                            SizedBox(height: 24.s),

                            // Premium decks with better presentation
                            Consumer<DeckProvider>(
                              builder: (context, deckProvider, _) {
                                if (deckProvider.premiumDecks.isNotEmpty) {
                                  return _buildSection(
                                    title:
                                        AppLocalizations.of(
                                          context,
                                        )!.unlockMoreFun,
                                    decks: deckProvider.premiumDecks,
                                    icon: Icons.star_rounded,
                                    iconColor: Colors.amber,
                                    isPremium: true,
                                  );
                                }
                                return const SizedBox();
                              },
                            ),

                            SizedBox(height: 100.s),
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
        24.s,
        MediaQuery.of(context).padding.top + 8.s,
        24.s,
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
                          padding: EdgeInsets.all(10.s),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16.s),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1.s,
                            ),
                          ),
                          child: Icon(
                            Icons.waving_hand_rounded,
                            color: Color(0xFFFFD700),
                            size: 24.s,
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

                    SizedBox(width: 16.s),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                    AppLocalizations.of(context)!.welcomeBack,
                                    style: GoogleFonts.poppins(
                                      fontSize: 26.sp,
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
                              Builder(
                                builder: (context) {
                                  // Show premium badge if user has premium subscription
                                  if (!PremiumUtils.hasPremium) {
                                    return const SizedBox();
                                  }
                                  return Container(
                                        margin: EdgeInsets.only(left: 12.s),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.s,
                                          vertical: 4.s,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFFFFD700),
                                              const Color(0xFFFFA500),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16.s,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFFD700,
                                              ).withOpacity(0.3),
                                              blurRadius: 8.s,
                                              offset: Offset(0, 2.s),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.workspace_premium_rounded,
                                              size: 14.s,
                                              color: Colors.black,
                                            ),
                                            SizedBox(width: 4.s),
                                            Text(
                                              'VIP',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.sp,
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

                          SizedBox(height: 4.s),

                          ShaderMask(
                                shaderCallback:
                                    (bounds) => LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.8),
                                        Colors.white.withOpacity(0.5),
                                      ],
                                    ).createShader(bounds),
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.whatWouldYouLikeToPlayToday,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5.sp,
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
                      margin: EdgeInsets.only(left: 12.s),
                      padding: EdgeInsets.symmetric(
                        horizontal: _streakBadgeExpanded ? 14.s : 10.s,
                        vertical: 8.s,
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
                        borderRadius: BorderRadius.circular(20.s),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          width: 1.5.s,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 12.s,
                            offset: Offset(0, 4.s),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                                Icons.local_fire_department_rounded,
                                color: const Color(0xFFFFD700),
                                size: 18.s,
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
                                        SizedBox(width: 7.s),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.dayCount(_currentStreak),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5.sp,
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
                                        SizedBox(width: 6.s),
                                        Text(
                                          '$_currentStreak',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.sp,
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
      key: _categoryChipsKey,
      height: 52.s,
      margin: EdgeInsets.symmetric(vertical: 8.s),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: 42.s,
          child: Row(
            children: [
              // Fixed search bubble on the left
              Padding(
                padding: EdgeInsets.only(left: 24.s, right: 12.s),
                child: _buildSearchChip(),
              ),

              // Elegant vertical divider
              Container(
                    margin: EdgeInsets.only(
                      left: 0,
                      right: 0,
                      top: 6.s,
                      bottom: 6.s,
                    ),
                    width: 1.5.s,
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
                    padding: EdgeInsets.symmetric(horizontal: 14.s),
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
      padding: EdgeInsets.only(right: 12.s),
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
                padding: EdgeInsets.symmetric(horizontal: 18.s, vertical: 10.s),
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
                      _getLocalizedCategoryName(categoryName),
                      style: GoogleFonts.poppins(
                        color:
                            isSelected
                                ? Colors.white
                                : isEmpty && !isSelected
                                ? Colors.white.withOpacity(0.4)
                                : Colors.white.withOpacity(0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13.5.sp,
                        letterSpacing: 0.1,
                      ),
                    ),
                    // Show "NEW" badge for categories with new content
                    if (hasNew && newCount > 0) ...[
                      SizedBox(width: 6.s),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.s,
                          vertical: 2.s,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.newBadge,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ]
                    // Show count badge if no NEW badge
                    else if (count != null && count > 0 && !hasNew) ...[
                      SizedBox(width: 6.s),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.s,
                          vertical: 2.s,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10.sp,
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
          margin: EdgeInsets.symmetric(horizontal: 20.s),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.s,
                          vertical: 32.s,
                        ),
                        child: Column(
                          children: [
                            // Icon with elegant animation
                            Container(
                                  width: 64.s,
                                  height: 64.s,
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
                                    size: 32.s,
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

                            SizedBox(height: 20.s),

                            // Title with premium typography
                            Text(
                                  AppLocalizations.of(context)!.noFavoritesYet,
                                  style: GoogleFonts.inter(
                                    fontSize: 22.sp,
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

                            SizedBox(height: 12.s),

                            // Subtitle with elegant opacity
                            Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.tapStarToAddFavorites,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
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

                            SizedBox(height: 24.s),

                            // Feature highlights
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildFeatureTag(
                                  icon: Icons.favorite_rounded,
                                  label:
                                      AppLocalizations.of(context)!.quickAccess,
                                  delay: 400,
                                ),
                                const SizedBox(width: 8),
                                _buildFeatureTag(
                                  icon: Icons.trending_up_rounded,
                                  label:
                                      AppLocalizations.of(
                                        context,
                                      )!.trackFavorites,
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
                SizedBox(height: 32.s),
                Row(
                  children: [
                    Container(
                          width: 36.s,
                          height: 36.s,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFF6B35),
                            size: 20.s,
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
                    SizedBox(width: 12.s),
                    Text(
                          'Suggested to Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 20.sp,
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
                SizedBox(height: 16.s),
                // Horizontal scrolling deck cards like other sections
                SizedBox(
                  height: 200.s,
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
            padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 10.s),
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
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 20.s,
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
    // Show placeholder during tutorial when no recent decks
    if (_recentDecks.isEmpty) {
      return Column(
        key: _continuePlayingKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 8.s),
            child: Text(
              AppLocalizations.of(context)!.continuePlayingTitle,
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SizedBox(height: 8.s),
          // Placeholder card for tutorial
          Container(
            height: 140.s,
            margin: EdgeInsets.symmetric(horizontal: 16.s),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12.s),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 40.s,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  SizedBox(height: 8.s),
                  Text(
                    'Play a game to see it here',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      key: _continuePlayingKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 8.s),
          child: Text(
            AppLocalizations.of(context)!.continuePlayingTitle,
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: 8.s),
        SizedBox(
          height: 140.s,
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
              padding: EdgeInsets.symmetric(horizontal: 12.s),
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
    final heroTag = 'continue_card_${deck.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    return Container(
      width: 200.s,
      margin: EdgeInsets.only(right: 8.s),
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
                    child: CachedNetworkImage(
                      imageUrl: deck.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 158,
                      memCacheHeight: 210,
                      maxWidthDiskCache: 600,
                      maxHeightDiskCache: 800,
                      placeholder:
                          (context, url) => Container(
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
                      fadeInDuration: const Duration(milliseconds: 300),
                      errorWidget: (context, url, error) => const SizedBox(),
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
                    width: 50.s,
                    height: 50.s,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32.s,
                    ),
                  ),
                ),

                // Info button (bottom left) - Shows deck details
                Positioned(
                  bottom: 8.s,
                  left: 8.s,
                  child: GestureDetector(
                    onTap: () {
                      _hapticService.lightImpact();
                      _showDeckDetails(deck, heroTag: heroTag);
                    },
                    child: Container(
                      width: 32.s,
                      height: 32.s,
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
                ),

                // More button (bottom right) - Shows options menu
                Positioned(
                  bottom: 8.s,
                  right: 8.s,
                  child: GestureDetector(
                    onTap: () {
                      _hapticService.lightImpact();
                      _showContinueCardOptions(deck);
                    },
                    child: Container(
                      width: 32.s,
                      height: 32.s,
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
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
  
  /// Show options menu for continue playing card
  void _showContinueCardOptions(Deck deck) {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final isFavorite = deckProvider.isFavorite(deck.id);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Deck info header
              Padding(
                padding: EdgeInsets.all(16.s),
                child: Row(
                  children: [
                    Container(
                      width: 48.s,
                      height: 48.s,
                      decoration: BoxDecoration(
                        color: deck.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: deck.color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: deck.imageUrl != null && deck.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: CachedNetworkImage(
                                imageUrl: deck.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              deck.icon,
                              color: deck.color,
                              size: 24.s,
                            ),
                    ),
                    SizedBox(width: 12.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.name,
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${deck.cards.length} cards',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              
              // Options
              _buildBottomSheetOption(
                icon: Icons.play_arrow_rounded,
                label: AppLocalizations.of(context)!.play,
                color: deck.color,
                onTap: () {
                  Navigator.pop(context);
                  _playDeck(deck);
                },
              ),
              
              _buildBottomSheetOption(
                icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                label: isFavorite 
                    ? AppLocalizations.of(context)!.removeFromFavorites 
                    : AppLocalizations.of(context)!.addToFavorites,
                color: const Color(0xFFFFD700),
                onTap: () async {
                  Navigator.pop(context);
                  if (isFavorite) {
                    await deckProvider.removeFromFavorites(deck.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.removedFromFavorites,
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: Colors.grey[800],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  } else {
                    await deckProvider.addToFavorites(deck.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.addedToFavorites,
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: const Color(0xFFFFD700),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              
              _buildBottomSheetOption(
                icon: Icons.remove_circle_outline_rounded,
                label: AppLocalizations.of(context)!.removeFromRecent,
                color: Colors.red.withOpacity(0.8),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeFromRecentDecks(deck.id);
                },
              ),
              
              SizedBox(height: 8.s),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomSheetOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 14.s),
          child: Row(
            children: [
              Container(
                width: 36.s,
                height: 36.s,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 14.s),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Remove deck from recent decks list
  Future<void> _removeFromRecentDecks(String deckId) async {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    
    // Remove from local list
    setState(() {
      _recentDecks.removeWhere((d) => d.id == deckId);
    });
    
    // Remove from storage
    await deckProvider.removeFromRecentDecks(deckId);
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.removedFromRecent,
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
          padding: EdgeInsets.fromLTRB(20.s, 8.s, 20.s, 16.s),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                      width: 36.s,
                      height: 36.s,
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
                SizedBox(width: 12.s),
              ],
              Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 22.sp,
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.s,
                          vertical: 8.s,
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
                                fontSize: 13.sp,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.s,
                        vertical: 6.s,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See All',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                              fontSize: 13.sp,
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
          height: 200.s,
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
              padding: EdgeInsets.only(left: 20.s, right: 12.s),
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
            width: 150.s,
            margin: EdgeInsets.only(right: 16.s),
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
                      height: 200.s,
                      width: 150.s,
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
                              CachedNetworkImage(
                                imageUrl: deck.imageUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 158,
                                memCacheHeight: 210,
                                maxWidthDiskCache: 600,
                                maxHeightDiskCache: 800,
                                placeholder:
                                    (context, url) => Container(
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
                                fadeInDuration: const Duration(
                                  milliseconds: 300,
                                ),
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
                                  child: Icon(
                                    deck.icon,
                                    color: deck.color,
                                    size: 40.s,
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
                                    '${deck.cards.length} cards',
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
                                        width: 2,
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
                                top: 8.s,
                                left: 8.s,
                                child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.s,
                                        vertical: 4.s,
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
                                              fontSize: 9.sp,
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

                            // NEW / UPDATED status badge (only show if not premium)
                            if (!isPremium && deck.statusTag != null)
                              Positioned(
                                top: 8.s,
                                left: 8.s,
                                child: _buildStatusBadge(deck.statusTag!, index),
                              ),
                            
                            // NEW / UPDATED status badge for premium decks (positioned below premium badge)
                            if (isPremium && deck.statusTag != null)
                              Positioned(
                                top: 36.s,
                                left: 8.s,
                                child: _buildStatusBadge(deck.statusTag!, index),
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
            margin: EdgeInsets.symmetric(horizontal: 24.s),
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
                                    size: 40.s,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  deck.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20.sp,
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
                      padding: EdgeInsets.all(24.s),
                      child: Column(
                        children: [
                          // Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.s),
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
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.s),

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

                          SizedBox(height: 24.s),

                          // Price
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.s,
                              vertical: 12.s,
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
                                    fontSize: 14.sp,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '\$2.99',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 20.s),

                          // CTA Buttons
                          SizedBox(
                            width: double.infinity,
                            height: 52.s,
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
                                        AppLocalizations.of(
                                          context,
                                        )!.premiumUnlockComingSoon,
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
                                      AppLocalizations.of(context)!.unlockNow,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
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
                                  AppLocalizations.of(context)!.maybeLater,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14.sp,
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
                                  AppLocalizations.of(
                                    context,
                                  )!.restorePurchases,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 14.sp,
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
      padding: EdgeInsets.symmetric(vertical: 8.s),
      child: Row(
        children: [
          Container(
            width: 32.s,
            height: 32.s,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFFFD700)),
          ),
          SizedBox(width: 16.s),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        // Get real statistics from provider
        final gamesWon = gameProvider.gamesWon;
        final winStreak = gameProvider.currentWinStreak;
        final teamGamesPlayed = gameProvider.teamGamesPlayed;
        final avgAccuracy = gameProvider.averageAccuracy;

        return Container(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      Icons.emoji_events_rounded,
                      '$gamesWon',
                      AppLocalizations.of(context)!.gamesWon,
                      const Color(0xFFFFC107),
                      0,
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      Icons.local_fire_department_rounded,
                      '$winStreak',
                      AppLocalizations.of(context)!.winStreak,
                      const Color(0xFFFF6B35),
                      1,
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      Icons.groups_rounded,
                      '$teamGamesPlayed',
                      AppLocalizations.of(context)!.playersMet,
                      const Color(0xFF0A84FF),
                      2,
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      Icons.star_rounded,
                      avgAccuracy.toStringAsFixed(1),
                      AppLocalizations.of(context)!.avgScore,
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
      },
    );
  }

  Widget _buildSettingsCard() {
    return GestureDetector(
      onTap: () {
        _hapticService.lightImpact();
        _audioService.playClick();
        context.push('/settings');
      },
      child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 14.s),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Settings icon with premium glow
                Container(
                  padding: EdgeInsets.all(10.s),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: Colors.white.withOpacity(0.9),
                    size: 20.s,
                  ),
                ),
                SizedBox(width: 14.s),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.settings,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.s,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2.s),
                      Text(
                        AppLocalizations.of(context)!.customizeYourExperience,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12.s,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chevron arrow
                Container(
                  padding: EdgeInsets.all(8.s),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 14.s,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(delay: 550.ms, duration: 600.ms)
          .slideY(
            begin: 0.15,
            end: 0,
            delay: 550.ms,
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1.s,
      height: 40.s,
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
                width: 44.s,
                height: 44.s,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22.s),
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
                  fontSize: 24.sp,
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
              fontSize: 11.sp,
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
                                  width: 56.s,
                                  height: 56.s,
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
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 28.s,
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
                                  AppLocalizations.of(
                                    context,
                                  )!.createCustomDeckPromptTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 20.sp,
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
                                  AppLocalizations.of(
                                    context,
                                  )!.createCustomDeckPromptSubtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
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
                                            AppLocalizations.of(
                                              context,
                                            )!.createDeck,
                                            style: GoogleFonts.inter(
                                              fontSize: 15.sp,
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
                                  label:
                                      AppLocalizations.of(context)!.quickSetup,
                                  delay: 500,
                                ),
                                const SizedBox(width: 8),
                                _buildFeatureTag(
                                  icon: Icons.palette_outlined,
                                  label:
                                      AppLocalizations.of(context)!.customize,
                                  delay: 600,
                                ),
                                const SizedBox(width: 8),
                                _buildFeatureTag(
                                  icon: Icons.share_rounded,
                                  label: AppLocalizations.of(context)!.share,
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

  /// Build NEW or UPDATED status badge for deck cards
  Widget _buildStatusBadge(String status, int index) {
    final l10n = AppLocalizations.of(context)!;
    final isNew = status == 'new';
    
    // Colors for NEW (green) and UPDATED (blue)
    final gradientColors = isNew
        ? [const Color(0xFF00C853), const Color(0xFF00E676)]  // Vibrant green
        : [const Color(0xFF2196F3), const Color(0xFF42A5F5)]; // Vibrant blue
    
    final badgeText = isNew ? l10n.newBadge : l10n.updatedBadge;
    final badgeIcon = isNew ? Icons.fiber_new_rounded : Icons.update_rounded;

    return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 7.s,
            vertical: 3.s,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                badgeIcon,
                size: 10,
                color: Colors.white,
              ),
              const SizedBox(width: 3),
              Text(
                badgeText,
                style: GoogleFonts.poppins(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (250 + index * 50).ms, duration: 400.ms)
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          delay: (250 + index * 50).ms,
          duration: 400.ms,
          curve: Curves.easeOutBack,
        )
        .shimmer(
          delay: (800 + index * 100).ms,
          duration: 1500.ms,
          color: Colors.white.withOpacity(0.3),
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
                  fontSize: 11.sp,
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
                    size: 80.s,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  SizedBox(height: 24.s),
                  Text(
                    AppLocalizations.of(context)!.unableToLoadDecks,
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.checkInternetAndRetry,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32.s),
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
                          AppLocalizations.of(context)!.retry,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
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
              size: 64.s,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noDecksAvailable,
              style: TextStyle(
                fontSize: 18.sp,
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
                  width: 36.s,
                  height: 36.s,
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
                  fontSize: 22.sp,
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
          height: 200.s,
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
                height: 200.s,
                width: 150.s,
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
                        width: 40.s,
                        height: 40.s,
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
