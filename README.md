# Heads Up! - Party Charades Game

A modern, beautifully designed charades party game built with Flutter. Hold your phone to your forehead and let your friends give you clues to guess the word!

## Features

### Core Gameplay

- **Tilt Detection**: Use natural phone movements to indicate correct answers (tilt down) or pass (tilt up)
- **Manual Controls**: Alternative tap controls for accessibility
- **60-Second Rounds**: Fast-paced gameplay with visual countdown timer
- **Real-time Feedback**: Instant visual and haptic feedback for actions

### Content & Categories

- **Multiple Categories**: 10+ pre-built categories including:
  - Animals
  - Movies
  - Celebrities
  - Sports
  - Music
  - Food & Drinks
  - Act It Out
  - For Kids
  - And more!
- **Premium Categories**: Special themed decks (Superheroes, Technology)
- **Custom Decks**: Create your own categories with personalized words

### User Experience

- **Beautiful Animations**: Smooth transitions, card flips, and celebratory effects
- **Modern Design**: Clean, colorful interface with gradient backgrounds
- **Haptic Feedback**: Tactile responses for all interactions
- **Sound Effects**: Audio cues for game events (optional)
- **Dark/Light Themes**: Comfortable viewing in any environment

### Social Features

- **Team Mode**: Play with multiple teams and track scores
- **Share Results**: Share your scores on social media
- **Game History**: Track your performance over time
- **Statistics**: View your gameplay stats and high scores

### Screens Implemented

1. **Splash Screen**: Animated logo and loading
2. **Onboarding**: Interactive tutorial for new users
3. **Home Screen**: Main hub with quick play and feature cards
4. **Category Selection**: Browse and search all available decks
5. **Gameplay Screen**: The main game experience with tilt detection
6. **Results Screen**: Score display with sharing options

## Getting Started

### Prerequisites

- Flutter SDK (^3.0.0)
- Dart SDK (^3.0.0)
- iOS/Android development environment

### Installation

1. Clone the repository:

```bash
git clone [repository-url]
cd "Heads Up"
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

### Building for Release

#### iOS

```bash
flutter build ios --release
```

#### Android

```bash
flutter build apk --release
```

## Project Structure

```
lib/
├── constants/       # Theme, colors, and default data
├── models/         # Data models (Deck, GameSession, etc.)
├── providers/      # State management with Provider
├── screens/        # All app screens
├── services/       # Audio and haptic services
├── utils/          # Routing and utilities
└── widgets/        # Reusable UI components
```

## Technologies Used

- **Flutter**: Cross-platform framework
- **Provider**: State management
- **Go Router**: Navigation
- **Sensors Plus**: Accelerometer for tilt detection
- **Flutter Animate**: Beautiful animations
- **Google Fonts**: Typography
- **Share Plus**: Social sharing
- **Audioplayers**: Sound effects

## Features In Progress

- Custom deck creation UI
- Settings screen
- Online multiplayer mode
- Video recording during gameplay
- Cloud sync for custom decks
- In-app purchases for premium content
- AdMob integration

## Design Philosophy

The app follows modern Material Design principles with:

- Clean, intuitive interfaces
- Vibrant color schemes
- Smooth animations
- Accessibility considerations
- Responsive layouts for all screen sizes

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## License

This project is created for educational and entertainment purposes.

## Acknowledgments

- Inspired by the popular Heads Up! game by Warner Bros
- Built with Flutter and love for party games
# headsup-flutter
# heads-up-flutter
