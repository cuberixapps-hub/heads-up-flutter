import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

class IconPickerDialog extends StatefulWidget {
  final IconData selectedIcon;
  final Color? accentColor;

  const IconPickerDialog({
    super.key,
    required this.selectedIcon,
    this.accentColor,
  });

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog>
    with SingleTickerProviderStateMixin {
  late IconData _selectedIcon;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _hapticService = HapticService();

  // Tap states for interactive animations
  bool _selectButtonPressed = false;
  bool _closeButtonPressed = false;

  late Color _accentColor;

  final Map<String, List<IconData>> _iconCategories = {
    'All': [],
    'Games': [
      FontAwesomeIcons.dice,
      FontAwesomeIcons.diceOne,
      FontAwesomeIcons.diceTwo,
      FontAwesomeIcons.diceThree,
      FontAwesomeIcons.diceFour,
      FontAwesomeIcons.diceFive,
      FontAwesomeIcons.diceSix,
      FontAwesomeIcons.gamepad,
      FontAwesomeIcons.chess,
      FontAwesomeIcons.chessKnight,
      FontAwesomeIcons.chessRook,
      FontAwesomeIcons.puzzlePiece,
      Icons.casino_rounded,
      Icons.sports_esports_rounded,
    ],
    'Sports': [
      FontAwesomeIcons.football,
      FontAwesomeIcons.basketball,
      FontAwesomeIcons.baseball,
      FontAwesomeIcons.bowlingBall,
      FontAwesomeIcons.golfBallTee,
      FontAwesomeIcons.tableTennisPaddleBall,
      FontAwesomeIcons.volleyball,
      FontAwesomeIcons.dumbbell,
      Icons.sports_soccer_rounded,
      Icons.sports_tennis_rounded,
      Icons.sports_hockey_rounded,
      Icons.sports_golf_rounded,
      Icons.fitness_center_rounded,
    ],
    'Entertainment': [
      FontAwesomeIcons.music,
      FontAwesomeIcons.film,
      FontAwesomeIcons.tv,
      FontAwesomeIcons.microphone,
      FontAwesomeIcons.guitar,
      FontAwesomeIcons.drum,
      FontAwesomeIcons.headphones,
      FontAwesomeIcons.ticket,
      Icons.movie_rounded,
      Icons.theater_comedy_rounded,
      Icons.music_note_rounded,
      Icons.mic_rounded,
    ],
    'Food': [
      FontAwesomeIcons.burger,
      FontAwesomeIcons.pizzaSlice,
      FontAwesomeIcons.iceCream,
      FontAwesomeIcons.cookie,
      FontAwesomeIcons.cake,
      FontAwesomeIcons.coffee,
      FontAwesomeIcons.martiniGlass,
      FontAwesomeIcons.beer,
      Icons.restaurant_rounded,
      Icons.local_pizza_rounded,
      Icons.cake_rounded,
      Icons.local_bar_rounded,
    ],
    'Animals': [
      FontAwesomeIcons.dog,
      FontAwesomeIcons.cat,
      FontAwesomeIcons.horse,
      FontAwesomeIcons.fish,
      FontAwesomeIcons.dove,
      FontAwesomeIcons.dragon,
      FontAwesomeIcons.spider,
      FontAwesomeIcons.bug,
      Icons.pets_rounded,
    ],
    'Nature': [
      FontAwesomeIcons.tree,
      FontAwesomeIcons.leaf,
      FontAwesomeIcons.seedling,
      FontAwesomeIcons.mountain,
      FontAwesomeIcons.water,
      FontAwesomeIcons.fire,
      FontAwesomeIcons.sun,
      FontAwesomeIcons.moon,
      FontAwesomeIcons.cloud,
      FontAwesomeIcons.snowflake,
      Icons.park_rounded,
      Icons.nature_rounded,
      Icons.eco_rounded,
    ],
    'Objects': [
      FontAwesomeIcons.solidStar,
      FontAwesomeIcons.heart,
      FontAwesomeIcons.solidHeart,
      FontAwesomeIcons.gem,
      FontAwesomeIcons.crown,
      FontAwesomeIcons.trophy,
      FontAwesomeIcons.medal,
      FontAwesomeIcons.gift,
      FontAwesomeIcons.bell,
      FontAwesomeIcons.lightbulb,
      FontAwesomeIcons.key,
      FontAwesomeIcons.lock,
      FontAwesomeIcons.magnet,
      FontAwesomeIcons.compass,
      Icons.star_rounded,
      Icons.favorite_rounded,
      Icons.emoji_events_rounded,
    ],
    'Tech': [
      FontAwesomeIcons.laptop,
      FontAwesomeIcons.mobile,
      FontAwesomeIcons.desktop,
      FontAwesomeIcons.keyboard,
      FontAwesomeIcons.robot,
      FontAwesomeIcons.microchip,
      FontAwesomeIcons.wifi,
      FontAwesomeIcons.bluetooth,
      Icons.computer_rounded,
      Icons.phone_android_rounded,
      Icons.smart_toy_rounded,
    ],
    'Travel': [
      FontAwesomeIcons.plane,
      FontAwesomeIcons.car,
      FontAwesomeIcons.train,
      FontAwesomeIcons.ship,
      FontAwesomeIcons.rocket,
      FontAwesomeIcons.bicycle,
      FontAwesomeIcons.motorcycle,
      FontAwesomeIcons.helicopter,
      Icons.flight_rounded,
      Icons.directions_car_rounded,
      Icons.directions_boat_rounded,
    ],
  };

  List<IconData> get _allIcons {
    if (_iconCategories['All']!.isEmpty) {
      for (var category in _iconCategories.keys) {
        if (category != 'All') {
          _iconCategories['All']!.addAll(_iconCategories[category]!);
        }
      }
    }
    return _iconCategories['All']!;
  }

  List<IconData> get _filteredIcons {
    List<IconData> icons =
        _selectedCategory == 'All'
            ? _allIcons
            : _iconCategories[_selectedCategory] ?? [];

    if (_searchQuery.isEmpty) {
      return icons;
    }
    return icons;
  }

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon;
    _accentColor = widget.accentColor ?? const Color(0xFF6366F1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 40.s),
      child: Container(
            constraints: BoxConstraints(maxWidth: 400.s, maxHeight: 620.s),
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
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildCategoryChips(),
                Expanded(child: _buildIconsGrid()),
                _buildPreviewSection(),
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
              'Choose Icon',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.s, 14.s, 18.s, 12.s),
      child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12.s),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Search icons...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20.s,
                  color: Colors.white.withOpacity(0.4),
                ),
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.s,
                  vertical: 12.s,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onTapOutside:
                  (_) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
          )
          .animate()
          .fadeIn(delay: 150.ms, duration: 400.ms)
          .slideY(begin: 0.03, end: 0),
    );
  }

  Widget _buildCategoryChips() {
    final categories = _iconCategories.keys.toList();

    return SizedBox(
      height: 38.s,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 18.s),
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
                      horizontal: 14.s,
                      vertical: 8.s,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isSelected
                              ? LinearGradient(
                                colors: [
                                  _accentColor,
                                  _accentColor.withOpacity(0.8),
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
                                  color: _accentColor.withOpacity(0.3),
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
                                  Icons.check_rounded,
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
                  delay: (200 + index * 30).ms,
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                )
                .slideX(begin: 0.05, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }

  Widget _buildIconsGrid() {
    final icons = _filteredIcons;

    return GridView.builder(
      padding: EdgeInsets.all(18.s),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10.s,
        mainAxisSpacing: 10.s,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        final isSelected = icon == _selectedIcon;

        return _IconCell(
          icon: icon,
          isSelected: isSelected,
          accentColor: _accentColor,
          onTap: () {
            _hapticService.lightImpact();
            setState(() {
              _selectedIcon = icon;
            });
          },
          animationDelay: (index * 15).ms,
        );
      },
    );
  }

  Widget _buildPreviewSection() {
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
              // Preview icon container
              Container(
                width: 56.s,
                height: 56.s,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _accentColor.withOpacity(0.15),
                      _accentColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14.s),
                  border: Border.all(
                    color: _accentColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: FaIcon(_selectedIcon, color: _accentColor, size: 24.s)
                      .animate(key: ValueKey(_selectedIcon))
                      .fadeIn(duration: 200.ms)
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        curve: Curves.easeOutBack,
                      ),
                ),
              ),
              SizedBox(width: 14.s),
              // Preview text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selected Icon',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 3.s),
                    Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Select button
              GestureDetector(
                onTapDown: (_) => setState(() => _selectButtonPressed = true),
                onTapUp: (_) => setState(() => _selectButtonPressed = false),
                onTapCancel: () => setState(() => _selectButtonPressed = false),
                onTap: () {
                  _hapticService.mediumImpact();
                  Navigator.pop(context, _selectedIcon);
                },
                child: AnimatedScale(
                      scale: _selectButtonPressed ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.s,
                          vertical: 12.s,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _accentColor,
                              _accentColor.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12.s),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.35),
                              blurRadius: 16.s,
                              offset: Offset(0, 6.s),
                            ),
                          ],
                        ),
                        child: Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 350.ms, duration: 400.ms)
        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }
}

/// Individual icon cell with tap animation
class _IconCell extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _IconCell({
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  State<_IconCell> createState() => _IconCellState();
}

class _IconCellState extends State<_IconCell> {
  bool _isPressed = false;

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
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient:
                    widget.isSelected
                        ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.accentColor,
                            widget.accentColor.withOpacity(0.8),
                          ],
                        )
                        : null,
                color:
                    widget.isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.s),
                border: Border.all(
                  color:
                      widget.isSelected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow:
                    widget.isSelected
                        ? [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.35),
                            blurRadius: 12.s,
                            offset: Offset(0, 4.s),
                          ),
                        ]
                        : null,
              ),
              child: Center(
                child: FaIcon(
                  widget.icon,
                  color:
                      widget.isSelected
                          ? Colors.white.withOpacity(0.95)
                          : Colors.white.withOpacity(0.5),
                  size: 20.s,
                ),
              ),
            ),
          )
          .animate()
          .fadeIn(delay: widget.animationDelay, duration: 250.ms)
          .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutCubic),
    );
  }
}
