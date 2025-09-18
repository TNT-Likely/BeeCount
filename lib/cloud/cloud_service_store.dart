import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'cloud_service_config.dart';

/// 持久化（单一自定义配置 + 活动标记）
class CloudServiceStore {
  static const _kActiveKey = 'cloud_active'; // builtin | custom
  static const _kCustomCfg = 'cloud_custom_supabase_cfg';
  static const _kFirstFullUploadFlag = 'cloud_first_full_upload_pending';

  Future<CloudServiceConfig> loadActive(CloudServiceConfig builtin) async {
    final sp = await SharedPreferences.getInstance();
    final mode = sp.getString(_kActiveKey) ?? 'builtin';
    if (mode == 'custom') {
      final raw = sp.getString(_kCustomCfg);
      if (raw != null) {
        try {
          final cfg = decodeCloudConfig(raw);
          if (cfg.valid) return cfg;
        } catch (e) {
          logW('cloudCfg', '解析自定义配置失败: $e');
        }
      }
    }
    return builtin; // 回退默认
  }

  Future<CloudServiceConfig?> loadCustom() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kCustomCfg);
    if (raw == null) {
      logI('cloudStore', 'loadCustom: 没有找到自定义配置');
      return null;
    }
    try {
      final config = decodeCloudConfig(raw);
      logI('cloudStore', 'loadCustom: 成功加载自定义配置');
      return config;
    } catch (e) {
      logW('cloudCfg', 'loadCustom 解析失败: $e');
      return null;
    }
  }

  Future<void> saveCustom(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCustomCfg, encodeCloudConfig(cfg));
    await sp.setString(_kActiveKey, 'custom');
    // 标记需要首次全量上传（待用户登录后执行）
    await sp.setBool(_kFirstFullUploadFlag, true);
  }

  /// 仅保存自定义配置，不激活
  Future<void> saveCustomOnly(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCustomCfg, encodeCloudConfig(cfg));
    logI('cloudStore', '自定义配置已保存到 SharedPreferences');
    // 不改变激活状态，不设置首次上传标记
  }

  Future<void> switchToBuiltin() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kActiveKey, 'builtin');
  }

  /// 仅切换激活为已存在的自定义配置，不重置首次全量上传标记
  Future<bool> activateExistingCustomIfAny() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kCustomCfg);
    if (raw == null) return false;
    try {
      final cfg = decodeCloudConfig(raw);
      if (!cfg.valid) return false;
      await sp.setString(_kActiveKey, 'custom');
      return true;
    } catch (e) {
      logW('cloudCfg', 'activateExistingCustomIfAny 解析失败: $e');
      return false;
    }
  }

  Future<bool> isFirstFullUploadPending() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kFirstFullUploadFlag) ?? false;
  }

  Future<void> clearFirstFullUploadFlag() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kFirstFullUploadFlag);
  }
}
