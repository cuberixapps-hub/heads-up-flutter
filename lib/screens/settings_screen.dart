import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/app_localizations.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/language_provider.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../widgets/version_switcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final _audioService = AudioService();
  final _hapticService = HapticService();

  // Settings values
  bool _soundEnabled = true;
  bool _hapticEnabled = true;
  bool _notificationsEnabled = false;
  int _timerDuration = 60;
  bool _showTutorials = true;
  bool _kidFriendlyMode = false;
  bool _showWordsAfterPass = true;
  bool _useManualControls = false;
  bool _preferLandscape = true;
  bool _reactionRecordingEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final gameProvider = context.read<GameProvider>();

    setState(() {
      _soundEnabled = gameProvider.soundEnabled;
      _hapticEnabled = gameProvider.vibrationEnabled;
      _kidFriendlyMode = gameProvider.kidFriendlyMode;
      _showWordsAfterPass = gameProvider.showWordsAfterPass;
      _timerDuration = gameProvider.roundDuration;

      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _showTutorials = prefs.getBool('show_tutorials') ?? true;
      _useManualControls = prefs.getBool('use_manual_controls') ?? false;
      _preferLandscape = prefs.getBool('prefer_landscape_gameplay') ?? true;
      _reactionRecordingEnabled =
          prefs.getBool('enable_reaction_recording') ?? true;
    });

    _audioService.setSoundEnabled(_soundEnabled);
    _hapticService.setHapticEnabled(_hapticEnabled);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final gameProvider = context.read<GameProvider>();

    // Save to GameProvider (syncs with Firebase)
    if (_soundEnabled != gameProvider.soundEnabled) {
      await gameProvider.toggleSound();
    }
    if (_hapticEnabled != gameProvider.vibrationEnabled) {
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
    await prefs.setBool('enable_reaction_recording', _reactionRecordingEnabled);

    _audioService.setSoundEnabled(_soundEnabled);
    _hapticService.setHapticEnabled(_hapticEnabled);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Elegant gradient background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.08),
                  const Color(0xFF000000),
                  const Color(0xFF000000),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Compact Header
              SliverAppBar(
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF000000).withOpacity(0.95),
                            const Color(0xFF000000).withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                leadingWidth: 72,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: IconButton(
                        onPressed: () {
                          _hapticService.lightImpact();
                          _audioService.playClick();
                          context.pop();
                        },
                        icon: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(delay: 100.ms, curve: Curves.easeOutBack),
                ),
              ),

              // Settings Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 50),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Game Settings Section
                    _buildModernSection(
                      AppLocalizations.of(context)!.gameSettings,
                      Icons.tune_rounded,
                      [
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.soundEffects,
                          AppLocalizations.of(
                            context,
                          )!.playSoundsDuringGameplay,
                          Icons.volume_up_rounded,
                          _soundEnabled,
                          (value) {
                            setState(() => _soundEnabled = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                        _buildItemDivider(),
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.hapticFeedback,
                          AppLocalizations.of(context)!.subtleTouchFeedback,
                          Icons.vibration_rounded,
                          _hapticEnabled,
                          (value) {
                            setState(() => _hapticEnabled = value);
                            _saveSettings();
                            if (value) _hapticService.mediumImpact();
                          },
                        ),
                        _buildItemDivider(),
                        _buildModernTimerItem(),
                        _buildItemDivider(),
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.kidFriendlyMode,
                          AppLocalizations.of(
                            context,
                          )!.filterInappropriateContent,
                          Icons.child_care_rounded,
                          _kidFriendlyMode,
                          (value) {
                            setState(() => _kidFriendlyMode = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                        _buildItemDivider(),
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.showWordsAfterPass,
                          AppLocalizations.of(
                            context,
                          )!.displayPassedWordsAfterRound,
                          Icons.visibility_rounded,
                          _showWordsAfterPass,
                          (value) {
                            setState(() => _showWordsAfterPass = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                        _buildItemDivider(),
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.recordReactions,
                          AppLocalizations.of(context)!.captureFunMoments,
                          Icons.videocam_rounded,
                          _reactionRecordingEnabled,
                          (value) {
                            setState(() => _reactionRecordingEnabled = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                      ],
                      0,
                    ),

                    const SizedBox(height: 28),

                    // Gameplay Controls Section
                    _buildModernSection(
                      AppLocalizations.of(context)!.gameplayControls,
                      Icons.gamepad_rounded,
                      [
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.manualControls,
                          AppLocalizations.of(context)!.useButtonsInsteadOfTilt,
                          Icons.touch_app_rounded,
                          _useManualControls,
                          (value) {
                            setState(() => _useManualControls = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                        _buildItemDivider(),
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.landscapeMode,
                          AppLocalizations.of(
                            context,
                          )!.playInHorizontalOrientation,
                          Icons.screen_rotation_rounded,
                          _preferLandscape,
                          (value) {
                            setState(() => _preferLandscape = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                      ],
                      1,
                    ),

                    const SizedBox(height: 28),

                    // General Section
                    _buildModernSection(
                      AppLocalizations.of(context)!.general,
                      Icons.settings_rounded,
                      [
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.notifications,
                          AppLocalizations.of(context)!.receiveGameReminders,
                          Icons.notifications_rounded,
                          _notificationsEnabled,
                          (value) {
                            setState(() => _notificationsEnabled = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                        _buildItemDivider(),
                        _buildModernToggleItem(
                          AppLocalizations.of(context)!.showTutorials,
                          AppLocalizations.of(context)!.displayHelpfulHints,
                          Icons.lightbulb_rounded,
                          _showTutorials,
                          (value) {
                            setState(() => _showTutorials = value);
                            _saveSettings();
                            _hapticService.lightImpact();
                          },
                        ),
                      ],
                      2,
                    ),

                    const SizedBox(height: 28),

                    // Language Section
                    _buildModernSection(
                      AppLocalizations.of(context)!.language,
                      Icons.language_rounded,
                      [_buildLanguageSelector()],
                      3,
                    ),

                    const SizedBox(height: 28),

                    // App Appearance Section
                    _buildModernSection(
                      AppLocalizations.of(context)!.appAppearance,
                      Icons.palette_rounded,
                      [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: const VersionSwitcher(),
                        ),
                      ],
                      4,
                    ),

                    const SizedBox(height: 28),

                    // About Section
                    _buildModernSection(
                      AppLocalizations.of(context)!.about,
                      Icons.info_rounded,
                      [
                        _buildModernInfoItem(
                          AppLocalizations.of(context)!.version,
                          '1.0.0',
                          Icons.verified_rounded,
                        ),
                        _buildItemDivider(),
                        _buildModernLinkItem(
                          AppLocalizations.of(context)!.rateUs,
                          Icons.star_rounded,
                          _rateApp,
                        ),
                      ],
                      5,
                    ),

                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Elegant Section Builder
  Widget _buildModernSection(
    String title,
    IconData icon,
    List<Widget> items,
    int index,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Refined Section Header
        Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            )
            .animate()
            .fadeIn(delay: (100 + index * 30).ms, duration: 500.ms)
            .slideX(begin: -0.02, end: 0),

        // Elegant Card
        Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(children: items),
              ),
            )
            .animate()
            .fadeIn(delay: (150 + index * 30).ms, duration: 600.ms)
            .slideY(
              begin: 0.05,
              end: 0,
              duration: 600.ms,
              curve: Curves.easeOutCubic,
            )
            .scale(
              begin: const Offset(0.98, 0.98),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }

  // Subtle Item Divider
  Widget _buildItemDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 68),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  // Refined Toggle Item
  Widget _buildModernToggleItem(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        splashColor: AppTheme.primaryColor.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // Elegant Icon Container
              AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient:
                          value
                              ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryColor.withOpacity(0.2),
                                  AppTheme.primaryColor.withOpacity(0.1),
                                ],
                              )
                              : null,
                      color: value ? null : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color:
                          value
                              ? AppTheme.primaryColor
                              : Colors.white.withOpacity(0.4),
                      size: 22,
                    ),
                  )
                  .animate(target: value ? 1 : 0)
                  .scaleXY(
                    begin: 1,
                    end: 1.08,
                    duration: 250.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(width: 18),

              // Polished Typography
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.4,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.15,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Premium Toggle Switch
              GestureDetector(
                onTap: () => onChanged(!value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 52,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient:
                        value
                            ? LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withOpacity(0.8),
                              ],
                            )
                            : null,
                    color: value ? null : const Color(0xFF1E1E1E),
                    boxShadow:
                        value
                            ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        left: value ? 22 : 2,
                        top: 2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
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
    );
  }

  // Refined Timer Item
  Widget _buildModernTimerItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Elegant Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.timer_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 18),

          // Polished Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.roundDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.4,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context)!.timePerRoundInSeconds,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Premium Timer Controls
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTimerButton(
                  Icons.remove_rounded,
                  _timerDuration > 30,
                  () {
                    if (_timerDuration > 30) {
                      setState(() => _timerDuration -= 10);
                      _saveSettings();
                      _hapticService.lightImpact();
                    }
                  },
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  alignment: Alignment.center,
                  child: Text(
                    '${_timerDuration}s',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _buildTimerButton(Icons.add_rounded, _timerDuration < 120, () {
                  if (_timerDuration < 120) {
                    setState(() => _timerDuration += 10);
                    _saveSettings();
                    _hapticService.lightImpact();
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerButton(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppTheme.primaryColor.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color:
                enabled
                    ? Colors.white.withOpacity(0.9)
                    : Colors.white.withOpacity(0.2),
            size: 18,
          ),
        ),
      ),
    );
  }

  // Refined Info Item
  Widget _buildModernInfoItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.4,
                height: 1.3,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Refined Link Item
  Widget _buildModernLinkItem(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _hapticService.lightImpact();
          onTap();
        },
        splashColor: AppTheme.primaryColor.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.primaryColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.4,
                    height: 1.3,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _rateApp() {
    _hapticService.mediumImpact();

    // App Store ID for iOS (you'll need to replace with your actual ID)
    const String appStoreId = 'YOUR_APP_STORE_ID';
    // Package name for Android (you'll need to replace with your actual package name)
    const String androidPackageName = 'com.headsup.heads_up_game';

    final String url;
    if (Platform.isIOS) {
      // iOS App Store URL
      url = 'https://apps.apple.com/app/id$appStoreId?action=write-review';
    } else if (Platform.isAndroid) {
      // Android Play Store URL
      url = 'https://play.google.com/store/apps/details?id=$androidPackageName';
    } else {
      // Fallback for other platforms
      return;
    }

    _launchUrl(url);
  }

  // Language Selector Widget
  Widget _buildLanguageSelector() {
    final languageProvider = context.watch<LanguageProvider>();
    final currentLanguageCode = languageProvider.locale.languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.language_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 18),

          // Label
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.selectLanguage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.4,
                height: 1.3,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Language Dropdown
          GestureDetector(
            onTap: () => _showLanguagePicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LanguageProvider.getLanguageName(currentLanguageCode),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show Language Picker Dialog
  void _showLanguagePicker(BuildContext context) {
    final languageProvider = context.read<LanguageProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.of(context)!.selectLanguage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // Language List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: LanguageProvider.supportedLocales.length,
                  itemBuilder: (context, index) {
                    final locale = LanguageProvider.supportedLocales[index];
                    final languageName = LanguageProvider.getLanguageName(
                      locale.languageCode,
                    );
                    final isSelected = languageProvider.locale == locale;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          _hapticService.lightImpact();
                          await languageProvider.setLocale(locale);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.primaryColor.withOpacity(0.1)
                                    : Colors.transparent,
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.05),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  languageName,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.white,
                                    fontSize: 16,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
