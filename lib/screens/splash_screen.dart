import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate immediately on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      // Always use v2 home screen
      final destination = hasSeenOnboarding ? '/home' : '/onboarding';

      if (mounted) {
        context.go(destination);
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
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

    // Simple blank screen - navigates immediately
    return const Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: SizedBox.shrink(),
    );
  }
}
