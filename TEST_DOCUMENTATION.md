# Heads Up! Game - Test Documentation

## Overview
This document provides comprehensive information about the test suite for the Heads Up! Flutter game application. All tests have been designed to ensure complete functionality and reliability of the application.

## Test Structure

### Directory Organization
```
test/
├── test_helpers/           # Test utilities and helpers
│   ├── test_data.dart     # Sample data for testing
│   ├── test_utils.dart    # Testing utility functions
│   └── mocks.dart         # Mock class definitions
├── models/                 # Model unit tests
│   ├── deck_test.dart     # Deck model tests
│   └── game_session_test.dart # GameSession model tests
├── services/               # Service unit tests
│   ├── audio_service_test.dart # Audio service tests
│   └── haptic_service_test.dart # Haptic service tests
├── screens/                # Screen widget tests
│   ├── home_screen_test.dart # Home screen tests
│   └── gameplay_screen_test.dart # Gameplay screen tests
└── widget_test.dart        # Main app widget tests

integration_test/
└── app_test.dart          # End-to-end integration tests
```

## Test Coverage

### 1. Model Tests

#### Deck Model (`test/models/deck_test.dart`)
- ✅ Creating deck with all properties
- ✅ Auto-generating unique ID when not provided
- ✅ Setting createdAt timestamp automatically
- ✅ Converting deck to/from Map
- ✅ Handling missing optional fields
- ✅ Copying deck with updated properties
- ✅ Shuffling cards for gameplay
- ✅ Checking minimum card requirements
- ✅ Equality based on ID
- ✅ Handling premium and custom decks
- ✅ Empty deck edge cases

#### GameSession Model (`test/models/game_session_test.dart`)
- ✅ Creating game session with all properties
- ✅ Starting new game (solo and team modes)
- ✅ Getting current card and team
- ✅ Adding results (correct/pass)
- ✅ Updating team scores
- ✅ Moving to next team
- ✅ Ending game session
- ✅ Pausing/resuming game
- ✅ Calculating statistics
- ✅ Checking game completion
- ✅ Time calculations (elapsed/remaining)
- ✅ Determining winning team

### 2. Service Tests

#### AudioService (`test/services/audio_service_test.dart`)
- ✅ Singleton pattern implementation
- ✅ Enabling/disabling sound
- ✅ Playing all sound effects
- ✅ Handling disabled state
- ✅ Error handling
- ✅ Proper disposal

#### HapticService (`test/services/haptic_service_test.dart`)
- ✅ Singleton pattern implementation
- ✅ Enabling/disabling vibration
- ✅ All haptic feedback types
- ✅ Handling disabled state
- ✅ Error handling

### 3. Screen Widget Tests

#### HomeScreen (`test/screens/home_screen_test.dart`)
- ✅ Display app title and welcome text
- ✅ Quick Play card functionality
- ✅ Feature grid display and interactions
- ✅ Stats card with correct data
- ✅ Recent decks section
- ✅ Settings button
- ✅ Navigation to different screens
- ✅ Snackbar messages
- ✅ Scrolling functionality
- ✅ Animations
- ✅ Loading states

#### GameplayScreen (`test/screens/gameplay_screen_test.dart`)
- ✅ Countdown display and timer
- ✅ Gameplay transition
- ✅ Current card display
- ✅ Timer display and warnings
- ✅ Manual control buttons
- ✅ Pause/resume functionality
- ✅ Feedback animations
- ✅ Tilt indicator
- ✅ Card flip animations
- ✅ Multiple cards in sequence
- ✅ Navigation to results

### 4. Main App Tests (`test/widget_test.dart`)
- ✅ App initialization
- ✅ Provider setup
- ✅ Theme configuration
- ✅ Router configuration
- ✅ Error handling
- ✅ Memory management
- ✅ Performance under load

### 5. Integration Tests (`integration_test/app_test.dart`)
- ✅ Complete app flow
- ✅ Navigation between screens
- ✅ Feature interactions
- ✅ Scrolling and animations
- ✅ Settings and configuration
- ✅ Error recovery
- ✅ Performance benchmarks
- ✅ Orientation handling

## Running Tests

### Quick Start
```bash
# Run all tests
./run_tests.sh

# Or manually:
flutter test
```

### Individual Test Suites
```bash
# Model tests
flutter test test/models/

# Service tests
flutter test test/services/

# Screen tests
flutter test test/screens/

# Integration tests
flutter test integration_test/app_test.dart
```

### Generate Mocks
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Test Coverage Report
```bash
# Generate coverage report
flutter test --coverage

# View coverage (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Data

The test suite uses comprehensive test data defined in `test/test_helpers/test_data.dart`:

- **Sample Decks**: Regular, Premium, Custom, and Empty decks
- **Game Sessions**: Solo and Team mode sessions
- **Statistics**: Sample user statistics
- **Settings**: Game configuration options
- **Leaderboard**: Sample leaderboard data

## Mocking Strategy

### Mocked Services
- `AudioService` - Audio playback
- `HapticService` - Haptic feedback
- `FirebaseService` - Firebase operations
- `DeckFirebaseService` - Deck-related Firebase operations
- `GameFirebaseService` - Game-related Firebase operations

### Mocked Providers
- `DeckProvider` - Deck state management
- `GameProvider` - Game state management

## Best Practices

### Writing New Tests
1. **Use Test Helpers**: Utilize `TestUtils` and `TestData` for consistency
2. **Mock External Dependencies**: Always mock Firebase and hardware services
3. **Test Edge Cases**: Include null, empty, and error scenarios
4. **Verify Animations**: Use `pumpAndSettle()` for animation completion
5. **Check Navigation**: Verify screen transitions and back navigation

### Test Organization
1. **Group Related Tests**: Use `group()` for logical organization
2. **Descriptive Names**: Use clear, descriptive test names
3. **Setup and Teardown**: Use `setUp()` and `tearDown()` for initialization
4. **Async Handling**: Properly handle futures and streams

## Continuous Integration

### GitHub Actions Workflow
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart run build_runner build
      - run: flutter test
      - run: flutter test integration_test
```

## Known Limitations

1. **Firebase Mocking**: Some Firebase features are mocked and may not reflect exact production behavior
2. **Hardware Testing**: Audio and haptic feedback cannot be fully tested in unit tests
3. **Accelerometer**: Device motion testing requires physical device or emulator
4. **Network Conditions**: Tests assume stable network connectivity

## Troubleshooting

### Common Issues

1. **Mock Generation Fails**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

2. **Test Timeout**
   - Increase timeout in test configuration
   - Check for infinite loops or blocking operations

3. **Widget Not Found**
   - Ensure proper `pumpAndSettle()` usage
   - Check if widget is actually in the tree

4. **Provider Errors**
   - Verify providers are properly mocked
   - Check provider disposal

## Performance Benchmarks

Expected test execution times:
- Unit Tests: < 5 seconds
- Widget Tests: < 10 seconds
- Integration Tests: < 30 seconds
- Full Test Suite: < 1 minute

## Maintenance

### Regular Updates
1. Update tests when adding new features
2. Review and update mocks when dependencies change
3. Run tests before each commit
4. Monitor test coverage metrics

### Test Review Checklist
- [ ] All new features have tests
- [ ] Tests pass locally
- [ ] Mocks are up to date
- [ ] Coverage is maintained above 80%
- [ ] Integration tests cover critical paths

## Contact

For questions or issues with tests, please refer to the main project documentation or create an issue in the repository.

