library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// WebDAV implementation of [CloudStorageService].
class WebDAVStorageService implements CloudStorageService {
  final webdav.Client _client;
  final String _remotePath;

  WebDAVStorageService(this._client, this._remotePath);

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Ensure parent directories exist
      await _ensureDirectory(PathHelper.dirname(fullPath));

      // Convert string to bytes
      final bytes = utf8.encode(data);

      // Upload file
      await _client.write(fullPath, bytes);

      // Store metadata as custom properties if provided
      if (metadata != null && metadata.isNotEmpty) {
        await _storeMetadata(fullPath, metadata);
      }
    } catch (e) {
      throw CloudStorageException('Upload failed: $e', e);
    }
  }

  @override
  Future<String?> download({required String path}) async {
    try {
      final fullPath = _buildPath(path);

      try {
        // Try standard read (OPTIONS + GET). Some WebDAV servers
        // (e.g. Synology NAS) return 404 for OPTIONS on individual files,
        // so fall back to direct GET if that happens.
        final bytes = await _client.read(fullPath);
        return utf8.decode(bytes);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final isNotFound = msg.contains('404') || msg.contains('not found');

        if (!isNotFound) rethrow;

        // OPTIONS pre-check failed — fall back to direct GET.
        return _directGet(fullPath);
      }
    } catch (e) {
      throw CloudStorageException('Download failed: $e', e);
    }
  }

  /// Bypass OPTIONS pre-check and download file directly via GET.
  Future<String?> _directGet(String fullPath) async {
    try {
      final response = await _client.c.req<List<int>>(
        _client,
        'GET',
        fullPath,
        optionsHandler: (options) {
          options.responseType = ResponseType.bytes;
          options.headers?['accept'] = '*/*';
        },
      );

      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw CloudStorageException(
            'Download failed: HTTP ${response.statusCode}');
      }

      final data = response.data;
      if (data == null || data.isEmpty) return '';

      return utf8.decode(data);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('404') || msg.contains('not found')) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> delete({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Delete file
      await _client.remove(fullPath);

      // Delete metadata file if exists
      await _deleteMetadata(fullPath);
    } catch (e) {
      throw CloudStorageException('Delete failed: $e', e);
    }
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // List files
      final files = await _client.readDir(fullPath);

      // Convert to CloudFile objects, excluding directories and metadata files
      return files
          .where((file) =>
              !(file.isDir ?? true) &&
              !(file.name?.endsWith('.metadata.json') ?? false))
          .map((file) => CloudFile(
                name: file.name ?? '',
                path: file.path ?? fullPath,
                size: file.size,
                lastModified: file.mTime,
                metadata: const {},
              ))
          .toList();
    } catch (e) {
      throw CloudStorageException('List failed: $e', e);
    }
  }

  @override
  Future<bool> exists({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Check if file exists by trying to read its directory listing
      final parentDir = PathHelper.dirname(fullPath);
      final fileName = PathHelper.basename(fullPath);

      final files = await _client.readDir(parentDir);
      return files.any((f) => f.name == fileName);
    } catch (e) {
      // If error (e.g. directory doesn't exist), file doesn't exist
      return false;
    }
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Get file list to find the file
      final parentDir = PathHelper.dirname(fullPath);
      final fileName = PathHelper.basename(fullPath);

      final files = await _client.readDir(parentDir);
      final file = files.firstWhere(
        (f) => f.name == fileName,
        orElse: () => throw CloudStorageException('File not found: $path'),
      );

      // Try to load custom metadata
      final customMetadata = await _getMetadata(fullPath);

      return CloudFile(
        name: file.name!,
        path: file.path!,
        size: file.size,
        lastModified: file.mTime,
        metadata: customMetadata,
      );
    } catch (e) {
      if (e.toString().contains('404') ||
          e.toString().contains('not found') ||
          e is CloudStorageException) {
        return null;
      }
      throw CloudStorageException('Get metadata failed: $e', e);
    }
  }

  /// Builds the full path with remote path prefix.
  String _buildPath(String path) {
    return PathHelper.join([_remotePath, path]);
  }

  /// Ensures a directory exists, creating it if necessary.
  Future<void> _ensureDirectory(String dirPath) async {
    try {
      await _client.readDir(dirPath);
      // If readDir succeeds, directory exists
      return;
    } catch (e) {
      // Directory doesn't exist, create it
      await _createDirectoryRecursively(dirPath);
    }
  }

  /// Creates a directory recursively.
  Future<void> _createDirectoryRecursively(String dirPath) async {
    final parts = dirPath.split('/').where((p) => p.isNotEmpty).toList();
    var currentPath = '';

    for (final part in parts) {
      currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
      try {
        await _client.readDir(currentPath);
        // Directory exists
      } catch (e) {
        // Directory doesn't exist, create it
        try {
          await _client.mkdir(currentPath);
        } catch (createError) {
          // Ignore error if directory was created by another process
        }
      }
    }
  }

  /// Stores custom metadata as a separate JSON file.
  Future<void> _storeMetadata(
      String filePath, Map<String, String> metadata) async {
    try {
      final metadataPath = '$filePath.metadata.json';
      final metadataJson = jsonEncode({
        'metadata': metadata,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      final bytes = utf8.encode(metadataJson);
      await _client.write(metadataPath, bytes);
    } catch (e) {
      // Silently fail if metadata storage fails
      // This is optional functionality
    }
  }

  /// Retrieves custom metadata from JSON file.
  Future<Map<String, dynamic>> _getMetadata(String filePath) async {
    try {
      final metadataPath = '$filePath.metadata.json';
      final bytes = await _client.read(metadataPath);
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return json['metadata'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      // Return empty map if metadata file doesn't exist
      return {};
    }
  }

  /// Deletes custom metadata file.
  Future<void> _deleteMetadata(String filePath) async {
    try {
      final metadataPath = '$filePath.metadata.json';
      await _client.remove(metadataPath);
    } catch (e) {
      // Silently fail if metadata file doesn't exist
    }
  }
}
