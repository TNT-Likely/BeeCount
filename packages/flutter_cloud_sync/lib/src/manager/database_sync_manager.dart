import 'dart:async';
import 'dart:collection';

import '../core/database_service.dart';
import '../core/exceptions.dart';
import '../core/realtime_service.dart';
import '../utils/logger.dart';

/// Sync operation type
enum SyncOperationType {
  /// Insert operation
  insert,

  /// Update operation
  update,

  /// Delete operation
  delete,
}

/// Pending sync operation
class PendingSyncOperation {
  /// Unique operation ID
  final String id;

  /// Operation type
  final SyncOperationType type;

  /// Table name
  final String table;

  /// Record data (for insert/update)
  final Map<String, dynamic>? data;

  /// Record ID (for update/delete)
  final String? recordId;

  /// Operation timestamp
  final DateTime timestamp;

  /// Number of retry attempts
  final int retryCount;

  /// Last error message (if any)
  final String? error;

  const PendingSyncOperation({
    required this.id,
    required this.type,
    required this.table,
    this.data,
    this.recordId,
    required this.timestamp,
    this.retryCount = 0,
    this.error,
  });

  /// Create a copy with updated fields
  PendingSyncOperation copyWith({
    int? retryCount,
    String? error,
  }) {
    return PendingSyncOperation(
      id: id,
      type: type,
      table: table,
      data: data,
      recordId: recordId,
      timestamp: timestamp,
      retryCount: retryCount ?? this.retryCount,
      error: error,
    );
  }

  @override
  String toString() {
    return 'PendingSyncOperation(id: $id, type: $type, table: $table, recordId: $recordId, retryCount: $retryCount)';
  }
}

/// Sync conflict
class SyncConflict {
  /// Local record data
  final Map<String, dynamic> localRecord;

  /// Cloud record data
  final Map<String, dynamic> cloudRecord;

  /// Table name
  final String table;

  /// Record ID
  final String recordId;

  const SyncConflict({
    required this.localRecord,
    required this.cloudRecord,
    required this.table,
    required this.recordId,
  });
}

/// Conflict resolution strategy
enum ConflictResolutionStrategy {
  /// Last-Write-Wins (use version/timestamp)
  lastWriteWins,

  /// Always prefer local changes
  preferLocal,

  /// Always prefer cloud changes
  preferCloud,

  /// Manual resolution required (throw exception)
  manual,
}

/// Database sync status
enum DatabaseSyncStatus {
  /// Idle (not syncing)
  idle,

  /// Syncing in progress
  syncing,

  /// Error occurred
  error,

  /// Offline (queuing operations)
  offline,
}

/// Database sync manager
///
/// Manages bidirectional synchronization between local and cloud databases.
/// Supports offline operations, conflict resolution, and realtime updates.
///
/// Example:
/// ```dart
/// final syncManager = DatabaseSyncManager(
///   databaseService: supabaseDatabaseProvider,
///   realtimeService: supabaseRealtimeProvider,
///   logger: CloudSyncLogger(onLog: (level, msg) => print('[$level] $msg')),
/// );
///
/// // Sync a single record
/// await syncManager.syncRecord(
///   table: 'transactions',
///   localRecord: {'id': '123', 'amount': 100, 'version': 1},
/// );
///
/// // Subscribe to table changes
/// await syncManager.subscribeToTable(
///   table: 'transactions',
///   filters: [QueryFilter.eq('ledger_id', ledgerId)],
///   onEvent: (event) async {
///     // Handle incoming changes from cloud
///     await updateLocalDatabase(event.record);
///   },
/// );
///
/// // Process offline queue when connection restored
/// await syncManager.processOfflineQueue();
/// ```
class DatabaseSyncManager {
  /// Cloud database service
  final CloudDatabaseService databaseService;

  /// Realtime service (optional, for subscriptions)
  final CloudRealtimeService? realtimeService;

  /// Logger instance
  final CloudSyncLogger? logger;

  /// Conflict resolution strategy
  final ConflictResolutionStrategy conflictStrategy;

  /// Maximum retry attempts for failed operations
  final int maxRetryAttempts;

  /// Current sync status
  DatabaseSyncStatus _status = DatabaseSyncStatus.idle;

  /// Offline operations queue
  final Queue<PendingSyncOperation> _offlineQueue = Queue();

  /// Active realtime subscriptions
  final Map<String, RealtimeChannel> _subscriptions = {};

  /// Stream controller for sync status changes
  final StreamController<DatabaseSyncStatus> _statusController =
      StreamController<DatabaseSyncStatus>.broadcast();

  /// Creates a database sync manager
  ///
  /// [databaseService] - Cloud database service implementation
  /// [realtimeService] - Optional realtime service for subscriptions
  /// [logger] - Optional logger for debugging
  /// [conflictStrategy] - Conflict resolution strategy (default: lastWriteWins)
  /// [maxRetryAttempts] - Maximum retry attempts for failed operations (default: 3)
  DatabaseSyncManager({
    required this.databaseService,
    this.realtimeService,
    this.logger,
    this.conflictStrategy = ConflictResolutionStrategy.lastWriteWins,
    this.maxRetryAttempts = 3,
  });

  /// Current sync status
  DatabaseSyncStatus get status => _status;

  /// Sync status stream
  Stream<DatabaseSyncStatus> get statusStream => _statusController.stream;

  /// Pending operations count
  int get pendingOperationsCount => _offlineQueue.length;

  /// Check if currently syncing
  bool get isSyncing => _status == DatabaseSyncStatus.syncing;

  /// Check if offline
  bool get isOffline => _status == DatabaseSyncStatus.offline;

  /// Sync a single record from local to cloud
  ///
  /// Handles conflict detection and resolution automatically.
  ///
  /// [table] - Table name
  /// [localRecord] - Local record data (must include 'id' and 'version' fields)
  /// [forceUpdate] - Skip conflict check and force update
  ///
  /// Throws [CloudSyncException] if sync fails.
  ///
  /// Example:
  /// ```dart
  /// await syncManager.syncRecord(
  ///   table: 'transactions',
  ///   localRecord: {
  ///     'id': '123',
  ///     'amount': 100,
  ///     'version': 2,
  ///     'updated_at': DateTime.now().toIso8601String(),
  ///   },
  /// );
  /// ```
  Future<void> syncRecord({
    required String table,
    required Map<String, dynamic> localRecord,
    bool forceUpdate = false,
  }) async {
    final recordId = localRecord['id'] as String?;
    if (recordId == null) {
      throw CloudSyncException('Record must have an id field');
    }

    logger?.info('Syncing record: $table/$recordId');

    try {
      // Check if cloud record exists
      final cloudRecord = await databaseService.getById(
        table: table,
        id: recordId,
      );

      if (cloudRecord == null) {
        // Cloud record doesn't exist, insert it
        logger?.debug('Cloud record not found, inserting');
        await databaseService.insert(
          table: table,
          data: localRecord,
        );
        logger?.info('Record inserted: $table/$recordId');
        return;
      }

      // Cloud record exists, check for conflicts
      if (!forceUpdate) {
        final conflict = _detectConflict(localRecord, cloudRecord);
        if (conflict != null) {
          logger?.warning('Conflict detected for $table/$recordId');
          final resolved = await _resolveConflict(conflict);
          if (resolved == null) {
            throw CloudSyncException('Conflict resolution failed');
          }
          // Update cloud with resolved data
          await databaseService.update(
            table: table,
            id: recordId,
            data: resolved,
          );
          logger?.info('Conflict resolved and updated: $table/$recordId');
          return;
        }
      }

      // No conflict or force update, proceed with update
      await databaseService.update(
        table: table,
        id: recordId,
        data: localRecord,
      );
      logger?.info('Record updated: $table/$recordId');
    } catch (e) {
      logger?.error('Sync record failed: $e');
      if (e is CloudSyncException) {
        rethrow;
      }
      throw CloudStorageException('Failed to sync record', e);
    }
  }

  /// Queue an operation for offline sync
  ///
  /// Used when internet connection is unavailable.
  ///
  /// [operation] - Operation to queue
  ///
  /// Example:
  /// ```dart
  /// if (syncManager.isOffline) {
  ///   syncManager.queueOperation(
  ///     PendingSyncOperation(
  ///       id: uuid.v4(),
  ///       type: SyncOperationType.insert,
  ///       table: 'transactions',
  ///       data: transactionData,
  ///       timestamp: DateTime.now(),
  ///     ),
  ///   );
  /// }
  /// ```
  void queueOperation(PendingSyncOperation operation) {
    logger?.info('Queueing operation: ${operation.id}');
    _offlineQueue.add(operation);
    _updateStatus(DatabaseSyncStatus.offline);
  }

  /// Process offline queue
  ///
  /// Attempts to sync all queued operations.
  /// Should be called when connection is restored.
  ///
  /// Returns the number of successfully synced operations.
  ///
  /// Example:
  /// ```dart
  /// // When connection restored
  /// final synced = await syncManager.processOfflineQueue();
  /// print('Synced $synced operations');
  /// ```
  Future<int> processOfflineQueue() async {
    if (_offlineQueue.isEmpty) {
      logger?.info('Offline queue is empty');
      return 0;
    }

    logger
        ?.info('Processing offline queue: ${_offlineQueue.length} operations');
    _updateStatus(DatabaseSyncStatus.syncing);

    int successCount = 0;
    final failedOperations = <PendingSyncOperation>[];

    while (_offlineQueue.isNotEmpty) {
      final operation = _offlineQueue.removeFirst();

      try {
        await _executeOperation(operation);
        successCount++;
        logger?.debug('Operation completed: ${operation.id}');
      } catch (e) {
        logger?.error('Operation failed: ${operation.id} - $e');

        // Retry if under max attempts
        if (operation.retryCount < maxRetryAttempts) {
          failedOperations.add(
            operation.copyWith(
              retryCount: operation.retryCount + 1,
              error: e.toString(),
            ),
          );
        } else {
          logger?.error('Operation max retries reached: ${operation.id}');
        }
      }
    }

    // Re-queue failed operations
    for (final op in failedOperations) {
      _offlineQueue.add(op);
    }

    _updateStatus(
      _offlineQueue.isEmpty
          ? DatabaseSyncStatus.idle
          : DatabaseSyncStatus.offline,
    );

    logger?.info(
        'Offline queue processed: $successCount succeeded, ${failedOperations.length} failed');
    return successCount;
  }

  /// Subscribe to table changes (Realtime)
  ///
  /// Listens for INSERT, UPDATE, DELETE events from cloud database.
  ///
  /// [table] - Table name
  /// [filters] - Optional filters for events
  /// [onEvent] - Callback function for handling events
  /// [channelName] - Custom channel name (optional, defaults to table name)
  ///
  /// Throws [CloudSyncException] if realtime service not available.
  ///
  /// Example:
  /// ```dart
  /// await syncManager.subscribeToTable(
  ///   table: 'transactions',
  ///   filters: [QueryFilter.eq('ledger_id', ledgerId)],
  ///   onEvent: (event) async {
  ///     switch (event.type) {
  ///       case DatabaseEventType.insert:
  ///         await localDb.insert(event.record);
  ///         break;
  ///       case DatabaseEventType.update:
  ///         await localDb.update(event.record);
  ///         break;
  ///       case DatabaseEventType.delete:
  ///         await localDb.delete(event.record['id']);
  ///         break;
  ///     }
  ///   },
  /// );
  /// ```
  Future<void> subscribeToTable({
    required String table,
    List<QueryFilter>? filters,
    required Future<void> Function(DatabaseEvent) onEvent,
    String? channelName,
  }) async {
    if (realtimeService == null) {
      throw CloudSyncException('Realtime service not available');
    }

    final effectiveChannelName = channelName ?? 'sync:$table';

    logger
        ?.info('Subscribing to table: $table (channel: $effectiveChannelName)');

    // Create or get existing channel
    final channel = realtimeService!.channel(effectiveChannelName);

    // Build filter string for Supabase format
    String? filterString;
    if (filters != null && filters.isNotEmpty) {
      // Example: "ledger_id=eq.123"
      filterString =
          filters.map((f) => '${f.column}=${f.operator}.${f.value}').join(',');
    }

    // Subscribe to PostgreSQL changes
    channel.onPostgresChanges(
      event: '*', // Listen to all events (INSERT, UPDATE, DELETE)
      schema: 'public',
      table: table,
      filter: filterString,
      callback: (payload) async {
        logger?.debug(
            'Realtime event received: $table - ${payload['eventType']}');

        // Convert payload to DatabaseEvent
        final eventType = _parseEventType(payload['eventType'] as String?);
        final record = (payload['new'] as Map<String, dynamic>?) ??
            (payload['old'] as Map<String, dynamic>?) ??
            {};
        final oldRecord = payload['old'] as Map<String, dynamic>?;

        final event = DatabaseEvent(
          type: eventType,
          table: table,
          record: record,
          oldRecord: oldRecord,
          timestamp: DateTime.now(),
        );

        try {
          await onEvent(event);
          logger?.debug('Event handled successfully');
        } catch (e) {
          logger?.error('Event handler failed: $e');
        }
      },
    );

    // Subscribe to channel
    await channel.subscribe();

    // Cache subscription
    _subscriptions[effectiveChannelName] = channel;

    logger?.info('Subscribed to table: $table');
  }

  /// Unsubscribe from table changes
  ///
  /// [table] - Table name or channel name
  ///
  /// Example:
  /// ```dart
  /// await syncManager.unsubscribeFromTable('transactions');
  /// ```
  Future<void> unsubscribeFromTable(String table) async {
    final channelName = table.startsWith('sync:') ? table : 'sync:$table';

    logger?.info('Unsubscribing from table: $channelName');

    final channel = _subscriptions.remove(channelName);
    if (channel != null) {
      await channel.unsubscribe();
      logger?.info('Unsubscribed from table: $channelName');
    } else {
      logger?.warning('Channel not found: $channelName');
    }
  }

  /// Unsubscribe from all tables
  ///
  /// Example:
  /// ```dart
  /// await syncManager.unsubscribeAll();
  /// ```
  Future<void> unsubscribeAll() async {
    logger?.info('Unsubscribing from all tables');

    for (final channel in _subscriptions.values) {
      await channel.unsubscribe();
    }

    _subscriptions.clear();
    logger?.info('Unsubscribed from all tables');
  }

  /// Detect conflict between local and cloud records
  ///
  /// Returns null if no conflict, otherwise returns SyncConflict.
  SyncConflict? _detectConflict(
    Map<String, dynamic> localRecord,
    Map<String, dynamic> cloudRecord,
  ) {
    // Compare version numbers (optimistic locking)
    final localVersion = localRecord['version'] as int?;
    final cloudVersion = cloudRecord['version'] as int?;

    if (localVersion != null && cloudVersion != null) {
      if (localVersion <= cloudVersion) {
        // Local version is not newer, no conflict
        return null;
      }
      if (localVersion == cloudVersion + 1) {
        // Local is exactly one version ahead, normal update
        return null;
      }
      // Version mismatch, conflict detected
      return SyncConflict(
        localRecord: localRecord,
        cloudRecord: cloudRecord,
        table: '', // Will be filled by caller
        recordId: localRecord['id'] as String,
      );
    }

    // Fallback to timestamp comparison
    final localUpdated = DateTime.tryParse(
      localRecord['updated_at'] as String? ?? '',
    );
    final cloudUpdated = DateTime.tryParse(
      cloudRecord['updated_at'] as String? ?? '',
    );

    if (localUpdated != null && cloudUpdated != null) {
      if (localUpdated.isAfter(cloudUpdated)) {
        // Local is newer, potential conflict
        return SyncConflict(
          localRecord: localRecord,
          cloudRecord: cloudRecord,
          table: '',
          recordId: localRecord['id'] as String,
        );
      }
    }

    return null;
  }

  /// Resolve conflict using configured strategy
  ///
  /// Returns resolved record data, or null if resolution failed.
  Future<Map<String, dynamic>?> _resolveConflict(SyncConflict conflict) async {
    logger?.info(
        'Resolving conflict: ${conflict.table}/${conflict.recordId} using strategy: $conflictStrategy');

    switch (conflictStrategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        // Use version or timestamp to determine winner
        final localVersion = conflict.localRecord['version'] as int?;
        final cloudVersion = conflict.cloudRecord['version'] as int?;

        if (localVersion != null && cloudVersion != null) {
          return localVersion > cloudVersion
              ? conflict.localRecord
              : conflict.cloudRecord;
        }

        final localUpdated = DateTime.tryParse(
          conflict.localRecord['updated_at'] as String? ?? '',
        );
        final cloudUpdated = DateTime.tryParse(
          conflict.cloudRecord['updated_at'] as String? ?? '',
        );

        if (localUpdated != null && cloudUpdated != null) {
          return localUpdated.isAfter(cloudUpdated)
              ? conflict.localRecord
              : conflict.cloudRecord;
        }

        // Cannot determine, prefer local
        return conflict.localRecord;

      case ConflictResolutionStrategy.preferLocal:
        return conflict.localRecord;

      case ConflictResolutionStrategy.preferCloud:
        return conflict.cloudRecord;

      case ConflictResolutionStrategy.manual:
        throw CloudSyncException(
          'Manual conflict resolution required: ${conflict.table}/${conflict.recordId}',
        );
    }
  }

  /// Execute a pending operation
  Future<void> _executeOperation(PendingSyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.insert:
        if (operation.data == null) {
          throw CloudSyncException('Insert operation requires data');
        }
        await databaseService.insert(
          table: operation.table,
          data: operation.data!,
        );
        break;

      case SyncOperationType.update:
        if (operation.recordId == null || operation.data == null) {
          throw CloudSyncException(
              'Update operation requires recordId and data');
        }
        await databaseService.update(
          table: operation.table,
          id: operation.recordId!,
          data: operation.data!,
        );
        break;

      case SyncOperationType.delete:
        if (operation.recordId == null) {
          throw CloudSyncException('Delete operation requires recordId');
        }
        await databaseService.delete(
          table: operation.table,
          id: operation.recordId!,
        );
        break;
    }
  }

  /// Update sync status and notify listeners
  void _updateStatus(DatabaseSyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
      logger?.debug('Status changed: $newStatus');
    }
  }

  /// Parse event type string to enum
  DatabaseEventType _parseEventType(String? eventType) {
    switch (eventType?.toUpperCase()) {
      case 'INSERT':
        return DatabaseEventType.insert;
      case 'UPDATE':
        return DatabaseEventType.update;
      case 'DELETE':
        return DatabaseEventType.delete;
      default:
        return DatabaseEventType.insert;
    }
  }

  /// Dispose resources
  void dispose() {
    logger?.info('Disposing DatabaseSyncManager');
    _statusController.close();
    // Note: Don't unsubscribe here, let caller manage subscription lifecycle
  }
}
