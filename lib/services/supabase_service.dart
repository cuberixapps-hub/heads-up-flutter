import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/environment.dart';

/// Service for managing Supabase connection
/// Used for deck content storage (decks and deck images)
/// Firebase is still used for auth, analytics, crashlytics, etc.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;
  SupabaseClient? _client;

  /// Check if Supabase is initialized
  bool get isInitialized => _initialized;

  /// Get the Supabase client
  SupabaseClient get client {
    if (_client == null) {
      throw StateError('SupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Initialize Supabase
  /// Call this in main.dart during app startup
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: EnvironmentConfig.supabaseUrl,
        anonKey: EnvironmentConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          // We're using Firebase for auth, so disable Supabase auth persistence
          authFlowType: AuthFlowType.implicit,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );

      _client = Supabase.instance.client;
      _initialized = true;

      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Supabase: $e');
      rethrow;
    }
  }

  /// Get a reference to a table
  SupabaseQueryBuilder from(String table) {
    return client.from(table);
  }

  /// Get storage reference
  SupabaseStorageClient get storage => client.storage;

  /// Check if Supabase is configured
  bool get isConfigured {
    return !EnvironmentConfig.supabaseUrl.contains('your-project') &&
           !EnvironmentConfig.supabaseAnonKey.contains('your-anon');
  }
}
