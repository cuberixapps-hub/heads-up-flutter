import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:heads_up_game/main.dart' as app;
import 'package:heads_up_game/screens/home_screen.dart';
import 'package:heads_up_game/screens/category_selection_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Tests', () {
    testWidgets('Complete app flow test', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify we're on the home screen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Ready to Play?'), findsOneWidget);

      // Test Quick Play navigation
      await tester.tap(find.text('Quick Play'));
      await tester.pumpAndSettle();

      // Should navigate to category selection
      expect(find.byType(CategorySelectionScreen), findsOneWidget);

      // Go back to home
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Navigate through all main features', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Test Categories feature
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(find.byType(CategorySelectionScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Test Custom feature (should show snackbar)
      await tester.tap(find.text('Custom'));
      await tester.pump();
      expect(find.text('Custom deck creation coming soon!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // Test Teams feature (should show snackbar)
      await tester.tap(find.text('Teams'));
      await tester.pump();
      expect(find.text('Team mode coming soon!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // Test Tutorial feature (should show snackbar)
      await tester.tap(find.text('Tutorial'));
      await tester.pump();
      expect(find.text('Tutorial coming soon!'), findsOneWidget);
    });

    testWidgets('Test settings button', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap settings button
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();

      // Should show settings snackbar (temporary implementation)
      expect(find.text('Settings coming soon!'), findsOneWidget);
    });

    testWidgets('Test scrolling on home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Content should still be visible
      expect(find.text('Your Progress'), findsOneWidget);

      // Scroll back up
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();

      expect(find.text('Ready to Play?'), findsOneWidget);
    });

    testWidgets('Test category selection flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to categories
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Verify category screen elements
      expect(find.text('Choose a Category'), findsOneWidget);

      // Look for deck cards (should have at least one)
      expect(find.byType(Card), findsWidgets);

      // Tap on a deck if available
      final deckCards = find.byType(Card);
      if (deckCards.evaluate().isNotEmpty) {
        await tester.tap(deckCards.first);
        await tester.pumpAndSettle();

        // Should navigate to gameplay or show selection
      }
    });

    testWidgets('Test app bar functionality', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify app bar is present
      expect(find.byType(SliverAppBar), findsOneWidget);

      // Scroll to collapse app bar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // App bar should still be visible (pinned)
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('Test stats display', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check if stats are displayed
      expect(find.text('Your Progress'), findsOneWidget);
      expect(find.text('Games'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Best'), findsOneWidget);

      // Verify stat icons
      expect(find.byIcon(Icons.gamepad_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });

    testWidgets('Test recent decks section', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Wait for async data to load
      await tester.pump(const Duration(seconds: 1));

      // Check if recent decks section appears (if there are recent decks)
      final recentDecksSection = find.text('Recent Adventures');
      if (recentDecksSection.evaluate().isNotEmpty) {
        expect(recentDecksSection, findsOneWidget);

        // Should have horizontal scroll for recent decks
        expect(find.byType(ListView), findsWidgets);
      }
    });

    testWidgets('Test animations on home screen', (WidgetTester tester) async {
      app.main();
      await tester.pump(); // Start animations

      // Let animations play
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      // Verify content is visible after animations
      expect(find.text('Ready to Play?'), findsOneWidget);
      expect(find.text('Quick Play'), findsOneWidget);
    });

    testWidgets('Test feature grid interactions', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find all feature grid items
      final features = ['Categories', 'Custom', 'Teams', 'Tutorial'];

      for (final feature in features) {
        expect(find.text(feature), findsOneWidget);

        // Verify each feature has an icon
        final featureWidget = find.ancestor(
          of: find.text(feature),
          matching: find.byType(Container),
        );
        expect(featureWidget, findsWidgets);
      }
    });

    testWidgets('Test Quick Play card animation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find Quick Play card
      final quickPlayCard = find.ancestor(
        of: find.text('Quick Play'),
        matching: find.byType(Container),
      );

      expect(quickPlayCard, findsWidgets);

      // The card should be visible and tappable
      await tester.tap(find.text('Quick Play'));
      await tester.pumpAndSettle();

      // Should navigate away from home
      expect(find.byType(CategorySelectionScreen), findsOneWidget);
    });

    testWidgets('Test back navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to categories
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Use back button
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Should be back on home screen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Ready to Play?'), findsOneWidget);
    });

    testWidgets('Test snackbar dismissal', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Trigger a snackbar
      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(find.text('Custom deck creation coming soon!'), findsOneWidget);

      // Wait for snackbar to auto-dismiss
      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Custom deck creation coming soon!'), findsNothing);
    });

    testWidgets('Test multiple navigation actions', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to categories
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Navigate using Quick Play
      await tester.tap(find.text('Quick Play'));
      await tester.pumpAndSettle();

      // Go back again
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Should still be on home screen
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Performance Tests', () {
    testWidgets('App should load quickly', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      app.main();
      await tester.pumpAndSettle();

      stopwatch.stop();

      // App should load within reasonable time (5 seconds)
      expect(stopwatch.elapsed.inSeconds, lessThan(5));
    });

    testWidgets('Navigation should be smooth', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final stopwatch = Stopwatch()..start();

      // Navigate to categories
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Navigation should complete within 2 seconds
      expect(stopwatch.elapsed.inSeconds, lessThan(2));
    });

    testWidgets('Scrolling should be smooth', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Perform multiple scroll actions
      for (int i = 0; i < 5; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pump();
      }

      await tester.pumpAndSettle();

      // App should still be responsive
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Error Recovery Tests', () {
    testWidgets('App should handle rapid taps gracefully', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Rapidly tap the same button
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Quick Play'), warnIfMissed: false);
        await tester.pump();
      }

      await tester.pumpAndSettle();

      // App should navigate correctly without crashing
      expect(find.byType(CategorySelectionScreen), findsOneWidget);
    });

    testWidgets('App should handle orientation changes', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Note: Orientation changes are locked to portrait in main.dart
      // But the app should still handle size changes gracefully

      // Simulate size change
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      await tester.pump();

      // App should still display correctly
      expect(find.byType(HomeScreen), findsOneWidget);

      // Reset size
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

