import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../system/logger_service.dart';

class AppLockService {
  static const _keyEnabled = 'app_lock_enabled';
  static const _keyPinHash = 'app_lock_pin_hash';
  static const _keyBiometricEnabled = 'app_lock_biometric_enabled';
  static const _keyTimeoutSeconds = 'app_lock_timeout_seconds';
  static const _keyLastBackgroundTime = 'app_lock_last_background_time';

  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// 最近一次解锁时间（内存中，防止解锁后立即被 resumed 事件重新锁定）
  static DateTime? _lastUnlockTime;

  /// 记录解锁时间
  static void recordUnlock() {
    _lastUnlockTime = DateTime.now();
    logger.info('AppLock', '已记录解锁时间');
  }

  /// SHA-256 哈希 PIN 码
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// 设置 PIN 码
  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, hashPin(pin));
    await prefs.setBool(_keyEnabled, true);
    logger.info('AppLock', 'PIN已设置');
  }

  /// 验证 PIN 码
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_keyPinHash);
    if (savedHash == null) return false;
    return hashPin(pin) == savedHash;
  }

  /// 清除 PIN 码并禁用锁定
  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.setBool(_keyEnabled, false);
    await prefs.setBool(_keyBiometricEnabled, false);
    logger.info('AppLock', 'PIN已清除，应用锁已禁用');
  }

  /// 是否已启用应用锁
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  /// 是否有已保存的 PIN
  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPinHash) != null;
  }

  /// 是否已启用生物识别
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// 设置生物识别开关
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    logger.info('AppLock', '生物识别: ${enabled ? "开启" : "关闭"}');
  }

  /// 获取超时时间（秒）
  static Future<int> getTimeoutSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTimeoutSeconds) ?? 0;
  }

  /// 设置超时时间（秒）
  static Future<void> setTimeoutSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimeoutSeconds, seconds);
    logger.info('AppLock', '超时时间设置: ${seconds}s');
  }

  /// 记录进入后台时间
  static Future<void> recordBackgroundTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _keyLastBackgroundTime, DateTime.now().millisecondsSinceEpoch);
  }

  /// 检查从后台恢复是否需要锁定
  static Future<bool> shouldLockOnResume() async {
    // 刚解锁后短时间内不重新锁定（防止 Face ID/PIN 解锁后
    // 因系统弹窗导致的 resumed 事件触发重新锁定）
    if (_lastUnlockTime != null &&
        DateTime.now().difference(_lastUnlockTime!) <
            const Duration(seconds: 3)) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    if (!enabled) return false;

    final lastBgTime = prefs.getInt(_keyLastBackgroundTime);
    if (lastBgTime == null) return false;

    final timeoutSeconds = prefs.getInt(_keyTimeoutSeconds) ?? 0;
    if (timeoutSeconds == 0) return true; // 立即锁定

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastBgTime;
    return elapsed >= timeoutSeconds * 1000;
  }

  /// 检查设备是否支持生物识别
  static Future<bool> canUseBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuth && isDeviceSupported;
    } catch (e) {
      logger.error('AppLock', '检查生物识别支持失败', e);
      return false;
    }
  }

  /// 执行生物识别认证
  static Future<bool> authenticateWithBiometrics(
      {String reason = '请验证身份以解锁应用'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      logger.error('AppLock', '生物识别认证失败', e);
      return false;
    }
  }
}
