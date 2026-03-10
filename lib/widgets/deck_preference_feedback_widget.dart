import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

/// Netflix-inspired deck preference feedback card widget
/// Navigates to the full feedback screen when tapped
class DeckPreferenceFeedbackWidget extends StatelessWidget {
  final VoidCallback? onNavigationReturn;
  final String? userCountry;
  final String? appVersion;

  const DeckPreferenceFeedbackWidget({
    super.key,
    this.onNavigationReturn,
    this.userCountry,
    this.appVersion,
  });

  // Accent colors
  static const Color _primaryAccent = Color(0xFF8B5CF6);
  static const Color _secondaryAccent = Color(0xFFA855F7);

  @override
  Widget build(BuildContext context) {
    final hapticService = HapticService();

    return GestureDetector(
      onTap: () async {
        hapticService.lightImpact();
        // Navigate to the feedback screen
        final countryParam = userCountry != null ? '?country=$userCountry' : '';
        await context.push('/deck-feedback$countryParam');
        // Call callback when returning from feedback screen
        onNavigationReturn?.call();
      },
      child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 14.s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1C1C1E),
                  _primaryAccent.withOpacity(0.06),
                ],
              ),
              border: Border.all(
                color: _primaryAccent.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryAccent.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon with gradient background
                Container(
                  width: 48.s,
                  height: 48.s,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primaryAccent.withOpacity(0.2),
                        _secondaryAccent.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _primaryAccent.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: _primaryAccent,
                    size: 24.s,
                  ),
                ),

                SizedBox(width: 14.s),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Help Us Improve',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(width: 8.s),
                          // "New" badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.s,
                              vertical: 3.s,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primaryAccent, _secondaryAccent],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.s),
                      Text(
                        'Tell us what decks you want to see',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow indicator
                Container(
                  padding: EdgeInsets.all(8.s),
                  decoration: BoxDecoration(
                    color: _primaryAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _primaryAccent.withOpacity(0.7),
                    size: 14.s,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(delay: 600.ms, duration: 700.ms)
          .slideY(
            begin: 0.15,
            end: 0,
            delay: 600.ms,
            duration: 700.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
