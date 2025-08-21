import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_theme.dart';
import '../services/haptic_service.dart';

class ColorPickerWidget extends StatefulWidget {
  final Color selectedColor;
  final Function(Color) onColorSelected;

  const ColorPickerWidget({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget>
    with SingleTickerProviderStateMixin {
  final _hapticService = HapticService();
  late AnimationController _animationController;
  late Color _currentColor;

  // Predefined color palettes
  final List<ColorPalette> _colorPalettes = [
    ColorPalette(
      name: 'Vibrant',
      colors: [
        Colors.red,
        Colors.pink,
        Colors.purple,
        Colors.deepPurple,
        Colors.indigo,
        Colors.blue,
        Colors.lightBlue,
        Colors.cyan,
      ],
    ),
    ColorPalette(
      name: 'Nature',
      colors: [
        Colors.green,
        Colors.lightGreen,
        Colors.lime,
        const Color(0xFF8BC34A),
        const Color(0xFF4CAF50),
        const Color(0xFF009688),
        const Color(0xFF00BCD4),
        const Color(0xFF006064),
      ],
    ),
    ColorPalette(
      name: 'Warm',
      colors: [
        Colors.orange,
        Colors.deepOrange,
        Colors.amber,
        const Color(0xFFFF9800),
        const Color(0xFFFF5722),
        const Color(0xFFFF6F00),
        const Color(0xFFFFAB00),
        const Color(0xFFFFD600),
      ],
    ),
    ColorPalette(
      name: 'Cool',
      colors: [
        const Color(0xFF1E88E5),
        const Color(0xFF039BE5),
        const Color(0xFF00ACC1),
        const Color(0xFF00897B),
        const Color(0xFF43A047),
        const Color(0xFF7CB342),
        const Color(0xFF9CCC65),
        const Color(0xFF26A69A),
      ],
    ),
    ColorPalette(
      name: 'Pastel',
      colors: [
        const Color(0xFFFFCDD2),
        const Color(0xFFF8BBD0),
        const Color(0xFFE1BEE7),
        const Color(0xFFD1C4E9),
        const Color(0xFFC5CAE9),
        const Color(0xFFBBDEFB),
        const Color(0xFFB3E5FC),
        const Color(0xFFB2DFDB),
      ],
    ),
    ColorPalette(
      name: 'Dark',
      colors: [
        const Color(0xFF37474F),
        const Color(0xFF455A64),
        const Color(0xFF546E7A),
        const Color(0xFF616161),
        const Color(0xFF6D4C41),
        const Color(0xFF5D4037),
        const Color(0xFF4E342E),
        const Color(0xFF3E2723),
      ],
    ),
  ];

  // Custom color values for HSV slider
  double _hue = 0.0;
  double _saturation = 1.0;
  double _value = 1.0;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.selectedColor;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    // Initialize HSV values from selected color
    final hsv = HSVColor.fromColor(widget.selectedColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectColor(Color color) {
    _hapticService.lightImpact();
    setState(() {
      _currentColor = color;
      final hsv = HSVColor.fromColor(color);
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    });
  }

  void _updateCustomColor() {
    setState(() {
      _currentColor =
          HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Choose a Color',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onColorSelected(_currentColor);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: _currentColor,
                    foregroundColor: _getContrastingColor(_currentColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ).animate().fadeIn(),

          // Color preview
          _buildColorPreview(),

          const SizedBox(height: 20),

          // Tab content
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: _currentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: _getContrastingColor(_currentColor),
                      unselectedLabelColor: AppTheme.textPrimary,
                      tabs: const [Tab(text: 'Palettes'), Tab(text: 'Custom')],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab views
                  Expanded(
                    child: TabBarView(
                      children: [_buildPalettesView(), _buildCustomColorView()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _currentColor.withOpacity(0.3),
            _currentColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _currentColor.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          // Color circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _currentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _currentColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
          ),

          const SizedBox(width: 20),

          // Color info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Color',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${_currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildColorValue('R', _currentColor.red),
                    const SizedBox(width: 12),
                    _buildColorValue('G', _currentColor.green),
                    const SizedBox(width: 12),
                    _buildColorValue('B', _currentColor.blue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1);
  }

  Widget _buildColorValue(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildPalettesView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _colorPalettes.length,
      itemBuilder: (context, index) {
        final palette = _colorPalettes[index];
        return _buildPaletteSection(palette)
            .animate()
            .fadeIn(delay: Duration(milliseconds: 50 * index))
            .slideX(begin: 0.1);
      },
    );
  }

  Widget _buildPaletteSection(ColorPalette palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            palette.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: palette.colors.length,
              itemBuilder: (context, index) {
                final color = palette.colors[index];
                final isSelected = color == _currentColor;

                return GestureDetector(
                  onTap: () => _selectColor(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: isSelected ? 3 : 0,
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
                            ? Icon(
                              Icons.check,
                              color: _getContrastingColor(color),
                              size: 20,
                            )
                            : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomColorView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hue slider
          _buildSliderSection('Hue', _hue, 0, 360, (value) {
            setState(() {
              _hue = value;
              _updateCustomColor();
            });
          }, _buildHueGradient()),

          const SizedBox(height: 24),

          // Saturation slider
          _buildSliderSection('Saturation', _saturation, 0, 1, (value) {
            setState(() {
              _saturation = value;
              _updateCustomColor();
            });
          }, _buildSaturationGradient()),

          const SizedBox(height: 24),

          // Value/Brightness slider
          _buildSliderSection('Brightness', _value, 0, 1, (value) {
            setState(() {
              _value = value;
              _updateCustomColor();
            });
          }, _buildValueGradient()),

          const SizedBox(height: 32),

          // Recent colors
          _buildRecentColors(),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildSliderSection(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    Gradient gradient,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              label == 'Hue'
                  ? '${value.round()}°'
                  : '${(value * 100).round()}%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 40,
              trackShape: const RectangularSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              thumbColor: Colors.white,
              overlayColor: Colors.black.withOpacity(0.1),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Gradient _buildHueGradient() {
    return LinearGradient(
      colors: List.generate(
        10,
        (index) => HSVColor.fromAHSV(1.0, index * 36.0, 1.0, 1.0).toColor(),
      ),
    );
  }

  Gradient _buildSaturationGradient() {
    return LinearGradient(
      colors: [
        HSVColor.fromAHSV(1.0, _hue, 0.0, _value).toColor(),
        HSVColor.fromAHSV(1.0, _hue, 1.0, _value).toColor(),
      ],
    );
  }

  Gradient _buildValueGradient() {
    return LinearGradient(
      colors: [
        HSVColor.fromAHSV(1.0, _hue, _saturation, 0.0).toColor(),
        HSVColor.fromAHSV(1.0, _hue, _saturation, 1.0).toColor(),
      ],
    );
  }

  Widget _buildRecentColors() {
    // In a real app, you'd store and retrieve recent colors from preferences
    final recentColors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Colors',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children:
              recentColors.map((color) {
                final isSelected = color == _currentColor;
                return GestureDetector(
                  onTap: () => _selectColor(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child:
                        isSelected
                            ? Icon(
                              Icons.check,
                              color: _getContrastingColor(color),
                              size: 16,
                            )
                            : null,
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Color _getContrastingColor(Color color) {
    // Calculate luminance and return black or white for contrast
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class ColorPalette {
  final String name;
  final List<Color> colors;

  ColorPalette({required this.name, required this.colors});
}
