import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/version_service.dart';
import '../utils/responsive.dart';

/// Full-screen blocking UI for force update
class ForceUpdateScreen extends StatelessWidget {
  final VersionInfo versionInfo;

  const ForceUpdateScreen({
    super.key,
    required this.versionInfo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f0f23),
                ],
              ),
            ),
          ),

          // Animated background particles
          ...List.generate(20, (index) {
            return Positioned(
              left: (index * 47.0) % MediaQuery.of(context).size.width,
              top: (index * 73.0) % MediaQuery.of(context).size.height,
              child: Container(
                width: 4 + (index % 3) * 2.0,
                height: 4 + (index % 3) * 2.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1 + (index % 5) * 0.02),
                ),
              )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.5, 1.5),
                    duration: Duration(milliseconds: 2000 + index * 200),
                    curve: Curves.easeInOut,
                  )
                  .fadeIn(
                    duration: Duration(milliseconds: 1000 + index * 100),
                  ),
            );
          }),

          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.s),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Update icon with glow
                  Container(
                        width: 120.s,
                        height: 120.s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF667eea).withOpacity(0.2),
                              const Color(0xFF764ba2).withOpacity(0.2),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF667eea).withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF667eea).withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.system_update_rounded,
                          size: 56.s,
                          color: Colors.white,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                      )
                      .then()
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                        duration: 2000.ms,
                        curve: Curves.easeInOut,
                      ),

                  SizedBox(height: 40.s),

                  // Title
                  Text(
                        l10n?.updateRequired ?? 'Update Required',
                        style: GoogleFonts.poppins(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms),

                  SizedBox(height: 16.s),

                  // Description
                  Text(
                        versionInfo.updateMessage.isNotEmpty
                            ? versionInfo.updateMessage
                            : (l10n?.updateRequiredDescription ??
                                'Please update to the latest version to continue using the app.'),
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms),

                  SizedBox(height: 24.s),

                  // Version info card
                  Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.s,
                          vertical: 16.s,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildVersionBadge(
                              label: l10n?.currentVersion ?? 'Current',
                              version: versionInfo.currentVersion,
                              color: Colors.red.shade400,
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.s),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white.withOpacity(0.5),
                                size: 24,
                              ),
                            ),
                            _buildVersionBadge(
                              label: l10n?.requiredVersion ?? 'Required',
                              version: versionInfo.minRequiredVersion,
                              color: Colors.green.shade400,
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms),

                  const Spacer(flex: 2),

                  // Update button
                  SizedBox(
                        width: double.infinity,
                        height: 56.s,
                        child: ElevatedButton(
                          onPressed: () => VersionService().openStore(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF667eea),
                                  Color(0xFF764ba2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF667eea).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.download_rounded,
                                    color: Colors.white,
                                    size: 22.s,
                                  ),
                                  SizedBox(width: 10.s),
                                  Text(
                                    l10n?.updateNow ?? 'Update Now',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms)
                      .then()
                      .shimmer(
                        delay: 1500.ms,
                        duration: 2000.ms,
                        color: Colors.white.withOpacity(0.2),
                      ),

                  SizedBox(height: 40.s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionBadge({
    required String label,
    required String version,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        SizedBox(height: 4.s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Text(
            'v$version',
            style: GoogleFonts.robotoMono(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft update dialog - dismissible bottom sheet
class SoftUpdateDialog extends StatelessWidget {
  final VersionInfo versionInfo;
  final VoidCallback? onLater;

  const SoftUpdateDialog({
    super.key,
    required this.versionInfo,
    this.onLater,
  });

  /// Show the soft update dialog as a bottom sheet
  static Future<void> show(BuildContext context, VersionInfo versionInfo) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) => SoftUpdateDialog(
        versionInfo: versionInfo,
        onLater: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      margin: EdgeInsets.all(16.s),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: EdgeInsets.all(24.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40.s,
                  height: 4.s,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                SizedBox(height: 24.s),

                // Icon with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72.s,
                      height: 72.s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF00C853).withOpacity(0.2),
                            const Color(0xFF00E676).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF00C853).withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        size: 36.s,
                        color: const Color(0xFF00E676),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.s,
                          vertical: 4.s,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n?.newBadge ?? 'NEW',
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),

                SizedBox(height: 20.s),

                // Title
                Text(
                  l10n?.updateAvailable ?? 'Update Available',
                  style: GoogleFonts.poppins(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                SizedBox(height: 8.s),

                // Version badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00C853).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'v${versionInfo.latestVersion}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                SizedBox(height: 16.s),

                // Description
                Text(
                  versionInfo.updateMessage.isNotEmpty
                      ? versionInfo.updateMessage
                      : (l10n?.updateAvailableDescription ??
                          'A new version is available with exciting features and improvements!'),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                SizedBox(height: 28.s),

                // Buttons
                Row(
                  children: [
                    // Later button
                    Expanded(
                      child: TextButton(
                        onPressed: onLater,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.s),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n?.later ?? 'Later',
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 12.s),

                    // Update button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => VersionService().openStore(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.s),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, size: 20.s),
                            SizedBox(width: 8.s),
                            Text(
                              l10n?.updateNow ?? 'Update Now',
                              style: GoogleFonts.inter(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                SizedBox(height: 8.s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

