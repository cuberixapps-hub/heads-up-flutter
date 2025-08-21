import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_theme.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color selectedColor;

  const ColorPickerDialog({super.key, required this.selectedColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog>
    with SingleTickerProviderStateMixin {
  late Color _selectedColor;
  late AnimationController _animationController;
  String _selectedCategory = 'Material';

  final Map<String, List<Color>> _colorCategories = {
    'Material': [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ],
    'Vibrant': [
      const Color(0xFFFF006E),
      const Color(0xFFFB5607),
      const Color(0xFFFFBE0B),
      const Color(0xFF8338EC),
      const Color(0xFF3A86FF),
      const Color(0xFF06FFB4),
      const Color(0xFFFF4365),
      const Color(0xFF00D9FF),
      const Color(0xFFFFC300),
      const Color(0xFFFF5E5B),
      const Color(0xFF23F0C7),
      const Color(0xFFFFD23F),
    ],
    'Pastel': [
      const Color(0xFFFFB3BA),
      const Color(0xFFFFDFBA),
      const Color(0xFFFFFFBA),
      const Color(0xFFBAFFC9),
      const Color(0xFFBAE1FF),
      const Color(0xFFE0BBE4),
      const Color(0xFFFEC8D8),
      const Color(0xFFD4A5A5),
      const Color(0xFFA8DADC),
      const Color(0xFFE6F3FF),
      const Color(0xFFFFF0F3),
      const Color(0xFFE8DFF5),
    ],
    'Dark': [
      const Color(0xFF2D3436),
      const Color(0xFF4B0082),
      const Color(0xFF191970),
      const Color(0xFF2C3E50),
      const Color(0xFF34495E),
      const Color(0xFF1B1B2F),
      const Color(0xFF162447),
      const Color(0xFF1F4068),
      const Color(0xFF16213E),
      const Color(0xFF0F3460),
      const Color(0xFF533483),
      const Color(0xFF3D0E61),
    ],
    'Nature': [
      const Color(0xFF228B22),
      const Color(0xFF32CD32),
      const Color(0xFF90EE90),
      const Color(0xFF8FBC8F),
      const Color(0xFF3CB371),
      const Color(0xFF2E8B57),
      const Color(0xFF808000),
      const Color(0xFF6B8E23),
      const Color(0xFF556B2F),
      const Color(0xFF8B4513),
      const Color(0xFFD2691E),
      const Color(0xFFCD853F),
    ],
    'Ocean': [
      const Color(0xFF006994),
      const Color(0xFF0077BE),
      const Color(0xFF00A8CC),
      const Color(0xFF05668D),
      const Color(0xFF028090),
      const Color(0xFF00A896),
      const Color(0xFF02C39A),
      const Color(0xFF00B4D8),
      const Color(0xFF0096C7),
      const Color(0xFF0077B6),
      const Color(0xFF023E8A),
      const Color(0xFF03045E),
    ],
  };

  List<Color> get _currentColors => _colorCategories[_selectedCategory] ?? [];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _darken(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return darkened.toColor();
  }

  Color _lighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return lightened.toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
          backgroundColor: AppTheme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Color',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Preview Card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_selectedColor, _selectedColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.palette_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Preview',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

                const SizedBox(height: 20),

                // Category Tabs
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children:
                        _colorCategories.keys.map((category) {
                          final isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                  label: Text(category),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                  },
                                  selectedColor: _selectedColor,
                                  backgroundColor: AppTheme.surfaceColor,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: (50).ms)
                                .scale(begin: const Offset(0.8, 0.8)),
                          );
                        }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Color Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: _currentColors.length,
                    itemBuilder: (context, index) {
                      final color = _currentColors[index];
                      final isSelected = color == _selectedColor;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                        child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, _darken(color, 0.1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : color.withOpacity(0.5),
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(
                                      isSelected ? 0.6 : 0.3,
                                    ),
                                    blurRadius: isSelected ? 12 : 6,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child:
                                  isSelected
                                      ? Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: color,
                                            size: 20,
                                          ),
                                        ),
                                      )
                                      : null,
                            )
                            .animate()
                            .fadeIn(delay: (index * 20).ms)
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              curve: Curves.easeOutBack,
                            ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Shades Section
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildShadeOption(_darken(_selectedColor, 0.2)),
                      _buildShadeOption(_darken(_selectedColor, 0.1)),
                      _buildShadeOption(_selectedColor),
                      _buildShadeOption(_lighten(_selectedColor, 0.1)),
                      _buildShadeOption(_lighten(_selectedColor, 0.2)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: AppTheme.dividerColor),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _selectedColor);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Select Color',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }

  Widget _buildShadeOption(Color color) {
    final isSelected = color == _selectedColor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child:
            isSelected
                ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}
