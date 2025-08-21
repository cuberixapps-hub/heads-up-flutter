import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../widgets/icon_picker_dialog.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/import_deck_dialog.dart';
import '../utils/deck_share_helper.dart';
import 'custom_deck_management_screen.dart';

class CustomDeckCreationScreen extends StatefulWidget {
  final Map<String, dynamic>? templateDeck;
  final String? editDeckId;

  const CustomDeckCreationScreen({
    super.key,
    this.templateDeck,
    this.editDeckId,
  });

  @override
  State<CustomDeckCreationScreen> createState() =>
      _CustomDeckCreationScreenState();
}

class _CustomDeckCreationScreenState extends State<CustomDeckCreationScreen>
    with TickerProviderStateMixin {
  final _hapticService = HapticService();
  final _audioService = AudioService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cardController = TextEditingController();
  final _scrollController = ScrollController();

  late AnimationController _floatingController;
  late AnimationController _pulseController;

  List<String> _cards = [];
  IconData _selectedIcon = FontAwesomeIcons.solidStar;
  Color _selectedColor = AppTheme.accentColor;
  bool _isLoading = false;
  int? _editingCardIndex;
  bool _showCardHint = true;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _initializeForm();
  }

  void _initializeForm() {
    if (widget.editDeckId != null) {
      // Load existing deck for editing
      final deck = context.read<DeckProvider>().getDeckById(widget.editDeckId!);
      if (deck != null) {
        _nameController.text = deck.name;
        _descriptionController.text = deck.description;
        _cards = List<String>.from(deck.cards);
        _selectedIcon = deck.icon;
        _selectedColor = deck.color;
      }
    } else if (widget.templateDeck != null) {
      // Load template
      _nameController.text = widget.templateDeck!['name'] ?? '';
      _descriptionController.text = widget.templateDeck!['description'] ?? '';
      _cards = List<String>.from(widget.templateDeck!['cards'] ?? []);
      _selectedIcon =
          widget.templateDeck!['icon'] ?? FontAwesomeIcons.solidStar;
      _selectedColor = widget.templateDeck!['color'] ?? AppTheme.accentColor;
    }
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _cardController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addCard() {
    final card = _cardController.text.trim();
    if (card.isNotEmpty) {
      setState(() {
        if (_editingCardIndex != null) {
          _cards[_editingCardIndex!] = card;
          _editingCardIndex = null;
        } else {
          _cards.add(card);
        }
        _cardController.clear();
        _showCardHint = false;
      });
      _hapticService.lightImpact();
      _audioService.playClick();

      // Scroll to bottom to show new card
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _editCard(int index) {
    setState(() {
      _editingCardIndex = index;
      _cardController.text = _cards[index];
    });
    _hapticService.lightImpact();
  }

  void _removeCard(int index) {
    setState(() {
      _cards.removeAt(index);
      if (_editingCardIndex == index) {
        _editingCardIndex = null;
        _cardController.clear();
      }
    });
    _hapticService.lightImpact();
    _audioService.playClick();
  }

  void _selectIcon() async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) => IconPickerDialog(selectedIcon: _selectedIcon),
    );
    if (icon != null) {
      setState(() {
        _selectedIcon = icon;
      });
      _hapticService.lightImpact();
    }
  }

  void _selectColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(selectedColor: _selectedColor),
    );
    if (color != null) {
      setState(() {
        _selectedColor = color;
      });
      _hapticService.lightImpact();
    }
  }

  Future<void> _saveDeck() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cards.length < 5) {
      _showErrorSnackBar('Please add at least 5 cards to your deck');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _hapticService.mediumImpact();
    _audioService.playSuccess();

    final deckProvider = context.read<DeckProvider>();
    bool success;

    if (widget.editDeckId != null) {
      // Update existing deck
      success = await deckProvider.updateCustomDeck(
        deckId: widget.editDeckId!,
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

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomDeckManagementScreen(),
          ),
        );
      }
    } else {
      _showErrorSnackBar('Failed to save deck. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showTemplatesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTemplatesSheet(),
    );
  }

  Widget _buildTemplatesSheet() {
    final templates = [
      {
        'name': 'Party Games',
        'description': 'Fun party activities and games',
        'icon': FontAwesomeIcons.champagneGlasses,
        'color': AppTheme.warningColor,
        'cards': [
          'Charades',
          'Truth or Dare',
          'Never Have I Ever',
          'Two Truths and a Lie',
          'Would You Rather',
          'Spin the Bottle',
          'Musical Chairs',
          'Beer Pong',
          'Karaoke',
          'Dance Off',
        ],
      },
      {
        'name': 'Study Terms',
        'description': 'Educational flashcards for studying',
        'icon': FontAwesomeIcons.graduationCap,
        'color': AppTheme.successColor,
        'cards': [
          'Photosynthesis',
          'Mitochondria',
          'Democracy',
          'Algorithm',
          'Hypothesis',
          'Ecosystem',
          'Gravity',
          'Evolution',
          'Molecule',
          'Chromosome',
        ],
      },
      {
        'name': 'Workout Moves',
        'description': 'Fitness exercises and routines',
        'icon': FontAwesomeIcons.dumbbell,
        'color': AppTheme.primaryColor,
        'cards': [
          'Push-ups',
          'Squats',
          'Lunges',
          'Planks',
          'Burpees',
          'Mountain Climbers',
          'Jumping Jacks',
          'Crunches',
          'Pull-ups',
          'Deadlifts',
        ],
      },
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Choose a Template',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _nameController.text = template['name'] as String;
                      _descriptionController.text =
                          template['description'] as String;
                      _cards = List<String>.from(template['cards'] as List);
                      _selectedIcon = template['icon'] as IconData;
                      _selectedColor = template['color'] as Color;
                    });
                    Navigator.pop(context);
                    _hapticService.mediumImpact();
                    _audioService.playClick();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (template['color'] as Color).withOpacity(0.1),
                          (template['color'] as Color).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (template['color'] as Color).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: template['color'] as Color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: FaIcon(
                              template['icon'] as IconData,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template['name'] as String,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                template['description'] as String,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(template['cards'] as List).length} cards',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: template['color'] as Color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.textTertiary,
                          size: 16,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                backgroundColor: _selectedColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  color: Colors.white,
                  onPressed: () {
                    _hapticService.lightImpact();
                    Navigator.pop(context);
                  },
                ),
                actions: [
                  if (!widget.editDeckId.isNull)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      color: Colors.white,
                      onPressed: () {
                        _hapticService.lightImpact();
                        _showDeckOptions();
                      },
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _selectedColor,
                          _selectedColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Pattern overlay
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PatternPainter(
                              animation: _pulseController,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        // Content
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _floatingController,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                        0,
                                        _floatingController.value * 8 - 4,
                                      ),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: FaIcon(
                                            _selectedIcon,
                                            color: Colors.white,
                                            size: 36,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.editDeckId != null
                                      ? 'Edit Deck'
                                      : 'Create Custom Deck',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Design your own unique deck',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Form Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick Actions
                          if (widget.editDeckId == null) ...[
                            Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor.withOpacity(0.1),
                                        AppTheme.accentColor.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildQuickAction(
                                        'Templates',
                                        Icons.dashboard_rounded,
                                        () => _showTemplatesDialog(),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: AppTheme.dividerColor,
                                      ),
                                      _buildQuickAction(
                                        'Import',
                                        Icons.file_upload_rounded,
                                        () => _showImportDialog(),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: AppTheme.dividerColor,
                                      ),
                                      _buildQuickAction(
                                        'AI Generate',
                                        Icons.auto_awesome_rounded,
                                        () => _showAIGenerateDialog(),
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideY(begin: 0.1),
                            const SizedBox(height: 24),
                          ],

                          // Deck Details Section
                          _buildSectionTitle('Deck Details'),
                          const SizedBox(height: 16),

                          // Name Field
                          _buildTextField(
                            controller: _nameController,
                            label: 'Deck Name',
                            hint: 'Enter a catchy name',
                            icon: Icons.title_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a deck name';
                              }
                              if (value.trim().length < 3) {
                                return 'Name must be at least 3 characters';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

                          const SizedBox(height: 16),

                          // Description Field
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'What\'s this deck about?',
                            icon: Icons.description_rounded,
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),

                          const SizedBox(height: 24),

                          // Appearance Section
                          _buildSectionTitle('Appearance'),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _buildAppearanceCard(
                                      'Icon',
                                      _selectedIcon,
                                      _selectedColor,
                                      () => _selectIcon(),
                                    )
                                    .animate()
                                    .fadeIn(delay: 500.ms)
                                    .scale(begin: const Offset(0.8, 0.8)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildColorCard(
                                      'Color',
                                      _selectedColor,
                                      () => _selectColor(),
                                    )
                                    .animate()
                                    .fadeIn(delay: 600.ms)
                                    .scale(begin: const Offset(0.8, 0.8)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Cards Section
                          _buildSectionTitle('Cards'),
                          const SizedBox(height: 8),
                          Text(
                            'Add at least 5 cards to your deck',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),

                          // Card Input
                          _buildCardInput(),

                          const SizedBox(height: 16),

                          // Cards List
                          if (_cards.isNotEmpty) ...[
                            Container(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.4,
                              ),
                              child: ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _cards.length,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }
                                    final item = _cards.removeAt(oldIndex);
                                    _cards.insert(newIndex, item);
                                  });
                                  _hapticService.lightImpact();
                                },
                                itemBuilder: (context, index) {
                                  return _buildCardItem(index, _cards[index]);
                                },
                              ),
                            ),
                          ] else if (_showCardHint) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  style: BorderStyle.solid,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.style_rounded,
                                    size: 48,
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No cards yet',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start adding cards to build your deck',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 700.ms),
                          ],

                          const SizedBox(height: 32),

                          // Stats
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _selectedColor.withOpacity(0.1),
                                  _selectedColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'Cards',
                                  _cards.length.toString(),
                                  Icons.style_rounded,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: AppTheme.dividerColor,
                                ),
                                _buildStatItem(
                                  'Min Required',
                                  '5',
                                  Icons.check_circle_rounded,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: AppTheme.dividerColor,
                                ),
                                _buildStatItem(
                                  'Status',
                                  _cards.length >= 5 ? 'Ready' : 'Incomplete',
                                  _cards.length >= 5
                                      ? Icons.check_rounded
                                      : Icons.warning_rounded,
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 800.ms),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),

          // Bottom Save Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDeck,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.editDeckId != null
                                    ? Icons.save_rounded
                                    : Icons.add_rounded,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.editDeckId != null
                                    ? 'Save Changes'
                                    : 'Create Deck',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _selectedColor),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _selectedColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildCardInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _cardController,
            decoration: InputDecoration(
              labelText: _editingCardIndex != null ? 'Edit Card' : 'Add Card',
              hintText: 'Enter card text',
              prefixIcon: Icon(Icons.add_card_rounded, color: _selectedColor),
              suffixIcon:
                  _editingCardIndex != null
                      ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _editingCardIndex = null;
                            _cardController.clear();
                          });
                        },
                      )
                      : null,
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.dividerColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _selectedColor, width: 2),
              ),
            ),
            onSubmitted: (_) => _addCard(),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _selectedColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _addCard,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  _editingCardIndex != null
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1);
  }

  Widget _buildCardItem(int index, String card) {
    return Container(
      key: ValueKey(card),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _editingCardIndex == index
                  ? _selectedColor
                  : AppTheme.dividerColor,
          width: _editingCardIndex == index ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _selectedColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: _selectedColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(card, style: Theme.of(context).textTheme.bodyLarge),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_rounded, color: AppTheme.primaryColor),
              onPressed: () => _editCard(index),
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded, color: AppTheme.errorColor),
              onPressed: () => _removeCard(index),
            ),
            Icon(Icons.drag_handle_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.1);
  }

  Widget _buildAppearanceCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Center(child: FaIcon(icon, color: color, size: 28)),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to change',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCard(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to change',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: AppTheme.primaryColor, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final isReady = label == 'Status' && value == 'Ready';
    final color = isReady ? AppTheme.successColor : _selectedColor;

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  void _showDeckOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_rounded),
                    title: const Text('Export Deck'),
                    onTap: () {
                      Navigator.pop(context);
                      _exportDeck();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_rounded,
                      color: AppTheme.errorColor,
                    ),
                    title: Text(
                      'Delete Deck',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDelete();
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Deck?'),
            content: const Text(
              'Are you sure you want to delete this deck? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await context
                      .read<DeckProvider>()
                      .deleteCustomDeck(widget.editDeckId!);
                  if (success && mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
    );
  }

  void _exportDeck() async {
    if (widget.editDeckId == null) return;

    final deck = context.read<DeckProvider>().getDeckById(widget.editDeckId!);
    if (deck == null) return;

    _hapticService.lightImpact();
    _audioService.playSuccess();

    await DeckShareHelper.copyDeckToClipboard(deck);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(child: Text('Deck code copied to clipboard!')),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showImportDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ImportDeckDialog(),
    );

    if (result == true && mounted) {
      // Navigate to management screen to see imported deck
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CustomDeckManagementScreen(),
        ),
      );
    }
  }

  void _showAIGenerateDialog() {
    // TODO: Implement AI generation functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI generation coming soon!')));
  }
}

class _PatternPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _PatternPainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    final spacing = 30.0;
    final progress = animation.value;

    for (double i = -spacing; i < size.width + spacing; i += spacing) {
      final offset = progress * spacing;
      canvas.drawLine(
        Offset(i + offset, 0),
        Offset(i + offset - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) => true;
}

extension NullCheck on String? {
  bool get isNull => this == null;
}
