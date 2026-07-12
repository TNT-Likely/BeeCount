library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Supabase implementation of [CloudDatabaseService].
///
/// Provides CRUD operations and realtime subscriptions for Supabase PostgreSQL database.
///
/// Example:
/// ```dart
/// final client = supabase.Supabase.instance.client;
/// final dbService = SupabaseDatabaseService(client);
///
/// // Insert
/// final record = await dbService.insert(
///   table: 'transactions',
///   data: {'amount': 100, 'note': 'Test'},
/// );
///
/// // Query
/// final records = await dbService.query(
///   table: 'transactions',
///   filters: [QueryFilter.eq('user_id', userId)],
/// );
/// ```
class SupabaseDatabaseService implements CloudDatabaseService {
  final supabase.SupabaseClient _client;

  SupabaseDatabaseService(this._client);

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> data,
    bool autoInjectUserId = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // 自动注入 user_id
      final insertData = Map<String, dynamic>.from(data);
      if (autoInjectUserId && !insertData.containsKey('user_id')) {
        insertData['user_id'] = user.id;
      }

      // Insert and return the created record
      final response =
          await _client.from(table).insert(insertData).select().single();

      return response as Map<String, dynamic>;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Insert failed: $e', e);
    }
  }

  /// Batch insert multiple records
  Future<List<Map<String, dynamic>>> insertBatch({
    required String table,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Batch insert and return created records
      final response = await _client.from(table).insert(data).select();

      return (response as List).cast<Map<String, dynamic>>();
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch insert failed: $e', e);
    }
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required String id,
    required Map<String, dynamic> data,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build query
      var query = _client.from(table).update(data).eq('id', id);

      // 自动添加用户过滤
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      // Update and return the updated record
      final response = await query.select().single();

      return response as Map<String, dynamic>;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Update failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Update failed: $e', e);
    }
  }

  @override
  Future<void> delete({
    required String table,
    required String id,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build query
      var query = _client.from(table).delete().eq('id', id);

      // 自动添加用户过滤
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      // Delete record
      await query;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Delete failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Delete failed: $e', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query({
    required String table,
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
    int? offset,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build query
      dynamic query = _client.from(table).select();

      // 自动添加用户过滤
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      // Apply filters
      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: !descending);
      }

      // Apply pagination
      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 1000) - 1);
      }

      // Execute query
      final response = await query;

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Query failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Query failed: $e', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getById({
    required String table,
    required String id,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Get single record
      final response =
          await _client.from(table).select().eq('id', id).maybeSingle();

      return response as Map<String, dynamic>?;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Get by ID failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Get by ID failed: $e', e);
    }
  }

  @override
  Stream<DatabaseEvent> subscribe({
    required String table,
    List<QueryFilter>? filters,
    String event = '*',
  }) {
    // Note: Realtime subscriptions should be handled by SupabaseRealtimeService
    // This method is kept for interface compatibility but delegates to realtime service
    throw UnimplementedError(
      'Use SupabaseRealtimeService for realtime subscriptions',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> batchInsert({
    required String table,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Batch insert
      final response = await _client.from(table).insert(data).select();

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch insert failed: $e', e);
    }
  }

  @override
  Future<void> batchUpdate({
    required String table,
    required List<Map<String, dynamic>> data,
    String idField = 'id',
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Supabase doesn't support batch update directly
      // We need to update records one by one
      for (final record in data) {
        final id = record[idField];
        if (id == null) {
          throw CloudStorageException('Record missing $idField field');
        }

        await _client.from(table).update(record).eq(idField, id);
      }
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch update failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch update failed: $e', e);
    }
  }

  @override
  Future<void> batchDelete({
    required String table,
    required List<QueryFilter> filters,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build delete query with filters
      var query = _client.from(table).delete();

      for (final filter in filters) {
        query = _applyFilter(query, filter);
      }

      await query;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch delete failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch delete failed: $e', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String query) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Execute raw RPC call
      // Note: This requires a custom PostgreSQL function to be created
      final response = await _client.rpc('execute_raw_query', params: {
        'query_text': query,
      });

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Raw query failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Raw query failed: $e', e);
    }
  }

  /// Apply filter to query
  dynamic _applyFilter(dynamic query, QueryFilter filter) {
    switch (filter.operator) {
      case 'eq':
        return query.eq(filter.column, filter.value);
      case 'neq':
        return query.neq(filter.column, filter.value);
      case 'gt':
        return query.gt(filter.column, filter.value);
      case 'gte':
        return query.gte(filter.column, filter.value);
      case 'lt':
        return query.lt(filter.column, filter.value);
      case 'lte':
        return query.lte(filter.column, filter.value);
      case 'like':
        return query.like(filter.column, filter.value);
      case 'ilike':
        return query.ilike(filter.column, filter.value);
      case 'in':
        return query.inFilter(filter.column, filter.value as List);
      case 'is':
        return query.isFilter(filter.column, filter.value);
      case 'contains':
        return query.contains(filter.column, filter.value);
      case 'containedBy':
        return query.containedBy(filter.column, filter.value);
      case 'overlaps':
        return query.overlaps(filter.column, filter.value as List);
      default:
        throw CloudStorageException(
            'Unsupported filter operator: ${filter.operator}');
    }
  }
}
