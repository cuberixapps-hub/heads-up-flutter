import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/app_theme.dart';
import '../services/haptic_service.dart';

class IconPickerWidget extends StatefulWidget {
  final IconData selectedIcon;
  final Color selectedColor;
  final Function(IconData) onIconSelected;

  const IconPickerWidget({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconSelected,
  });

  @override
  State<IconPickerWidget> createState() => _IconPickerWidgetState();
}

class _IconPickerWidgetState extends State<IconPickerWidget>
    with SingleTickerProviderStateMixin {
  final _hapticService = HapticService();
  late TabController _tabController;

  // Icon categories
  final Map<String, List<IconData>> _iconCategories = {
    'Popular': [
      FontAwesomeIcons.solidStar,
      FontAwesomeIcons.solidHeart,
      FontAwesomeIcons.fire,
      FontAwesomeIcons.bolt,
      FontAwesomeIcons.crown,
      FontAwesomeIcons.trophy,
      FontAwesomeIcons.medal,
      FontAwesomeIcons.award,
      FontAwesomeIcons.gem,
      FontAwesomeIcons.rocket,
      FontAwesomeIcons.lightbulb,
      FontAwesomeIcons.brain,
    ],
    'Entertainment': [
      FontAwesomeIcons.film,
      FontAwesomeIcons.music,
      FontAwesomeIcons.gamepad,
      FontAwesomeIcons.tv,
      FontAwesomeIcons.microphone,
      FontAwesomeIcons.guitar,
      FontAwesomeIcons.drum,
      FontAwesomeIcons.headphones,
      FontAwesomeIcons.radio,
      FontAwesomeIcons.ticket,
      FontAwesomeIcons.masksTheater,
      FontAwesomeIcons.dice,
    ],
    'Sports': [
      FontAwesomeIcons.football,
      FontAwesomeIcons.basketball,
      FontAwesomeIcons.baseball,
      FontAwesomeIcons.volleyball,
      FontAwesomeIcons.golfBall,
      FontAwesomeIcons.tableTennis,
      FontAwesomeIcons.bowlingBall,
      FontAwesomeIcons.dumbbell,
      FontAwesomeIcons.running,
      FontAwesomeIcons.personSwimming,
      FontAwesomeIcons.biking,
      FontAwesomeIcons.skiing,
    ],
    'Nature': [
      FontAwesomeIcons.tree,
      FontAwesomeIcons.leaf,
      FontAwesomeIcons.seedling,
      FontAwesomeIcons.fan,
      FontAwesomeIcons.sun,
      FontAwesomeIcons.moon,
      FontAwesomeIcons.cloudSun,
      FontAwesomeIcons.mountain,
      FontAwesomeIcons.water,
      FontAwesomeIcons.fish,
      FontAwesomeIcons.dove,
      FontAwesomeIcons.paw,
    ],
    'Food': [
      FontAwesomeIcons.utensils,
      FontAwesomeIcons.pizzaSlice,
      FontAwesomeIcons.burger,
      FontAwesomeIcons.iceCream,
      FontAwesomeIcons.cookie,
      FontAwesomeIcons.cake,
      FontAwesomeIcons.coffee,
      FontAwesomeIcons.martiniGlass,
      FontAwesomeIcons.beer,
      FontAwesomeIcons.wineGlass,
      FontAwesomeIcons.apple,
      FontAwesomeIcons.carrot,
    ],
    'Objects': [
      FontAwesomeIcons.book,
      FontAwesomeIcons.pen,
      FontAwesomeIcons.palette,
      FontAwesomeIcons.camera,
      FontAwesomeIcons.phone,
      FontAwesomeIcons.laptop,
      FontAwesomeIcons.car,
      FontAwesomeIcons.plane,
      FontAwesomeIcons.ship,
      FontAwesomeIcons.train,
      FontAwesomeIcons.bicycle,
      FontAwesomeIcons.motorcycle,
    ],
    'Symbols': [
      FontAwesomeIcons.flag,
      FontAwesomeIcons.bell,
      FontAwesomeIcons.bookmark,
      FontAwesomeIcons.tag,
      FontAwesomeIcons.hashtag,
      FontAwesomeIcons.at,
      FontAwesomeIcons.percent,
      FontAwesomeIcons.dollarSign,
      FontAwesomeIcons.euroSign,
      FontAwesomeIcons.yenSign,
      FontAwesomeIcons.infinity,
      FontAwesomeIcons.atom,
    ],
    'Emotions': [
      FontAwesomeIcons.solidFaceSmile,
      FontAwesomeIcons.solidFaceLaugh,
      FontAwesomeIcons.solidFaceGrin,
      FontAwesomeIcons.solidFaceMeh,
      FontAwesomeIcons.solidFaceSadTear,
      FontAwesomeIcons.solidFaceAngry,
      FontAwesomeIcons.solidFaceSurprise,
      FontAwesomeIcons.solidFaceKiss,
      FontAwesomeIcons.solidFaceDizzy,
      FontAwesomeIcons.solidFaceFlushed,
      FontAwesomeIcons.solidFaceGrimace,
      FontAwesomeIcons.solidFaceRollingEyes,
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _iconCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                  'Choose an Icon',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          // Current selection preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.selectedColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.selectedColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: widget.selectedColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.selectedIcon,
                    color: widget.selectedColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Icon',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap any icon below to change',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1),

          const SizedBox(height: 16),

          // Tab bar
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: widget.selectedColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: widget.selectedColor,
              indicatorSize: TabBarIndicatorSize.label,
              tabs:
                  _iconCategories.keys.map((category) {
                    return Tab(text: category);
                  }).toList(),
            ),
          ),

          // Icon grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children:
                  _iconCategories.entries.map((entry) {
                    return _buildIconGrid(entry.value);
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGrid(List<IconData> icons) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        final isSelected = icon == widget.selectedIcon;

        return GestureDetector(
          onTap: () {
            _hapticService.lightImpact();
            widget.onIconSelected(icon);
          },
          child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? widget.selectedColor.withOpacity(0.2)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected ? widget.selectedColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color:
                      isSelected ? widget.selectedColor : AppTheme.textPrimary,
                ),
              )
              .animate()
              .fadeIn(delay: Duration(milliseconds: 50 * index))
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
        );
      },
    );
  }
}
