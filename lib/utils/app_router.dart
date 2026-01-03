import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/notification_permission_screen.dart';
import '../screens/home_screen.dart';
import '../screens/home_screen_v2.dart';
import '../screens/category_selection_screen.dart';
import '../screens/results_screen.dart';
import '../screens/shared_results_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/team_setup_screen.dart';
import '../screens/team_results_screen.dart';
import '../screens/custom_deck_management_screen.dart';
import '../screens/custom_deck_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/search_screen.dart';
import '../screens/deck_details_screen.dart';
import '../services/deep_link_service.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation:
        '/splash', // Start with splash screen to check onboarding status
    
    // Handle deep link URLs that GoRouter can't match directly
    onException: (context, state, router) {
      final uri = state.uri;
      debugPrint('🔗 GoRouter exception for URI: $uri');
      
      // Parse the URI to extract path and query parameters
      // For custom scheme URLs (headsup://deck?id=x), the path segment is in the HOST
      final rawPath = uri.path.replaceAll(RegExp(r'^/+|/+$'), '');
      final host = uri.host;
      
      // Reconstruct effective path from host if it's a known route
      final String effectivePath;
      if (host.isNotEmpty && (host == 'deck' || host == 'results' || host == 'invite' || host == 'home')) {
        effectivePath = host; // Use host as path for custom scheme URLs
      } else {
        effectivePath = rawPath;
      }
      
      final queryParams = uri.queryParameters;
      
      debugPrint('🔗 EffectivePath: $effectivePath, Host: $host, RawPath: $rawPath, Query: $queryParams');
      
      // Handle deck deep links
      if (effectivePath == 'deck' || effectivePath.startsWith('deck') || queryParams.containsKey('deckId')) {
        final deckId = queryParams['deckId'] ?? queryParams['id'] ?? '';
        if (deckId.isNotEmpty) {
          debugPrint('🔗 Navigating to deck: $deckId');
          router.go('/deck/$deckId');
          return;
        }
      }
      
      // Handle results deep links
      if (effectivePath == 'results' || effectivePath.startsWith('results') || queryParams.containsKey('score')) {
        if (queryParams.containsKey('score') || queryParams.containsKey('deck')) {
          final linkData = DeepLinkData(
            type: DeepLinkType.results,
            deckName: queryParams['deck'] != null 
                ? Uri.decodeComponent(queryParams['deck']!) 
                : null,
            score: int.tryParse(queryParams['score'] ?? ''),
            correct: int.tryParse(queryParams['correct'] ?? ''),
            passed: int.tryParse(queryParams['passed'] ?? ''),
          );
          router.go('/shared-results', extra: linkData);
          return;
        }
      }
      
      // Handle invite deep links
      if (effectivePath == 'invite' || effectivePath.startsWith('invite') || queryParams.containsKey('ref')) {
        router.go('/home');
        return;
      }
      
      // Default: go to home
      debugPrint('🔗 Unknown deep link, going to home');
      router.go('/home');
    },
    
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/notification-permission',
        builder: (context, state) => const NotificationPermissionScreen(isOnboarding: true),
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
        path: '/explore',
        builder: (context, state) {
          final categoryParam = state.uri.queryParameters['category'];
          final category = categoryParam != null 
              ? Uri.decodeComponent(categoryParam) 
              : null;
          return ExploreScreen(category: category);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
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
      // Deep link routes
      // Route for /deck/:id (path parameter format)
      GoRoute(
        path: '/deck/:id',
        builder: (context, state) {
          final deckId = state.pathParameters['id'];
          return DeckDetailsScreen(deckId: deckId ?? '');
        },
      ),
      // Route for /deck?deckId=xxx (query parameter format - from deep links)
      GoRoute(
        path: '/deck',
        builder: (context, state) {
          // Get deckId from query parameters
          final deckId = state.uri.queryParameters['deckId'] ?? 
                         state.uri.queryParameters['id'] ?? '';
          return DeckDetailsScreen(deckId: deckId);
        },
      ),
      // Route for /results with query params (from deep links)
      GoRoute(
        path: '/results',
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          // Check if this is a shared results deep link
          if (queryParams.containsKey('score') || queryParams.containsKey('deck')) {
            final linkData = DeepLinkData(
              type: DeepLinkType.results,
              deckName: queryParams['deck'] != null 
                  ? Uri.decodeComponent(queryParams['deck']!) 
                  : null,
              score: int.tryParse(queryParams['score'] ?? ''),
              correct: int.tryParse(queryParams['correct'] ?? ''),
              passed: int.tryParse(queryParams['passed'] ?? ''),
            );
            return SharedResultsScreen(linkData: linkData);
          }
          // Regular results screen (from gameplay)
          return const ResultsScreen();
        },
      ),
      GoRoute(
        path: '/shared-results',
        builder: (context, state) {
          final data = state.extra as DeepLinkData?;
          return SharedResultsScreen(linkData: data);
        },
      ),
      // Route for /invite (from deep links)
      GoRoute(
        path: '/invite',
        builder: (context, state) {
          // Just navigate to home, referral tracking is done in DeepLinkService
          return const HomeScreenV2();
        },
      ),
    ],
  );
}
