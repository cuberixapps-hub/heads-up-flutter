import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'l10n/app_localizations.dart';
import 'constants/app_theme.dart';
import 'providers/deck_provider.dart';
import 'providers/game_provider.dart';
import 'providers/language_provider.dart';
import 'widgets/network_status_widget.dart';

import 'services/firebase_service.dart';
import 'services/ad_service.dart';
import 'services/purchases_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/version_service.dart';
import 'screens/force_update_screen.dart';
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

  debugPrint('');
  debugPrint('========================================');
  debugPrint('🎮 HEADS UP GAME STARTING...');
  debugPrint('========================================');

  // IMPORTANT: Initialize Firebase FIRST (includes Remote Config)
  final firebaseService = FirebaseService();
  await firebaseService.initialize();
  
  // Register FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize AdMob (will use Firebase Remote Config to determine ad type)
  await AdService.initialize();
  
  // Initialize RevenueCat for in-app purchases
  await PurchasesService.initialize();
  
  // Initialize Push Notifications
  await NotificationService.initialize();
  
  // Initialize Deep Link Service for sharing
  await DeepLinkService.initialize();

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
    // Listen for incoming deep links
    DeepLinkService().onDeepLink.listen((linkData) {
      debugPrint('🔗 Handling deep link: $linkData');
      // Navigate using the router
      DeepLinkService().handleDeepLinkNavigation(AppRouter.router, linkData);
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
                title: 'Heads Up!',
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
                  // Wrap with version check and network status
                  return VersionCheckWrapper(
                    child: NetworkStatusWidget(child: child ?? const SizedBox.shrink()),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Wrapper widget that checks for app updates on startup
class VersionCheckWrapper extends StatefulWidget {
  final Widget child;

  const VersionCheckWrapper({super.key, required this.child});

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  UpdateStatus? _updateStatus;
  VersionInfo? _versionInfo;
  bool _hasChecked = false;
  bool _softUpdateDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final versionService = VersionService();
      final status = await versionService.checkUpdateStatus();
      final versionInfo = await versionService.getVersionInfo();

      if (mounted) {
        setState(() {
          _updateStatus = status;
          _versionInfo = versionInfo;
          _hasChecked = true;
        });

        // Show soft update dialog after a short delay
        if (status == UpdateStatus.softUpdateAvailable && !_softUpdateDismissed) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_softUpdateDismissed) {
              _showSoftUpdateDialog();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      if (mounted) {
        setState(() {
          _updateStatus = UpdateStatus.upToDate;
          _hasChecked = true;
        });
      }
    }
  }

  void _showSoftUpdateDialog() {
    if (_versionInfo != null && mounted) {
      SoftUpdateDialog.show(context, _versionInfo!).then((_) {
        setState(() {
          _softUpdateDismissed = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show force update screen if required
    if (_hasChecked && 
        _updateStatus == UpdateStatus.forceUpdateRequired && 
        _versionInfo != null) {
      return ForceUpdateScreen(versionInfo: _versionInfo!);
    }

    // Otherwise show the normal app
    return widget.child;
  }
}
