import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/deck_feedback_service.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

/// Premium deck feedback screen with Netflix-inspired design
/// Collects user preferences about desired deck types
class DeckFeedbackScreen extends StatefulWidget {
  final String? userCountry;

  const DeckFeedbackScreen({
    super.key,
    this.userCountry,
  });

  @override
  State<DeckFeedbackScreen> createState() => _DeckFeedbackScreenState();
}

class _DeckFeedbackScreenState extends State<DeckFeedbackScreen>
    with TickerProviderStateMixin {
  final _feedbackService = DeckFeedbackService();
  final _hapticService = HapticService();

  // UI State
  bool _isSubmitting = false;
  bool _showThankYou = false;
  final Set<String> _selectedCategories = {};
  final TextEditingController _suggestionController = TextEditingController();
  final FocusNode _suggestionFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Feedback count tracking
  int _remainingCount = 0;
  int _maxCount = 5;
  bool _isLoadingCount = true;

  // Accent colors
  static const Color _primaryAccent = Color(0xFF8B5CF6);
  static const Color _secondaryAccent = Color(0xFFA855F7);

  @override
  void initState() {
    super.initState();
    _suggestionFocusNode.addListener(() {
      setState(() {});
    });
    _loadFeedbackCounts();
  }

  Future<void> _loadFeedbackCounts() async {
    try {
      final remaining = await _feedbackService.getRemainingFeedbackCount();
      final max = await _feedbackService.getMaxFeedbackCount();
      if (mounted) {
        setState(() {
          _remainingCount = remaining;
          _maxCount = max;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCount = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _suggestionController.dispose();
    _suggestionFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleCategory(String categoryId) {
    _hapticService.selection();
    setState(() {
      if (_selectedCategories.contains(categoryId)) {
        _selectedCategories.remove(categoryId);
      } else {
        _selectedCategories.add(categoryId);
      }
    });
  }

  Future<void> _submitFeedback() async {
    if (_selectedCategories.isEmpty && _suggestionController.text.isEmpty) {
      _hapticService.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select at least one category or add a suggestion',
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

    setState(() => _isSubmitting = true);
    _hapticService.lightImpact();

    final success = await _feedbackService.submitFeedback(
      selectedCategories: _selectedCategories.toList(),
      deckSuggestion: _suggestionController.text.isNotEmpty
          ? _suggestionController.text
          : null,
      userCountry: widget.userCountry,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (success) {
          _showThankYou = true;
        }
      });

      if (success) {
        _hapticService.success();
        // Wait for thank you animation, then go back
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) {
          context.pop();
        }
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

    if (_showThankYou) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildThankYouScreen(),
      );
    }

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
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.s),
                          _buildHeader(),
                          SizedBox(height: 32.s),
                          _buildCategorySection(),
                          SizedBox(height: 32.s),
                          _buildSuggestionSection(),
                          SizedBox(height: 120.s),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom submit button
          _buildBottomButton(),
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
            Color(0xFF1A0A20),
            Color(0xFF0D0510),
            Color(0xFF000000),
          ],
          stops: [0.0, 0.4, 1.0],
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
      ],
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 12.s),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hapticService.lightImpact();
                context.pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(10.s),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 22.s,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Remaining count badge
          if (!_isLoadingCount && _remainingCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
              decoration: BoxDecoration(
                color: _primaryAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _primaryAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    color: _primaryAccent,
                    size: 14.s,
                  ),
                  SizedBox(width: 6.s),
                  Text(
                    '${_maxCount - _remainingCount + 1} of $_maxCount',
                    style: GoogleFonts.inter(
                      color: _primaryAccent,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 400.ms)
    .slideY(begin: -0.3, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryAccent.withOpacity(0.2),
                _secondaryAccent.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primaryAccent.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: _primaryAccent,
                size: 14.s,
              ),
              SizedBox(width: 6.s),
              Text(
                'HELP US IMPROVE',
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: _primaryAccent,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideY(begin: 0.3, duration: 500.ms, curve: Curves.easeOutCubic),

        SizedBox(height: 16.s),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.white, Colors.white.withOpacity(0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'What decks\nwould you love?',
            style: GoogleFonts.poppins(
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutCubic),

        SizedBox(height: 12.s),

        // Subtitle
        Text(
          'Your feedback shapes the future of our content. Select categories you\'d like to see more of.',
          style: GoogleFonts.inter(
            fontSize: 15.sp,
            color: Colors.white.withOpacity(0.6),
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 300.ms)
        .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutCubic),

        // Selection count
        if (_selectedCategories.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 16.s),
            padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
            decoration: BoxDecoration(
              color: _primaryAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _primaryAccent.withOpacity(0.3),
                width: 1,
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
                  '${_selectedCategories.length} selected',
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

  Widget _buildCategorySection() {
    final categories = DeckFeedbackService.feedbackCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select categories',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 400.ms),

        SizedBox(height: 16.s),

        // Category grid
        Wrap(
          spacing: 10.s,
          runSpacing: 10.s,
          children: categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return _buildCategoryChip(category, index);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(FeedbackCategory category, int index) {
    final isSelected = _selectedCategories.contains(category.id);
    final color = Color(category.colorValue);

    return GestureDetector(
      onTap: () => _toggleCategory(category.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 12.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.25),
                    color.withOpacity(0.12),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8.s),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIconData(category.iconName),
                color: isSelected ? color : Colors.white.withOpacity(0.6),
                size: 18.s,
              ),
            ),
            SizedBox(width: 10.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.displayName,
                  style: GoogleFonts.inter(
                    color: isSelected ? color : Colors.white.withOpacity(0.85),
                    fontSize: 13.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (category.description.isNotEmpty)
                  Text(
                    category.description,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            if (isSelected) ...[
              SizedBox(width: 8.s),
              Container(
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
              ),
            ],
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(
      delay: Duration(milliseconds: 450 + (index * 40)),
      duration: 400.ms,
    )
    .slideY(
      begin: 0.2,
      delay: Duration(milliseconds: 450 + (index * 40)),
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildSuggestionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              color: _primaryAccent,
              size: 20.s,
            ),
            SizedBox(width: 8.s),
            Text(
              'Have a specific idea?',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),

        SizedBox(height: 8.s),

        Text(
          'Tell us exactly what deck you\'d love to play',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
          ),
        ),

        SizedBox(height: 12.s),

        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _suggestionFocusNode.hasFocus
                  ? _primaryAccent.withOpacity(0.5)
                  : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: _suggestionFocusNode.hasFocus
                ? [
                    BoxShadow(
                      color: _primaryAccent.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _suggestionController,
            focusNode: _suggestionFocusNode,
            maxLines: 3,
            maxLength: 200,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15.sp,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., "K-Pop Artists", "Marvel Characters", "90s Cartoons"...',
              hintStyle: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14.sp,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.all(16.s),
              border: InputBorder.none,
              counterStyle: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11.sp,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    )
    .animate()
    .fadeIn(duration: 500.ms, delay: 700.ms)
    .slideY(begin: 0.2, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildBottomButton() {
    final hasSelection = _selectedCategories.isNotEmpty ||
        _suggestionController.text.isNotEmpty;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(24.s, 16.s, 24.s, 34.s),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.9),
              Colors.black,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasSelection && !_isSubmitting ? _submitFeedback : null,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              height: 58.s,
              decoration: BoxDecoration(
                gradient: hasSelection
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primaryAccent, _secondaryAccent],
                      )
                    : null,
                color: hasSelection ? null : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: hasSelection
                    ? null
                    : Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                boxShadow: hasSelection
                    ? [
                        BoxShadow(
                          color: _primaryAccent.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: -8,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _isSubmitting
                    ? SizedBox(
                        width: 24.s,
                        height: 24.s,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hasSelection ? 'Submit Feedback' : 'Select at least one',
                            style: GoogleFonts.inter(
                              color: hasSelection
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
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
          ),
        ),
      )
      .animate()
      .fadeIn(duration: 500.ms, delay: 800.ms)
      .slideY(begin: 0.3, duration: 500.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildThankYouScreen() {
    return Stack(
      children: [
        _buildBackground(),
        _buildBackgroundDecorations(),
        Center(
          child: Padding(
            padding: EdgeInsets.all(32.s),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success icon
                Container(
                  width: 100.s,
                  height: 100.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_primaryAccent, _secondaryAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryAccent.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 48.s,
                  ),
                )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),

                SizedBox(height: 32.s),

                Text(
                  'Thank You!',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.3, delay: 300.ms, duration: 500.ms),

                SizedBox(height: 12.s),

                Text(
                  'Your feedback helps us create\namazing new decks just for you',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(delay: 500.ms, duration: 500.ms)
                .slideY(begin: 0.3, delay: 500.ms, duration: 500.ms),

                SizedBox(height: 40.s),

                // Confetti-like elements
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final colors = [
                      const Color(0xFFFF6B6B),
                      const Color(0xFFFECA57),
                      const Color(0xFF48BB78),
                      _primaryAccent,
                      const Color(0xFF3B82F6),
                    ];
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.s),
                      width: 8.s,
                      height: 8.s,
                      decoration: BoxDecoration(
                        color: colors[index],
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 700 + (index * 100)), duration: 300.ms)
                    .scale(
                      begin: const Offset(0, 0),
                      delay: Duration(milliseconds: 700 + (index * 100)),
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'history':
        return Icons.history_rounded;
      case 'public':
        return Icons.public_rounded;
      case 'celebration':
        return Icons.celebration_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'family_restroom':
        return Icons.family_restroom_rounded;
      case 'sports_basketball':
        return Icons.sports_basketball_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'event':
        return Icons.event_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
