import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_theme.dart';
import '../providers/deck_provider.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../services/daily_deck_service.dart';
import '../models/daily_deck.dart';
import '../widgets/banner_ad_widget.dart';
import 'category_selection_screen.dart';
import 'gameplay_screen.dart';
import 'tutorial_screen.dart';
import 'team_setup_screen.dart';
import 'explore_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _hapticService = HapticService();
  final _audioService = AudioService();
  final _dailyDeckService = DailyDeckService();
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _underlineController;
  late Animation<double> _underlineAnimation;
  bool _hasSeenTutorial = false;
  DailyDeck? _todaysDeck;
  bool _hasPlayedDaily = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _underlineController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _underlineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _underlineController, curve: Curves.linear),
    );

    _checkFirstTimeUser();
    _loadDailyDeck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh daily deck when app resumes
      print('🔄 App resumed - refreshing daily deck');
      _loadDailyDeck();
    }
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSeenTutorial = prefs.getBool('tutorial_completed') ?? false;

    // Show tutorial suggestion for first-time users
    if (!_hasSeenTutorial && mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _showTutorialSuggestion();
        }
      });
    }
  }

  Future<void> _loadDailyDeck() async {
    try {
      print('🔍 Loading daily deck...');

      // For debugging: Clear played status to test the feature
      // Uncomment the line below to reset the played status
      // await _dailyDeckService.clearPlayedStatus();

      final deck = await _dailyDeckService.getTodaysDeck();
      final hasPlayed = await _dailyDeckService.hasPlayedToday();

      print(
        '📅 Daily deck loaded: ${deck != null ? deck.title : "No deck found"}',
      );
      print('✅ Has played today: $hasPlayed');

      if (mounted) {
        setState(() {
          _todaysDeck = deck;
          _hasPlayedDaily = hasPlayed;
        });
      }
    } catch (e) {
      print('❌ Error loading daily deck: $e');
    }
  }

  void _showTutorialSuggestion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      children: [
                        // Icon container
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.waving_hand,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                        ).animate().scale(
                          duration: 500.ms,
                          curve: Curves.easeOutBack,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to Heads Up!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The ultimate party game that brings\nlaughter and excitement to any gathering',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.grey.withOpacity(0.15),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Primary action button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showTutorial(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded, size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  'Take a Quick Tour',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Secondary action button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Skip for Now',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
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
          ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _floatingController.dispose();
    _pulseController.dispose();
    _underlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();

    // Show loading screen if provider is not initialized
    if (!deckProvider.isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 20),
              Text(
                'Loading game data...',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return BottomBannerAd(
      widgetKey: 'home_screen',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: RefreshIndicator(
          onRefresh: () async {
            print('🔄 Manual refresh triggered');
            await _loadDailyDeck();
          },
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Elegant Modern App Bar with clean design
              SliverAppBar(
                expandedHeight: 240,
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: const [],
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
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _HeaderPatternPainter(
                              animation: _pulseController,
                            ),
                          ),
                        ),
                        // Bottom curve
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(40),
                                topRight: Radius.circular(40),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Content
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildLogo(),
                                    _buildSettingsButton(),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Flexible(child: _buildWelcomeText(context)),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildQuickPlayCard(context),
                    const SizedBox(height: 16),
                    if (_todaysDeck != null) ...[
                      _buildDailyHeadsUpCard(context),
                      const SizedBox(height: 16),
                    ],
                    _buildFeatureGrid(context),
                    const SizedBox(height: 24),
                    _buildStatsCard(context),
                    const SizedBox(height: 24),
                    _buildRecentDecksSection(context),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Heads Up!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              Text(
                'Party Game',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
  }

  Widget _buildSettingsButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _hapticService.lightImpact();
            _audioService.playClick();
            context.push('/settings');
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
  }

  Widget _buildWelcomeText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Main heading with clean design
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Custom signature-style "Ready to Play?" with animated underline
              _buildSignatureText(context),
              const SizedBox(height: 12),
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Choose your adventure',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 800.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPlayCard(BuildContext context) {
    return AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatingController.value * 4 - 2),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                      AppTheme.secondaryColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(-5, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Subtle geometric pattern instead of bubbles
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GeometricPatternPainter(
                            animation: _pulseController,
                          ),
                        ),
                      ),
                      // Content
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _hapticService.mediumImpact();
                            _audioService.playClick();
                            _showCategorySelection(context);
                          },
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.white.withOpacity(0.2),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Animated Play Button
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        final scale =
                                            1.0 +
                                            (_pulseController.value * 0.1);
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withOpacity(0.3),
                                                  Colors.white.withOpacity(
                                                    0.15,
                                                  ),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: const FaIcon(
                                                FontAwesomeIcons.play,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Check if we have enough space for both text and chip
                                              final showChip =
                                                  constraints.maxWidth > 150;

                                              return Row(
                                                children: [
                                                  Text(
                                                    'Quick Play',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineSmall
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 26,
                                                          letterSpacing: -0.5,
                                                        ),
                                                  ),
                                                  if (showChip) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .warningColor
                                                            .withOpacity(0.9),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .local_fire_department_rounded,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'HOT',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Jump into the action now!',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(
                                              color: Colors.white.withOpacity(
                                                0.95,
                                              ),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Arrow with pulse
                                    AnimatedBuilder(
                                      animation: _floatingController,
                                      builder: (context, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                            _floatingController.value * 3 - 1.5,
                                            0,
                                          ),
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.25,
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Stats preview row
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildQuickStat(
                                        context,
                                        Icons.category_rounded,
                                        '15+',
                                        'Categories',
                                      ),
                                      Container(
                                        width: 1,
                                        height: 30,
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                      _buildQuickStat(
                                        context,
                                        Icons.style_rounded,
                                        '500+',
                                        'Cards',
                                      ),
                                      Container(
                                        width: 1,
                                        height: 30,
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                      _buildQuickStat(
                                        context,
                                        Icons.timer_rounded,
                                        '60s',
                                        'Timer',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
        )
        .animate()
        .fadeIn(delay: 400.ms, duration: 800.ms)
        .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }

  Widget _buildQuickStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyHeadsUpCard(BuildContext context) {
    final deck = _todaysDeck!;

    return AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatingController.value * 3 - 1.5),
              child: Container(
                decoration: BoxDecoration(
                  gradient:
                      deck.imageUrl == null
                          ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(deck.color),
                              Color(deck.color).withOpacity(0.85),
                              AppTheme.accentColor.withOpacity(0.6),
                            ],
                          )
                          : null,
                  image:
                      deck.imageUrl != null
                          ? DecorationImage(
                            image: CachedNetworkImageProvider(deck.imageUrl!),
                            fit: BoxFit.cover,
                          )
                          : null,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Color(deck.color).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
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
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      // Daily pattern overlay (only for non-image decks)
                      if (deck.imageUrl == null) ...[
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Calendar icon pattern
                        Positioned(
                          bottom: -20,
                          left: -20,
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 80,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ],
                      // Content
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              _hasPlayedDaily
                                  ? null
                                  : () {
                                    _hapticService.mediumImpact();
                                    _audioService.playClick();
                                    _playDailyDeck(context, deck);
                                  },
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.white.withOpacity(0.2),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.local_fire_department_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'DAILY CHALLENGE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_hasPlayedDaily)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Title and description
                                Text(
                                  deck.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  deck.description,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                // Stats row
                                Row(
                                  children: [
                                    _buildDailyStat(
                                      Icons.style_rounded,
                                      '${deck.cards.length}',
                                      'Cards',
                                    ),
                                    const SizedBox(width: 20),
                                    _buildDailyStat(
                                      Icons.timer_rounded,
                                      '60s',
                                      'Timer',
                                    ),
                                    const SizedBox(width: 20),
                                    _buildDailyStat(
                                      Icons.star_rounded,
                                      '+50',
                                      'Points',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Play button or completed status
                                Container(
                                  width: double.infinity,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        _hasPlayedDaily
                                            ? Colors.white.withOpacity(0.2)
                                            : Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap:
                                          _hasPlayedDaily
                                              ? null
                                              : () {
                                                _hapticService.mediumImpact();
                                                _audioService.playClick();
                                                _playDailyDeck(context, deck);
                                              },
                                      borderRadius: BorderRadius.circular(14),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _hasPlayedDaily
                                                  ? Icons.check_circle_rounded
                                                  : Icons.play_arrow_rounded,
                                              color:
                                                  _hasPlayedDaily
                                                      ? Colors.white
                                                          .withOpacity(0.7)
                                                      : Color(deck.color),
                                              size: 22,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _hasPlayedDaily
                                                  ? 'Completed Today'
                                                  : 'Play Now',
                                              style: TextStyle(
                                                color:
                                                    _hasPlayedDaily
                                                        ? Colors.white
                                                            .withOpacity(0.7)
                                                        : Color(deck.color),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        )
        .animate()
        .fadeIn(delay: 300.ms, duration: 800.ms)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }

  Widget _buildDailyStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _playDailyDeck(BuildContext context, DailyDeck dailyDeck) async {
    final gameProvider = context.read<GameProvider>();
    final regularDeck = _dailyDeckService.convertToRegularDeck(dailyDeck);

    // Start the game (uses default 60 seconds)
    gameProvider.startGame(deck: regularDeck, isTeamMode: false);

    // Mark as played with the deck ID
    await _dailyDeckService.markAsPlayed(dailyDeck.id);
    setState(() {
      _hasPlayedDaily = true;
    });

    // Navigate to gameplay screen with the deck
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GameplayScreen(deck: regularDeck, isTeamMode: false),
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final features = [
      {
        'title': 'Categories',
        'subtitle': 'Explore decks',
        'icon': FontAwesomeIcons.layerGroup,
        'color': AppTheme.secondaryColor,
        'gradient': [
          AppTheme.secondaryColor,
          AppTheme.secondaryColor.withOpacity(0.7),
        ],
        'badge': '15+',
        'badgeIcon': Icons.collections_rounded,
        'onTap': () => _showCategorySelection(context),
      },
      {
        'title': 'Custom',
        'subtitle': 'Create your own',
        'icon': FontAwesomeIcons.wandMagicSparkles,
        'color': AppTheme.accentColor,
        'gradient': [
          AppTheme.accentColor,
          AppTheme.accentColor.withOpacity(0.7),
        ],
        'badge': 'NEW',
        'badgeIcon': Icons.auto_awesome_rounded,
        'onTap': () => _showCreateCustomDeck(context),
      },
      {
        'title': 'Teams',
        'subtitle': 'Battle mode',
        'icon': FontAwesomeIcons.userGroup,
        'color': AppTheme.warningColor,
        'gradient': [
          AppTheme.warningColor,
          AppTheme.warningColor.withOpacity(0.7),
        ],
        'badge': '2-4',
        'badgeIcon': Icons.groups_rounded,
        'onTap': () => _showTeamSetup(context),
      },
      {
        'title': 'Tutorial',
        'subtitle': 'Learn to play',
        'icon': FontAwesomeIcons.graduationCap,
        'color': AppTheme.successColor,
        'gradient': [
          AppTheme.successColor,
          AppTheme.successColor.withOpacity(0.7),
        ],
        'badge': 'EASY',
        'badgeIcon': Icons.school_rounded,
        'onTap': () => _showTutorial(context),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final offsetY =
                    index.isEven
                        ? _floatingController.value * 2 - 1
                        : -_floatingController.value * 2 + 1;
                return Transform.translate(
                  offset: Offset(0, offsetY),
                  child: GestureDetector(
                    onTap: () {
                      _hapticService.lightImpact();
                      _audioService.playClick();
                      (feature['onTap'] as VoidCallback)();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: feature['gradient'] as List<Color>,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (feature['color'] as Color).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: (feature['color'] as Color).withOpacity(0.2),
                            blurRadius: 24,
                            offset: const Offset(-4, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Background pattern
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
                              left: -30,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.05),
                                ),
                              ),
                            ),
                            // Shimmer overlay
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment(
                                          -1 +
                                              (_pulseController.value +
                                                      index * 0.25) *
                                                  2,
                                          -1,
                                        ),
                                        end: Alignment(
                                          1 +
                                              (_pulseController.value +
                                                      index * 0.25) *
                                                  2,
                                          1,
                                        ),
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withOpacity(0.05),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Content
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _hapticService.lightImpact();
                                  _audioService.playClick();
                                  (feature['onTap'] as VoidCallback)();
                                },
                                borderRadius: BorderRadius.circular(20),
                                splashColor: Colors.white.withOpacity(0.3),
                                highlightColor: Colors.white.withOpacity(0.1),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top section with icon and badge
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _pulseController,
                                            builder: (context, child) {
                                              final scale =
                                                  1.0 +
                                                  (_pulseController.value *
                                                      0.05);
                                              return Transform.scale(
                                                scale: scale,
                                                child: Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        Colors.white
                                                            .withOpacity(0.25),
                                                        Colors.white
                                                            .withOpacity(0.1),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: FaIcon(
                                                      feature['icon']
                                                          as IconData,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  feature['badgeIcon']
                                                      as IconData,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  feature['badge'] as String,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Bottom section with text
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            feature['title'] as String,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  feature['subtitle'] as String,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.white
                                                            .withOpacity(0.9),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
            .animate()
            .fadeIn(delay: (600 + index * 100).ms, duration: 600.ms)
            .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final stats = gameProvider.getStatistics();
        final totalGames = stats['totalGames'] ?? 0;
        final totalCorrect = stats['totalCorrect'] ?? 0;
        final highScore = stats['highScore'] ?? 0;
        final winRate =
            totalGames > 0
                ? ((totalCorrect / (totalGames * 10)) * 100).round()
                : 0;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.08),
                AppTheme.accentColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Decorative elements
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentColor.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -40,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor.withOpacity(0.06),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Progress',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Keep up the great work!',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Main Stats Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernStatItem(
                              context,
                              'Total Games',
                              totalGames.toString(),
                              Icons.sports_esports_rounded,
                              AppTheme.primaryColor,
                              true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModernStatItem(
                              context,
                              'High Score',
                              highScore.toString(),
                              Icons.emoji_events_rounded,
                              AppTheme.warningColor,
                              true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernStatItem(
                              context,
                              'Total Points',
                              totalCorrect.toString(),
                              Icons.star_rounded,
                              AppTheme.successColor,
                              false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModernStatItem(
                              context,
                              'Win Rate',
                              '$winRate%',
                              Icons.trending_up_rounded,
                              AppTheme.accentColor,
                              false,
                            ),
                          ),
                        ],
                      ),
                      if (totalGames > 0) ...[
                        const SizedBox(height: 24),
                        // Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Level Progress',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Level ${(totalGames ~/ 10) + 1}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dividerColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 1000),
                                  curve: Curves.easeOutCubic,
                                  height: 8,
                                  width:
                                      MediaQuery.of(context).size.width *
                                      0.85 *
                                      ((totalGames % 10) / 10),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalGames % 10}/10 games to next level',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textTertiary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    bool isLarge,
  ) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.02);
        return Transform.scale(
          scale: isLarge ? scale : 1.0,
          child: Container(
            padding: EdgeInsets.all(isLarge ? 20 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: isLarge ? 20 : 18),
                    ),
                    if (isLarge && value != '0')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              color: AppTheme.successColor,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '+${(int.tryParse(value) ?? 0) > 10 ? '10' : value}%',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: isLarge ? 28 : 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentDecksSection(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: context.read<DeckProvider>().getRecentDeckIds(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recentIds = snapshot.data!;
        final deckProvider = context.watch<DeckProvider>();
        final recentDecks =
            recentIds
                .map((id) => deckProvider.getDeckById(id))
                .where((deck) => deck != null)
                .toList();

        if (recentDecks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Adventures',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recentDecks.length,
                itemBuilder: (context, index) {
                  final deck = recentDecks[index]!;
                  return GestureDetector(
                    onTap: () {
                      _hapticService.lightImpact();
                      _startGameWithDeck(context, deck);
                    },
                    child: Container(
                      width: 95,
                      margin: const EdgeInsets.only(right: 10),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              deck.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            deck.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                      delay: (1200 + index * 100).ms,
                      duration: 600.ms,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCategorySelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CategorySelectionScreen()),
    );
  }

  void _showCreateCustomDeck(BuildContext context) {
    _hapticService.mediumImpact();
    _audioService.playClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExploreScreen(category: 'My Decks'),
      ),
    );
  }

  void _showTeamSetup(BuildContext context) {
    _hapticService.mediumImpact();
    _audioService.playClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TeamSetupScreen()),
    );
  }

  void _showTutorial(BuildContext context) {
    _hapticService.lightImpact();
    _audioService.playClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TutorialScreen()),
    );
  }

  void _startGameWithDeck(BuildContext context, dynamic deck) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Starting game with ${deck.name}!')));
  }

  Widget _buildSignatureText(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none, // Allow content to overflow
      children: [
        // Main text with elegant cursive style
        Padding(
              padding: const EdgeInsets.only(
                top: 5.0,
              ), // Add padding to prevent top cropping
              child: ShaderMask(
                shaderCallback:
                    (bounds) => LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.98),
                        AppTheme.accentColor.withOpacity(0.95),
                        AppTheme.secondaryColor.withOpacity(0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ).createShader(bounds),
                child: Transform.rotate(
                  angle: -0.015, // Subtle tilt for signature effect
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Ready ',
                          style: GoogleFonts.dancingScript(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            height: 1.2, // Adjusted height
                            shadows: [
                              Shadow(
                                color: AppTheme.primaryColor.withOpacity(0.4),
                                offset: const Offset(2, 3),
                                blurRadius: 6,
                              ),
                              Shadow(
                                color: Colors.black.withOpacity(0.15),
                                offset: const Offset(1, 4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: 'to ',
                          style: GoogleFonts.satisfy(
                            fontSize: 34,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: AppTheme.primaryColor.withOpacity(0.35),
                                offset: const Offset(1.5, 2.5),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: 'Play',
                          style: GoogleFonts.dancingScript(
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: AppTheme.secondaryColor.withOpacity(
                                  0.45,
                                ),
                                offset: const Offset(2.5, 3),
                                blurRadius: 7,
                              ),
                              Shadow(
                                color: Colors.black.withOpacity(0.18),
                                offset: const Offset(1.5, 4.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: '?',
                          style: GoogleFonts.kalam(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: AppTheme.accentColor.withOpacity(0.6),
                                offset: const Offset(3, 3),
                                blurRadius: 8,
                              ),
                              Shadow(
                                color: AppTheme.warningColor.withOpacity(0.3),
                                offset: const Offset(-1, -1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 1200.ms, curve: Curves.easeOutQuart)
            .slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack)
            .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1.0, 1.0),
              duration: 1000.ms,
              curve: Curves.easeOutBack,
            ),

        // Simple animated underline
        Positioned(
          bottom: -5,
          child: AnimatedBuilder(
            animation: _underlineAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(260, 15),
                painter: _SimpleUnderlinePainter(
                  progress: _underlineAnimation.value,
                  color1: AppTheme.primaryColor,
                  color2: AppTheme.secondaryColor,
                  color3: AppTheme.accentColor,
                ),
              );
            },
          ),
        ),

        // Decorative flourish dots
        Positioned(
          right: -10,
          top: 5,
          child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warningColor.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
              .animate()
              .scale(delay: 500.ms, duration: 1500.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 2000.ms, delay: 1000.ms),
        ),

        // Small star decoration
        Positioned(
          left: -15,
          bottom: 10,
          child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppTheme.warningColor.withOpacity(0.7),
              )
              .animate()
              .fadeIn(delay: 800.ms)
              .rotate(duration: 3000.ms, begin: 0, end: 1)
              .then()
              .shimmer(duration: 2000.ms),
        ),
      ],
    );
  }
}

// Custom painter for subtle header pattern
class _HeaderPatternPainter extends CustomPainter {
  final Animation<double> animation;

  _HeaderPatternPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw subtle diagonal lines
    for (int i = 0; i < 20; i++) {
      final progress = (animation.value + i * 0.05) % 1.0;
      paint.color = Colors.white.withOpacity(0.03 * (1 - progress));

      final startX = size.width * i / 10;
      final path =
          Path()
            ..moveTo(startX, 0)
            ..lineTo(startX + 50, size.height);

      canvas.drawPath(path, paint);
    }

    // Draw horizontal accent lines
    paint.color = Colors.white.withOpacity(0.05);
    paint.strokeWidth = 0.5;

    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.3),
      paint,
    );

    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(_HeaderPatternPainter oldDelegate) => true;
}

// Simple and smooth underline painter
class _SimpleUnderlinePainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;
  final Color color3;

  _SimpleUnderlinePainter({
    required this.progress,
    required this.color1,
    required this.color2,
    required this.color3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // Create a simple, smooth wave
    final path = Path();

    // Simple sine wave parameters
    final waveHeight = 3.0;

    // Draw smooth sine wave
    for (double x = 0; x <= size.width; x += 1) {
      final normalizedX = x / size.width;

      // Simple sine wave with gentle motion
      final y =
          size.height / 2 +
          math.sin((normalizedX * math.pi * 2 + progress * math.pi * 2)) *
              waveHeight *
              math.sin(normalizedX * math.pi); // Taper at ends

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Simple gradient that shifts smoothly
    final gradientProgress = (math.sin(progress * math.pi * 2) + 1) / 2;
    final currentColor =
        Color.lerp(
          Color.lerp(color1, color2, gradientProgress),
          color3,
          gradientProgress * 0.5,
        )!;

    // Draw main line with gradient color
    paint.color = currentColor.withOpacity(0.9);
    canvas.drawPath(path, paint);

    // Add subtle glow
    paint
      ..color = currentColor.withOpacity(0.2)
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SimpleUnderlinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Geometric pattern painter for Quick Play card
class _GeometricPatternPainter extends CustomPainter {
  final Animation<double> animation;

  _GeometricPatternPainter({required this.animation})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw subtle hexagon pattern
    final hexSize = 30.0;
    final rows = (size.height / hexSize).ceil() + 1;
    final cols = (size.width / hexSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = col * hexSize * 1.5;
        final y = row * hexSize * 1.7 + (col % 2 == 1 ? hexSize * 0.85 : 0);

        final opacity =
            (0.02 + (animation.value * 0.02)) *
            ((row + col) % 3 == 0 ? 1.5 : 1.0);
        paint.color = Colors.white.withOpacity(opacity.clamp(0.0, 0.08));

        // Draw hexagon
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60 - 30) * 3.14159 / 180;
          final px = x + hexSize * 0.5 * math.cos(angle);
          final py = y + hexSize * 0.5 * math.sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GeometricPatternPainter oldDelegate) => true;
}
