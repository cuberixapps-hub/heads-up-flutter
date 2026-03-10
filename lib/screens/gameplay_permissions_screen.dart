import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

/// Dedicated permission screen shown before gameplay.
/// Requests camera and microphone permissions with clear explanations.
/// Skips automatically when all permissions are already granted.
class GameplayPermissionsScreen extends StatefulWidget {
  /// Called when all required permissions are resolved (granted or skipped).
  final VoidCallback onPermissionsResolved;

  /// Called when the user wants to go back.
  final VoidCallback onBack;

  const GameplayPermissionsScreen({
    super.key,
    required this.onPermissionsResolved,
    required this.onBack,
  });

  /// Check if all gameplay permissions are already granted.
  /// Returns true if permissions screen can be skipped.
  static Future<bool> arePermissionsGranted() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;
    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  /// Check if the user has already been through the permissions flow.
  static Future<bool> hasCompletedPermissionsFlow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('gameplay_permissions_completed') ?? false;
  }

  /// Mark the permissions flow as completed.
  static Future<void> markPermissionsFlowCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gameplay_permissions_completed', true);
  }

  @override
  State<GameplayPermissionsScreen> createState() =>
      _GameplayPermissionsScreenState();
}

class _GameplayPermissionsScreenState extends State<GameplayPermissionsScreen>
    with SingleTickerProviderStateMixin {
  final _hapticService = HapticService();
  late AnimationController _glowController;

  bool _isRequesting = false;
  bool _cameraGranted = false;
  bool _microphoneGranted = false;

  // Color palette matching the app's premium dark theme
  static const Color _primaryColor = Color(0xFF4CAF50);
  static const Color _secondaryColor = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _checkCurrentPermissions();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    if (mounted) {
      setState(() {
        _cameraGranted = cameraStatus.isGranted;
        _microphoneGranted = microphoneStatus.isGranted;
      });

      // If all permissions are already granted, proceed immediately
      if (_cameraGranted && _microphoneGranted) {
        await GameplayPermissionsScreen.markPermissionsFlowCompleted();
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          widget.onPermissionsResolved();
        }
      }
    }
  }

  Future<void> _requestAllPermissions() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);
    _hapticService.mediumImpact();

    try {
      // Request camera permission
      if (!_cameraGranted) {
        final cameraResult = await Permission.camera.request();
        if (mounted) {
          setState(() {
            _cameraGranted = cameraResult.isGranted;
          });
        }

        // If permanently denied, open settings
        if (cameraResult.isPermanentlyDenied && mounted) {
          _showSettingsDialog('Camera');
          setState(() => _isRequesting = false);
          return;
        }
      }

      // Request microphone permission
      if (!_microphoneGranted) {
        final micResult = await Permission.microphone.request();
        if (mounted) {
          setState(() {
            _microphoneGranted = micResult.isGranted;
          });
        }

        // If permanently denied, open settings
        if (micResult.isPermanentlyDenied && mounted) {
          _showSettingsDialog('Microphone');
          setState(() => _isRequesting = false);
          return;
        }
      }

      // Mark flow as completed regardless of outcome
      await GameplayPermissionsScreen.markPermissionsFlowCompleted();

      if (mounted) {
        _hapticService.success();
        // Brief delay so the user sees the checkmarks before transitioning
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          widget.onPermissionsResolved();
        }
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // Still proceed even if permissions fail — gameplay handles fallback
      await GameplayPermissionsScreen.markPermissionsFlowCompleted();
      if (mounted) {
        widget.onPermissionsResolved();
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _skipPermissions() async {
    _hapticService.lightImpact();
    await GameplayPermissionsScreen.markPermissionsFlowCompleted();
    if (mounted) {
      widget.onPermissionsResolved();
    }
  }

  void _showSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.s),
            ),
            title: Text(
              '$permissionName Access Required',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18.sp,
              ),
            ),
            content: Text(
              '$permissionName access was denied. Please enable it in your device settings to use this feature during gameplay.',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14.sp,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text(
                  'Open Settings',
                  style: GoogleFonts.inter(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          _buildBackground(),
          _buildAmbientGlow(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.s),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            SizedBox(height: 16.s),

                            // Top bar with back and skip
                            _buildTopBar(),

                            SizedBox(height: 24.s),

                            // Shield illustration
                            _buildIllustration(),

                            SizedBox(height: 32.s),

                            // Title
                            _buildTitle(),

                            SizedBox(height: 10.s),

                            // Subtitle
                            _buildSubtitle(),

                            SizedBox(height: 28.s),

                            // Permission cards
                            _buildPermissionCards(),

                            const Spacer(),

                            SizedBox(height: 24.s),

                            // Enable button
                            _buildEnableButton(),

                            SizedBox(height: 12.s),

                            // Privacy note
                            _buildPrivacyNote(),

                            SizedBox(height: 24.s),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12141C), Color(0xFF0A0A0F), Color(0xFF050507)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_glowController.value * 0.1);

        return Stack(
          children: [
            Positioned(
              top: -100.s,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 350.s,
                  height: 350.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _primaryColor.withOpacity(glowOpacity),
                        _secondaryColor.withOpacity(glowOpacity * 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        GestureDetector(
          onTap: () {
            _hapticService.lightImpact();
            widget.onBack();
          },
          child: Container(
            padding: EdgeInsets.all(8.s),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.s),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 22.s,
            ),
          ),
        ),
        // Skip button
        TextButton(
          onPressed: _skipPermissions,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 8.s),
          ),
          child: Text(
            'Skip',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms);
  }

  Widget _buildIllustration() {
    return AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowIntensity = 0.4 + (_glowController.value * 0.3);

            return SizedBox(
              width: 160.s,
              height: 160.s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 145.s,
                    height: 145.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.15),
                        width: 1.s,
                      ),
                    ),
                  ),

                  // Inner gradient circle
                  Container(
                    width: 115.s,
                    height: 115.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _primaryColor.withOpacity(0.2),
                          _secondaryColor.withOpacity(0.15),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(glowIntensity * 0.4),
                          blurRadius: 50.s,
                          spreadRadius: 10.s,
                        ),
                      ],
                    ),
                  ),

                  // Camera icon
                  Icon(Icons.videocam_rounded, size: 48.s, color: Colors.white),

                  // Checkmark badge
                  if (_cameraGranted && _microphoneGranted)
                    Positioned(
                      bottom: 24.s,
                      right: 24.s,
                      child: Container(
                        width: 30.s,
                        height: 30.s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.5),
                              blurRadius: 12.s,
                              spreadRadius: 2.s,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18.s,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        )
        .animate()
        .fadeIn(duration: 800.ms, delay: 300.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildTitle() {
    return Text(
          'Almost Ready!',
          style: GoogleFonts.poppins(
            fontSize: 32.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -1,
          ),
          textAlign: TextAlign.center,
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 500.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildSubtitle() {
    return Text(
      'We need a couple of permissions to give you the best gameplay experience',
      style: GoogleFonts.inter(
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
        color: Colors.white.withOpacity(0.6),
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    ).animate().fadeIn(duration: 600.ms, delay: 600.ms);
  }

  Widget _buildPermissionCards() {
    final permissions = [
      _PermissionItem(
        icon: Icons.videocam_rounded,
        gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
        title: 'Camera',
        subtitle: 'Record fun reaction videos during gameplay',
        isGranted: _cameraGranted,
      ),
      _PermissionItem(
        icon: Icons.mic_rounded,
        gradient: const [Color(0xFF2196F3), Color(0xFF1565C0)],
        title: 'Microphone',
        subtitle: 'Capture audio for your reaction clips',
        isGranted: _microphoneGranted,
      ),
    ];

    return Column(
      children:
          permissions.asMap().entries.map((entry) {
            final index = entry.key;
            final perm = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: 12.s),
              child: _buildPermissionCard(perm)
                  .animate()
                  .fadeIn(
                    duration: 500.ms,
                    delay: Duration(milliseconds: 700 + (index * 100)),
                  )
                  .slideX(
                    begin: -0.1,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
            );
          }).toList(),
    );
  }

  Widget _buildPermissionCard(_PermissionItem perm) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.s),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 14.s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(
              color:
                  perm.isGranted
                      ? perm.gradient[0].withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
              width: 1.s,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 44.s,
                height: 44.s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.s),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: perm.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: perm.gradient[0].withOpacity(0.3),
                      blurRadius: 12.s,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(perm.icon, color: Colors.white, size: 22.s),
              ),
              SizedBox(width: 14.s),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perm.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.s),
                    Text(
                      perm.subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              SizedBox(width: 8.s),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child:
                    perm.isGranted
                        ? Container(
                          key: const ValueKey('granted'),
                          width: 28.s,
                          height: 28.s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: perm.gradient),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16.s,
                          ),
                        )
                        : Container(
                          key: const ValueKey('pending'),
                          width: 28.s,
                          height: 28.s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 2.s,
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnableButton() {
    final allGranted = _cameraGranted && _microphoneGranted;
    final buttonText = allGranted ? 'Continue to Game' : 'Allow Permissions';
    final buttonIcon =
        allGranted ? Icons.play_arrow_rounded : Icons.shield_rounded;

    return GestureDetector(
          onTap:
              _isRequesting
                  ? null
                  : (allGranted
                      ? widget.onPermissionsResolved
                      : _requestAllPermissions),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 56.s,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    _isRequesting
                        ? [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ]
                        : [_primaryColor, _secondaryColor],
              ),
              borderRadius: BorderRadius.circular(16.s),
              boxShadow:
                  _isRequesting
                      ? []
                      : [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.4),
                          blurRadius: 20.s,
                          offset: Offset(0, 8.s),
                        ),
                      ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap:
                    _isRequesting
                        ? null
                        : (allGranted
                            ? widget.onPermissionsResolved
                            : _requestAllPermissions),
                borderRadius: BorderRadius.circular(16.s),
                child: Center(
                  child:
                      _isRequesting
                          ? SizedBox(
                            width: 24.s,
                            height: 24.s,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5.s,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(buttonIcon, color: Colors.white, size: 22.s),
                              SizedBox(width: 10.s),
                              Text(
                                buttonText,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
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
        .fadeIn(duration: 600.ms, delay: 1000.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildPrivacyNote() {
    return Text(
      'Permissions are optional. You can change them anytime in Settings.',
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        color: Colors.white.withOpacity(0.35),
      ),
      textAlign: TextAlign.center,
    ).animate().fadeIn(duration: 500.ms, delay: 1100.ms);
  }
}

class _PermissionItem {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final bool isGranted;

  _PermissionItem({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.isGranted,
  });
}
