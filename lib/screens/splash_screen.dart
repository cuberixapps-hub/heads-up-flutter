import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import '../services/version_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    try {
      // Ensure Remote Config is fetched before checking version.
      // Timeout keeps the splash from hanging; on failure we fall through
      // to normal navigation (fail-open).
      await FirebaseService().ensureRemoteConfigReady().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Splash: Remote Config ready timeout — continuing');
        },
      );

      // Check for force update
      final versionService = VersionService();
      final status = await versionService.checkUpdateStatus();

      if (status == UpdateStatus.forceUpdateRequired) {
        final versionInfo = await versionService.getVersionInfo();
        if (mounted) {
          context.go('/force-update', extra: versionInfo);
          return;
        }
      }

      // Normal navigation
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      final destination = hasSeenOnboarding ? '/home' : '/onboarding';

      if (mounted) {
        context.go(destination);
      }
    } catch (e) {
      debugPrint('Splash navigation error: $e');
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A1628),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return const Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: SizedBox.shrink(),
    );
  }
}
