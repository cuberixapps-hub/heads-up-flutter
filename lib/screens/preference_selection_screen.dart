import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import '../services/user_preference_service.dart';
import '../utils/responsive.dart';

/// Premium preference selection screen shown after onboarding
/// Users select their interests to personalize deck recommendations
class PreferenceSelectionScreen extends StatefulWidget {
  final bool isOnboarding;
  
  const PreferenceSelectionScreen({
    super.key,
    this.isOnboarding = true,
  });

  @override
  State<PreferenceSelectionScreen> createState() => _PreferenceSelectionScreenState();
}

class _PreferenceSelectionScreenState extends State<PreferenceSelectionScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _preferenceService = UserPreferenceService();
  
  // Selected interest IDs
  final Set<String> _selectedInterests = {};
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _floatingController;

  // Accent colors for the screen
  static const Color _primaryAccent = Color(0xFF7C3AED);
  static const Color _secondaryAccent = Color(0xFFA855F7);

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);
    
    // Load existing preferences when editing from settings
    _loadExistingPreferences();
  }

  Future<void> _loadExistingPreferences() async {
    final existingPrefs = await _preferenceService.getPreferences();
    if (existingPrefs.isNotEmpty && mounted) {
      setState(() {
        _selectedInterests.addAll(existingPrefs);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  void _toggleInterest(String interestId) {
    _hapticService.selection();
    setState(() {
      if (_selectedInterests.contains(interestId)) {
        _selectedInterests.remove(interestId);
      } else {
        _selectedInterests.add(interestId);
      }
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedInterests.isEmpty) {
      _hapticService.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select at least one interest to personalize your experience',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    _hapticService.success();
    
    // Save preferences
    await _preferenceService.savePreferencesAndUpdateCache(_selectedInterests.toList());
    
    // Notify DeckProvider to refresh with new preferences
    // This ensures home screen will show personalized content
    if (mounted) {
      final deckProvider = Provider.of<DeckProvider>(context, listen: false);
      await deckProvider.refreshUserPreferences();
    }
    
    if (mounted) {
      _navigateNext();
    }
  }

  Future<void> _skipPreferences() async {
    _hapticService.lightImpact();
    
    // Save empty preferences to mark as completed
    await _preferenceService.savePreferencesAndUpdateCache([]);
    
    // Notify DeckProvider (even though empty, this marks preferences as set)
    if (mounted) {
      final deckProvider = Provider.of<DeckProvider>(context, listen: false);
      await deckProvider.refreshUserPreferences();
    }
    
    if (mounted) {
      _navigateNext();
    }
  }

  void _navigateNext() {
    if (widget.isOnboarding) {
      // During onboarding, go to notification permission
      context.go('/notification-permission');
    } else {
      // From settings, go back
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated gradient background
          _buildBackground(),

          // Background decorations
          _buildBackgroundDecorations(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 16.s),
                          _buildHeader(),
                          SizedBox(height: 32.s),
                          _buildInterestGrid(),
                          SizedBox(height: 32.s),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A0A20),
            Color(0xFF0D0510),
            Color(0xFF000000),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        // Ambient glow - top
        Positioned(
          top: -150.s,
          left: -100.s,
          child: Container(
            width: 400.s,
            height: 400.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _primaryAccent.withOpacity(0.15),
                  _primaryAccent.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Ambient glow - bottom right
        Positioned(
          bottom: -100.s,
          right: -100.s,
          child: Container(
            width: 350.s,
            height: 350.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _secondaryAccent.withOpacity(0.1),
                  _secondaryAccent.withOpacity(0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Subtle vignette
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.s, vertical: 16.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Progress indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 10.s),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24.s),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.s,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: _primaryAccent,
                  size: 18.s,
                ),
                SizedBox(width: 8.s),
                Text(
                  'Personalize',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: -0.5, duration: 700.ms, curve: Curves.easeOutCubic),

          // Skip button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _skipPreferences,
              borderRadius: BorderRadius.circular(24.s),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 10.s),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24.s),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.s,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4.s),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.4),
                      size: 12.s,
                    ),
                  ],
                ),
              ),
            ),
          )
          .animate()
          .fadeIn(delay: 300.ms, duration: 600.ms)
          .slideY(begin: -0.5, duration: 700.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Subtitle badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 10.s),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryAccent.withOpacity(0.2),
                _secondaryAccent.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(30.s),
            border: Border.all(
              color: _primaryAccent.withOpacity(0.3),
              width: 1.5.s,
            ),
          ),
          child: Text(
            'WHAT DO YOU LOVE?',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: _primaryAccent,
              letterSpacing: 2,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.3, duration: 500.ms, curve: Curves.easeOutCubic),

        SizedBox(height: 20.s),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.white, Colors.white.withOpacity(0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'Pick Your\nInterests',
            style: GoogleFonts.poppins(
              fontSize: 38.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.05,
              letterSpacing: -1.5,
            ),
            textAlign: TextAlign.center,
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 300.ms)
        .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutCubic),

        SizedBox(height: 16.s),

        // Description
        Container(
          constraints: BoxConstraints(maxWidth: 320.s),
          child: Text(
            'Select topics you enjoy to get personalized deck recommendations',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              color: Colors.white.withOpacity(0.7),
              height: 1.6,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 400.ms)
        .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutCubic),

        // Selection count badge
        if (_selectedInterests.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 20.s),
            padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 8.s),
            decoration: BoxDecoration(
              color: _primaryAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20.s),
              border: Border.all(
                color: _primaryAccent.withOpacity(0.3),
                width: 1.s,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: _primaryAccent,
                  size: 16.s,
                ),
                SizedBox(width: 8.s),
                Text(
                  '${_selectedInterests.length} selected',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _primaryAccent,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.8, 0.8), duration: 300.ms, curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildInterestGrid() {
    final interests = UserPreferenceService.availableInterests;
    
    return Wrap(
      spacing: 12.s,
      runSpacing: 12.s,
      alignment: WrapAlignment.center,
      children: interests.asMap().entries.map((entry) {
        final index = entry.key;
        final interest = entry.value;
        return _buildInterestCard(interest, index);
      }).toList(),
    );
  }

  Widget _buildInterestCard(InterestCategory interest, int index) {
    final isSelected = _selectedInterests.contains(interest.id);
    final color = Color(interest.colorValue);
    
    return GestureDetector(
      onTap: () => _toggleInterest(interest.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 105.s,
        height: 110.s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.s),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.15),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.6) : Colors.white.withOpacity(0.1),
            width: isSelected ? 2.s : 1.s,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20.s,
                    spreadRadius: -5.s,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.all(12.s),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? color.withOpacity(0.2) 
                          : Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconData(interest.iconName),
                      color: isSelected ? color : Colors.white.withOpacity(0.7),
                      size: 26.s,
                    ),
                  ),
                  SizedBox(height: 8.s),
                  // Label
                  Text(
                    interest.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? color : Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Check mark for selected
            if (isSelected)
              Positioned(
                top: 8.s,
                right: 8.s,
                child: Container(
                  padding: EdgeInsets.all(4.s),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 12.s,
                  ),
                )
                .animate()
                .scale(begin: const Offset(0, 0), duration: 200.ms, curve: Curves.easeOutBack),
              ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(
      duration: 400.ms,
      delay: Duration(milliseconds: 100 + (index * 50)),
    )
    .slideY(
      begin: 0.3,
      duration: 400.ms,
      delay: Duration(milliseconds: 100 + (index * 50)),
      curve: Curves.easeOutCubic,
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'movie_rounded':
        return Icons.movie_rounded;
      case 'music_note_rounded':
        return Icons.music_note_rounded;
      case 'sports_basketball_rounded':
        return Icons.sports_basketball_rounded;
      case 'celebration_rounded':
        return Icons.celebration_rounded;
      case 'psychology_rounded':
        return Icons.psychology_rounded;
      case 'star_rounded':
        return Icons.star_rounded;
      case 'sports_esports_rounded':
        return Icons.sports_esports_rounded;
      case 'restaurant_rounded':
        return Icons.restaurant_rounded;
      case 'pets_rounded':
        return Icons.pets_rounded;
      case 'science_rounded':
        return Icons.science_rounded;
      case 'history_edu_rounded':
        return Icons.history_edu_rounded;
      case 'family_restroom_rounded':
        return Icons.family_restroom_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildBottomButtons() {
    final hasSelection = _selectedInterests.isNotEmpty;
    
    return Container(
      padding: EdgeInsets.fromLTRB(24.s, 16.s, 24.s, 32.s),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
            Colors.black,
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveAndContinue,
          borderRadius: BorderRadius.circular(22.s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 62.s,
            decoration: BoxDecoration(
              gradient: hasSelection
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryAccent, _secondaryAccent],
                    )
                  : null,
              color: hasSelection ? null : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22.s),
              border: hasSelection
                  ? null
                  : Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.s,
                    ),
              boxShadow: hasSelection
                  ? [
                      BoxShadow(
                        color: _primaryAccent.withOpacity(0.4),
                        blurRadius: 24.s,
                        offset: Offset(0, 8.s),
                        spreadRadius: -4.s,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hasSelection ? 'Continue' : 'Select at least one',
                  style: GoogleFonts.inter(
                    color: hasSelection 
                        ? Colors.white 
                        : Colors.white.withOpacity(0.5),
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                if (hasSelection) ...[
                  SizedBox(width: 10.s),
                  Container(
                    padding: EdgeInsets.all(6.s),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16.s,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      )
      .animate()
      .fadeIn(duration: 500.ms, delay: 600.ms)
      .slideY(begin: 0.3, duration: 500.ms, curve: Curves.easeOutCubic),
    );
  }
}
