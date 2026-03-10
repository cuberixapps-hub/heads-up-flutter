import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'config/environment.dart';
import 'l10n/app_localizations.dart';
import 'constants/app_theme.dart';
import 'providers/deck_provider.dart';
import 'providers/game_provider.dart';
import 'providers/language_provider.dart';
import 'widgets/network_status_widget.dart';

import 'services/firebase_service.dart';
import 'services/supabase_service.dart';
import 'services/ad_service.dart';
import 'services/purchases_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'utils/app_router.dart';
import 'utils/responsive.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  // Handle background message (data processing only, no UI)
}

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

  EnvironmentConfig.printEnvironmentInfo();

  debugPrint('');
  debugPrint('========================================');
  debugPrint('🎮 HEADS UP GAME STARTING...');
  debugPrint('========================================');

  // Set preferred orientations (fast, essential)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style (fast, essential)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase core + Crashlytics BEFORE runApp so all errors are captured
  await _initializeFirebaseCrashlytics();

  // Register FCM background message handler (sync, fast)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Wrap runApp in runZonedGuarded to catch uncaught async errors
  runZonedGuarded<void>(() {
    runApp(const MyApp());

    // Initialize remaining services in background AFTER app is running
    _initializeServicesInBackground();
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

/// Initialize Firebase core and Crashlytics before runApp().
/// Ensures crash reporting is active from the very start of the app.
Future<void> _initializeFirebaseCrashlytics() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final crashlytics = FirebaseCrashlytics.instance;

    // Disable collection in debug mode to avoid noisy dev reports
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Catch all Flutter framework errors (fatal)
    FlutterError.onError = crashlytics.recordFlutterFatalError;

    // Catch platform-level errors not handled by Flutter (e.g. from isolates)
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    debugPrint('✅ Firebase Crashlytics initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase Crashlytics init failed: $e');
  }
}

/// Initialize all services in the background after app UI is shown
/// This dramatically improves app startup time
Future<void> _initializeServicesInBackground() async {
  debugPrint('🔄 Starting background service initialization...');
  final stopwatch = Stopwatch()..start();

  try {
    // Initialize Firebase first (required by other services)
    // Use a short timeout to avoid blocking
    final firebaseService = FirebaseService();
    await firebaseService.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('⚠️ Firebase init timeout - continuing anyway');
      },
    );

    // Initialize Supabase for deck content
    // This is used alongside Firebase (Firebase for auth, Supabase for decks)
    final supabaseService = SupabaseService();
    await supabaseService.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('⚠️ Supabase init timeout - continuing anyway');
      },
    );

    // AdMob and RevenueCat: run unconditionally, no timeout-based failures
    try {
      await AdService.initialize();
    } catch (e) {
      debugPrint('❌ AdMob initialization failed: $e');
    }
    try {
      await PurchasesService.initialize();
    } catch (e) {
      debugPrint('❌ RevenueCat initialization failed: $e');
    }

    // Other services in parallel
    await Future.wait([
      NotificationService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Notification init timeout');
        },
      ),
      DeepLinkService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ DeepLink init timeout');
        },
      ),
    ], eagerError: false);

    stopwatch.stop();
    debugPrint('✅ Background services initialized in ${stopwatch.elapsedMilliseconds}ms');
  } catch (e) {
    debugPrint('⚠️ Background initialization error: $e');
    debugPrint('📱 App will continue with limited functionality');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    final deepLinkService = DeepLinkService();
    
    // Check for pending deep link from cold start (handles race condition)
    // Use post-frame callback to ensure router is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingLink = deepLinkService.consumePendingDeepLink();
      if (pendingLink != null && pendingLink.type != DeepLinkType.home) {
        debugPrint('🔗 Processing pending deep link from cold start: $pendingLink');
        deepLinkService.handleDeepLinkNavigation(AppRouter.router, pendingLink);
      }
    });
    
    // Listen for incoming deep links while app is running
    deepLinkService.onDeepLink.listen((linkData) {
      debugPrint('🔗 Handling deep link from stream: $linkData');
      // Navigate using the router
      deepLinkService.handleDeepLinkNavigation(AppRouter.router, linkData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => DeckProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // Initialize responsive utility BEFORE MaterialApp uses the theme
              Responsive.init(context);
              
              return MaterialApp.router(
                title: 'Charades',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                routerConfig: AppRouter.router,
                scrollBehavior: SmoothScrollBehavior(),
                
                    // Localization configuration
                    locale: languageProvider.locale,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: LanguageProvider.supportedLocales,
                
                builder: (context, child) {
                  return NetworkStatusWidget(child: child ?? const SizedBox.shrink());
                },
              );
            },
          );
        },
      ),
    );
  }
}
