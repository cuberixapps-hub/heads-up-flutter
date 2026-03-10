import 'package:flutter/foundation.dart';

/// Environment enum: development, UAT, production.
/// Resolved ONLY from --dart-define=ENVIRONMENT=... (no build-mode coupling).
enum Environment {
  development,
  uat,
  production,
}

/// Single entry point for environment-based behavior.
/// Environment is controlled ONLY via ENVIRONMENT dart-define.
class EnvironmentConfig {
  EnvironmentConfig._();

  static Environment? _resolved;

  /// Active environment. Resolved once from ENVIRONMENT dart-define only.
  static Environment get current {
    _resolved ??= _resolve();
    return _resolved!;
  }

  static Environment _resolve() {
    final raw =
        String.fromEnvironment('ENVIRONMENT', defaultValue: '').trim().toLowerCase();
    if (raw.isNotEmpty) {
      switch (raw) {
        case 'uat':
        case 'staging':
        case 'test':
          return Environment.uat;
        case 'production':
        case 'prod':
          return Environment.production;
        case 'development':
        case 'dev':
          return Environment.development;
        default:
          return Environment.development;
      }
    }
    return Environment.development;
  }

  static bool get isDevelopment => current == Environment.development;
  static bool get isUAT => current == Environment.uat;
  static bool get isProduction => current == Environment.production;

  /// Use test/sample ad unit IDs (dev + UAT). Production uses IDs from ProductionConfig.
  static bool get useTestAds => isDevelopment || isUAT;

  /// Use sandbox IAP / RevenueCat sandbox keys (dev + UAT). Production uses ProductionConfig keys.
  static bool get useSandboxIAP => isDevelopment || isUAT;

  /// Enable verbose debug logging (dev + UAT). Off in production.
  static bool get enableDebugLogging => isDevelopment || isUAT;

  // ===========================================================================
  // Supabase – override via --dart-define for production builds
  // ===========================================================================
  static String get supabaseUrl => const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://ybrtwonwgvangibcvrpx.supabase.co',
      );

  static String get supabaseAnonKey => const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlicnR3b253Z3ZhbmdpYmN2cnB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3NTU0MzEsImV4cCI6MjA4NDMzMTQzMX0.MYTzmqBXoLgq3kmpEii7d8R81-328NfK-1lSDnSg_F8',
      );

  /// Print current environment and flags. Call from main() after ensureInitialized().
  static void printEnvironmentInfo() {
    debugPrint('========================================');
    debugPrint('ENVIRONMENT: $current');
    debugPrint('  useTestAds: $useTestAds');
    debugPrint('  useSandboxIAP: $useSandboxIAP');
    debugPrint('  enableDebugLogging: $enableDebugLogging');
    debugPrint('========================================');
  }
}
