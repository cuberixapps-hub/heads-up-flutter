import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';

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
    if (!_formKey.currentState!.validate()) return;
    if (_cards.isEmpty) {
      _showSnackBar('Please add at least 5 cards to your deck', isError: true);
      return;
    }
    if (_cards.length < 5) {
      _showSnackBar('A deck needs at least 5 cards to play', isError: true);
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
            ? 'Deck updated successfully!'
            : 'Deck created successfully!',
      );
      Navigator.pop(context, true);
    } else {
      _hapticService.error();
      _showSnackBar('Failed to save deck. Please try again.', isError: true);
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
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a deck name first', isError: true);
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

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to leave?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          child: Column(
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey.shade100,
                                  Colors.grey.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              size: 22,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existingDeck != null
                                    ? 'Edit Deck'
                                    : 'Create Deck',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                widget.existingDeck != null
                                    ? 'Modify your custom deck'
                                    : 'Build your own custom deck',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Save button
                        GestureDetector(
                          onTap: _isLoading ? null : _saveDeck,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isLoading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                else ...[
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Save',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form content
              Expanded(child: _buildModernFormContent()),
            ],
          ),
        ),

        // Floating Action Button for AI
        floatingActionButton: _buildModernFloatingActionButton(),
      ),
    );
  }

  Widget _buildModernFormContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deck Info Card
            _buildModernSection(
              title: 'Deck Information',
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF6366F1),
              child: Column(
                children: [
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Deck Name',
                      hintText: 'Enter a unique name',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF6366F1),
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a deck name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Describe your deck',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF6366F1),
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            // Customization Card
            _buildModernSection(
                  title: 'Customization',
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  child: Column(
                    children: [
                      // Icon and Color Pickers
                      Row(
                        children: [
                          // Icon Picker
                          Expanded(
                            child: _buildCustomizationOption(
                              label: 'Icon',
                              child: GestureDetector(
                                onTap: _pickIcon,
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _selectedColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedColor.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    _selectedIcon,
                                    size: 32,
                                    color: _selectedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Color Picker
                          Expanded(
                            child: _buildCustomizationOption(
                              label: 'Color',
                              child: GestureDetector(
                                onTap: _pickColor,
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _selectedColor.withOpacity(0.8),
                                        _selectedColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.palette_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 100.ms, duration: 500.ms)
                .slideY(begin: 0.05),

            const SizedBox(height: 20),

            // Cards Section
            _buildModernCardsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationOption({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildModernCardsSection() {
    return _buildModernSection(
      title: 'Cards (${_cards.length})',
      icon: Icons.style_rounded,
      iconColor: const Color(0xFFEC4899),
      child: Column(
        children: [
          // Add Card Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardController,
                  decoration: InputDecoration(
                    hintText: 'Enter card text...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFEC4899),
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.add_rounded),
                  ),
                  onSubmitted: (_) => _addCard(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _addCard,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_cards.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Cards List
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _cards.length,
                separatorBuilder:
                    (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xFFEC4899),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      _cards[index],
                      style: const TextStyle(fontSize: 15),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () => _removeCard(index),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Card count indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _cards.length >= 5
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _cards.length >= 5
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color:
                        _cards.length >= 5
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _cards.length >= 5
                        ? '${_cards.length} cards - Ready to play!'
                        : 'Need at least 5 cards (${5 - _cards.length} more)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          _cards.length >= 5
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_showAISuggestions && _aiSuggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAISuggestionsWidget(),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.05);
  }

  Widget _buildModernFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _generateAISuggestions,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoadingAI)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isLoadingAI ? 'Generating...' : 'AI Suggestions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAISuggestionsWidget() {
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
              const Text(
                'AI Suggestions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _addAllAISuggestions,
                child: const Text('Add All'),
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
                        color: Colors.white,
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
}
