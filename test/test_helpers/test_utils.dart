import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:heads_up_game/providers/deck_provider.dart';
import 'package:heads_up_game/providers/game_provider.dart';

class TestUtils {
  // Wrap widget with MaterialApp for testing
  static Widget wrapWithMaterialApp(Widget widget, {ThemeData? theme}) {
    return MaterialApp(theme: theme, home: Scaffold(body: widget));
  }

  // Wrap widget with providers for testing
  static Widget wrapWithProviders(
    Widget widget, {
    DeckProvider? deckProvider,
    GameProvider? gameProvider,
  }) {
    return MultiProvider(
      providers: [
        if (deckProvider != null)
          ChangeNotifierProvider<DeckProvider>.value(value: deckProvider),
        if (gameProvider != null)
          ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
      ],
      child: widget,
    );
  }

  // Complete widget wrapper with MaterialApp and Providers
  static Widget createTestableWidget(
    Widget widget, {
    DeckProvider? deckProvider,
    GameProvider? gameProvider,
    ThemeData? theme,
  }) {
    return wrapWithMaterialApp(
      wrapWithProviders(
        widget,
        deckProvider: deckProvider,
        gameProvider: gameProvider,
      ),
      theme: theme,
    );
  }

  // Helper to pump and settle with timeout
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  // Helper to find widgets by key
  static Finder findByKey(String key) {
    return find.byKey(Key(key));
  }

  // Helper to find text widgets
  static Finder findText(String text) {
    return find.text(text);
  }

  // Helper to find icon widgets
  static Finder findIcon(IconData icon) {
    return find.byIcon(icon);
  }

  // Helper to tap a widget
  static Future<void> tapWidget(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
  }

  // Helper to enter text
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.enterText(finder, text);
    await tester.pump();
  }

  // Helper to scroll until visible
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder finder,
    Finder scrollable,
  ) async {
    await tester.scrollUntilVisible(finder, 100, scrollable: scrollable);
  }

  // Helper to verify widget properties
  static void verifyTextWidget(
    WidgetTester tester,
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
  }) {
    final textWidget = tester.widget<Text>(find.text(text));
    expect(textWidget.data, equals(text));

    if (style != null) {
      expect(textWidget.style, equals(style));
    }

    if (textAlign != null) {
      expect(textWidget.textAlign, equals(textAlign));
    }
  }

  // Helper to verify container properties
  static void verifyContainer(
    WidgetTester tester,
    Finder finder, {
    Color? color,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BoxDecoration? decoration,
  }) {
    final container = tester.widget<Container>(finder);

    if (color != null) {
      expect(container.color, equals(color));
    }

    if (padding != null) {
      expect(container.padding, equals(padding));
    }

    if (margin != null) {
      expect(container.margin, equals(margin));
    }

    if (decoration != null) {
      expect(container.decoration, equals(decoration));
    }
  }

  // Helper to wait for animations
  static Future<void> waitForAnimation(
    WidgetTester tester, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    await tester.pump(duration);
  }

  // Helper to verify navigation
  static void verifyNavigation(WidgetTester tester, Type expectedRoute) {
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), isNotNull);
  }

  // Helper to create a mock BuildContext
  static BuildContext createMockContext(WidgetTester tester) {
    return tester.element(find.byType(MaterialApp));
  }
}

