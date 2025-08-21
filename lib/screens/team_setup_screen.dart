import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/app_theme.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import 'category_selection_screen.dart';

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
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _hapticService.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.shade100,
                                Colors.grey.shade50,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 22,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Team Battle',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Set up your epic competition',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Team Selection Section
                    _buildModernSection(
                      title: 'Choose Your Teams',
                      subtitle: 'Select the number of competing teams',
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF6366F1),
                      child: _buildTeamCountSelector(),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),

                    const SizedBox(height: 20),

                    // Team Names Section
                    _buildModernSection(
                          title: 'Team Identity',
                          subtitle: 'Give your teams unique names',
                          icon: Icons.edit_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          child: _buildTeamNameInputs(),
                        )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 500.ms)
                        .slideY(begin: 0.05),

                    const SizedBox(height: 20),

                    // Game Settings
                    _buildModernSection(
                          title: 'Game Rules',
                          subtitle: 'Configure your battle settings',
                          icon: Icons.tune_rounded,
                          iconColor: const Color(0xFF10B981),
                          child: _buildGameSettings(),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 500.ms)
                        .slideY(begin: 0.05),

                    if (_numberOfTeams > 2) ...[
                      const SizedBox(height: 20),
                      // Tournament Settings
                      _buildModernSection(
                            title: 'Tournament Style',
                            subtitle: 'Choose your competition format',
                            icon: Icons.emoji_events_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            child: _buildTournamentSettings(),
                          )
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 500.ms)
                          .slideY(begin: 0.05),
                    ],

                    const SizedBox(height: 30),

                    // Start Button
                    _buildModernStartButton()
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 500.ms)
                        .scale(begin: const Offset(0.95, 0.95)),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  // Keep old method for compatibility
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return _buildModernSection(
      title: title,
      subtitle: '',
      icon: Icons.category_rounded,
      iconColor: AppTheme.primaryColor,
      child: child,
    );
  }

  Widget _buildTeamCountSelector() {
    final teamOptions = [
      {
        'count': 2,
        'icon': Icons.people_alt_rounded,
        'label': 'DUO',
        'color': const Color(0xFF6366F1), // Indigo
        'bgColor': const Color(0xFFEEF2FF),
      },
      {
        'count': 3,
        'icon': Icons.groups_2_rounded,
        'label': 'TRIO',
        'color': const Color(0xFF8B5CF6), // Purple
        'bgColor': const Color(0xFFF3E8FF),
      },
      {
        'count': 4,
        'icon': Icons.diversity_1_rounded,
        'label': 'SQUAD',
        'color': const Color(0xFFEC4899), // Pink
        'bgColor': const Color(0xFFFCE7F3),
      },
    ];

    return Container(
          height: 90,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Row(
            children: List.generate(teamOptions.length, (index) {
              final option = teamOptions[index];
              final teamCount = option['count'] as int;
              final icon = option['icon'] as IconData;
              final label = option['label'] as String;
              final color = option['color'] as Color;
              final bgColor = option['bgColor'] as Color;
              final isSelected = _numberOfTeams == teamCount;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _updateNumberOfTeams(teamCount),
                  child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        margin: EdgeInsets.symmetric(
                          horizontal: index == 1 ? 4 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon container
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
                              width: isSelected ? 42 : 38,
                              height: isSelected ? 42 : 38,
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Colors.white.withOpacity(0.9)
                                        : bgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: isSelected ? 24 : 22,
                                color:
                                    isSelected ? color : color.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Label
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                              child: Text(label),
                            ),
                          ],
                        ),
                      )
                      .animate(target: isSelected ? 1 : 0)
                      .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.02, 1.02),
                        duration: 300.ms,
                        curve: Curves.easeInOutCubic,
                      ),
                ),
              );
            }),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideY(begin: 0.02, duration: 500.ms, curve: Curves.easeOutCubic);
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

  Widget _buildModernStartButton() {
    return GestureDetector(
      onTap: _proceedToCategories,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'Start Battle',
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
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // Keep old method for compatibility
  Widget _buildStartButton() {
    return _buildModernStartButton();
  }
}
