import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:heads_up_game/screens/home_screen.dart';
import 'package:heads_up_game/providers/deck_provider.dart';
import 'package:heads_up_game/providers/game_provider.dart';
import 'package:heads_up_game/constants/app_theme.dart';
import '../test_helpers/test_utils.dart';
import '../test_helpers/test_data.dart';

@GenerateMocks([DeckProvider, GameProvider])
import 'home_screen_test.mocks.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    late MockDeckProvider mockDeckProvider;
    late MockGameProvider mockGameProvider;

    setUp(() {
      mockDeckProvider = MockDeckProvider();
      mockGameProvider = MockGameProvider();

      // Setup default mock behaviors
      when(mockDeckProvider.allDecks).thenReturn([
        TestData.sampleDeck,
        TestData.premiumDeck,
        TestData.customDeck,
      ]);
      when(mockDeckProvider.isLoading).thenReturn(false);
      when(mockDeckProvider.isInitialized).thenReturn(true);
      when(
        mockDeckProvider.getRecentDeckIds(),
      ).thenAnswer((_) async => ['test-deck-1', 'premium-deck-1']);
      when(
        mockDeckProvider.getDeckById('test-deck-1'),
      ).thenReturn(TestData.sampleDeck);
      when(
        mockDeckProvider.getDeckById('premium-deck-1'),
      ).thenReturn(TestData.premiumDeck);

      when(
        mockGameProvider.getStatistics(),
      ).thenReturn(TestData.sampleStatistics);
      when(mockGameProvider.isGameActive).thenReturn(false);
      when(mockGameProvider.currentSession).thenReturn(null);
    });

    Widget createTestWidget() {
      return TestUtils.createTestableWidget(
        const HomeScreen(),
        deckProvider: mockDeckProvider,
        gameProvider: mockGameProvider,
        theme: AppTheme.lightTheme,
      );
    }

    testWidgets('should display app title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Heads Up!'), findsOneWidget);
    });

    testWidgets('should display welcome text', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Ready to Play?'), findsOneWidget);
      expect(find.text('Choose your adventure'), findsOneWidget);
    });

    testWidgets('should display Quick Play card', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Jump into the action now!'), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.play), findsOneWidget);
    });

    testWidgets('should display feature grid', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Teams'), findsOneWidget);
      expect(find.text('Tutorial'), findsOneWidget);

      expect(find.byIcon(FontAwesomeIcons.layerGroup), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.wandMagicSparkles), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.userGroup), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.graduationCap), findsOneWidget);
    });

    testWidgets('should display stats card with correct data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Your Progress'), findsOneWidget);
      expect(find.text('Games'), findsOneWidget);
      expect(find.text('10'), findsOneWidget); // totalGames
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('45'), findsOneWidget); // totalCorrect
      expect(find.text('Best'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // highScore
    });

    testWidgets('should display recent decks section', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Wait for the future to complete
      await tester.pump();

      expect(find.text('Recent Adventures'), findsOneWidget);
      expect(find.text('Test Deck'), findsOneWidget);
      expect(find.text('Premium Deck'), findsOneWidget);
    });

    testWidgets('should display settings button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('should handle Quick Play tap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Play'));
      await tester.pumpAndSettle();

      // Should navigate to category selection
      // In a real test, we'd verify navigation occurred
    });

    testWidgets('should handle Categories feature tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Should navigate to category selection
    });

    testWidgets('should handle Custom feature tap and show snackbar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(find.text('Custom deck creation coming soon!'), findsOneWidget);
    });

    testWidgets('should handle Teams feature tap and show snackbar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Teams'));
      await tester.pump();

      expect(find.text('Team mode coming soon!'), findsOneWidget);
    });

    testWidgets('should handle Tutorial feature tap and show snackbar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tutorial'));
      await tester.pump();

      expect(find.text('Tutorial coming soon!'), findsOneWidget);
    });

    testWidgets('should handle Settings button tap and show snackbar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();

      expect(find.text('Settings coming soon!'), findsOneWidget);
    });

    testWidgets('should handle recent deck tap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Wait for future to complete
      await tester.pump();

      await tester.tap(find.text('Test Deck'));
      await tester.pump();

      expect(find.text('Starting game with Test Deck!'), findsOneWidget);
    });

    testWidgets('should handle empty recent decks', (
      WidgetTester tester,
    ) async {
      when(mockDeckProvider.getRecentDeckIds()).thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Recent Adventures section should not be displayed
      expect(find.text('Recent Adventures'), findsNothing);
    });

    testWidgets('should display correct icons and colors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify app bar color
      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.backgroundColor, equals(AppTheme.primaryColor));

      // Verify Quick Play card exists
      final quickPlayCard = find.ancestor(
        of: find.text('Quick Play'),
        matching: find.byType(Container),
      );
      expect(quickPlayCard, findsWidgets);
    });

    testWidgets('should scroll properly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify CustomScrollView exists
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Try scrolling
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Content should still be visible
      expect(find.text('Quick Play'), findsOneWidget);
    });

    testWidgets('should display all stat items with correct icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gamepad_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });

    testWidgets('should handle loading state', (WidgetTester tester) async {
      when(mockDeckProvider.isLoading).thenReturn(true);
      when(mockDeckProvider.isInitialized).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Should still display main UI elements
      expect(find.text('Ready to Play?'), findsOneWidget);
    });

    testWidgets('should apply animations', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initial pump for animations to start
      await tester.pump();

      // Pump through animation duration
      await tester.pump(const Duration(milliseconds: 600));

      // Verify widgets are still present after animations
      expect(find.text('Heads Up!'), findsOneWidget);
      expect(find.text('Quick Play'), findsOneWidget);
    });
  });
}

