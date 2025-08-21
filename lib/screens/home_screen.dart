import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/deck_provider.dart';
import '../providers/game_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'category_selection_screen.dart';
import 'dart:math' as math;

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
          // Modern App Bar with solid color
          SliverAppBar(
            expandedHeight: 180,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [_buildLogo(), _buildSettingsButton()],
                        ),
                        const Spacer(),
                        _buildWelcomeText(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildQuickPlayCard(context),
                const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.phone_android_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'Heads Up!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2);
  }

  Widget _buildSettingsButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: () {
          _hapticService.lightImpact();
          _showSettingsBottomSheet(context);
        },
        icon: const Icon(Icons.settings_rounded, color: Colors.white),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.2);
  }

  Widget _buildWelcomeText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to Play?',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3),
        const SizedBox(height: 6),
        Text(
          'Choose your adventure',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.9)),
        ).animate().fadeIn(delay: 200.ms, duration: 800.ms).slideY(begin: 0.3),
      ],
    );
  }

  Widget _buildQuickPlayCard(BuildContext context) {
    return AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatingController.value * 6 - 3),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.buttonShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _hapticService.mediumImpact();
                      _audioService.playClick();
                      _showCategorySelection(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: FaIcon(
                                FontAwesomeIcons.play,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Play',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Jump into the action now!',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildFeatureGrid(BuildContext context) {
    final features = [
      {
        'title': 'Categories',
        'subtitle': 'Explore decks',
        'icon': FontAwesomeIcons.layerGroup,
        'color': AppTheme.secondaryColor,
        'onTap': () => _showCategorySelection(context),
      },
      {
        'title': 'Custom',
        'subtitle': 'Create your own',
        'icon': FontAwesomeIcons.wandMagicSparkles,
        'color': AppTheme.accentColor,
        'onTap': () => _showCreateCustomDeck(context),
      },
      {
        'title': 'Teams',
        'subtitle': 'Battle mode',
        'icon': FontAwesomeIcons.userGroup,
        'color': AppTheme.warningColor,
        'onTap': () => _showTeamSetup(context),
      },
      {
        'title': 'Tutorial',
        'subtitle': 'Learn to play',
        'icon': FontAwesomeIcons.graduationCap,
        'color': AppTheme.successColor,
        'onTap': () => _showTutorial(context),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return GestureDetector(
              onTap: () {
                _hapticService.lightImpact();
                _audioService.playClick();
                (feature['onTap'] as VoidCallback)();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: feature['color'] as Color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (feature['color'] as Color).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          feature['icon'] as IconData,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        feature['title'] as String,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feature['subtitle'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
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

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Your Progress',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    context,
                    'Games',
                    stats['totalGames'].toString(),
                    Icons.gamepad_rounded,
                    AppTheme.primaryColor,
                  ),
                  _buildStatItem(
                    context,
                    'Score',
                    stats['totalCorrect'].toString(),
                    Icons.check_circle_rounded,
                    AppTheme.successColor,
                  ),
                  _buildStatItem(
                    context,
                    'Best',
                    stats['highScore'].toString(),
                    Icons.emoji_events_rounded,
                    AppTheme.warningColor,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(delay: 1000.ms, duration: 800.ms).slideY(begin: 0.2);
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color.withOpacity(0.8)),
          ),
        ],
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom deck creation coming soon!')),
    );
  }

  void _showTeamSetup(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Team mode coming soon!')));
  }

  void _showTutorial(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tutorial coming soon!')));
  }

  void _showSettingsBottomSheet(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings coming soon!')));
  }

  void _startGameWithDeck(BuildContext context, dynamic deck) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Starting game with ${deck.name}!')));
  }
}
