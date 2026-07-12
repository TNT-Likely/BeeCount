import 'dart:convert';
import 'dart:io';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 's3_client.dart';
import 's3_exceptions.dart';

/// S3 存储服务实现
class S3StorageService implements CloudStorageService {
  final S3Client client;
  final String bucket;

  S3StorageService(this.client, this.bucket);

  @override
  Future<void> uploadFile(String localPath, String remotePath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw CloudStorageException('File not found: $localPath');
      }

      // 读取文件
      final bytes = await file.readAsBytes();

      // 上传到 S3
      await client.putObject(
        bucket: bucket,
        key: _normalizePath(remotePath),
        data: bytes,
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to upload file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to upload file: $e');
    }
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath) async {
    try {
      // 从 S3 下载
      final bytes = await client.getObject(
        bucket: bucket,
        key: _normalizePath(remotePath),
      );

      // 写入本地文件
      final file = File(localPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    } on S3ObjectNotFoundException catch (e) {
      throw CloudStorageException('File not found: ${e.key}');
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to download file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to download file: $e');
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    try {
      await client.deleteObject(
        bucket: bucket,
        key: _normalizePath(remotePath),
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to delete file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to delete file: $e');
    }
  }

  @override
  Future<bool> fileExists(String remotePath) async {
    try {
      return await client.headObject(
        bucket: bucket,
        key: _normalizePath(remotePath),
      );
    } on S3Exception catch (e) {
      throw CloudStorageException(
          'Failed to check file existence: ${e.message}');
    } catch (e) {
      // 其他错误返回 false
      return false;
    }
  }

  @override
  Future<List<String>> listFiles(String remotePath) async {
    try {
      final prefix = _normalizePath(remotePath);
      return await client.listObjects(
        bucket: bucket,
        prefix: prefix.isEmpty ? null : prefix,
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to list files: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to list files: $e');
    }
  }

  @override
  Future<int> getFileSize(String remotePath) async {
    // S3 HeadObject 可以返回 Content-Length
    // 但当前 S3Client 实现中未解析，暂时不支持
    throw UnimplementedError('getFileSize not implemented for S3');
  }

  @override
  Future<DateTime?> getLastModified(String remotePath) async {
    // S3 HeadObject 可以返回 Last-Modified
    // 但当前 S3Client 实现中未解析，暂时不支持
    throw UnimplementedError('getLastModified not implemented for S3');
  }

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    try {
      // 将字符串数据转为字节
      final bytes = utf8.encode(data);

      // 上传到 S3
      await client.putObject(
        bucket: bucket,
        key: _normalizePath(path),
        data: bytes,
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to upload file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to upload file: $e');
    }
  }

  @override
  Future<String?> download({required String path}) async {
    try {
      // 从 S3 下载
      final bytes = await client.getObject(
        bucket: bucket,
        key: _normalizePath(path),
      );

      // 将字节转为字符串
      return utf8.decode(bytes);
    } on S3ObjectNotFoundException {
      return null;
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to download file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to download file: $e');
    }
  }

  @override
  Future<void> delete({required String path}) async {
    return deleteFile(path);
  }

  @override
  Future<bool> exists({required String path}) async {
    return fileExists(path);
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    final files = await listFiles(path);
    return files
        .map((name) => CloudFile(
              name: name,
              path: name,
              size: 0, // Size not available in list operation
              lastModified: DateTime.now(), // Not available
            ))
        .toList();
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    try {
      final exists = await fileExists(path);
      if (!exists) return null;

      return CloudFile(
        name: path.split('/').last,
        path: path,
        size: 0, // Not implemented yet
        lastModified: DateTime.now(), // Not implemented yet
      );
    } catch (e) {
      return null;
    }
  }

  /// 标准化路径：去除开头的斜杠
  ///
  /// S3 的 Key 不应该以 / 开头
  String _normalizePath(String path) {
    if (path.startsWith('/')) {
      return path.substring(1);
    }
    return path;
  }
}
