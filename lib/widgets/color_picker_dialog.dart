import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 50,
              offset: const Offset(0, 25),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium Header
            _buildPremiumHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    
                    // Preview Card
                    _buildPreviewCard(),

                    const SizedBox(height: 24),

                    // Category Tabs
                    _buildCategoryTabs(),

                    const SizedBox(height: 24),

                    // Color Grid
                    _buildColorGrid(),

                    const SizedBox(height: 20),

                    // Shades Section
                    _buildShadesSection(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.88, 0.88),
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF1A1A1A).withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Text(
              'Choose Color',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A).withOpacity(0.95),
                letterSpacing: -0.8,
                height: 1.2,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .slideX(begin: -0.02, curve: Curves.easeOutCubic),
          ),

          // Close Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1A1A1A).withOpacity(0.06),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: const Color(0xFF1A1A1A).withOpacity(0.7),
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutCubic)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.easeOutCubic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _selectedColor,
            _darken(_selectedColor, 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.palette_outlined,
              color: Colors.white,
              size: 28,
            ),
          )
              .animate(
                key: ValueKey(_selectedColor.value),
              )
              .fadeIn(duration: 250.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.7, 0.7),
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 12),
          Text(
            'Preview',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 500.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _colorCategories.keys.length,
        itemBuilder: (context, index) {
          final category = _colorCategories.keys.elementAt(index);
          final isSelected = _selectedCategory == category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            _selectedColor.withOpacity(0.9),
                            _selectedColor,
                          ],
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF1A1A1A).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : const Color(0xFF1A1A1A).withOpacity(0.08),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _selectedColor.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.95),
                        )
                            .animate(
                              key: ValueKey(category),
                            )
                            .fadeIn(duration: 200.ms)
                            .scale(
                              begin: const Offset(0.6, 0.6),
                              curve: Curves.easeOutBack,
                            ),
                      ),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white.withOpacity(0.95)
                            : const Color(0xFF1A1A1A).withOpacity(0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(
                  delay: (200 + index * 50).ms,
                  duration: 400.ms,
                  curve: Curves.easeOutCubic,
                )
                .slideX(begin: 0.1, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }

  Widget _buildColorGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _currentColors.length,
      itemBuilder: (context, index) {
        final color = _currentColors[index];
        final isSelected = color.value == _selectedColor.value;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  _darken(color, 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.15),
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isSelected ? 0.45 : 0.25),
                  blurRadius: isSelected ? 16 : 8,
                  offset: Offset(0, isSelected ? 8 : 4),
                ),
              ],
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: color,
                        size: 20,
                      ),
                    )
                        .animate(
                          key: ValueKey(color.value),
                        )
                        .fadeIn(duration: 200.ms, curve: Curves.easeOut)
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          curve: Curves.easeOutBack,
                        ),
                  )
                : null,
          )
              .animate()
              .fadeIn(
                delay: (index * 25).ms,
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              )
              .scale(
                begin: const Offset(0.7, 0.7),
                curve: Curves.easeOutCubic,
              ),
        );
      },
    );
  }

  Widget _buildShadesSection() {
    final shades = [
      _darken(_selectedColor, 0.3),
      _darken(_selectedColor, 0.15),
      _selectedColor,
      _lighten(_selectedColor, 0.15),
      _lighten(_selectedColor, 0.3),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1A1A1A).withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: shades.asMap().entries.map((entry) {
          final index = entry.key;
          final color = entry.value;
          final isSelected = color.value == _selectedColor.value;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedColor = color;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1A1A1A).withOpacity(0.8)
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                      )
                          .animate(
                            key: ValueKey(color.value),
                          )
                          .fadeIn(duration: 150.ms)
                          .scale(
                            begin: const Offset(0.3, 0.3),
                            curve: Curves.easeOutBack,
                          ),
                    )
                  : null,
            )
                .animate()
                .fadeIn(
                  delay: (300 + index * 40).ms,
                  duration: 400.ms,
                  curve: Curves.easeOutCubic,
                )
                .scale(
                  begin: const Offset(0.6, 0.6),
                  curve: Curves.easeOutCubic,
                ),
          );
        }).toList(),
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 500.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFF1A1A1A).withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Cancel Button
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF1A1A1A).withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A).withOpacity(0.7),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: 450.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .slideY(begin: 0.15, curve: Curves.easeOutCubic),
            ),
          ),

          const SizedBox(width: 12),

          // Select Button
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, _selectedColor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _selectedColor,
                      _darken(_selectedColor, 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Select Color',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: 500.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .slideY(begin: 0.15, curve: Curves.easeOutCubic),
            ),
          ),
        ],
      ),
    );
  }
}
