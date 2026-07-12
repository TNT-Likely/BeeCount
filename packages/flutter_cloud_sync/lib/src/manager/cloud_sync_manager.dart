import 'dart:convert';

import '../core/cloud_provider.dart';
import '../core/data_serializer.dart';
import '../core/exceptions.dart';
import '../core/sync_status.dart';
import '../utils/logger.dart';

/// Cached sync status entry
class _CachedStatus {
  final SyncStatus status;
  final DateTime cachedAt;

  _CachedStatus(this.status, this.cachedAt);

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

/// Cloud sync manager
///
/// Orchestrates sync operations between local and cloud storage.
/// Generic type [T] represents the business data type (e.g., ledger ID).
///
/// Example:
/// ```dart
/// final manager = CloudSyncManager<int>(
///   provider: supabaseProvider,
///   serializer: LedgerDataSerializer(db),
///   logger: CloudSyncLogger(onLog: (level, msg) => print('[$level] $msg')),
/// );
///
/// // Upload local data to cloud
/// await manager.upload(ledgerId: 123, path: 'ledgers/123.json');
///
/// // Check sync status
/// final status = await manager.getStatus(ledgerId: 123, path: 'ledgers/123.json');
/// ```
class CloudSyncManager<T> {
  /// Cloud provider instance
  final CloudProvider provider;

  /// Data serializer for business logic
  final DataSerializer<T> serializer;

  /// Logger instance
  final CloudSyncLogger? logger;

  /// Cache TTL (Time To Live) for sync status
  final Duration cacheTTL;

  /// Internal cache for sync status
  final Map<String, _CachedStatus> _statusCache = {};

  /// Creates a cloud sync manager
  ///
  /// [provider] - Cloud provider (Supabase, WebDAV, etc.)
  /// [serializer] - Business data serializer
  /// [logger] - Optional logger for debugging
  /// [cacheTTL] - Cache duration for sync status (default: 30 seconds)
  CloudSyncManager({
    required this.provider,
    required this.serializer,
    this.logger,
    this.cacheTTL = const Duration(seconds: 30),
  });

  /// Upload local data to cloud
  ///
  /// [data] - Business data to upload (e.g., ledger ID)
  /// [path] - Cloud storage path (e.g., 'ledgers/123.json')
  /// [metadata] - Optional metadata to attach
  ///
  /// Throws [CloudNotAuthenticatedException] if user not authenticated.
  /// Throws [CloudStorageException] if upload fails.
  ///
  /// Example:
  /// ```dart
  /// await manager.upload(
  ///   ledgerId: 123,
  ///   path: 'ledgers/123.json',
  ///   metadata: {'version': '1.0'},
  /// );
  /// ```
  Future<void> upload({
    required T data,
    required String path,
    Map<String, String>? metadata,
  }) async {
    logger?.info('Starting upload: $path');

    // 1. Check authentication
    final user = await provider.auth.currentUser;
    if (user == null) {
      logger?.error('Upload failed: User not authenticated');
      throw CloudNotAuthenticatedException();
    }

    try {
      // 2. Serialize business data
      final serializedData = await serializer.serialize(data);
      logger?.debug('Data serialized: ${serializedData.length} bytes');

      // 3. Calculate fingerprint
      final fingerprint = serializer.fingerprint(serializedData);
      logger?.debug('Fingerprint: $fingerprint');

      // 4. Prepare metadata
      final fullMetadata = <String, String>{
        'fingerprint': fingerprint,
        'uploadedAt': DateTime.now().toIso8601String(),
        'userId': user.id,
        ...?metadata,
      };

      // 5. Upload to cloud storage
      await provider.storage.upload(
        path: path,
        data: serializedData,
        metadata: fullMetadata,
      );

      // 6. Invalidate cache
      _statusCache.remove(path);

      logger?.info('Upload completed: $path');
    } catch (e) {
      logger?.error('Upload failed: $e');
      if (e is CloudSyncException) {
        rethrow;
      }
      throw CloudStorageException('Upload failed', e);
    }
  }

  /// Download data from cloud
  ///
  /// [path] - Cloud storage path
  ///
  /// Returns deserialized business data, or null if file doesn't exist.
  /// Throws [CloudNotAuthenticatedException] if user not authenticated.
  /// Throws [CloudStorageException] if download fails.
  ///
  /// Example:
  /// ```dart
  /// final ledgerId = await manager.download(path: 'ledgers/123.json');
  /// if (ledgerId != null) {
  ///   // Process downloaded data
  /// }
  /// ```
  Future<T?> download({required String path}) async {
    logger?.info('Starting download: $path');

    // 1. Check authentication
    final user = await provider.auth.currentUser;
    if (user == null) {
      logger?.error('Download failed: User not authenticated');
      throw CloudNotAuthenticatedException();
    }

    try {
      // 2. Download from cloud storage
      final serializedData = await provider.storage.download(path: path);

      if (serializedData == null) {
        logger?.info('Download completed: File not found');
        return null;
      }

      logger?.debug('Data downloaded: ${serializedData.length} bytes');

      // 3. Deserialize business data
      final data = await serializer.deserialize(serializedData);

      // 4. Invalidate cache
      _statusCache.remove(path);

      logger?.info('Download completed: $path');
      return data;
    } catch (e) {
      logger?.error('Download failed: $e');
      if (e is CloudSyncException) {
        rethrow;
      }
      throw CloudStorageException('Download failed', e);
    }
  }

  /// Get sync status
  ///
  /// [data] - Local business data (optional, for fingerprint comparison)
  /// [path] - Cloud storage path
  /// [localUpdatedAt] - Local data update timestamp (optional, for direction determination)
  /// [forceRefresh] - Bypass cache and fetch fresh status
  ///
  /// Returns [SyncStatus] with current sync state, direction, and timestamps.
  ///
  /// Example:
  /// ```dart
  /// final status = await manager.getStatus(
  ///   data: 123,
  ///   path: 'ledgers/123.json',
  ///   localUpdatedAt: DateTime.now(),
  /// );
  ///
  /// if (status.isLocalNewer) {
  ///   // Show "Upload" button
  /// } else if (status.isCloudNewer) {
  ///   // Show "Download" button
  /// }
  /// ```
  Future<SyncStatus> getStatus({
    T? data,
    required String path,
    DateTime? localUpdatedAt,
    bool forceRefresh = false,
  }) async {
    logger?.debug('Getting sync status: $path (forceRefresh: $forceRefresh)');

    // 1. Check cache
    if (!forceRefresh) {
      final cached = _statusCache[path];
      if (cached != null && !cached.isExpired(cacheTTL)) {
        logger?.debug('Returning cached status: $path');
        return cached.status;
      }
    }

    try {
      // 2. Check authentication
      final user = await provider.auth.currentUser;
      if (user == null) {
        const status = SyncStatus(
          state: SyncState.notAuthenticated,
          message: 'User not authenticated',
        );
        _cacheStatus(path, status);
        return status;
      }

      // 3. Calculate local fingerprint and extract metadata if data provided
      String? localFingerprint;
      int? localCount;
      String? localData;

      if (data != null) {
        localData = await serializer.serialize(data);
        localFingerprint = serializer.fingerprint(localData);

        // Try to extract count from serialized data (if it's JSON with a 'count' field)
        try {
          final json = jsonDecode(localData) as Map<String, dynamic>?;
          if (json != null && json.containsKey('count')) {
            localCount = (json['count'] as num?)?.toInt();
          }
        } catch (_) {
          // Not JSON or doesn't have count field, ignore
        }

        logger
            ?.debug('Local fingerprint: $localFingerprint, count: $localCount');
      }

      // 4. Check if cloud file exists
      final cloudFile = await provider.storage.getMetadata(path: path);

      if (cloudFile == null) {
        final status = SyncStatus(
          state: SyncState.localOnly,
          localFingerprint: localFingerprint,
          message: 'No cloud backup found',
        );
        _cacheStatus(path, status);
        return status;
      }

      // 5. Download cloud data to extract metadata
      final cloudData = await provider.storage.download(path: path);
      String? cloudFingerprint;
      int? cloudCount;
      DateTime? cloudUpdatedAt;

      if (cloudData != null) {
        cloudFingerprint = serializer.fingerprint(cloudData);

        // Try to extract metadata from cloud JSON
        try {
          final cloudJson = jsonDecode(cloudData) as Map<String, dynamic>?;
          if (cloudJson != null) {
            // Extract count
            if (cloudJson.containsKey('count')) {
              cloudCount = (cloudJson['count'] as num?)?.toInt();
            }

            // Extract exportedAt timestamp
            if (cloudJson.containsKey('exportedAt')) {
              final exportedAtStr = cloudJson['exportedAt'] as String?;
              if (exportedAtStr != null) {
                cloudUpdatedAt = DateTime.tryParse(exportedAtStr);
              }
            }
          }
        } catch (_) {
          // Not JSON or missing fields, ignore
        }
      }

      logger?.debug(
          'Cloud fingerprint: $cloudFingerprint, count: $cloudCount, updatedAt: $cloudUpdatedAt');

      // 6. Get last sync timestamp from metadata
      final lastSyncedAtStr = cloudFile.metadata?['uploadedAt'] as String?;
      final lastSyncedAt = lastSyncedAtStr != null
          ? DateTime.tryParse(lastSyncedAtStr)
          : cloudFile.lastModified;

      // 7. Compare fingerprints and determine state/direction
      SyncState state;
      SyncDirection? direction;
      String? message;

      if (localFingerprint == null) {
        // No local data to compare, just report cloud state
        state = SyncState.synced;
        message = 'Cloud backup exists';
      } else if (cloudFingerprint == null) {
        // No cloud data found
        state = SyncState.localOnly;
        direction = SyncDirection.localNewer;
        message = 'No cloud backup';
      } else if (localFingerprint == cloudFingerprint) {
        // Fingerprints match - data is synced
        state = SyncState.synced;
        message = 'Local and cloud data match';
      } else {
        // Fingerprints differ - data is out of sync
        state = SyncState.outOfSync;

        // Determine direction using timestamps or counts
        if (localUpdatedAt != null && cloudUpdatedAt != null) {
          // Use timestamps if available
          if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
            direction = SyncDirection.localNewer;
            message = 'Local data is newer (timestamp)';
          } else if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
            direction = SyncDirection.cloudNewer;
            message = 'Cloud data is newer (timestamp)';
          } else {
            direction = SyncDirection.unknown;
            message = 'Data differs but same timestamp';
          }
        } else if (localCount != null && cloudCount != null) {
          // Fallback to count comparison
          if (localCount > cloudCount) {
            direction = SyncDirection.localNewer;
            message = 'Local has more items ($localCount vs $cloudCount)';
          } else if (cloudCount > localCount) {
            direction = SyncDirection.cloudNewer;
            message = 'Cloud has more items ($cloudCount vs $localCount)';
          } else {
            direction = SyncDirection.unknown;
            message = 'Data differs but same count';
          }
        } else {
          // Cannot determine direction
          direction = SyncDirection.unknown;
          message = 'Local and cloud data differ';
        }
      }

      final status = SyncStatus(
        state: state,
        localFingerprint: localFingerprint,
        cloudFingerprint: cloudFingerprint,
        lastSyncedAt: lastSyncedAt,
        localUpdatedAt: localUpdatedAt,
        cloudUpdatedAt: cloudUpdatedAt,
        direction: direction,
        localCount: localCount,
        cloudCount: cloudCount,
        message: message,
      );

      _cacheStatus(path, status);
      logger?.info('Sync status: $state');
      return status;
    } catch (e) {
      logger?.error('Get status failed: $e');
      final status = SyncStatus(
        state: SyncState.error,
        message: 'Failed to get sync status: $e',
      );
      return status;
    }
  }

  /// Delete remote file
  ///
  /// [path] - Cloud storage path
  ///
  /// Throws [CloudNotAuthenticatedException] if user not authenticated.
  /// Throws [CloudStorageException] if deletion fails.
  ///
  /// Example:
  /// ```dart
  /// await manager.deleteRemote(path: 'ledgers/123.json');
  /// ```
  Future<void> deleteRemote({required String path}) async {
    logger?.info('Deleting remote file: $path');

    // 1. Check authentication
    final user = await provider.auth.currentUser;
    if (user == null) {
      logger?.error('Delete failed: User not authenticated');
      throw CloudNotAuthenticatedException();
    }

    try {
      // 2. Delete from cloud storage
      await provider.storage.delete(path: path);

      // 3. Invalidate cache
      _statusCache.remove(path);

      logger?.info('Delete completed: $path');
    } catch (e) {
      logger?.error('Delete failed: $e');
      if (e is CloudSyncException) {
        rethrow;
      }
      throw CloudStorageException('Delete failed', e);
    }
  }

  /// Clear all cached status
  void clearCache() {
    logger?.debug('Clearing status cache');
    _statusCache.clear();
  }

  /// Cache sync status
  void _cacheStatus(String path, SyncStatus status) {
    _statusCache[path] = _CachedStatus(status, DateTime.now());
  }
}
