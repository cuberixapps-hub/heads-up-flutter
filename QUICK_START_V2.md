# Quick Start Guide - Home Screen V2

## 🎉 Your Netflix-Style Home Screen is Ready!

I've created a beautiful, modern Netflix-style home screen (V2) for your Heads Up! game. Both the original and new versions coexist, so you can choose which one to use or let users switch between them.

## 🚀 How to Test It Right Now

### Option 1: Quick Test via Settings (Recommended)
1. Run your app: `flutter run`
2. Go to **Settings** (gear icon)
3. Scroll down to **"App Appearance"** section
4. Toggle between **"Original"** and **"Netflix"** styles
5. Restart the app to see the changes

### Option 2: Direct Navigation
Add a temporary button in your current home screen to test V2:
```dart
FloatingActionButton(
  onPressed: () => context.push('/home-v2'),
  child: Icon(Icons.preview),
)
```

### Option 3: Make V2 Default (Permanent)
In `lib/utils/app_router.dart`, change line 27:
```dart
// Before:
GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),

// After:
GoRoute(path: '/home', builder: (context, state) => const HomeScreenV2()),
```

## 📱 What You'll See

### Home Screen V2 Features
✨ **Dark, cinematic design** with Netflix-inspired UI  
🎴 **Large featured deck card** with prominent play button  
📊 **Horizontal scrolling sections** for different categories  
🏆 **Daily Challenge section** with completion tracking  
⏱️ **Continue Playing** - quick access to recent decks  
⭐ **Premium deck previews** with unlock prompts  
🎨 **Smooth animations** and transitions  
📱 **Bottom navigation** with blur effects  

## 🎨 Key Differences

| Feature | Original (V1) | Netflix Style (V2) |
|---------|---------------|-------------------|
| **Theme** | Bright & Colorful | Dark & Cinematic |
| **Layout** | Grid/List view | Content cards |
| **Navigation** | Top bar only | Top + Bottom nav |
| **Focus** | Category first | Content first |
| **Scrolling** | Vertical | Horizontal sections |

## 🛠️ Files Created/Modified

### New Files:
- `lib/screens/home_screen_v2.dart` - The new Netflix-style home screen
- `lib/widgets/version_switcher.dart` - Widget to toggle between versions
- `HOME_SCREEN_V2_README.md` - Detailed documentation
- `QUICK_START_V2.md` - This file

### Modified Files:
- `lib/utils/app_router.dart` - Added `/home-v2` route
- `lib/screens/splash_screen.dart` - Auto-routes to preferred version
- `lib/screens/settings_screen.dart` - Added version switcher widget

## 🎯 Testing Checklist

- [ ] View the featured deck with play/save buttons
- [ ] Scroll through horizontal deck sections
- [ ] Test the bottom navigation (Home, Explore, My Decks)
- [ ] Click on a deck to see the detail modal
- [ ] Try playing a deck from the new UI
- [ ] Test premium deck unlock dialogs
- [ ] Check daily challenge section (if available)
- [ ] Test the search button (currently a placeholder)
- [ ] Navigate to settings from the new home screen
- [ ] Toggle between V1 and V2 in settings

## 🎨 Customization Tips

### Change the Featured Deck
Edit `_buildFeaturedDeck()` in `home_screen_v2.dart`:
```dart
final featuredDeck = deckProvider.freeDecks.first; // Change this logic
```

### Adjust Colors
The design automatically uses your deck colors. To change the dark background:
```dart
backgroundColor: Colors.black, // Line 106 in home_screen_v2.dart
```

### Modify Bottom Navigation
Edit `_buildBottomNav()` to add/remove tabs:
```dart
_buildNavItem(
  icon: Icons.your_icon,
  label: 'Your Label',
  onTap: () => context.push('/your-route'),
),
```

## 🔄 Switching Back to Original

If you want to revert to the original home screen:

1. **Via Settings**: Users can toggle back to "Original" style
2. **Via Code**: Don't make V2 the default in router
3. **Remove V2**: Simply don't use the `/home-v2` route

## 📊 A/B Testing

The version switcher makes it easy to A/B test:
1. Keep both versions live
2. Let users choose in settings
3. Track which version gets more engagement
4. Make data-driven decision on default

## 🐛 Troubleshooting

### App doesn't show V2 after toggle
- Make sure to **restart the app** after changing the setting
- The splash screen reads the preference on app start

### Animations are laggy
- Check device performance
- Reduce animation count in the code if needed

### Bottom nav overlaps content
- The bottom padding (100px) should prevent this
- Adjust `const SizedBox(height: 100)` at the bottom of the scrollview

### Featured deck not showing
- Ensure you have at least one deck in `deckProvider.allDecks`
- Check console for any errors

## 💡 Next Steps

### Immediate
1. Test V2 thoroughly on different screen sizes
2. Gather feedback from users
3. Decide which version to make default

### Future Enhancements
- Implement "My List" functionality
- Add search feature
- Create video previews for decks
- Add user profiles
- Implement deck recommendations

## 📞 Support

If you encounter any issues:
1. Check the detailed `HOME_SCREEN_V2_README.md`
2. Review the code comments in `home_screen_v2.dart`
3. Compare with the original `home_screen.dart` for reference

## 🎊 Enjoy Your New Design!

The Netflix-style design is modern, engaging, and should provide a great user experience. Feel free to customize colors, layouts, and features to match your brand!

---

**Version**: 2.0  
**Created**: October 31, 2025  
**Status**: ✅ Ready to Use


