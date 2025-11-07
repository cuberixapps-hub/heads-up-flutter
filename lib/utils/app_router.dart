import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/home_screen_v2.dart';
import '../screens/category_selection_screen.dart';
import '../screens/results_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/team_setup_screen.dart';
import '../screens/team_results_screen.dart';
import '../screens/custom_deck_management_screen.dart';
import '../screens/custom_deck_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation:
        '/splash', // Start with splash screen to check onboarding status
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreenV2()),
      GoRoute(
        path: '/home-v2',
        builder: (context, state) => const HomeScreenV2(),
      ),
      GoRoute(
        path: '/home-v1',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategorySelectionScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/team-setup',
        builder: (context, state) => const TeamSetupScreen(),
      ),
      GoRoute(
        path: '/team-results',
        builder: (context, state) => const TeamResultsScreen(),
      ),
      GoRoute(
        path: '/custom-decks',
        builder: (context, state) => const CustomDeckManagementScreen(),
      ),
      GoRoute(
        path: '/custom-deck-create',
        builder: (context, state) => const CustomDeckScreen(),
      ),
    ],
  );
}
