import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';

/// Premium notification permission screen
class NotificationPermissionScreen extends StatefulWidget {
  final bool isOnboarding;

  const NotificationPermissionScreen({
    super.key,
    this.isOnboarding = true,
  });

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> with SingleTickerProviderStateMixin {
  final _hapticService = HapticService();
  bool _isRequesting = false;
  late AnimationController _glowController;

  // Premium color palette
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _accentPurple = Color(0xFF7C3AED);
  static const Color _accentCyan = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);
    _hapticService.mediumImpact();

    try {
      final notificationService = NotificationService();
      final granted = await notificationService.requestPermission(context: context);

      if (mounted) {
        if (granted) {
          _hapticService.success();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)?.notificationsEnabled ??
                        'Notifications enabled!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.s),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _navigateNext();
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      if (mounted) {
        _navigateNext();
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _skipNotifications() async {
    _hapticService.lightImpact();
    _navigateNext();
  }

  void _navigateNext() async {
    if (widget.isOnboarding) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_asked_notification_permission', true);
      
      if (mounted) {
        context.go('/home');
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Elegant gradient background
          _buildBackground(),
          
          // Ambient glow
          _buildAmbientGlow(),
          
          // Main content
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
                            
                            // Skip button
                            _buildSkipButton(l10n),
                            
                            SizedBox(height: 24.s),
                            
                            // Bell illustration
                            _buildBellIllustration(),
                            
                            SizedBox(height: 32.s),
                            
                            // Title
                            _buildTitle(l10n),
                            
                            SizedBox(height: 10.s),
                            
                            // Subtitle
                            _buildSubtitle(l10n),
                            
                            SizedBox(height: 28.s),
                            
                            // Benefits list
                            _buildBenefitsList(l10n),
                            
                            const Spacer(),
                            
                            SizedBox(height: 24.s),
                            
                            // Enable button
                            _buildEnableButton(l10n),
                            
                            SizedBox(height: 12.s),
                            
                            // Privacy note
                            _buildPrivacyNote(l10n),
                            
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
          colors: [
            Color(0xFF12141C),
            Color(0xFF0A0A0F),
            Color(0xFF050507),
          ],
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
            // Top glow
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
                        _primaryBlue.withOpacity(glowOpacity),
                        _accentPurple.withOpacity(glowOpacity * 0.5),
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

  Widget _buildSkipButton(AppLocalizations? l10n) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _skipNotifications,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 8.s),
        ),
        child: Text(
          l10n?.maybeLater ?? 'Maybe Later',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms);
  }

  Widget _buildBellIllustration() {
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
                    color: _primaryBlue.withOpacity(0.15),
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
                      _primaryBlue.withOpacity(0.2),
                      _accentPurple.withOpacity(0.15),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryBlue.withOpacity(glowIntensity * 0.4),
                      blurRadius: 50.s,
                      spreadRadius: 10.s,
                    ),
                  ],
                ),
              ),
              
              // Bell icon
              Icon(
                Icons.notifications_rounded,
                size: 48.s,
                color: Colors.white,
              ),
              
              // Notification badge
              Positioned(
                top: 28.s,
                right: 28.s,
                child: Container(
                  width: 26.s,
                  height: 26.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEF4444),
                        Color(0xFFDC2626),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.5),
                        blurRadius: 12.s,
                        spreadRadius: 2.s,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '3',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).animate()
        .fadeIn(duration: 800.ms, delay: 300.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildTitle(AppLocalizations? l10n) {
    return Text(
      l10n?.stayInTheLoop ?? 'Stay in the Loop',
      style: GoogleFonts.poppins(
        fontSize: 32.sp,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -1,
      ),
      textAlign: TextAlign.center,
    ).animate()
        .fadeIn(duration: 600.ms, delay: 500.ms)
        .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildSubtitle(AppLocalizations? l10n) {
    return Text(
      l10n?.notificationPermissionSubtitle ?? 'Get notified about new content and challenges',
      style: GoogleFonts.inter(
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
        color: Colors.white.withOpacity(0.6),
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    ).animate()
        .fadeIn(duration: 600.ms, delay: 600.ms);
  }

  Widget _buildBenefitsList(AppLocalizations? l10n) {
    final benefits = [
      _BenefitItem(
        icon: Icons.local_fire_department_rounded,
        gradient: const [Color(0xFFFF6B35), Color(0xFFFF4500)],
        title: l10n?.streakRemindersBenefit ?? 'Streak Reminders',
        subtitle: l10n?.streakRemindersBenefitDesc ?? "Keep your winning streak alive",
      ),
      _BenefitItem(
        icon: Icons.auto_awesome_rounded,
        gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        title: l10n?.newDecksBenefit ?? 'New Content',
        subtitle: l10n?.newDecksBenefitDesc ?? 'Be first to discover new decks',
      ),
      _BenefitItem(
        icon: Icons.emoji_events_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
        title: l10n?.challengesBenefit ?? 'Daily Challenges',
        subtitle: l10n?.challengesBenefitDesc ?? 'Never miss a fun challenge',
      ),
    ];

    return Column(
      children: benefits.asMap().entries.map((entry) {
        final index = entry.key;
        final benefit = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: 12.s),
          child: _buildBenefitCard(benefit)
              .animate()
              .fadeIn(duration: 500.ms, delay: Duration(milliseconds: 700 + (index * 100)))
              .slideX(begin: -0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitCard(_BenefitItem benefit) {
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
              color: Colors.white.withOpacity(0.08),
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
                    colors: benefit.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: benefit.gradient[0].withOpacity(0.3),
                      blurRadius: 12.s,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  benefit.icon,
                  color: Colors.white,
                  size: 22.s,
                ),
              ),
              SizedBox(width: 14.s),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.s),
                    Text(
                      benefit.subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
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

  Widget _buildEnableButton(AppLocalizations? l10n) {
    return GestureDetector(
      onTap: _isRequesting ? null : _requestPermission,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56.s,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isRequesting
                ? [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ]
                : [
                    _primaryBlue,
                    _accentCyan,
                  ],
          ),
          borderRadius: BorderRadius.circular(16.s),
          boxShadow: _isRequesting
              ? []
              : [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.4),
                    blurRadius: 20.s,
                    offset: Offset(0, 8.s),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isRequesting ? null : _requestPermission,
            borderRadius: BorderRadius.circular(16.s),
            child: Center(
              child: _isRequesting
                  ? SizedBox(
                      width: 24.s,
                      height: 24.s,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5.s,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 22.s,
                        ),
                        SizedBox(width: 10.s),
                        Text(
                          l10n?.enableNotifications ?? 'Enable Notifications',
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
    ).animate()
        .fadeIn(duration: 600.ms, delay: 1000.ms)
        .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildPrivacyNote(AppLocalizations? l10n) {
    return Text(
      l10n?.notificationPrivacyNote ?? 'You can change this anytime in Settings',
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        color: Colors.white.withOpacity(0.35),
      ),
      textAlign: TextAlign.center,
    ).animate()
        .fadeIn(duration: 500.ms, delay: 1100.ms);
  }
}

class _BenefitItem {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;

  _BenefitItem({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
  });
}
