import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/app_theme.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'category_selection_screen.dart';
import '../widgets/animated_gradient_background.dart';

class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({super.key});

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();

  // Animation controllers
  late AnimationController _floatingController;
  late AnimationController _pulseController;

  // Team setup state
  int _numberOfTeams = 2;
  int _roundsPerTeam = 1;
  int _roundDuration = 60;
  List<TextEditingController> _teamNameControllers = [];
  final List<Color> _teamColors = [
    AppTheme.primaryColor,
    AppTheme.secondaryColor,
    AppTheme.accentColor,
    AppTheme.warningColor,
  ];
  final List<IconData> _teamIcons = [
    FontAwesomeIcons.crown,
    FontAwesomeIcons.bolt,
    FontAwesomeIcons.fire,
    FontAwesomeIcons.star,
  ];

  // Tournament mode
  bool _isTournamentMode = false;
  String _tournamentType = 'round_robin'; // 'round_robin' or 'elimination'

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTeamControllers();
  }

  void _initializeAnimations() {
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  void _initializeTeamControllers() {
    _teamNameControllers = List.generate(
      4,
      (index) => TextEditingController(text: 'Team ${index + 1}'),
    );
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    for (var controller in _teamNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateNumberOfTeams(int teams) {
    setState(() {
      _numberOfTeams = teams;
      if (_numberOfTeams > 2) {
        _isTournamentMode = true;
      }
    });
    _hapticService.lightImpact();
    _audioService.playClick();
  }

  void _proceedToCategories() {
    // Validate team names
    final teamNames =
        _teamNameControllers
            .take(_numberOfTeams)
            .map((controller) => controller.text.trim())
            .toList();

    if (teamNames.any((name) => name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter names for all teams'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Check for duplicate names
    if (teamNames.toSet().length != teamNames.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team names must be unique'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    _hapticService.mediumImpact();
    _audioService.playClick();

    // Navigate to category selection with team data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CategorySelectionScreen(
              isTeamMode: true,
              teamNames: teamNames,
              teamColors: _teamColors.take(_numberOfTeams).toList(),
              roundsPerTeam: _roundsPerTeam,
              roundDuration: _roundDuration,
              isTournamentMode: _isTournamentMode,
              tournamentType: _tournamentType,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          const AnimatedGradientBackground(child: SizedBox.expand()),

          // Main content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () {
                      _hapticService.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Teams Battle Mode',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Set up your epic battle!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    centerTitle: true,
                  ),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Number of Teams Selection
                      _buildSectionCard(
                        title: 'Number of Teams',
                        icon: FontAwesomeIcons.users,
                        child: _buildTeamCountSelector(),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),

                      const SizedBox(height: 20),

                      // Team Names
                      _buildSectionCard(
                            title: 'Team Names',
                            icon: FontAwesomeIcons.signature,
                            child: _buildTeamNameInputs(),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 600.ms)
                          .slideY(begin: 0.1),

                      const SizedBox(height: 20),

                      // Game Settings
                      _buildSectionCard(
                            title: 'Game Settings',
                            icon: FontAwesomeIcons.sliders,
                            child: _buildGameSettings(),
                          )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 600.ms)
                          .slideY(begin: 0.1),

                      if (_numberOfTeams > 2) ...[
                        const SizedBox(height: 20),
                        // Tournament Settings
                        _buildSectionCard(
                              title: 'Tournament Mode',
                              icon: FontAwesomeIcons.trophy,
                              child: _buildTournamentSettings(),
                            )
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 600.ms)
                            .slideY(begin: 0.1),
                      ],

                      const SizedBox(height: 30),

                      // Start Button
                      _buildStartButton()
                          .animate()
                          .fadeIn(delay: 800.ms, duration: 600.ms)
                          .scale(begin: const Offset(0.9, 0.9)),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCountSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        final teamCount = index + 2;
        final isSelected = _numberOfTeams == teamCount;

        return GestureDetector(
          onTap: () => _updateNumberOfTeams(teamCount),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.primaryGradient : null,
              color: isSelected ? null : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                width: 2,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                      : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$teamCount',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Teams',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected
                            ? Colors.white.withOpacity(0.9)
                            : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTeamNameInputs() {
    return Column(
      children: List.generate(_numberOfTeams, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _teamColors[index].withOpacity(0.1),
                _teamColors[index].withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _teamColors[index].withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _teamColors[index],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FaIcon(
                      _teamIcons[index],
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _teamNameControllers[index],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter team name',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.5),
                      ),
                    ),
                    onTap: () => _hapticService.lightImpact(),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGameSettings() {
    return Column(
      children: [
        // Rounds per team
        _buildSettingRow(
          icon: FontAwesomeIcons.repeat,
          label: 'Rounds per Team',
          value: '$_roundsPerTeam',
          onDecrease:
              _roundsPerTeam > 1
                  ? () {
                    setState(() => _roundsPerTeam--);
                    _hapticService.lightImpact();
                  }
                  : null,
          onIncrease:
              _roundsPerTeam < 5
                  ? () {
                    setState(() => _roundsPerTeam++);
                    _hapticService.lightImpact();
                  }
                  : null,
        ),
        const SizedBox(height: 16),
        // Round duration
        _buildSettingRow(
          icon: FontAwesomeIcons.clock,
          label: 'Round Duration',
          value: '${_roundDuration}s',
          onDecrease:
              _roundDuration > 30
                  ? () {
                    setState(() => _roundDuration -= 15);
                    _hapticService.lightImpact();
                  }
                  : null,
          onIncrease:
              _roundDuration < 120
                  ? () {
                    setState(() => _roundDuration += 15);
                    _hapticService.lightImpact();
                  }
                  : null,
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onDecrease,
    VoidCallback? onIncrease,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FaIcon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded),
                onPressed: onDecrease,
                color:
                    onDecrease != null
                        ? AppTheme.primaryColor
                        : AppTheme.textTertiary,
                iconSize: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: onIncrease,
                color:
                    onIncrease != null
                        ? AppTheme.primaryColor
                        : AppTheme.textTertiary,
                iconSize: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentSettings() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text(
            'Enable Tournament',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: const Text(
            'Teams compete in a structured tournament',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          value: _isTournamentMode,
          onChanged: (value) {
            setState(() => _isTournamentMode = value);
            _hapticService.lightImpact();
          },
          activeColor: AppTheme.primaryColor,
        ),
        if (_isTournamentMode) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTournamentTypeOption(
                  'Round Robin',
                  'round_robin',
                  FontAwesomeIcons.circleNodes,
                  'Every team plays each other',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTournamentTypeOption(
                  'Elimination',
                  'elimination',
                  FontAwesomeIcons.sitemap,
                  'Single elimination bracket',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTournamentTypeOption(
    String title,
    String type,
    IconData icon,
    String description,
  ) {
    final isSelected = _tournamentType == type;

    return GestureDetector(
      onTap: () {
        setState(() => _tournamentType = type);
        _hapticService.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            FaIcon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color:
                    isSelected
                        ? Colors.white.withOpacity(0.9)
                        : AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          onTap: _proceedToCategories,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.gamepad,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Choose Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
