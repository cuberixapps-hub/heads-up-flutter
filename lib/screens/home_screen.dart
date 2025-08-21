import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../providers/deck_provider.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'category_selection_screen.dart';
import 'tutorial_screen.dart';
import 'team_setup_screen.dart';
import 'custom_deck_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  bool _hasSeenTutorial = false;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _checkFirstTimeUser();
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

  void _showTutorialSuggestion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      FontAwesomeIcons.graduationCap,
                      color: Colors.white,
                      size: 36,
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to Heads Up!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Would you like a quick tutorial to learn how to play?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showTutorial(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Start Tutorial',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Elegant Modern App Bar with clean design
          SliverAppBar(
            expandedHeight: 240,
            floating: true,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
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
                          children: [
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [_buildLogo(), _buildSettingsButton()],
                            ),
                            const SizedBox(height: 32),
                            _buildWelcomeText(context),
                            const SizedBox(height: 40),
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
                const SizedBox(height: 8),
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
              Text(
                'Ready to Play?',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
              const SizedBox(height: 8),
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
                                          Row(
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
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.warningColor
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'HOT',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
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
    ).animate().fadeIn(delay: 1000.ms, duration: 800.ms).slideY(begin: 0.1);
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
        builder: (context) => const CustomDeckManagementScreen(),
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
          final px = x + hexSize * 0.5 * cos(angle);
          final py = y + hexSize * 0.5 * sin(angle);
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
