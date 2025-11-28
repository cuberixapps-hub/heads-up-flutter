# Home Screen V2 - Netflix-Style UI

## Overview
HomeScreen V2 is a modern, Netflix-inspired redesign of the Heads Up! game home screen. It features a sleek, content-focused design with smooth animations and an intuitive user experience.

## Key Features

### 1. **Modern Netflix-Style Design**
- Dark theme with gradient backgrounds
- Large featured deck cards with prominent play buttons
- Smooth scrolling horizontal sections
- Glassmorphism effects with blur

### 2. **User Interface Components**

#### Header Section
- Dynamic app bar that appears on scroll
- User profile area with "For You" personalized greeting
- Search and settings buttons

#### Category Chips
- Horizontal scrollable category filters
- "Shows", "Movies", "Categories" tabs
- Selected state with visual feedback

#### Featured Deck Card
- Large, eye-catching card with deck information
- Gradient backgrounds using deck colors
- Two prominent action buttons:
  - **Play**: Start playing immediately
  - **My List**: Save for later (coming soon)
- Deck tags showing popularity and card count
- Visual deck icon

#### Content Sections
- **Daily Challenge**: Special daily deck with completion tracking
- **Continue Playing**: Recent decks for quick access
- **Popular Decks**: Free decks available to all users
- **My Custom Decks**: User-created custom decks
- **Premium Decks**: Locked premium content with unlock prompts

#### Bottom Navigation
- Home, Explore, and My Decks tabs
- Fixed position with blur effect
- Active state indicators

### 3. **Animations**
- Fade-in and slide animations for smooth entry
- Scale animations on featured cards
- Staggered animations for deck cards
- Smooth scroll-based transitions

### 4. **Interactive Elements**
- Haptic feedback on all interactions
- Sound effects when playing decks
- Modal bottom sheets for deck details
- Premium unlock dialogs

## How to Access

### Method 1: Direct Navigation
Navigate to `/home-v2` route in your app:

```dart
context.push('/home-v2');
```

### Method 2: Temporary Switch in Code
In `lib/utils/app_router.dart`, you can temporarily change the home route:

```dart
GoRoute(path: '/home', builder: (context, state) => const HomeScreenV2()),
```

### Method 3: Add a Switch Button
Add a button in settings or home screen to toggle between versions:

```dart
IconButton(
  icon: Icon(Icons.switch_account),
  onPressed: () => context.push('/home-v2'),
)
```

## Technical Details

### Dependencies Used
- `flutter_animate`: For smooth animations
- `google_fonts`: Poppins font for modern typography
- `provider`: State management
- `go_router`: Navigation
- `font_awesome_flutter`: Icon library

### File Location
```
lib/screens/home_screen_v2.dart
```

### Key Differences from V1

| Feature | V1 (Original) | V2 (Netflix-Style) |
|---------|---------------|-------------------|
| Layout | Traditional grid/list | Content-focused cards |
| Navigation | Standard app bar | Dynamic blur app bar + bottom nav |
| Featured Content | Small cards | Large hero card |
| Scrolling | Vertical only | Horizontal sections |
| Visual Style | Bright, playful | Dark, cinematic |
| Animations | Basic | Smooth, staggered |
| Content Discovery | Category-first | Content-first |

## Customization

### Colors
The design automatically uses your deck colors for gradient backgrounds. Adjust in the featured deck section:

```dart
colors: [
  featuredDeck.color,
  featuredDeck.color.withOpacity(0.6),
],
```

### Typography
Currently uses Poppins font. Change in GoogleFonts calls:

```dart
style: GoogleFonts.poppins(...)
// Change to:
style: GoogleFonts.roboto(...)
```

### Bottom Navigation Items
Modify the bottom nav items in `_buildBottomNav()`:

```dart
_buildNavItem(
  icon: Icons.your_icon,
  label: 'Your Label',
  isSelected: false,
  onTap: () => context.push('/your-route'),
),
```

## Future Enhancements

### Planned Features
- [ ] "My List" functionality to save favorite decks
- [ ] Search functionality with real-time filtering
- [ ] User profiles and personalization
- [ ] Video preview on deck hover
- [ ] Continue playing with progress indicators
- [ ] Recommended decks based on play history
- [ ] Social features (friends, sharing)
- [ ] Deck ratings and reviews

### Easy Additions
1. **Carousel Autoplay**: Auto-scroll featured decks
2. **Pull-to-Refresh**: Refresh daily deck
3. **Skeleton Loading**: Show loading states
4. **Filters**: Filter by difficulty, category
5. **Sort Options**: Sort by popularity, date, etc.

## Performance Considerations

- Horizontal lists use `ListView.builder` for efficient rendering
- Images are cached automatically
- Animations are hardware-accelerated
- Scroll controller manages title bar visibility

## Testing

To test the new design:

1. Run the app: `flutter run`
2. Navigate to `/home-v2` or modify the router
3. Test all interactive elements:
   - Play buttons
   - Navigation tabs
   - Scroll behavior
   - Deck detail modals
   - Premium unlock dialogs

## Feedback and Iteration

This is Version 2, but both versions coexist. You can:
- A/B test with users
- Gather feedback on preferred design
- Make the switch permanent when ready
- Keep both versions for different use cases

## Making V2 the Default

When ready to make V2 the default home screen:

1. **Update router** (`lib/utils/app_router.dart`):
```dart
GoRoute(
  path: '/home',
  builder: (context, state) => const HomeScreenV2(), // Changed from HomeScreen
),
```

2. **Optional**: Rename files:
```bash
mv lib/screens/home_screen.dart lib/screens/home_screen_v1.dart
mv lib/screens/home_screen_v2.dart lib/screens/home_screen.dart
```

3. **Update imports** throughout the codebase

## Support

For questions or issues with V2:
- Check this documentation
- Review the code comments in `home_screen_v2.dart`
- Compare with V1 for reference (`home_screen.dart`)

---

**Created**: October 31, 2025  
**Status**: Complete and Ready for Testing  
**Compatibility**: Flutter 3.0+






