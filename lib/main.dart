import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'providers/deck_provider.dart';
import 'providers/game_provider.dart';
import 'widgets/network_status_widget.dart';

import 'services/firebase_service.dart';
import 'services/ad_service.dart';
import 'utils/app_router.dart';
import 'utils/responsive.dart';

// Custom scroll behavior for smooth, elegant scrolling
class SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use BouncingScrollPhysics for iOS-like smooth bouncing
    // with AlwaysScrollableScrollPhysics as parent for consistent behavior
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Remove the overscroll glow indicator for a cleaner, more elegant look
    return child;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('');
  debugPrint('========================================');
  debugPrint('🎮 HEADS UP GAME STARTING...');
  debugPrint('========================================');

  // IMPORTANT: Initialize Firebase FIRST (includes Remote Config)
  final firebaseService = FirebaseService();
  await firebaseService.initialize();
  
  // Initialize AdMob (will use Firebase Remote Config to determine ad type)
  await AdService.initialize();

  // Try to sign in anonymously, but don't block app startup if it fails
  try {
    await firebaseService.signInAnonymously().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('📱 Starting in OFFLINE MODE (no internet connection)');
        debugPrint(
          'ℹ️ Note: Firebase warnings below are NORMAL and expected when offline',
        );
        return null;
      },
    );
    debugPrint('✅ Connected to Firebase successfully');
  } catch (e) {
    debugPrint('📱 Starting in OFFLINE MODE');
    debugPrint(
      'ℹ️ Note: Firebase warnings below are NORMAL and expected when offline',
    );
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeckProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Initialize responsive utility BEFORE MaterialApp uses the theme
          Responsive.init(context);
          
          return MaterialApp.router(
            title: 'Heads Up!',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
            scrollBehavior: SmoothScrollBehavior(),
            builder: (context, child) {
              // Wrap the child with NetworkStatusWidget after MaterialApp provides Directionality
              return NetworkStatusWidget(child: child ?? const SizedBox.shrink());
            },
          );
        },
      ),
    );
  }
}
