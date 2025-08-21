import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_theme.dart';
import '../providers/game_provider.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final _audioService = AudioService();
  final _hapticService = HapticService();

  late AnimationController _floatingController;
  late AnimationController _pulseController;

  // Settings values
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _notificationsEnabled = false;
  int _timerDuration = 60;
  String _difficulty = 'Medium';
  bool _darkMode = false;
  bool _showTutorials = true;
  bool _kidFriendlyMode = false;
  bool _showWordsAfterPass = true;
  String _userName = '';
  String _userAvatar = '👤';

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final gameProvider = context.read<GameProvider>();

    setState(() {
      _soundEnabled = gameProvider.soundEnabled;
      _vibrationEnabled = gameProvider.vibrationEnabled;
      _kidFriendlyMode = gameProvider.kidFriendlyMode;
      _showWordsAfterPass = gameProvider.showWordsAfterPass;
      _timerDuration = gameProvider.roundDuration;

      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _difficulty = prefs.getString('difficulty') ?? 'Medium';
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _showTutorials = prefs.getBool('show_tutorials') ?? true;
      _userName = prefs.getString('user_name') ?? '';
      _userAvatar = prefs.getString('user_avatar') ?? '👤';
    });

    _audioService.setSoundEnabled(_soundEnabled);
    _hapticService.setVibrationEnabled(_vibrationEnabled);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final gameProvider = context.read<GameProvider>();

    // Save to GameProvider (syncs with Firebase)
    if (_soundEnabled != gameProvider.soundEnabled) {
      await gameProvider.toggleSound();
    }
    if (_vibrationEnabled != gameProvider.vibrationEnabled) {
      await gameProvider.toggleVibration();
    }
    if (_kidFriendlyMode != gameProvider.kidFriendlyMode) {
      await gameProvider.toggleKidFriendlyMode();
    }
    if (_showWordsAfterPass != gameProvider.showWordsAfterPass) {
      await gameProvider.toggleShowWordsAfterPass();
    }
    if (_timerDuration != gameProvider.roundDuration) {
      await gameProvider.updateRoundDuration(_timerDuration);
    }

    // Save local preferences
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('difficulty', _difficulty);
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('show_tutorials', _showTutorials);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_avatar', _userAvatar);

    _audioService.setSoundEnabled(_soundEnabled);
    _hapticService.setVibrationEnabled(_vibrationEnabled);
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
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                _hapticService.lightImpact();
                _audioService.playClick();
                context.pop();
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative elements
                    Positioned(
                      top: -50,
                      right: -50,
                      child: AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _floatingController.value * 0.2,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ).animate().scale(
                              duration: 600.ms,
                              curve: Curves.easeOutBack,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Settings',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 8),
                            Text(
                              'Customize your experience',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ).animate().fadeIn(delay: 300.ms),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Settings Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // User Profile Section
                _buildUserProfileCard()
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.1),
                const SizedBox(height: 24),

                // Game Settings Section
                _buildSectionHeader('Game Settings', Icons.sports_esports),
                const SizedBox(height: 12),
                _buildSettingsCard([
                  _buildSwitchTile(
                    title: 'Sound Effects',
                    subtitle: 'Play sounds during gameplay',
                    icon: Icons.volume_up_rounded,
                    value: _soundEnabled,
                    onChanged: (value) {
                      setState(() => _soundEnabled = value);
                      _saveSettings();
                      if (value) _audioService.playClick();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Vibration',
                    subtitle: 'Haptic feedback for actions',
                    icon: Icons.vibration_rounded,
                    value: _vibrationEnabled,
                    onChanged: (value) {
                      setState(() => _vibrationEnabled = value);
                      _saveSettings();
                      if (value) _hapticService.mediumImpact();
                    },
                  ),
                  _buildDivider(),
                  _buildTimerTile(),
                  _buildDivider(),
                  _buildDifficultyTile(),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Kid-Friendly Mode',
                    subtitle: 'Filter content for younger players',
                    icon: Icons.child_care_rounded,
                    value: _kidFriendlyMode,
                    onChanged: (value) {
                      setState(() => _kidFriendlyMode = value);
                      _saveSettings();
                      _hapticService.lightImpact();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Show Passed Words',
                    subtitle: 'Display skipped words after round',
                    icon: Icons.visibility_rounded,
                    value: _showWordsAfterPass,
                    onChanged: (value) {
                      setState(() => _showWordsAfterPass = value);
                      _saveSettings();
                      _hapticService.lightImpact();
                    },
                  ),
                ]).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                const SizedBox(height: 24),

                // Preferences Section
                _buildSectionHeader('Preferences', Icons.tune_rounded),
                const SizedBox(height: 12),
                _buildSettingsCard([
                  _buildSwitchTile(
                    title: 'Dark Mode',
                    subtitle: 'Coming soon',
                    icon: Icons.dark_mode_rounded,
                    value: _darkMode,
                    enabled: false,
                    onChanged: (value) {
                      // Dark mode implementation
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Notifications',
                    subtitle: 'Get reminders to play',
                    icon: Icons.notifications_rounded,
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                      _saveSettings();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Show Tutorials',
                    subtitle: 'Display helpful tips',
                    icon: Icons.help_outline_rounded,
                    value: _showTutorials,
                    onChanged: (value) {
                      setState(() => _showTutorials = value);
                      _saveSettings();
                    },
                  ),
                ]).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

                const SizedBox(height: 24),

                // Data & Privacy Section
                _buildSectionHeader('Data & Privacy', Icons.security_rounded),
                const SizedBox(height: 12),
                _buildSettingsCard([
                  _buildActionTile(
                    title: 'Clear Game History',
                    subtitle: 'Remove all game statistics',
                    icon: Icons.delete_outline_rounded,
                    onTap: () => _showClearDataDialog(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Export Data',
                    subtitle: 'Download your game data',
                    icon: Icons.download_rounded,
                    onTap: () => _showComingSoonSnackbar('Data export'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Privacy Policy',
                    subtitle: 'View our privacy policy',
                    icon: Icons.privacy_tip_rounded,
                    onTap: () => _launchURL('https://example.com/privacy'),
                  ),
                ]).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

                const SizedBox(height: 24),

                // About Section
                _buildSectionHeader('About', Icons.info_outline_rounded),
                const SizedBox(height: 12),
                _buildSettingsCard([
                  _buildInfoTile(
                    title: 'Version',
                    value: '1.0.0',
                    icon: Icons.verified_rounded,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Rate Us',
                    subtitle: 'Love the app? Leave a review',
                    icon: Icons.star_rounded,
                    onTap: () => _showRateDialog(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Share App',
                    subtitle: 'Tell your friends',
                    icon: Icons.share_rounded,
                    onTap: () => _shareApp(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Contact Support',
                    subtitle: 'Get help or report issues',
                    icon: Icons.support_agent_rounded,
                    onTap: () => _launchURL('mailto:support@headsup.com'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Terms of Service',
                    subtitle: 'View terms and conditions',
                    icon: Icons.description_rounded,
                    onTap: () => _launchURL('https://example.com/terms'),
                  ),
                ]).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),

                const SizedBox(height: 24),

                // Developer Section
                _buildSectionHeader('Developer', Icons.code_rounded),
                const SizedBox(height: 12),
                _buildSettingsCard([
                  _buildActionTile(
                    title: 'GitHub',
                    subtitle: 'View source code',
                    icon: FontAwesomeIcons.github,
                    onTap: () => _launchURL('https://github.com'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Report Bug',
                    subtitle: 'Help us improve',
                    icon: Icons.bug_report_rounded,
                    onTap: () => _launchURL('https://github.com/issues'),
                  ),
                ]).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),

                const SizedBox(height: 40),

                // Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Made with ❤️ by Cuberix',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© 2024 Heads Up! Game',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 900.ms),

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => _showAvatarPicker(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _userAvatar,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showNameEditDialog(),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _userName.isEmpty ? 'Guest Player' : _userName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer<GameProvider>(
                        builder: (context, gameProvider, _) {
                          final stats = gameProvider.getStatistics();
                          final totalGames = stats['totalGames'] ?? 0;
                          final level = (totalGames ~/ 10) + 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.military_tech_rounded,
                                  size: 16,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Level $level',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Stats Row
            Consumer<GameProvider>(
              builder: (context, gameProvider, _) {
                final stats = gameProvider.getStatistics();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Games',
                      '${stats['totalGames'] ?? 0}',
                      Icons.sports_esports_rounded,
                    ),
                    _buildStatItem(
                      'High Score',
                      '${stats['highScore'] ?? 0}',
                      Icons.emoji_events_rounded,
                    ),
                    _buildStatItem(
                      'Win Rate',
                      '${((stats['winRate'] ?? 0) * 100).round()}%',
                      Icons.trending_up_rounded,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
    bool enabled = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              value
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : AppTheme.dividerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: value ? AppTheme.primaryColor : AppTheme.textTertiary,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: enabled ? AppTheme.textPrimary : AppTheme.textTertiary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: enabled ? AppTheme.textSecondary : AppTheme.textTertiary,
        ),
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: AppTheme.primaryColor,
        thumbColor: Colors.white,
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 24),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppTheme.textTertiary,
        size: 16,
      ),
      onTap: () {
        _hapticService.lightImpact();
        _audioService.playClick();
        onTap();
      },
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.successColor, size: 24),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTimerTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.timer_rounded,
          color: AppTheme.warningColor,
          size: 24,
        ),
      ),
      title: Text(
        'Timer Duration',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$_timerDuration seconds per round',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed:
                  _timerDuration > 30
                      ? () {
                        setState(() => _timerDuration -= 10);
                        _saveSettings();
                        _hapticService.lightImpact();
                      }
                      : null,
              icon: const Icon(Icons.remove_rounded),
              color: AppTheme.primaryColor,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$_timerDuration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            IconButton(
              onPressed:
                  _timerDuration < 120
                      ? () {
                        setState(() => _timerDuration += 10);
                        _saveSettings();
                        _hapticService.lightImpact();
                      }
                      : null,
              icon: const Icon(Icons.add_rounded),
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyTile() {
    final difficulties = ['Easy', 'Medium', 'Hard'];
    final difficultyColors = {
      'Easy': AppTheme.successColor,
      'Medium': AppTheme.warningColor,
      'Hard': AppTheme.errorColor,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: difficultyColors[_difficulty]!.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.speed_rounded,
          color: difficultyColors[_difficulty],
          size: 24,
        ),
      ),
      title: Text(
        'Difficulty',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Adjust game challenge level',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: difficultyColors[_difficulty]!.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: difficultyColors[_difficulty]!.withOpacity(0.3),
          ),
        ),
        child: DropdownButton<String>(
          value: _difficulty,
          underline: const SizedBox(),
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: difficultyColors[_difficulty],
          ),
          items:
              difficulties.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: difficultyColors[value],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _difficulty = newValue);
              _saveSettings();
              _hapticService.lightImpact();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 20,
      endIndent: 20,
      color: AppTheme.dividerColor,
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: AppTheme.errorColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Clear Data?'),
              ],
            ),
            content: const Text(
              'This will permanently delete all your game statistics and progress. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _hapticService.lightImpact();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _hapticService.heavyImpact();
                  context.read<GameProvider>().clearAllData();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Game data cleared successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('Clear Data'),
              ),
            ],
          ),
    );
  }

  void _showRateDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: AppTheme.warningColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Enjoying Heads Up?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'We\'d love to hear your feedback! Please rate us on the App Store.',
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star_rounded,
                      color: AppTheme.warningColor,
                      size: 32,
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _hapticService.lightImpact();
                  Navigator.pop(context);
                },
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  _hapticService.success();
                  Navigator.pop(context);
                  _launchURL('https://apps.apple.com');
                },
                child: const Text('Rate Now'),
              ),
            ],
          ),
    );
  }

  void _shareApp() {
    // Share functionality would be implemented here
    _showComingSoonSnackbar('Share feature');
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $url'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showNameEditDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Edit Name'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
              maxLength: 20,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _userName = controller.text.trim());
                  _saveSettings();
                  Navigator.pop(context);
                  _hapticService.lightImpact();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showAvatarPicker() {
    final avatars = [
      '👤',
      '😀',
      '😎',
      '🤓',
      '🥳',
      '🤠',
      '😇',
      '🤩',
      '🦸',
      '🦹',
      '🧙',
      '🧚',
      '🧛',
      '🧜',
      '🧝',
      '🧞',
      '👨',
      '👩',
      '👶',
      '👴',
      '👵',
      '👨‍🎓',
      '👩‍🎓',
      '👨‍💼',
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
      '🦄',
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Choose Avatar'),
            content: Container(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final avatar = avatars[index];
                  final isSelected = avatar == _userAvatar;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _userAvatar = avatar);
                      _saveSettings();
                      Navigator.pop(context);
                      _hapticService.lightImpact();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.dividerColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }

  void _showComingSoonSnackbar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
