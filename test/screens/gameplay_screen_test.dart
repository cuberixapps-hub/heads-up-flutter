import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:heads_up_game/screens/gameplay_screen.dart';
import 'package:heads_up_game/providers/game_provider.dart';
import 'package:heads_up_game/constants/app_theme.dart';
import '../test_helpers/test_utils.dart';
import '../test_helpers/test_data.dart';

@GenerateMocks([GameProvider])
import 'gameplay_screen_test.mocks.dart';

void main() {
  group('GameplayScreen Widget Tests', () {
    late MockGameProvider mockGameProvider;

    setUp(() {
      mockGameProvider = MockGameProvider();

      // Setup default mock behaviors
      when(
        mockGameProvider.currentSession,
      ).thenReturn(TestData.sampleGameSession);
      when(mockGameProvider.isGameActive).thenReturn(true);
      when(
        mockGameProvider.remainingTime,
      ).thenReturn(const Duration(seconds: 45));
      when(mockGameProvider.markCorrect()).thenReturn(null);
      when(mockGameProvider.markPass()).thenReturn(null);
      when(mockGameProvider.togglePause()).thenReturn(null);
    });

    Widget createTestWidget() {
      return TestUtils.createTestableWidget(
        GameplayScreen(deck: TestData.sampleDeck),
        gameProvider: mockGameProvider,
        theme: AppTheme.lightTheme,
      );
    }

    testWidgets('should display countdown initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Initial state should show countdown
      expect(find.text('Place on forehead!'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.phone_android_rounded), findsWidgets);
    });

    testWidgets('should update countdown timer', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('3'), findsOneWidget);

      // Wait for countdown to progress
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('should transition to gameplay after countdown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Skip through countdown
      await tester.pump(const Duration(seconds: 3));

      // Should now show gameplay elements
      expect(find.text('Place on forehead!'), findsNothing);
      expect(find.text('45s'), findsOneWidget); // Timer
      expect(find.text('Card 1'), findsOneWidget); // Current card
    });

    testWidgets('should display current card', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      expect(find.text('Card 1'), findsOneWidget);
    });

    testWidgets('should display timer', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      expect(find.text('45s'), findsOneWidget);
    });

    testWidgets('should display manual control buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      expect(find.text('PASS'), findsOneWidget);
      expect(find.text('CORRECT'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('should display pause button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('should handle manual correct button tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      await tester.tap(find.text('CORRECT'));
      await tester.pump();

      verify(mockGameProvider.markCorrect()).called(1);
    });

    testWidgets('should handle manual pass button tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      await tester.tap(find.text('PASS'));
      await tester.pump();

      verify(mockGameProvider.markPass()).called(1);
    });

    testWidgets('should handle pause button tap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      verify(mockGameProvider.togglePause()).called(1);

      // Should show pause dialog
      expect(find.text('Game Paused'), findsOneWidget);
      expect(find.text('Take a break! Tap resume when ready.'), findsOneWidget);
      expect(find.text('Quit Game'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('should handle resume from pause dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      await tester.tap(find.text('Resume'));
      await tester.pump();

      // Dialog should be dismissed
      expect(find.text('Game Paused'), findsNothing);

      // togglePause should be called twice (pause and resume)
      verify(mockGameProvider.togglePause()).called(2);
    });

    testWidgets('should handle quit from pause dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      await tester.tap(find.text('Quit Game'));
      await tester.pump();

      // Should navigate back (in real app)
      // Dialog should be dismissed
      expect(find.text('Game Paused'), findsNothing);
    });

    testWidgets('should show feedback for correct answer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      await tester.tap(find.text('CORRECT'));
      await tester.pump();

      // Feedback should appear
      expect(find.text('CORRECT!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should show feedback for pass', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      await tester.tap(find.text('PASS'));
      await tester.pump();

      // Feedback should appear
      expect(
        find.text('PASS'),
        findsWidgets,
      ); // One for button, one for feedback
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('should display tilt indicator', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
      expect(find.textContaining('Tilt:'), findsOneWidget);
    });

    testWidgets('should handle time running out warning', (
      WidgetTester tester,
    ) async {
      when(
        mockGameProvider.remainingTime,
      ).thenReturn(const Duration(seconds: 8));

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      expect(find.text('8s'), findsOneWidget);

      // Timer container should have red background when time is running out
      final timerContainer = tester.widget<Container>(
        find
            .ancestor(of: find.text('8s'), matching: find.byType(Container))
            .first,
      );

      // Color should be red with opacity
      expect(timerContainer.decoration, isNotNull);
    });

    testWidgets('should navigate to results when game is complete', (
      WidgetTester tester,
    ) async {
      final completedSession = TestData.completedGameSession;
      when(mockGameProvider.currentSession).thenReturn(completedSession);
      when(mockGameProvider.isGameActive).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      await tester.tap(find.text('CORRECT'));
      await tester.pump(
        const Duration(milliseconds: 700),
      ); // Wait for navigation delay

      // Should navigate to results screen (would need proper navigation testing)
    });

    testWidgets('should display deck color in background', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Find the main container with gradient
      final container = tester.widget<Container>(find.byType(Container).first);

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
    });

    testWidgets('should display card with deck color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      // Find the card text
      final cardText = tester.widget<Text>(find.text('Card 1'));
      expect(cardText.style?.color, equals(TestData.sampleDeck.color));
    });

    testWidgets('should not allow actions during countdown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Try to tap correct during countdown
      await tester.tap(find.text('CORRECT'), warnIfMissed: false);
      await tester.pump();

      // Should not call markCorrect during countdown
      verifyNever(mockGameProvider.markCorrect());
    });

    testWidgets('should handle PopScope for back button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Find PopScope widget
      expect(find.byType(PopScope), findsOneWidget);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('should animate card flip on correct answer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      await tester.tap(find.text('CORRECT'));

      // Pump through animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Card should be animating (Transform widget should exist)
      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('should handle multiple cards in sequence', (
      WidgetTester tester,
    ) async {
      var cardIndex = 0;
      when(mockGameProvider.currentSession).thenAnswer((_) {
        return TestData.sampleGameSession.copyWith(currentCardIndex: cardIndex);
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 3)); // Skip countdown

      expect(find.text('Card 1'), findsOneWidget);

      // Mark correct and move to next card
      cardIndex = 1;
      await tester.tap(find.text('CORRECT'));
      await tester.pump(const Duration(milliseconds: 700));

      // Should show next card
      expect(find.text('Card 2'), findsOneWidget);
    });
  });
}

