import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';
import '../widgets/icon_picker_dialog.dart';
import '../widgets/color_picker_dialog.dart';

// ===========================================================================
// CustomDeckScreen – Premium Step Wizard
// ===========================================================================
class CustomDeckScreen extends StatefulWidget {
  final Deck? existingDeck;
  const CustomDeckScreen({super.key, this.existingDeck});

  @override
  State<CustomDeckScreen> createState() => _CustomDeckScreenState();
}

class _CustomDeckScreenState extends State<CustomDeckScreen>
    with TickerProviderStateMixin {
  final _haptic = HapticService();
  final _pageController = PageController();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _cardController = TextEditingController();
  final _cardFocus = FocusNode();

  List<String> _cards = [];
  IconData _selectedIcon = FontAwesomeIcons.solidStar;
  Color _selectedColor = Colors.purple;
  bool _isLoading = false;
  bool _hasChanges = false;
  int _step = 0;
  int? _editingCardIdx;

  static const _totalSteps = 3;
  static const _minCards = 5;
  static const _bg = Color(0xFF0A0A0A);

  bool get _isEditing => widget.existingDeck != null;
  bool get _step0Valid => _nameController.text.trim().isNotEmpty;
  bool get _canCreate => _cards.length >= _minCards && !_isLoading;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.existingDeck!.name;
      _descController.text = widget.existingDeck!.description;
      _cards = List.from(widget.existingDeck!.cards);
      _selectedIcon = widget.existingDeck!.icon;
      _selectedColor = widget.existingDeck!.color;
    }
    _nameController.addListener(_onChange);
    _descController.addListener(_onChange);
  }

  void _onChange() => setState(() => _hasChanges = true);

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _cardController.dispose();
    _cardFocus.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Navigation
  // -----------------------------------------------------------------------

  void _goNext() {
    if (_step == 0 && !_step0Valid) return;
    if (_step < _totalSteps - 1) {
      FocusScope.of(context).unfocus();
      _haptic.mediumImpact();
      _pageController.animateToPage(
        _step + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _step++);
    } else {
      _saveDeck();
    }
  }

  void _goBack() {
    if (_step > 0) {
      FocusScope.of(context).unfocus();
      _haptic.lightImpact();
      _pageController.animateToPage(
        _step - 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _step--);
    } else {
      _tryExit();
    }
  }

  Future<void> _tryExit() async {
    if (!_hasChanges) {
      Navigator.maybePop(context);
      return;
    }
    final leave = await _showDiscardDialog();
    if (leave && mounted) Navigator.pop(context);
  }

  // -----------------------------------------------------------------------
  // Save
  // -----------------------------------------------------------------------

  Future<void> _saveDeck() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      _snack(l10n.pleaseEnterDeckName, error: true);
      return;
    }
    if (_cards.length < _minCards) {
      _snack(l10n.deckNeedsCards(_minCards), error: true);
      return;
    }

    setState(() => _isLoading = true);
    _haptic.mediumImpact();

    final provider = context.read<DeckProvider>();
    final ok = _isEditing
        ? await provider.updateCustomDeck(
            deckId: widget.existingDeck!.id,
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            cards: _cards,
            icon: _selectedIcon,
            color: _selectedColor,
          )
        : await provider.createCustomDeck(
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            cards: _cards,
            icon: _selectedIcon,
            color: _selectedColor,
          );

    setState(() => _isLoading = false);

    if (ok) {
      _haptic.success();
      _snack(_isEditing ? l10n.deckUpdatedSuccessfully : l10n.customDeckCreatedSuccessfully);
      Navigator.pop(context, true);
    } else {
      _haptic.error();
      _snack(l10n.failedToSaveDeck, error: true);
    }
  }

  // -----------------------------------------------------------------------
  // Card Actions
  // -----------------------------------------------------------------------

  void _addCard() {
    final text = _cardController.text.trim();
    if (text.isEmpty) return;
    if (_cards.any((c) => c.toLowerCase() == text.toLowerCase())) {
      _snack(AppLocalizations.of(context)!.duplicateCard, error: true);
      return;
    }
    setState(() {
      _cards.add(text);
      _cardController.clear();
      _hasChanges = true;
    });
    _haptic.lightImpact();
    _cardFocus.requestFocus();
  }

  void _updateCard(int i, String val) {
    final t = val.trim();
    if (t.isEmpty || t == _cards[i]) {
      setState(() => _editingCardIdx = null);
      return;
    }
    setState(() {
      _cards[i] = t;
      _editingCardIdx = null;
      _hasChanges = true;
    });
  }

  void _removeCard(int i) {
    setState(() {
      _cards.removeAt(i);
      _hasChanges = true;
      if (_editingCardIdx == i) _editingCardIdx = null;
    });
    _haptic.lightImpact();
  }

  void _onReorder(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final c = _cards.removeAt(oldIdx);
      _cards.insert(newIdx, c);
      _hasChanges = true;
    });
    _haptic.lightImpact();
  }

  void _showBulkAdd() {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BulkAddSheet(
        controller: ctrl,
        l10n: l10n,
        color: _selectedColor,
        onAdd: (lines) {
          final added = <String>[];
          for (final l in lines) {
            final t = l.trim();
            if (t.isNotEmpty && !_cards.any((c) => c.toLowerCase() == t.toLowerCase())) {
              added.add(t);
            }
          }
          if (added.isNotEmpty) {
            setState(() {
              _cards.addAll(added);
              _hasChanges = true;
            });
            _haptic.mediumImpact();
            _snack(l10n.cardsAdded(added.length));
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _pickIcon() async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (_) => IconPickerDialog(selectedIcon: _selectedIcon),
    );
    if (icon != null) setState(() { _selectedIcon = icon; _hasChanges = true; });
  }

  void _pickColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(selectedColor: _selectedColor),
    );
    if (color != null) setState(() { _selectedColor = color; _hasChanges = true; });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step > 0) {
          _goBack();
        } else {
          final leave = await _showDiscardDialog();
          if (leave && mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Radial gradient background glow (matching deck_details)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.55,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.0,
                    colors: [
                      _selectedColor.withOpacity(0.25),
                      _selectedColor.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildNameStep(),
                        _buildStyleStep(),
                        _buildCardsStep(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Floating bottom bar with blur
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // App bar (matching deck_details circular buttons)
  // -----------------------------------------------------------------------

  Widget _buildAppBar() {
    final l10n = AppLocalizations.of(context)!;
    final progress = (_step + 1) / _totalSteps;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 16.h),
      child: Column(
        children: [
          Row(
            children: [
              // Circular back button (matching deck_details)
              GestureDetector(
                    onTap: () {
                      _haptic.lightImpact();
                      _goBack();
                    },
                    child: Container(
                      width: 40.s,
                      height: 40.s,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20.s,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),

              const Spacer(),

              // Step counter pill
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_step),
                  padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20.s),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    l10n.stepOf(_step + 1, _totalSteps),
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.s),

          // Progress bar
          Container(
            height: 3.s,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(2.s),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AnimatedBar(
                widthFactor: progress,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_selectedColor, _selectedColor.withOpacity(0.5)],
                    ),
                    borderRadius: BorderRadius.circular(2.s),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Step 1: Name
  // -----------------------------------------------------------------------

  Widget _buildNameStep() {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 30.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 32.h),

          Text(
            _isEditing ? l10n.editDeck : l10n.nameYourDeck,
            style: GoogleFonts.poppins(
              fontSize: 34.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.15, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),

          SizedBox(height: 10.h),

          Text(
            l10n.giveItAName,
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 500.ms),

          SizedBox(height: 44.h),

          // Name field
          _buildLabel(l10n.deckName),
          SizedBox(height: 12.s),
          _buildInputField(
            controller: _nameController,
            hint: l10n.enterUniqueName,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            textCapitalization: TextCapitalization.words,
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 500.ms, curve: Curves.easeOutCubic),

          SizedBox(height: 28.h),

          // Description
          Row(
            children: [
              _buildLabel(l10n.description),
              SizedBox(width: 8.s),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 2.s),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(4.s),
                ),
                child: Text(
                  l10n.optional,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: Colors.white.withOpacity(0.35),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.s),
          _buildInputField(
            controller: _descController,
            hint: l10n.tellUsAboutYourDeck,
            maxLines: 3,
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.1, end: 0, delay: 400.ms, duration: 500.ms, curve: Curves.easeOutCubic),

          SizedBox(height: 120.h),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Step 2: Style
  // -----------------------------------------------------------------------

  Widget _buildStyleStep() {
    final l10n = AppLocalizations.of(context)!;
    final deckName = _nameController.text.trim().isEmpty
        ? l10n.yourDeckName
        : _nameController.text.trim();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 30.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 32.h),

          Text(
            l10n.styleYourDeck,
            style: GoogleFonts.poppins(
              fontSize: 34.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            l10n.makeItYours,
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              color: Colors.white.withOpacity(0.5),
              height: 1.5,
            ),
          ),

          SizedBox(height: 36.h),

          // Hero preview card (like deck_details hero)
          Center(child: _buildHeroPreview(deckName, l10n)),

          SizedBox(height: 36.h),

          // Icon & Color stat-style cards (matching deck_details stat cards)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () { _haptic.lightImpact(); _pickIcon(); },
                  child: _buildStatCard(
                    icon: _selectedIcon,
                    value: l10n.icon,
                    label: l10n.chooseAnIcon,
                    isFaIcon: true,
                    index: 0,
                  ),
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: GestureDetector(
                  onTap: () { _haptic.lightImpact(); _pickColor(); },
                  child: _buildStatCard(
                    icon: Icons.palette_rounded,
                    value: l10n.color,
                    label: l10n.pickAColor,
                    isFaIcon: false,
                    index: 1,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 120.h),
        ],
      ),
    );
  }

  Widget _buildHeroPreview(String deckName, AppLocalizations l10n) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: 210.s,
      height: 280.s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.s),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withOpacity(0.35),
            blurRadius: 40.s,
            spreadRadius: -5,
            offset: Offset(0, 20.s),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.s),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_selectedColor, _selectedColor.withOpacity(0.7)],
                ),
              ),
              child: Center(
                child: FaIcon(
                  _selectedIcon,
                  color: Colors.white.withOpacity(0.25),
                  size: 100.s,
                ),
              ),
            ),
            // Depth overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            // Bottom text
            Positioned(
              left: 20.s,
              right: 20.s,
              bottom: 20.s,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deckName,
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.s),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 4.s),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12.s),
                    ),
                    child: Text(
                      _cards.isEmpty
                          ? l10n.deckPreview
                          : l10n.cardsCount(_cards.length),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stat card matching deck_details_screen design
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required bool isFaIcon,
    required int index,
  }) {
    return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 20.h),
          decoration: BoxDecoration(
            color: _selectedColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: _selectedColor.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              isFaIcon
                  ? FaIcon(icon, color: _selectedColor, size: 28.s)
                  : Icon(icon, color: _selectedColor, size: 28.s),
              SizedBox(height: 12.h),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.5),
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withOpacity(0.2),
                  decorationStyle: TextDecorationStyle.dotted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (400 + index * 100).ms, duration: 500.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          delay: (400 + index * 100).ms,
          duration: 500.ms,
          curve: Curves.easeOutBack,
        );
  }

  // -----------------------------------------------------------------------
  // Step 3: Cards
  // -----------------------------------------------------------------------

  Widget _buildCardsStep() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(30.s, 24.h, 30.s, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.addYourCards,
                          style: GoogleFonts.poppins(
                            fontSize: 34.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          l10n.youNeedAtLeast('$_minCards cards'),
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.s),
                  _ProgressRing(
                    current: _cards.length,
                    total: _minCards,
                    color: _selectedColor,
                  ),
                ],
              ),

              SizedBox(height: 28.h),

              // Card input
              _buildCardInputRow(l10n),
              SizedBox(height: 10.s),

              // Bulk add (feature-card style)
              GestureDetector(
                onTap: () { _haptic.lightImpact(); _showBulkAdd(); },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.s),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14.s),
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32.s,
                        height: 32.s,
                        decoration: BoxDecoration(
                          color: _selectedColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.s),
                        ),
                        child: Icon(Icons.playlist_add_rounded, color: _selectedColor, size: 18.s),
                      ),
                      SizedBox(width: 12.s),
                      Text(
                        l10n.bulkAddCards,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

              SizedBox(height: 16.h),
            ],
          ),
        ),

        // Card list
        Expanded(
          child: _cards.isEmpty
              ? _buildEmptyCards()
              : _buildCardsList(),
        ),
      ],
    );
  }

  Widget _buildCardInputRow(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _buildInputField(
            controller: _cardController,
            hint: l10n.addACard,
            focusNode: _cardFocus,
            onSubmitted: (_) => _addCard(),
            textInputAction: TextInputAction.done,
          ),
        ),
        SizedBox(width: 12.s),
        GestureDetector(
              onTap: () { _haptic.lightImpact(); _addCard(); },
              child: Container(
                width: 52.s,
                height: 52.s,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_selectedColor, _selectedColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16.s),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withOpacity(0.4),
                      blurRadius: 20.s,
                      offset: Offset(0, 8.s),
                    ),
                  ],
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 24.s),
              ),
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              delay: 200.ms,
              duration: 400.ms,
              curve: Curves.easeOutBack,
            ),
      ],
    );
  }

  Widget _buildEmptyCards() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72.s,
            height: 72.s,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20.s),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(Icons.layers_outlined, size: 32.s, color: Colors.white.withOpacity(0.15)),
          ),
          SizedBox(height: 16.h),
          Text(
            AppLocalizations.of(context)!.addACard,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              color: Colors.white.withOpacity(0.3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildCardsList() {
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(30.s, 0, 30.s, 140.h),
      proxyDecorator: (child, _, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (ctx, child) => Material(
            color: Colors.transparent,
            elevation: 6,
            shadowColor: _selectedColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14.s),
            child: child,
          ),
          child: child,
        );
      },
      onReorder: _onReorder,
      itemCount: _cards.length,
      itemBuilder: (_, i) {
        return _CardTile(
          key: ValueKey('card_${i}_${_cards[i]}'),
          index: i,
          text: _cards[i],
          color: _selectedColor,
          isEditing: _editingCardIdx == i,
          onEdit: () => setState(() => _editingCardIdx = i),
          onUpdate: (v) => _updateCard(i, v),
          onDelete: () => _removeCard(i),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Bottom bar with backdrop blur (matching deck_details)
  // -----------------------------------------------------------------------

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;

    final bool canContinue;
    final String label;
    final bool isFinal;

    switch (_step) {
      case 0:
        canContinue = _step0Valid;
        label = l10n.continueText;
        isFinal = false;
        break;
      case 1:
        canContinue = true;
        label = l10n.continueText;
        isFinal = false;
        break;
      default:
        canContinue = _canCreate;
        label = _isEditing ? l10n.saveChanges : l10n.createDeckAction;
        isFinal = true;
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(30.s, 20.h, 30.s, 30.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: GestureDetector(
              onTap: canContinue ? () { _haptic.mediumImpact(); _goNext(); } : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                height: 56.h,
                decoration: BoxDecoration(
                  gradient: canContinue
                      ? LinearGradient(
                          colors: isFinal
                              ? [_selectedColor, _selectedColor.withOpacity(0.8)]
                              : [Colors.white, const Color(0xFFF0F0F0)],
                        )
                      : null,
                  color: canContinue ? null : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16.s),
                  boxShadow: canContinue
                      ? [
                          BoxShadow(
                            color: isFinal
                                ? _selectedColor.withOpacity(0.4)
                                : Colors.white.withOpacity(0.06),
                            blurRadius: 20.s,
                            offset: Offset(0, 8.s),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      SizedBox(
                        width: 22.s,
                        height: 22.s,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                            isFinal ? Colors.white : _bg,
                          ),
                        ),
                      )
                    else ...[
                      if (isFinal && canContinue)
                        Padding(
                          padding: EdgeInsets.only(right: 10.s),
                          child: Icon(Icons.check_rounded, color: Colors.white, size: 22.s),
                        ),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: canContinue
                              ? (isFinal ? Colors.white : _bg)
                              : Colors.white.withOpacity(0.25),
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (!isFinal && canContinue)
                        Padding(
                          padding: EdgeInsets.only(left: 8.s),
                          child: Icon(Icons.arrow_forward_rounded, size: 20.s, color: _bg),
                        ),
                      if (isFinal && !canContinue && _cards.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(left: 10.s),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 3.s),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8.s),
                            ),
                            child: Text(
                              '${_cards.length}/$_minCards',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(
      begin: 0.3,
      end: 0,
      delay: 600.ms,
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }

  // -----------------------------------------------------------------------
  // Shared UI helpers
  // -----------------------------------------------------------------------

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.5),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    double? fontSize,
    FontWeight? fontWeight,
    int maxLines = 1,
    FocusNode? focusNode,
    ValueChanged<String>? onSubmitted,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.s),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: GoogleFonts.inter(
          fontSize: fontSize ?? 15.sp,
          fontWeight: fontWeight ?? FontWeight.w400,
          color: Colors.white.withOpacity(0.95),
          letterSpacing: -0.2,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.2),
            fontSize: fontSize ?? 15.sp,
            fontWeight: FontWeight.w400,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.s,
            vertical: maxLines > 1 ? 16.s : 18.s,
          ),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Discard Dialog
  // -----------------------------------------------------------------------

  Future<bool> _showDiscardDialog() async {
    await _haptic.mediumImpact();
    final l10n = AppLocalizations.of(context)!;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 48,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_rounded, size: 32,
                      color: const Color(0xFFEF4444).withOpacity(0.9)),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.discardChanges,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.95),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.unsavedChangesMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.45),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        l10n.discard,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444).withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        l10n.cancel,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate()
            .fadeIn(duration: 250.ms)
            .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutCubic),
      ),
    );
    return result ?? false;
  }
}

// ===========================================================================
// Shared Widgets
// ===========================================================================

/// Animated progress bar
class _AnimatedBar extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;

  const _AnimatedBar({
    required this.widthFactor,
    required this.child,
    required super.duration,
    super.curve,
  });

  @override
  AnimatedWidgetBaseState<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends AnimatedWidgetBaseState<_AnimatedBar> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (dynamic v) => Tween<double>(begin: v as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}

/// Progress ring
class _ProgressRing extends StatelessWidget {
  final int current;
  final int total;
  final Color color;
  const _ProgressRing({required this.current, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (current / total).clamp(0.0, 1.0);
    final done = current >= total;

    return SizedBox(
      width: 52.s,
      height: 52.s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48.s,
            height: 48.s,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 3.s,
              valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.06)),
              strokeCap: StrokeCap.round,
            ),
          ),
          SizedBox(
            width: 48.s,
            height: 48.s,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => CircularProgressIndicator(
                value: v,
                strokeWidth: 3.s,
                valueColor: AlwaysStoppedAnimation(done ? const Color(0xFF10B981) : color),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          done
              ? Icon(Icons.check_rounded, size: 20.s, color: const Color(0xFF10B981))
              : Text(
                  '$current',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
        ],
      ),
    );
  }
}

/// Card tile (feature-card style from deck_details)
class _CardTile extends StatefulWidget {
  final int index;
  final String text;
  final Color color;
  final bool isEditing;
  final VoidCallback onEdit;
  final ValueChanged<String> onUpdate;
  final VoidCallback onDelete;

  const _CardTile({
    super.key,
    required this.index,
    required this.text,
    required this.color,
    required this.isEditing,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<_CardTile> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(_CardTile old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _ctrl.text = widget.text;
    if (widget.isEditing && !old.isEditing) _ctrl.text = widget.text;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isEditing ? null : widget.onEdit,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.s),
        padding: EdgeInsets.all(14.s),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(widget.isEditing ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(14.s),
          border: Border.all(
            color: widget.isEditing
                ? widget.color.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Number badge (icon-container style)
            Container(
              width: 32.s,
              height: 32.s,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.s),
              ),
              child: Center(
                child: Text(
                  '${widget.index + 1}',
                  style: GoogleFonts.poppins(
                    color: widget.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
            SizedBox(width: 14.s),

            Expanded(
              child: widget.isEditing
                  ? TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 15.sp, color: Colors.white.withOpacity(0.95)),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 6.s),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: widget.onUpdate,
                      onTapOutside: (_) => widget.onUpdate(_ctrl.text),
                    )
                  : Text(
                      widget.text,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),

            if (!widget.isEditing) ...[
              GestureDetector(
                onTap: widget.onDelete,
                child: Padding(
                  padding: EdgeInsets.all(4.s),
                  child: Icon(Icons.close_rounded, size: 16.s,
                      color: Colors.white.withOpacity(0.25)),
                ),
              ),
              SizedBox(width: 2.s),
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: EdgeInsets.all(4.s),
                  child: Icon(Icons.drag_indicator_rounded, size: 18.s,
                      color: Colors.white.withOpacity(0.15)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bulk add sheet (matching bottom sheet style from deck_details)
class _BulkAddSheet extends StatelessWidget {
  final TextEditingController controller;
  final AppLocalizations l10n;
  final Color color;
  final ValueChanged<List<String>> onAdd;

  const _BulkAddSheet({
    required this.controller,
    required this.l10n,
    required this.color,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: EdgeInsets.all(12.s),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24.s),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        padding: EdgeInsets.all(24.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.s,
                height: 4.s,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.s),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              l10n.bulkAddCardsTitle,
              style: GoogleFonts.poppins(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.95),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              l10n.bulkAddCardsHint,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              height: 160.s,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16.s),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                autofocus: true,
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: 'Card 1\nCard 2\nCard 3\n...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.15),
                    fontSize: 15.sp,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(18.s),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: () => onAdd(controller.text.split('\n')),
              child: Container(
                height: 56.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(16.s),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 20.s,
                      offset: Offset(0, 8.s),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    l10n.addCards,
                    style: GoogleFonts.poppins(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
