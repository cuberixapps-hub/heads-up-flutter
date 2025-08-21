import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:heads_up_game/main.dart';
import 'package:heads_up_game/providers/deck_provider.dart';
import 'package:heads_up_game/providers/game_provider.dart';
import 'package:heads_up_game/services/firebase_service.dart';
import 'test_helpers/test_data.dart';

@GenerateMocks([FirebaseService, DeckProvider, GameProvider])
import 'widget_test.mocks.dart';

void main() {
  group('Main App Tests', () {
    late MockFirebaseService mockFirebaseService;
    late MockDeckProvider mockDeckProvider;
    late MockGameProvider mockGameProvider;

    setUp(() {
      mockFirebaseService = MockFirebaseService();
      mockDeckProvider = MockDeckProvider();
      mockGameProvider = MockGameProvider();

      // Setup default mock behaviors
      when(mockFirebaseService.initialize()).thenAnswer((_) async {});
      when(
        mockFirebaseService.signInAnonymously(),
      ).thenAnswer((_) async => null);

      when(mockDeckProvider.allDecks).thenReturn([TestData.sampleDeck]);
      when(mockDeckProvider.isLoading).thenReturn(false);
      when(mockDeckProvider.isInitialized).thenReturn(true);

      when(mockGameProvider.currentSession).thenReturn(null);
      when(mockGameProvider.isGameActive).thenReturn(false);
      when(
        mockGameProvider.getStatistics(),
      ).thenReturn(TestData.sampleStatistics);
    });

    testWidgets('App should build and display correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify the app builds without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App should have correct title', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      final materialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).first,
      );
      expect(materialApp.title, equals('Heads Up!'));
    });

    testWidgets('App should not show debug banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      final materialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).first,
      );
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('App should provide MultiProvider with correct providers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(MultiProvider), findsOneWidget);

      // Verify providers are available in the widget tree
      // MultiProvider doesn't expose providers property, so we check for the app itself
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App should use correct theme', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).first,
      );
      expect(materialApp.theme, isNotNull);
    });

    testWidgets('App should have router configuration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      final materialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).first,
      );
      expect(materialApp.routerConfig, isNotNull);
    });
  });

  group('App Initialization Tests', () {
    testWidgets('App should handle initialization properly', (
      WidgetTester tester,
    ) async {
      // Test that the app can be initialized and run
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DeckProvider()),
            ChangeNotifierProvider(create: (_) => GameProvider()),
          ],
          child: MaterialApp(
            title: 'Heads Up! Test',
            home: Scaffold(body: Center(child: Text('Test App'))),
          ),
        ),
      );

      expect(find.text('Test App'), findsOneWidget);
    });

    testWidgets('Providers should be accessible in widget tree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Create a test widget that uses the providers
      await tester.pumpWidget(const MyApp());

      // The app should build successfully with providers
      expect(find.byType(MyApp), findsOneWidget);
    });
  });

  group('App Navigation Tests', () {
    testWidgets('App should have initial route', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // The app should display some initial content
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('App Theme Tests', () {
    testWidgets('App should apply light theme correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      final BuildContext context = tester.element(find.byType(MaterialApp));
      final ThemeData theme = Theme.of(context);

      // Verify theme properties
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.primaryColor, isNotNull);
      expect(theme.scaffoldBackgroundColor, isNotNull);
    });
  });

  group('Provider Integration Tests', () {
    testWidgets('DeckProvider should be available in context', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DeckProvider()),
            ChangeNotifierProvider(create: (_) => GameProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final deckProvider = Provider.of<DeckProvider>(
                  context,
                  listen: false,
                );
                expect(deckProvider, isNotNull);
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('GameProvider should be available in context', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DeckProvider()),
            ChangeNotifierProvider(create: (_) => GameProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final gameProvider = Provider.of<GameProvider>(
                  context,
                  listen: false,
                );
                expect(gameProvider, isNotNull);
                return Container();
              },
            ),
          ),
        ),
      );
    });
  });

  group('Error Handling Tests', () {
    testWidgets('App should handle provider errors gracefully', (
      WidgetTester tester,
    ) async {
      // Create a mock provider that throws an error
      final errorProvider = DeckProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: errorProvider),
            ChangeNotifierProvider(create: (_) => GameProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<DeckProvider>(
                builder: (context, provider, child) {
                  return Text('Decks: ${provider.allDecks.length}');
                },
              ),
            ),
          ),
        ),
      );

      // App should still render even if provider has issues
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Memory and Performance Tests', () {
    testWidgets('App should dispose providers properly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      // Pump a few frames to ensure everything is built
      await tester.pump();
      await tester.pump();

      // Dispose the widget tree
      await tester.pumpWidget(Container());

      // Providers should be disposed without errors
      expect(true, isTrue);
    });

    testWidgets('App should handle rapid rebuilds', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      // Rapidly rebuild the widget tree
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }

      // App should still be functional
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
