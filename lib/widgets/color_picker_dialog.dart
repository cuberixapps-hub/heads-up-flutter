import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color selectedColor;

  const ColorPickerDialog({super.key, required this.selectedColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;
  String _selectedCategory = 'Material';
  final _hapticService = HapticService();

  // Tap states for interactive animations
  bool _selectButtonPressed = false;
  bool _cancelButtonPressed = false;
  bool _closeButtonPressed = false;

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
      insetPadding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 40.s),
      child: Container(
            constraints: BoxConstraints(maxWidth: 400.s, maxHeight: 650.s),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(24.s),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40.s,
                  offset: Offset(0, 20.s),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 18.s),
                    child: Column(
                      children: [
                        SizedBox(height: 6.s),
                        _buildPreviewCard(),
                        SizedBox(height: 20.s),
                        _buildCategoryTabs(),
                        SizedBox(height: 18.s),
                        _buildColorGrid(),
                        SizedBox(height: 18.s),
                        _buildShadesSection(),
                        SizedBox(height: 18.s),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(),
              ],
            ),
          )
          .animate()
          .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
          .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutCubic),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(22.s, 20.s, 16.s, 16.s),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Choose Color',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.95),
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.02, end: 0),
          ),
          GestureDetector(
            onTapDown: (_) => setState(() => _closeButtonPressed = true),
            onTapUp: (_) => setState(() => _closeButtonPressed = false),
            onTapCancel: () => setState(() => _closeButtonPressed = false),
            onTap: () {
              _hapticService.lightImpact();
              Navigator.pop(context);
            },
            child: AnimatedScale(
                  scale: _closeButtonPressed ? 0.9 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    width: 36.s,
                    height: 36.s,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10.s),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18.s,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.easeOutBack,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 120.s,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_selectedColor, _darken(_selectedColor, 0.18)],
            ),
            borderRadius: BorderRadius.circular(18.s),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: _selectedColor.withOpacity(0.35),
                blurRadius: 24.s,
                offset: Offset(0, 10.s),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                    width: 48.s,
                    height: 48.s,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      color: Colors.white.withOpacity(0.95),
                      size: 24.s,
                    ),
                  )
                  .animate(key: ValueKey(_selectedColor.value))
                  .fadeIn(duration: 200.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    curve: Curves.easeOutBack,
                  ),
              SizedBox(height: 10.s),
              Text(
                'Preview',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 150.ms, duration: 450.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildCategoryTabs() {
    final categories = _colorCategories.keys.toList();

    return SizedBox(
      height: 38.s,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(right: 8.s),
            child: GestureDetector(
                  onTap: () {
                    _hapticService.lightImpact();
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.s,
                      vertical: 8.s,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isSelected
                              ? LinearGradient(
                                colors: [
                                  _selectedColor.withOpacity(0.9),
                                  _selectedColor,
                                ],
                              )
                              : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10.s),
                      border: Border.all(
                        color:
                            isSelected
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: _selectedColor.withOpacity(0.3),
                                  blurRadius: 12.s,
                                  offset: Offset(0, 4.s),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Padding(
                            padding: EdgeInsets.only(right: 6.s),
                            child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 14.s,
                                  color: Colors.white.withOpacity(0.9),
                                )
                                .animate(key: ValueKey('check_$category'))
                                .fadeIn(duration: 200.ms)
                                .scale(
                                  begin: const Offset(0.5, 0.5),
                                  curve: Curves.easeOutBack,
                                ),
                          ),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color:
                                isSelected
                                    ? Colors.white.withOpacity(0.95)
                                    : Colors.white.withOpacity(0.55),
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(
                  delay: (200 + index * 40).ms,
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                )
                .slideX(begin: 0.05, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }

  Widget _buildColorGrid() {
    final colors = _currentColors;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10.s,
        mainAxisSpacing: 10.s,
        childAspectRatio: 1.0,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        final color = colors[index];
        final isSelected = color.value == _selectedColor.value;

        return _ColorCell(
          color: color,
          isSelected: isSelected,
          onTap: () {
            _hapticService.lightImpact();
            setState(() {
              _selectedColor = color;
            });
          },
          animationDelay: (index * 25).ms,
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
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 12.s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14.s),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                shades.asMap().entries.map((entry) {
                  final index = entry.key;
                  final color = entry.value;
                  final isSelected = color.value == _selectedColor.value;

                  return GestureDetector(
                    onTap: () {
                      _hapticService.lightImpact();
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 40.s,
                          height: 40.s,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.35),
                                blurRadius: 8.s,
                                offset: Offset(0, 3.s),
                              ),
                            ],
                          ),
                          child:
                              isSelected
                                  ? Center(
                                    child: Container(
                                          width: 8.s,
                                          height: 8.s,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                        .animate(key: ValueKey('shade_$index'))
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
                          delay: (350 + index * 40).ms,
                          duration: 350.ms,
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
        .fadeIn(delay: 400.ms, duration: 450.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(18.s, 14.s, 18.s, 18.s),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Cancel Button
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _cancelButtonPressed = true),
              onTapUp: (_) => setState(() => _cancelButtonPressed = false),
              onTapCancel: () => setState(() => _cancelButtonPressed = false),
              onTap: () {
                _hapticService.lightImpact();
                Navigator.pop(context);
              },
              child: AnimatedScale(
                    scale: _cancelButtonPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.s),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12.s),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 450.ms, duration: 400.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic),
            ),
          ),
          SizedBox(width: 10.s),
          // Select Button
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _selectButtonPressed = true),
              onTapUp: (_) => setState(() => _selectButtonPressed = false),
              onTapCancel: () => setState(() => _selectButtonPressed = false),
              onTap: () {
                _hapticService.mediumImpact();
                Navigator.pop(context, _selectedColor);
              },
              child: AnimatedScale(
                    scale: _selectButtonPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(vertical: 14.s),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _selectedColor,
                            _darken(_selectedColor, 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.s),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedColor.withOpacity(0.35),
                            blurRadius: 16.s,
                            offset: Offset(0, 6.s),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Select Color',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 400.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual color cell with tap animation
class _ColorCell extends StatefulWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _ColorCell({
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  State<_ColorCell> createState() => _ColorCellState();
}

class _ColorCellState extends State<_ColorCell> {
  bool _isPressed = false;

  Color _darken(Color color, [double amount = 0.12]) {
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return darkened.toColor();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
            scale: _isPressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.color, _darken(widget.color)],
                ),
                borderRadius: BorderRadius.circular(14.s),
                border: Border.all(
                  color:
                      widget.isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white.withOpacity(0.1),
                  width: widget.isSelected ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(
                      widget.isSelected ? 0.45 : 0.25,
                    ),
                    blurRadius: widget.isSelected ? 14.s : 8.s,
                    offset: Offset(0, widget.isSelected ? 6.s : 3.s),
                  ),
                ],
              ),
              child:
                  widget.isSelected
                      ? Center(
                        child: Container(
                              width: 28.s,
                              height: 28.s,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: widget.color,
                                size: 18.s,
                              ),
                            )
                            .animate(
                              key: ValueKey('selected_${widget.color.value}'),
                            )
                            .fadeIn(duration: 200.ms)
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              curve: Curves.easeOutBack,
                            ),
                      )
                      : null,
            ),
          )
          .animate()
          .fadeIn(delay: widget.animationDelay, duration: 280.ms)
          .scale(begin: const Offset(0.75, 0.75), curve: Curves.easeOutCubic),
    );
  }
}
