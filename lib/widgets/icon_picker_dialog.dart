import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_theme.dart';

class IconPickerDialog extends StatefulWidget {
  final IconData selectedIcon;

  const IconPickerDialog({super.key, required this.selectedIcon});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  late IconData _selectedIcon;
  String _searchQuery = '';
  String _selectedCategory = 'All';

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
    'Education': [
      FontAwesomeIcons.book,
      FontAwesomeIcons.graduationCap,
      FontAwesomeIcons.pencil,
      FontAwesomeIcons.ruler,
      FontAwesomeIcons.calculator,
      FontAwesomeIcons.microscope,
      FontAwesomeIcons.atom,
      Icons.school_rounded,
      Icons.science_rounded,
      Icons.psychology_rounded,
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
    'Misc': [
      FontAwesomeIcons.flag,
      FontAwesomeIcons.mapPin,
      FontAwesomeIcons.globe,
      FontAwesomeIcons.language,
      FontAwesomeIcons.palette,
      FontAwesomeIcons.brush,
      FontAwesomeIcons.camera,
      FontAwesomeIcons.image,
      FontAwesomeIcons.wandMagicSparkles,
      FontAwesomeIcons.bolt,
      FontAwesomeIcons.fire,
      FontAwesomeIcons.snowman,
      Icons.flag_rounded,
      Icons.public_rounded,
      Icons.palette_rounded,
      Icons.auto_awesome_rounded,
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

    // Simple search by icon name (would need more sophisticated search in production)
    return icons;
  }

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon;
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
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Icon',
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

                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search icons...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children:
                        _iconCategories.keys.map((category) {
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
                                  selectedColor: AppTheme.primaryColor,
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
                const SizedBox(height: 16),

                // Icons Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _filteredIcons.length,
                    itemBuilder: (context, index) {
                      final icon = _filteredIcons[index];
                      final isSelected = icon == _selectedIcon;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIcon = icon;
                          });
                        },
                        child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.dividerColor,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                        : [],
                              ),
                              child: Center(
                                child: FaIcon(
                                  icon,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                  size: 24,
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: (index * 10).ms)
                            .scale(begin: const Offset(0.8, 0.8)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Preview and Confirm
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: FaIcon(
                            _selectedIcon,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Icon',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Preview',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _selectedIcon);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Select',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }
}
