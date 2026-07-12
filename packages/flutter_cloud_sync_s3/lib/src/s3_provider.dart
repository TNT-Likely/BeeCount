import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 's3_client.dart';
import 's3_auth_service.dart';
import 's3_storage_service.dart';
import 's3_exceptions.dart';

/// S3 Provider 实现
///
/// 支持所有 S3 兼容存储服务：
/// - AWS S3
/// - Cloudflare R2
/// - Backblaze B2
/// - MinIO (自托管)
/// - 阿里云 OSS
/// - 腾讯云 COS
/// - 七牛云 Kodo
class S3Provider implements CloudProvider {
  S3Client? _client;
  String? _bucket;
  S3AuthService? _authService;
  S3StorageService? _storageService;

  @override
  String get providerId => 's3';

  @override
  String get providerName => 'S3 Compatible Storage';

  @override
  CloudAuthService get auth {
    if (_authService == null) {
      throw StateError('S3Provider not initialized. Call initialize() first.');
    }
    return _authService!;
  }

  @override
  CloudStorageService get storage {
    if (_storageService == null) {
      throw StateError('S3Provider not initialized. Call initialize() first.');
    }
    return _storageService!;
  }

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // 解析配置
    final endpoint = config['endpoint'] as String;
    final region = config['region'] as String? ?? 'us-east-1';
    final accessKey = config['accessKey'] as String;
    final secretKey = config['secretKey'] as String;
    final bucket = config['bucket'] as String;
    final useSSL = config['useSSL'] as bool? ?? true;
    final port = config['port'] as int?;

    // 解析 endpoint（可能包含端口）
    String host;
    int? finalPort = port;
    if (endpoint.contains(':') && port == null) {
      final parts = endpoint.split(':');
      host = parts[0];
      finalPort = int.tryParse(parts[1]);
    } else {
      host = endpoint;
    }

    // 创建 S3 客户端
    _client = S3Client(
      endpoint: host,
      region: region,
      accessKey: accessKey,
      secretKey: secretKey,
      useSSL: useSSL,
      port: finalPort,
    );

    _bucket = bucket;

    // 测试连接：尝试列出 bucket
    try {
      await _client!.listObjects(bucket: bucket);
    } on S3BucketNotFoundException catch (e) {
      throw CloudConfigurationException(
        'Bucket not found: ${e.bucket}. Please create the bucket first.',
      );
    } on S3AuthException catch (e) {
      throw CloudConfigurationException(
        'Authentication failed: ${e.message}. Please check your Access Key and Secret Key.',
      );
    } on S3NetworkException catch (e) {
      throw CloudConfigurationException(
        'Network error: ${e.message}. Please check your endpoint and network connection.',
      );
    } catch (e) {
      throw CloudConfigurationException(
        'Failed to initialize S3: $e',
      );
    }

    // 初始化服务
    _authService = S3AuthService(_client!, _bucket!);
    _storageService = S3StorageService(_client!, _bucket!);
  }

  @override
  bool validateConfig(Map<String, dynamic> config) {
    // 必需字段验证
    if (!config.containsKey('endpoint') ||
        !config.containsKey('accessKey') ||
        !config.containsKey('secretKey') ||
        !config.containsKey('bucket')) {
      return false;
    }

    // 非空验证
    final endpoint = config['endpoint'] as String?;
    final accessKey = config['accessKey'] as String?;
    final secretKey = config['secretKey'] as String?;
    final bucket = config['bucket'] as String?;

    return endpoint != null &&
        endpoint.isNotEmpty &&
        accessKey != null &&
        accessKey.isNotEmpty &&
        secretKey != null &&
        secretKey.isNotEmpty &&
        bucket != null &&
        bucket.isNotEmpty;
  }

  @override
  Future<void> dispose() async {
    _client?.dispose();
    _client = null;
    _bucket = null;
    _authService = null;
    _storageService = null;
  }
}
