import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  bool _showTutorials = true;
  bool _kidFriendlyMode = false;
  bool _showWordsAfterPass = true;
  bool _useManualControls = false;
  bool _preferLandscape = true;

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
      _showTutorials = prefs.getBool('show_tutorials') ?? true;
      _useManualControls = prefs.getBool('use_manual_controls') ?? false;
      _preferLandscape = prefs.getBool('prefer_landscape_gameplay') ?? true;
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
    await prefs.setBool('show_tutorials', _showTutorials);
    await prefs.setBool('use_manual_controls', _useManualControls);
    await prefs.setBool('prefer_landscape_gameplay', _preferLandscape);

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
                child: Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 40),
                            Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.settings_rounded,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 600.ms)
                                .scale(delay: 200.ms),
                            const SizedBox(height: 12),
                            Text(
                                  'Settings',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 100.ms, duration: 600.ms)
                                .slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 6),
                            Text(
                              'Customize your experience',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game Settings
                  _buildSectionTitle('Game Settings', Icons.games_rounded),
                  const SizedBox(height: 12),
                  _buildCard([
                    _buildSwitchTile(
                      'Sound Effects',
                      'Play sounds during gameplay',
                      Icons.volume_up_rounded,
                      _soundEnabled,
                      (value) {
                        setState(() => _soundEnabled = value);
                        _saveSettings();
                        _hapticService.lightImpact();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Vibration',
                      'Haptic feedback during gameplay',
                      Icons.vibration_rounded,
                      _vibrationEnabled,
                      (value) {
                        setState(() => _vibrationEnabled = value);
                        _saveSettings();
                        if (value) _hapticService.mediumImpact();
                      },
                    ),
                    _buildDivider(),
                    _buildTimerTile(),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Kid-Friendly Mode',
                      'Filter inappropriate content',
                      Icons.child_care_rounded,
                      _kidFriendlyMode,
                      (value) {
                        setState(() => _kidFriendlyMode = value);
                        _saveSettings();
                        _hapticService.lightImpact();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Show Words After Pass',
                      'Display passed words after round',
                      Icons.visibility_rounded,
                      _showWordsAfterPass,
                      (value) {
                        setState(() => _showWordsAfterPass = value);
                        _saveSettings();
                        _hapticService.lightImpact();
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Gameplay Controls
                  _buildSectionTitle(
                    'Gameplay Controls',
                    Icons.gamepad_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildCard([
                    _buildSwitchTile(
                      'Manual Controls',
                      'Use buttons instead of tilt',
                      Icons.touch_app_rounded,
                      _useManualControls,
                      (value) {
                        setState(() => _useManualControls = value);
                        _saveSettings();
                        _hapticService.lightImpact();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Landscape Mode',
                      'Play in horizontal orientation',
                      Icons.screen_rotation_rounded,
                      _preferLandscape,
                      (value) {
                        setState(() => _preferLandscape = value);
                        _saveSettings();
                        _hapticService.lightImpact();
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // General Settings
                  _buildSectionTitle('General', Icons.tune_rounded),
                  const SizedBox(height: 12),
                  _buildCard([
                    _buildSwitchTile(
                      'Notifications',
                      'Receive game reminders',
                      Icons.notifications_rounded,
                      _notificationsEnabled,
                      (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSettings();
                        _hapticService.lightImpact();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Show Tutorials',
                      'Display helpful hints',
                      Icons.help_outline_rounded,
                      _showTutorials,
                      (value) {
                        setState(() => _showTutorials = value);
                        _saveSettings();
                        _hapticService.lightImpact();
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // About Section
                  _buildSectionTitle('About', Icons.info_outline_rounded),
                  const SizedBox(height: 12),
                  _buildCard([
                    _buildInfoTile('Version', '1.0.0', Icons.verified_rounded),
                    _buildDivider(),
                    _buildLinkTile(
                      'Privacy Policy',
                      Icons.privacy_tip_rounded,
                      () => _launchUrl('https://example.com/privacy'),
                    ),
                    _buildDivider(),
                    _buildLinkTile(
                      'Terms of Service',
                      Icons.description_rounded,
                      () => _launchUrl('https://example.com/terms'),
                    ),
                    _buildDivider(),
                    _buildLinkTile(
                      'Rate Us',
                      Icons.star_rounded,
                      () => _launchUrl('https://example.com/rate'),
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            Theme.of(context).brightness == Brightness.light
                ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
        border:
            Theme.of(context).brightness == Brightness.dark
                ? Border.all(color: Colors.grey.shade300, width: 1)
                : null,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTimerTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timer_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Round Duration',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Time per round in seconds',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_timerDuration > 30) {
                      setState(() => _timerDuration -= 10);
                      _saveSettings();
                      _hapticService.lightImpact();
                    }
                  },
                  child: Icon(
                    Icons.remove_rounded,
                    color:
                        _timerDuration > 30
                            ? AppTheme.primaryColor
                            : AppTheme.textTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_timerDuration}s',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (_timerDuration < 120) {
                      setState(() => _timerDuration += 10);
                      _saveSettings();
                      _hapticService.lightImpact();
                    }
                  },
                  child: Icon(
                    Icons.add_rounded,
                    color:
                        _timerDuration < 120
                            ? AppTheme.primaryColor
                            : AppTheme.textTertiary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        _hapticService.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.dividerColor,
      indent: 60,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
