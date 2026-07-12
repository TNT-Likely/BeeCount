library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'webdav_auth_service.dart';
import 'webdav_storage_service.dart';

/// WebDAV implementation of [CloudProvider].
///
/// This provider uses WebDAV protocol for cloud storage.
/// WebDAV uses Basic Auth for authentication.
///
/// Required configuration keys:
/// - `url`: WebDAV server URL
/// - `username`: Username for authentication
/// - `password`: Password for authentication
/// - `remotePath`: Remote path prefix (optional, defaults to '/')
///
/// Example:
/// ```dart
/// final provider = WebDAVProvider();
/// await provider.initialize({
///   'url': 'https://webdav.example.com',
///   'username': 'your-username',
///   'password': 'your-password',
///   'remotePath': '/sync/', // optional
/// });
/// ```
class WebDAVProvider implements CloudProvider {
  webdav.Client? _client;
  WebDAVAuthService? _authService;
  WebDAVStorageService? _storageService;

  @override
  String get providerId => 'webdav';

  @override
  String get providerName => 'WebDAV';

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

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    if (!validateConfig(config)) {
      throw CloudConfigurationException(
          'Invalid configuration. Required keys: url, username, password');
    }

    final url = config['url'] as String;
    final username = config['username'] as String;
    final password = config['password'] as String;
    final remotePath = config['remotePath'] as String? ?? '/';

    try {
      // Create WebDAV client
      _client = webdav.newClient(
        url,
        user: username,
        password: password,
        debug: false,
      );

      // Verify connection by reading the remote path
      try {
        await _client!.readDir(remotePath);
      } catch (e) {
        // If remote path doesn't exist, try to create it
        await _client!.mkdir(remotePath);
      }

      // Create service instances
      _authService = WebDAVAuthService(username);

      _storageService = WebDAVStorageService(_client!, remotePath);
    } catch (e) {
      throw CloudConfigurationException('Failed to initialize WebDAV: $e', e);
    }
  }

  @override
  bool validateConfig(Map<String, dynamic> config) {
    if (!config.containsKey('url') || config['url'] is! String) {
      return false;
    }
    if (!config.containsKey('username') || config['username'] is! String) {
      return false;
    }
    if (!config.containsKey('password') || config['password'] is! String) {
      return false;
    }
    // remotePath is optional
    if (config.containsKey('remotePath') && config['remotePath'] is! String) {
      return false;
    }
    return true;
  }

  @override
  Future<void> dispose() async {
    _authService?.dispose();
    _authService = null;
    _storageService = null;
    _client = null;
  }
}
