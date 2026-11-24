import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_service_config.dart';

/// 云服务配置持久化存储
/// 支持类型: 本地存储、BeeCount Cloud、自定义 Supabase、自定义 WebDAV、iCloud、S3
class CloudServiceStore {
  static const _kActiveType =
      'cloud_active_type'; // local | beecount_cloud | supabase | webdav | icloud | s3
  static const _kBeeCountCloudCfg = 'cloud_beecount_cloud_cfg';
  static const _kSupabaseCfg = 'cloud_supabase_cfg';
  static const _kWebdavCfg = 'cloud_webdav_cfg';
  static const _kS3Cfg = 'cloud_s3_cfg';

  /// Billing ownership must survive disconnection and an unreadable Cloud configuration.
  Future<bool> usesBeeCountCloud() async =>
      (await SharedPreferences.getInstance()).getString(_kActiveType) == 'beecount_cloud';

  /// 加载当前激活的云服务配置
  Future<CloudServiceConfig> loadActive() async {
    final sp = await SharedPreferences.getInstance();
    final activeType = sp.getString(_kActiveType) ?? 'local';

    switch (activeType) {
      case 'local':
        return CloudServiceConfig.localStorage();

      case 'beecount_cloud':
        final raw = sp.getString(_kBeeCountCloudCfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        return CloudServiceConfig.localStorage();

      case 'supabase':
        final raw = sp.getString(_kSupabaseCfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      case 'webdav':
        final raw = sp.getString(_kWebdavCfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      case 'icloud':
        // iCloud 无需额外配置，返回 iCloud 类型的配置
        return const CloudServiceConfig(
          type: CloudBackendType.icloud,
          name: 'iCloud',
        );

      case 's3':
        final raw = sp.getString(_kS3Cfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      default:
        return CloudServiceConfig.localStorage();
    }
  }

  /// 加载 BeeCount Cloud 配置(不管是否激活)
  Future<CloudServiceConfig?> loadBeeCountCloud() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kBeeCountCloudCfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载Supabase配置(不管是否激活)
  Future<CloudServiceConfig?> loadSupabase() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSupabaseCfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载WebDAV配置(不管是否激活)
  Future<CloudServiceConfig?> loadWebdav() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kWebdavCfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载S3配置(不管是否激活)
  Future<CloudServiceConfig?> loadS3() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kS3Cfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 保存并激活配置
  Future<void> saveAndActivate(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();

    switch (cfg.type) {
      case CloudBackendType.local:
        await sp.setString(_kActiveType, 'local');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.beecountCloud:
        await sp.setString(_kBeeCountCloudCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'beecount_cloud');
        break;

      case CloudBackendType.supabase:
        await sp.setString(_kSupabaseCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'supabase');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.webdav:
        await sp.setString(_kWebdavCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'webdav');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.icloud:
        await sp.setString(_kActiveType, 'icloud');
        // iCloud 无需额外配置，Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.s3:
        await sp.setString(_kS3Cfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 's3');
        // Provider 会在下次使用时自动初始化
        break;
    }
  }

  /// 仅保存配置,不激活
  Future<void> saveOnly(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();

    switch (cfg.type) {
      case CloudBackendType.local:
        // 本地存储无需保存
        break;

      case CloudBackendType.beecountCloud:
        await sp.setString(_kBeeCountCloudCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.supabase:
        await sp.setString(_kSupabaseCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.webdav:
        await sp.setString(_kWebdavCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.icloud:
        // iCloud 无需保存额外配置
        break;

      case CloudBackendType.s3:
        await sp.setString(_kS3Cfg, encodeCloudConfig(cfg));
        break;
    }
  }

  /// 激活指定类型的配置
  Future<bool> activate(CloudBackendType type) async {
    final sp = await SharedPreferences.getInstance();

    switch (type) {
      case CloudBackendType.local:
        await sp.setString(_kActiveType, 'local');
        return true;

      case CloudBackendType.beecountCloud:
        final raw = sp.getString(_kBeeCountCloudCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'beecount_cloud');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.supabase:
        final raw = sp.getString(_kSupabaseCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'supabase');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.webdav:
        final raw = sp.getString(_kWebdavCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'webdav');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.icloud:
        // iCloud 无需配置，直接激活
        await sp.setString(_kActiveType, 'icloud');
        return true;

      case CloudBackendType.s3:
        final raw = sp.getString(_kS3Cfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 's3');
          return true;
        } catch (e) {
          return false;
        }
    }
  }
}
