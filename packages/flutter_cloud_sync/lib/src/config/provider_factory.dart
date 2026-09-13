import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';
import 'package:flutter_cloud_sync_webdav/flutter_cloud_sync_webdav.dart';
import 'package:flutter_cloud_sync_icloud/flutter_cloud_sync_icloud.dart';
import 'package:flutter_cloud_sync_s3/flutter_cloud_sync_s3.dart';
import '../providers/beecount_cloud_provider.dart';

import '../core/auth_service.dart';
import '../core/cloud_provider.dart';
import 'cloud_service_config.dart';

/// 根据 CloudServiceConfig 创建对应的 CloudProvider 和 CloudAuthService
///
/// 返回 (CloudProvider, CloudAuthService) 元组
///
/// 支持:
/// - Supabase: 使用独立包内的初始化逻辑
/// - WebDAV: 创建新的 WebDAV provider
Future<({CloudProvider? provider, CloudAuthService? auth})> createCloudServices(
  CloudServiceConfig config, {
  bool persistSession = true,
}) async {
  if (!config.valid) {
    return (provider: null, auth: null);
  }

  switch (config.type) {
    case CloudBackendType.local:
      return (provider: null, auth: null);

    case CloudBackendType.beecountCloud:
      final provider = BeeCountCloudProvider();
      await provider.initialize({
        'baseUrl': config.beecountCloudBaseUrl!,
        'apiPrefix': config.beecountCloudApiPrefix ?? '/api/v1',
        'persistSession': persistSession,
        'email': config.beecountCloudEmail,
      });
      return (provider: provider, auth: provider.auth);

    case CloudBackendType.supabase:
      // 创建并初始化 Supabase provider
      // 包内会处理重复初始化的问题
      final provider = SupabaseProvider();
      await provider.initialize({
        'url': config.supabaseUrl!,
        'anonKey': config.supabaseAnonKey!,
        'bucket': config.supabaseBucket ?? 'beecount-backups', // 兼容老配置，提供默认值
        'pathPrefix': null, // 使用默认的 users/{userId}/ 结构，基础包支持但业务层不配置
      });

      // Auth service 直接从 provider 获取
      final auth = provider.auth;

      return (provider: provider, auth: auth);

    case CloudBackendType.webdav:
      final provider = WebDAVProvider();
      await provider.initialize({
        'url': config.webdavUrl!,
        'username': config.webdavUsername!,
        'password': config.webdavPassword!,
        'remotePath': config.webdavRemotePath ?? '/',
      });

      final auth = provider.auth;

      return (provider: provider, auth: auth);

    case CloudBackendType.icloud:
      // iCloud 仅支持 iOS/iPadOS
      if (kIsWeb || !Platform.isIOS) {
        return (provider: null, auth: null);
      }

      try {
        final provider = ICloudProvider();
        await provider.initialize({});

        final auth = provider.auth;

        return (provider: provider, auth: auth);
      } catch (e) {
        // iCloud 不可用（未登录等），返回 null
        return (provider: null, auth: null);
      }

    case CloudBackendType.s3:
      // S3 初始化 - 不捕获异常，让错误向上传递以便调试
      final provider = S3Provider();
      await provider.initialize({
        'endpoint': config.s3Endpoint!.replaceFirst(RegExp(r'^https?://'), ''),
        'region': config.s3Region ?? 'us-east-1',
        'accessKey': config.s3AccessKey!,
        'secretKey': config.s3SecretKey!,
        'bucket': config.s3Bucket!,
        'useSSL': config.s3UseSSL ?? true,
        'port': config.s3Port,
      });

      final auth = provider.auth;

      return (provider: provider, auth: auth);
  }
}

/// 兼容旧代码的方法
@Deprecated('Use createCloudServices instead')
Future<CloudProvider?> createCloudProvider(CloudServiceConfig config) async {
  final services = await createCloudServices(config);
  return services.provider;
}
