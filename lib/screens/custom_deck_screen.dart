import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/icon_picker_dialog.dart';
import '../widgets/color_picker_dialog.dart';

class CustomDeckScreen extends StatefulWidget {
  final Deck? existingDeck;

  const CustomDeckScreen({super.key, this.existingDeck});

  @override
  State<CustomDeckScreen> createState() => _CustomDeckScreenState();
}

class _CustomDeckScreenState extends State<CustomDeckScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();

  late final AnimationController _animationController;
  late final AnimationController _fabController;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cardController = TextEditingController();
  final _scrollController = ScrollController();

  List<String> _cards = [];
  IconData _selectedIcon = FontAwesomeIcons.solidStar;
  Color _selectedColor = Colors.purple;
  bool _isLoading = false;
  bool _hasChanges = false;

  // AI Suggestions
  bool _showAISuggestions = false;
  List<String> _aiSuggestions = [];
  bool _isLoadingAI = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize with existing deck if editing
    if (widget.existingDeck != null) {
      _nameController.text = widget.existingDeck!.name;
      _descriptionController.text = widget.existingDeck!.description;
      _cards = List.from(widget.existingDeck!.cards);
      _selectedIcon = widget.existingDeck!.icon;
      _selectedColor = widget.existingDeck!.color;
    }

    // Add listeners for change detection
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _cardController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveDeck() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_cards.isEmpty) {
      _showSnackBar(l10n.pleaseAddCards(5), isError: true);
      return;
    }
    if (_cards.length < 5) {
      _showSnackBar(l10n.deckNeedsCards(5), isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _hapticService.mediumImpact();

    final deckProvider = context.read<DeckProvider>();
    bool success;

    if (widget.existingDeck != null) {
      // Update existing deck
      success = await deckProvider.updateCustomDeck(
        deckId: widget.existingDeck!.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        cards: _cards,
        icon: _selectedIcon,
        color: _selectedColor,
      );
    } else {
      // Create new deck
      success = await deckProvider.createCustomDeck(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        cards: _cards,
        icon: _selectedIcon,
        color: _selectedColor,
      );
    }

    setState(() => _isLoading = false);

    if (success) {
      _hapticService.success();
      _showSnackBar(
        widget.existingDeck != null
            ? l10n.deckUpdatedSuccessfully
            : l10n.customDeckCreatedSuccessfully,
      );
      Navigator.pop(context, true);
    } else {
      _hapticService.error();
      _showSnackBar(l10n.failedToSaveDeck, isError: true);
    }
  }

  void _addCard() {
    final card = _cardController.text.trim();
    if (card.isEmpty) return;

    setState(() {
      _cards.add(card);
      _cardController.clear();
      _hasChanges = true;
    });
    _hapticService.lightImpact();
  }

  void _removeCard(int index) {
    setState(() {
      _cards.removeAt(index);
      _hasChanges = true;
    });
    _hapticService.lightImpact();
  }

  Future<void> _generateAISuggestions() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar(l10n.enterDeckNameFirst, isError: true);
      return;
    }

    setState(() {
      _isLoadingAI = true;
      _showAISuggestions = false;
    });

    // Simulate AI generation
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _aiSuggestions = [
        'Celebrity',
        'Movie',
        'Animal',
        'Food',
        'Country',
        'Sport',
        'Book',
        'Song',
      ];
      _showAISuggestions = true;
      _isLoadingAI = false;
    });

    _hapticService.mediumImpact();
  }

  void _addAISuggestion(String suggestion) {
    if (!_cards.contains(suggestion)) {
      setState(() {
        _cards.add(suggestion);
        _hasChanges = true;
      });
      _hapticService.lightImpact();
    }
  }

  void _addAllAISuggestions() {
    setState(() {
      for (final suggestion in _aiSuggestions) {
        if (!_cards.contains(suggestion)) {
          _cards.add(suggestion);
        }
      }
      _hasChanges = true;
      _showAISuggestions = false;
    });
    _hapticService.mediumImpact();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    await _hapticService.mediumImpact();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => _buildPremiumDiscardDialog(),
    );

    return result ?? false;
  }

  // Premium Discard Dialog Widget
  Widget _buildPremiumDiscardDialog() {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
                  child: Column(
                    children: [
                      // Icon
                      Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFEF4444).withOpacity(0.12),
                                  const Color(0xFFDC2626).withOpacity(0.08),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_rounded,
                              size: 32,
                              color: const Color(0xFFEF4444).withOpacity(0.9),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                          .scale(
                            begin: const Offset(0.7, 0.7),
                            curve: Curves.easeOutBack,
                          ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                            l10n.discardChanges,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A).withOpacity(0.95),
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                          )
                          .animate()
                          .fadeIn(
                            delay: 100.ms,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideY(begin: 0.1, curve: Curves.easeOutCubic),

                      const SizedBox(height: 12),

                      // Description
                      Text(
                            l10n.unsavedChangesMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF1A1A1A).withOpacity(0.55),
                              letterSpacing: -0.2,
                              height: 1.5,
                            ),
                          )
                          .animate()
                          .fadeIn(
                            delay: 200.ms,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),

                // Buttons Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      // Discard Button
                      _buildDialogButton(
                        label: l10n.discard,
                        isPrimary: false,
                        onTap: () async {
                          await _hapticService.lightImpact();
                          Navigator.pop(context, true);
                        },
                        delay: 300.ms,
                      ),

                      const SizedBox(height: 12),

                      // Cancel Button
                      _buildDialogButton(
                        label: l10n.cancel,
                        isPrimary: true,
                        onTap: () async {
                          await _hapticService.lightImpact();
                          Navigator.pop(context, false);
                        },
                        delay: 350.ms,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
          .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic),
    );
  }

  // Dialog Button Widget
  Widget _buildDialogButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient:
                  isPrimary
                      ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
                      )
                      : null,
              color:
                  isPrimary ? null : const Color(0xFF1A1A1A).withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border:
                  !isPrimary
                      ? Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      )
                      : null,
              boxShadow:
                  isPrimary
                      ? [
                        BoxShadow(
                          color: const Color(0xFF1A1A1A).withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isPrimary)
                  Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: const Color(0xFFEF4444).withOpacity(0.9),
                  ),
                if (!isPrimary) const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        isPrimary
                            ? Colors.white.withOpacity(0.95)
                            : const Color(0xFFEF4444).withOpacity(0.9),
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(delay: delay, duration: 400.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.15, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Stack(
          children: [
            // Subtle gradient background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0D0D0D),
                      const Color(0xFF0D0D0D).withBlue(8),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Refined Header
                  _buildElegantHeader(),
                  // Form content
                  Expanded(child: _buildModernFormContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Elegant Back Button
          _buildElegantBackButton(),
          const SizedBox(width: 24),

          // Title Section with refined typography
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      widget.existingDeck != null ? l10n.editDeck : l10n.createDeck,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                    .slideX(begin: -0.02, end: 0, curve: Curves.easeOutQuart),

                const SizedBox(height: 4),

                Text(
                      widget.existingDeck != null
                          ? l10n.refineAndPerfect
                          : l10n.craftSomethingUnique,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                        height: 1.2,
                      ),
                    )
                    .animate()
                    .fadeIn(
                      delay: 200.ms,
                      duration: 600.ms,
                      curve: Curves.easeOut,
                    )
                    .slideX(begin: -0.02, end: 0, curve: Curves.easeOutQuart),
              ],
            ),
          ),

          // Refined Save Button
          _buildElegantSaveButton(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildModernFormContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Refined Deck Info Section
            _buildRefinedInfoSection()
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuart),

            const SizedBox(height: 20),

            // Elegant Customization Section
            _buildElegantCustomizationSection()
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuart),

            const SizedBox(height: 20),

            // Refined Cards Section
            _buildRefinedCardsSection()
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuart),
          ],
        ),
      ),
    );
  }

  // Legacy methods - kept temporarily for reference
  Widget _buildPremiumCardsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header - Ultra Minimal
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(
                  children: [
                    Icon(
                          Icons.layers_rounded,
                          size: 18,
                          color: Colors.white.withOpacity(0.7),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                            '${l10n.cards} (${_cards.length})',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          )
                          .animate()
                          .fadeIn(
                            delay: 50.ms,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideX(begin: -0.02, curve: Curves.easeOutCubic),
                    ),
                    // Card status badge - Minimalist
                    if (_cards.isNotEmpty)
                      AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _cards.length >= 5
                                      ? const Color(
                                        0xFF10B981,
                                      ).withOpacity(0.12)
                                      : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _cards.length >= 5
                                      ? Icons.check_circle
                                      : Icons.schedule_rounded,
                                  size: 12,
                                  color:
                                      _cards.length >= 5
                                          ? const Color(
                                            0xFF10B981,
                                          ).withOpacity(0.9)
                                          : Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _cards.length >= 5
                                      ? l10n.ready
                                      : l10n.moreNeeded(5 - _cards.length),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _cards.length >= 5
                                            ? const Color(
                                              0xFF10B981,
                                            ).withOpacity(0.9)
                                            : Colors.white.withOpacity(0.5),
                                    letterSpacing: -0.15,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            curve: Curves.easeOutBack,
                          ),
                  ],
                ),
              ),

              // Card Input - Refined Design
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.025),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                                  controller: _cardController,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                    letterSpacing: -0.2,
                                    height: 1.4,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.addACard,
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.35),
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.15,
                                    ),
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _addCard(),
                                )
                                .animate()
                                .fadeIn(
                                  delay: 100.ms,
                                  duration: 500.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideX(
                                  begin: -0.02,
                                  curve: Curves.easeOutCubic,
                                ),
                          ),
                          // Elegant Add Button
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () async {
                                await _hapticService.lightImpact();
                                _addCard();
                              },
                              child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 20,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: 150.ms,
                                    duration: 500.ms,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .scale(
                                    begin: const Offset(0.9, 0.9),
                                    curve: Curves.easeOutBack,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(
                      delay: 100.ms,
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .slideY(begin: 0.03, curve: Curves.easeOutCubic),
              ),

              // Cards List
              if (_cards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFF1A1A1A,
                                ).withOpacity(0.05),
                                width: 1,
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(6),
                              itemCount: _cards.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 3),
                              itemBuilder: (context, index) {
                                return _buildCardItem(index)
                                    .animate()
                                    .fadeIn(
                                      delay: (index * 25).ms,
                                      duration: 300.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .slideX(
                                      begin: -0.03,
                                      curve: Curves.easeOutCubic,
                                    );
                              },
                            ),
                          )
                          .animate()
                          .fadeIn(
                            delay: 200.ms,
                            duration: 350.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideY(begin: 0.02, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),

              // AI Suggestions Section (moved to bottom)
              if (!_showAISuggestions && _cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _buildAISuggestionButton(),
                ),

              if (_showAISuggestions && _aiSuggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _buildAISuggestionsWidget(),
                ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 150.ms, duration: 350.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.03, curve: Curves.easeOutCubic);
  }

  // Premium Card Item Widget
  Widget _buildCardItem(int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: const Color(0xFF1A1A1A).withOpacity(0.6),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        title: Text(
          _cards[index],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: -0.2,
            height: 1.3,
          ),
        ),
        trailing: GestureDetector(
          onTap: () async {
            await _hapticService.lightImpact();
            _removeCard(index);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  // AI Suggestion Button Widget - Refined
  Widget _buildAISuggestionButton() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () async {
        await _hapticService.mediumImpact();
        _generateAISuggestions();
      },
      child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.95),
                  const Color(0xFF8B5CF6).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoadingAI)
                  SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.9),
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .rotate(duration: 1200.ms, curve: Curves.linear)
                else
                  Icon(
                        Icons.auto_awesome,
                        color: Colors.white.withOpacity(0.95),
                        size: 16,
                      )
                      .animate(
                        onPlay:
                            (controller) => controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.15, 1.15),
                        duration: 1800.ms,
                        curve: Curves.easeInOut,
                      ),
                const SizedBox(width: 9),
                Text(
                  _isLoadingAI ? l10n.generating : l10n.aiSuggestions,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.03, curve: Curves.easeOutCubic)
          .then(delay: 300.ms)
          .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.2)),
    );
  }

  Widget _buildAISuggestionsWidget() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withOpacity(0.05),
            const Color(0xFF8B5CF6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.aiSuggestions,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _addAllAISuggestions,
                child: Text(l10n.addAll),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _aiSuggestions.map((suggestion) {
                  return GestureDetector(
                    onTap: () => _addAISuggestion(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            suggestion,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.add_circle_outline_rounded,
                            size: 16,
                            color: const Color(0xFF6366F1),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  void _pickIcon() async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) => IconPickerDialog(selectedIcon: _selectedIcon),
    );
    if (icon != null) {
      setState(() {
        _selectedIcon = icon;
        _hasChanges = true;
      });
    }
  }

  void _pickColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(selectedColor: _selectedColor),
    );
    if (color != null) {
      setState(() {
        _selectedColor = color;
        _hasChanges = true;
      });
    }
  }

  Widget _buildUltraPremiumBackButton() {
    return GestureDetector(
      onTap: () async {
        await _hapticService.lightImpact();
        Navigator.maybePop(context);
      },
      child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          )
          .animate()
          .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
          .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic),
    );
  }

  Widget _buildUltraPremiumSaveButton() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap:
          _isLoading
              ? null
              : () async {
                await _hapticService.mediumImpact();
                _saveDeck();
              },
      child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: _isLoading ? 20 : 18,
              vertical: _isLoading ? 11 : 10,
            ),
            decoration: BoxDecoration(
              gradient:
                  _isLoading
                      ? LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.1),
                        ],
                      )
                      : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFE8E8E8)],
                      ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                if (!_isLoading)
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF0A0A0A).withOpacity(0.7),
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .rotate(duration: 1200.ms, curve: Curves.linear)
                else ...[
                  const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF0A0A0A),
                        size: 15,
                      )
                      .animate()
                      .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(width: 6),
                  Text(
                        l10n.save,
                        style: const TextStyle(
                          color: Color(0xFF0A0A0A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
                      .slideX(begin: -0.1, curve: Curves.easeOutCubic),
                ],
              ],
            ),
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 450.ms, curve: Curves.easeOutCubic)
          .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic),
    );
  }

  Widget _buildPremiumInfoSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header - Minimal & Elegant
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.85, 0.85),
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(width: 12),
                    Text(
                          l10n.deckInformation,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        )
                        .animate()
                        .fadeIn(
                          delay: 50.ms,
                          duration: 350.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .slideX(begin: -0.015, curve: Curves.easeOutCubic),
                  ],
                ),
              ),

              // Form Fields
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // Deck Name Field
                    _buildPremiumTextField(
                          controller: _nameController,
                          label: l10n.deckName,
                          placeholder: l10n.enterUniqueName,
                          icon: Icons.edit_note_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.pleaseEnterDeckName;
                            }
                            return null;
                          },
                        )
                        .animate()
                        .fadeIn(
                          delay: 100.ms,
                          duration: 450.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .slideY(begin: 0.02, curve: Curves.easeOutCubic),

                    const SizedBox(height: 16),

                    // Description Field
                    _buildPremiumTextField(
                          controller: _descriptionController,
                          label: l10n.description,
                          placeholder: l10n.tellUsAboutYourDeck,
                          icon: Icons.article_outlined,
                          maxLines: 3,
                          isOptional: true,
                        )
                        .animate()
                        .fadeIn(
                          delay: 150.ms,
                          duration: 450.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .slideY(begin: 0.02, curve: Curves.easeOutCubic),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.03, curve: Curves.easeOutCubic);
  }

  Widget _buildPremiumCustomizationSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header - Ultra Minimal
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Text(
                      l10n.customization,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    )
                    .animate()
                    .fadeIn(
                      delay: 50.ms,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .slideY(begin: -0.1, curve: Curves.easeOutCubic),
              ),

              // Customization Options
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Icon Picker
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await _hapticService.lightImpact();
                          _pickIcon();
                        },
                        child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              height: 88,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.06),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                      _selectedIcon,
                                      size: 32,
                                      color: _selectedColor.withOpacity(0.9),
                                    )
                                    .animate(key: ValueKey(_selectedIcon))
                                    .fadeIn(
                                      duration: 250.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .scale(
                                      begin: const Offset(0.8, 0.8),
                                      end: const Offset(1.0, 1.0),
                                      curve: Curves.easeOutBack,
                                    ),
                              ),
                            )
                            .animate()
                            .fadeIn(
                              delay: 100.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            )
                            .then(delay: 200.ms)
                            .shimmer(
                              duration: 1200.ms,
                              color: Colors.white.withOpacity(0.05),
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Color Picker
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await _hapticService.lightImpact();
                          _pickColor();
                        },
                        child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              height: 88,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _selectedColor.withOpacity(0.9),
                                    _selectedColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _selectedColor.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.water_drop_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    )
                                    .animate(
                                      onPlay:
                                          (controller) =>
                                              controller.repeat(reverse: true),
                                    )
                                    .scale(
                                      begin: const Offset(1.0, 1.0),
                                      end: const Offset(1.08, 1.08),
                                      duration: 2000.ms,
                                      curve: Curves.easeInOut,
                                    ),
                              ),
                            )
                            .animate()
                            .fadeIn(
                              delay: 150.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            )
                            .then(delay: 300.ms)
                            .shimmer(
                              duration: 1500.ms,
                              color: Colors.white.withOpacity(0.3),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 100.ms, duration: 500.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.03, curve: Curves.easeOutCubic);
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isOptional = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              if (isOptional) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.optional,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Text Field
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1A1A),
            letterSpacing: -0.3,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontWeight: FontWeight.w400,
              letterSpacing: -0.2,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: maxLines > 1 ? 16 : 18,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 12),
              child: Icon(icon, size: 20, color: Colors.white.withOpacity(0.4)),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 46,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFEF4444),
              height: 1.3,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // New elegant button implementations
  Widget _buildElegantBackButton() {
    return GestureDetector(
      onTap: () async {
        await _hapticService.lightImpact();
        if (_hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop) {
            Navigator.maybePop(context);
          }
        } else {
          Navigator.maybePop(context);
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ).animate().scale(
        begin: const Offset(0.8, 0.8),
        duration: 400.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }

  Widget _buildElegantSaveButton() {
    final l10n = AppLocalizations.of(context)!;
    final bool isReady =
        _nameController.text.trim().isNotEmpty &&
        _cards.length >= 5 &&
        !_isLoading;

    return GestureDetector(
      onTap:
          isReady
              ? () async {
                await _hapticService.mediumImpact();
                _saveDeck();
              }
              : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isReady ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isReady
                        ? const Color(0xFF0D0D0D)
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              )
            else
              Icon(
                Icons.check,
                size: 18,
                color:
                    isReady
                        ? const Color(0xFF0D0D0D)
                        : Colors.white.withOpacity(0.5),
              ),
            const SizedBox(width: 8),
            Text(
              _isLoading ? l10n.saving : l10n.save,
              style: TextStyle(
                color:
                    isReady
                        ? const Color(0xFF0D0D0D)
                        : Colors.white.withOpacity(0.5),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ).animate().scale(
        begin: const Offset(0.9, 0.9),
        duration: 400.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }

  // Refined section builders
  Widget _buildRefinedInfoSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with icon
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.deckInformation,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.02, end: 0),

          const SizedBox(height: 18),

          // Name field
          _buildElegantTextField(
            controller: _nameController,
            label: l10n.deckName,
            placeholder: l10n.enterUniqueName,
            icon: Icons.edit_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.pleaseEnterDeckName;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Description field
          _buildElegantTextField(
            controller: _descriptionController,
            label: l10n.description,
            placeholder: l10n.tellUsAboutYourDeck,
            icon: Icons.description_outlined,
            maxLines: 2,
            isOptional: true,
          ),
        ],
      ),
    );
  }

  Widget _buildElegantTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isOptional = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 0,
              ),
            ),
            if (isOptional) ...[
              const SizedBox(width: 6),
              Text(
                l10n.optional,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Text field
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 12 : 14,
            ),
            prefixIcon:
                maxLines == 1
                    ? Icon(icon, size: 18, color: Colors.white.withOpacity(0.5))
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
            ),
          ),
          validator: validator,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        ),
      ],
    );
  }

  Widget _buildElegantCustomizationSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.customization,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Icon selector
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await _hapticService.lightImpact();
                    _pickIcon();
                  },
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                              _selectedIcon,
                              size: 32,
                              color: Colors.white.withOpacity(0.8),
                            )
                            .animate(key: ValueKey(_selectedIcon))
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              duration: 300.ms,
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(),
                        const SizedBox(height: 6),
                        Text(
                          l10n.icon,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ).animate().shimmer(
                    duration: 2000.ms,
                    delay: 1000.ms,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Color selector
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await _hapticService.lightImpact();
                    _pickColor();
                  },
                  child: Container(
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _selectedColor.withOpacity(0.8),
                              _selectedColor.withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedColor.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.palette_rounded,
                              size: 28,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            Positioned(
                              bottom: 10,
                              child: Text(
                                l10n.color,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(key: ValueKey(_selectedColor))
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        duration: 300.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefinedCardsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Icon(
                  Icons.style_rounded,
                  size: 18,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.cards,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _cards.length >= 5
                            ? Colors.green.withOpacity(0.15)
                            : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_cards.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          _cards.length >= 5
                              ? Colors.green.withOpacity(0.9)
                              : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                const Spacer(),
                if (_cards.length < 5)
                  Text(
                    l10n.moreNeeded(5 - _cards.length),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),

          // Card input
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _cardController,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.addACard,
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _addCard(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addCard,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ).animate().scale(
                    delay: 500.ms,
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  ),
                ),
              ],
            ),
          ),

          // Cards list
          if (_cards.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  return _buildElegantCardItem(index)
                      .animate()
                      .fadeIn(delay: (index * 50).ms, duration: 300.ms)
                      .slideX(begin: -0.05, end: 0);
                },
              ),
            ),

          // AI suggestions button
          if (_cards.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildElegantAISuggestionButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildElegantCardItem(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        dense: true,
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        title: Text(
          _cards[index],
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: GestureDetector(
          onTap: () {
            _removeCard(index);
          },
          child: Icon(
            Icons.close,
            size: 16,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantAISuggestionButton() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _generateAISuggestions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1).withOpacity(0.8),
              const Color(0xFF8B5CF6).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingAI)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.9),
                  ),
                ),
              )
            else
              Icon(
                    Icons.auto_awesome,
                    color: Colors.white.withOpacity(0.9),
                    size: 18,
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    duration: 2000.ms,
                    color: Colors.white.withOpacity(0.3),
                  ),
            const SizedBox(width: 8),
            Text(
              _isLoadingAI ? l10n.generating : l10n.aiSuggestions,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ).animate().shimmer(
        delay: 1000.ms,
        duration: 2000.ms,
        color: Colors.white.withOpacity(0.1),
      ),
    );
  }
}
