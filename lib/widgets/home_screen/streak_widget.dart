import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../services/haptic_service.dart';
import '../../services/streak_service.dart' show StreakMilestone;

class StreakWidget extends StatefulWidget {
  final int currentStreak;
  final bool hasPlayedToday;
  final List<bool> weeklyProgress;
  final StreakMilestone? nextMilestone;
  final VoidCallback onPlayToday;
  final HapticService hapticService;

  const StreakWidget({
    super.key,
    required this.currentStreak,
    required this.hasPlayedToday,
    required this.weeklyProgress,
    required this.nextMilestone,
    required this.onPlayToday,
    required this.hapticService,
  });

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget> {
  bool _showExpandedStreak = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                widget.hapticService.lightImpact();
                setState(() {
                  _showExpandedStreak = !_showExpandedStreak;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1C1C1E),
                      const Color(0xFF2C2C2E).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        widget.currentStreak > 0
                            ? const Color(0xFFFFD700).withOpacity(0.3)
                            : Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          widget.currentStreak > 0
                              ? const Color(0xFFFFD700).withOpacity(0.15)
                              : Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Main streak info row
                    Row(
                      children: [
                        // Animated flame icon with premium effects
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            if (widget.currentStreak > 0)
                              Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          _getFlameColors()[0].withOpacity(0.4),
                                          _getFlameColors()[0].withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  )
                                  .animate(
                                    onPlay: (controller) => controller.repeat(),
                                  )
                                  .scale(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1.1, 1.1),
                                    duration: 2000.ms,
                                    curve: Curves.easeInOut,
                                  )
                                  .fadeIn(begin: 0.0, duration: 1000.ms)
                                  .then()
                                  .fadeOut(duration: 1000.ms),

                            // Main flame container
                            Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _getFlameColors(),
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getFlameColors()[0].withOpacity(
                                          0.5,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: _getFlameColors()[1].withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.local_fire_department_rounded,
                                    color: Colors.white,
                                    size: widget.currentStreak > 7 ? 32 : 28,
                                  ),
                                )
                                .animate(
                                  onPlay:
                                      (controller) =>
                                          controller.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(1, 1),
                                  end: Offset(
                                    1.08 +
                                        (widget.currentStreak * 0.01).clamp(0, 0.15),
                                    1.08 +
                                        (widget.currentStreak * 0.01).clamp(0, 0.15),
                                  ),
                                  duration: 1800.ms,
                                  curve: Curves.easeInOut,
                                )
                                .then()
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        // Streak info with premium text effects
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ShaderMask(
                                        shaderCallback:
                                            (bounds) => LinearGradient(
                                              colors:
                                                  widget.currentStreak > 0
                                                      ? [
                                                        Colors.white,
                                                        const Color(0xFFFFD700),
                                                        Colors.white,
                                                      ]
                                                      : [
                                                        Colors.white,
                                                        Colors.white,
                                                      ],
                                              stops: widget.currentStreak > 0
                                                  ? const [0.0, 0.5, 1.0]
                                                  : const [0.0, 1.0],
                                            ).createShader(bounds),
                                        child: Text(
                                          '${widget.currentStreak}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: 1,
                                          ),
                                        ),
                                      )
                                      .animate(
                                        onPlay:
                                            (controller) => controller.repeat(),
                                      )
                                      .shimmer(
                                        duration: 3000.ms,
                                        color: const Color(
                                          0xFFFFD700,
                                        ).withOpacity(0.5),
                                      ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.day,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.5),
                                          letterSpacing: 0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      Text(
                                        AppLocalizations.of(context)!.streak,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.5),
                                          letterSpacing: 0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getStreakMessage(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Expand/collapse indicator
                        Icon(
                          _showExpandedStreak
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 24,
                        ),
                      ],
                    ),

                    // Weekly progress (shown when expanded)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      child:
                          _showExpandedStreak
                              ? Column(
                                children: [
                                  const SizedBox(height: 20),
                                  // Weekly progress
                                  _buildWeeklyProgress(),

                                  // Next milestone
                                  if (widget.nextMilestone != null) ...[
                                    const SizedBox(height: 20),
                                    _buildNextMilestone(),
                                  ],

                                  // Play button if not played today
                                  if (!widget.hasPlayedToday &&
                                      widget.currentStreak > 0) ...[
                                    const SizedBox(height: 16),
                                    _buildPlayTodayButton(),
                                  ],
                                ],
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 600.ms, duration: 800.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          delay: 600.ms,
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        )
        .then()
        .shimmer(
          delay: 1400.ms,
          duration: 1500.ms,
          color:
              widget.currentStreak > 0
                  ? const Color(0xFFFFD700).withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
        );
  }

  List<Color> _getFlameColors() {
    if (widget.currentStreak == 0) {
      return [Colors.grey.shade600, Colors.grey.shade700];
    } else if (widget.currentStreak < 3) {
      return [const Color(0xFFFFC107), const Color(0xFFFF9800)];
    } else if (widget.currentStreak < 7) {
      return [const Color(0xFFFF9800), const Color(0xFFFF5722)];
    } else if (widget.currentStreak < 14) {
      return [const Color(0xFFFF5722), const Color(0xFFE91E63)];
    } else {
      return [const Color(0xFFE91E63), const Color(0xFF9C27B0)];
    }
  }

  String _getStreakMessage() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.currentStreak == 0) {
      return l10n.startYourStreakToday;
    } else if (!widget.hasPlayedToday) {
      return 'Play today to keep your streak!';
    } else if (widget.currentStreak < 3) {
      return 'Great start! Keep it going!';
    } else if (widget.currentStreak < 7) {
      return 'You\'re on fire! 🔥';
    } else if (widget.currentStreak < 14) {
      return 'Amazing dedication! 💪';
    } else {
      return 'Unstoppable player! 🏆';
    }
  }

  String _getLocalizedMilestoneName(String milestoneName) {
    final l10n = AppLocalizations.of(context)!;
    switch (milestoneName) {
      case 'Getting Started':
        return l10n.gettingStarted;
      case 'Week Warrior':
        return l10n.weekWarrior;
      case 'Consistent Player':
        return l10n.consistentPlayer;
      case 'Monthly Master':
        return l10n.monthlyMaster;
      case 'Dedicated Gamer':
        return l10n.dedicatedGamer;
      case 'Century Club':
        return l10n.centuryClub;
      default:
        return milestoneName;
    }
  }

  Widget _buildWeeklyProgress() {
    final l10n = AppLocalizations.of(context)!;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    // DateTime.weekday returns 1 for Monday, 7 for Sunday
    // We want to display Monday first, so we adjust
    var today = DateTime.now().weekday - 1; // 0-6 where 0 is Monday
    if (today == -1) today = 6; // Sunday

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.thisWeek,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final played =
                index < widget.weeklyProgress.length && widget.weeklyProgress[index];
            final isToday = index == today;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ring for current day
                if (isToday && played)
                  Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.1, 1.1),
                        duration: 2000.ms,
                        curve: Curves.easeInOut,
                      )
                      .fadeIn(begin: 0.0, duration: 1000.ms)
                      .then()
                      .fadeOut(duration: 1000.ms),

                // Main circle
                Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            played
                                ? const Color(0xFFFFD700).withOpacity(0.9)
                                : Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isToday
                                  ? const Color(0xFFFFD700).withOpacity(0.6)
                                  : played
                                  ? const Color(0xFFFFD700).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.08),
                          width: isToday ? 2.5 : 1,
                        ),
                        boxShadow:
                            played
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Center(
                        child:
                            played
                                ? Icon(
                                  Icons.check_rounded,
                                  color: Colors.black,
                                  size: 20,
                                ).animate().scale(
                                  begin: const Offset(0, 0),
                                  end: const Offset(1, 1),
                                  duration: 300.ms,
                                  curve: Curves.elasticOut,
                                  delay: (100 * index).ms,
                                )
                                : Text(
                                  days[index],
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isToday
                                            ? const Color(
                                              0xFFFFD700,
                                            ).withOpacity(0.9)
                                            : Colors.white.withOpacity(0.4),
                                  ),
                                ),
                      ),
                    )
                    .animate(delay: (80 * index).ms)
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNextMilestone() {
    final l10n = AppLocalizations.of(context)!;
    final progress = widget.currentStreak / widget.nextMilestone!.days;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.nextMilestone!.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.next}: ${_getLocalizedMilestoneName(widget.nextMilestone!.name)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.daysToGo(widget.nextMilestone!.days - widget.currentStreak),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar with premium animations
          Stack(
            children: [
              // Background track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Animated progress fill
              AnimatedContainer(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    height: 8,
                    width: (MediaQuery.of(context).size.width - 104) * progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700),
                          const Color(0xFFFFC107),
                          const Color(0xFFFFD700),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    duration: 2000.ms,
                    color: Colors.white.withOpacity(0.4),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayTodayButton() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.9),
            const Color(0xFFFFC107).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.hapticService.mediumImpact();
            widget.onPlayToday();
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              'Play to Keep Streak! 🔥',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
