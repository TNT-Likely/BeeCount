library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'supabase_auth_service.dart';
import 'supabase_storage_service.dart';
import 'supabase_database_service.dart';
import 'supabase_realtime_service.dart';

/// Supabase implementation of [CloudProvider].
///
/// This provider uses Supabase for cloud storage and authentication.
///
/// Required configuration keys:
/// - `url`: Supabase project URL
/// - `anonKey`: Supabase anonymous key
/// - `bucket`: Storage bucket name (optional, defaults to 'storage')
///
/// Example:
/// ```dart
/// final provider = SupabaseProvider();
/// await provider.initialize({
///   'url': 'https://your-project.supabase.co',
///   'anonKey': 'your-anon-key',
///   'bucket': 'user-data',
/// });
/// ```
class SupabaseProvider implements CloudProvider {
  supabase.SupabaseClient? _client;
  SupabaseAuthService? _authService;
  SupabaseStorageService? _storageService;
  SupabaseDatabaseService? _databaseService;
  SupabaseRealtimeService? _realtimeService;
  String _bucketName = 'storage';
  String? _pathPrefix;

  // Track current configuration to detect changes
  static String? _currentUrl;
  static String? _currentAnonKey;
  static bool _isInitialized = false;

  @override
  String get providerId => 'supabase';

  @override
  String get providerName => 'Supabase';

  @override
  CloudAuthService get auth {
    if (_authService == null) {
      throw CloudConfigurationException(
          'Provider not initialized. Call initialize() first.');
    }
    return _authService!;
  }

  @override
  CloudStorageService get storage {
    if (_storageService == null) {
      throw CloudConfigurationException(
          'Provider not initialized. Call initialize() first.');
    }
    return _storageService!;
  }

  /// Database service for direct database operations
  CloudDatabaseService? get databaseService => _databaseService;

  /// Realtime service for WebSocket-based subscriptions
  CloudRealtimeService? get realtimeService => _realtimeService;

  /// Supabase client instance
  supabase.SupabaseClient? get client => _client;

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    if (!validateConfig(config)) {
      throw CloudConfigurationException(
          'Invalid configuration. Required keys: url, anonKey');
    }

    final url = config['url'] as String;
    final anonKey = config['anonKey'] as String;
    _bucketName = config['bucket'] as String? ?? 'storage';
    _pathPrefix = config['pathPrefix'] as String?;

    try {
      // Check if Supabase is already initialized with the same config
      final configChanged = _currentUrl != url || _currentAnonKey != anonKey;

      if (_isInitialized && configChanged) {
        // Configuration changed, need to sign out and reinitialize
        try {
          await supabase.Supabase.instance.client.auth.signOut();
        } catch (_) {
          // Ignore signout errors
        }
        _isInitialized = false;
      }

      if (!_isInitialized) {
        // Initialize Supabase client (only once per configuration)
        await supabase.Supabase.initialize(
          url: url,
          anonKey: anonKey,
          authOptions: const supabase.FlutterAuthClientOptions(
            authFlowType: supabase.AuthFlowType.pkce,
          ),
        );
        _isInitialized = true;
        _currentUrl = url;
        _currentAnonKey = anonKey;
      }

      _client = supabase.Supabase.instance.client;

      // Create service instances
      _authService = SupabaseAuthService(_client!);
      _storageService =
          SupabaseStorageService(_client!, _bucketName, _pathPrefix);
      _databaseService = SupabaseDatabaseService(_client!);
      _realtimeService = SupabaseRealtimeService(_client!);
    } catch (e) {
      // If initialization fails due to already initialized, try to use existing instance
      if (e.toString().contains('already initialized') ||
          e.toString().contains('LateInitializationError')) {
        _client = supabase.Supabase.instance.client;
        _authService = SupabaseAuthService(_client!);
        _storageService =
            SupabaseStorageService(_client!, _bucketName, _pathPrefix);
        _databaseService = SupabaseDatabaseService(_client!);
        _realtimeService = SupabaseRealtimeService(_client!);
        _isInitialized = true;
        _currentUrl = url;
        _currentAnonKey = anonKey;
      } else {
        throw CloudConfigurationException(
            'Failed to initialize Supabase: $e', e);
      }
    }
  }

  @override
  bool validateConfig(Map<String, dynamic> config) {
    if (!config.containsKey('url') || config['url'] is! String) {
      return false;
    }
    if (!config.containsKey('anonKey') || config['anonKey'] is! String) {
      return false;
    }
    // bucket is optional
    if (config.containsKey('bucket') && config['bucket'] is! String) {
      return false;
    }
    return true;
  }

  @override
  Future<void> dispose() async {
    _authService = null;
    _storageService = null;
    _databaseService = null;
    _realtimeService = null;
    _client = null;
  }
}
