import 'package:shared_preferences/shared_preferences.dart';

/// 当前 AI 隐私"告知+同意"文案版本。文案实质变更时 +1,可强制用户重新同意。
const int kAiPrivacyConsentVersion = 1;

/// AI 第三方数据共享"告知+同意"的持久化存取(纯逻辑,便于单测)。
///
/// 仅本机授权状态:不入库、不参与云同步。
class AiPrivacyConsentStore {
  AiPrivacyConsentStore._();

  static const String prefsKey = 'ai_privacy_consent_version';

  /// 已同意的文案版本;从未同意返回 0。
  static Future<int> readVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefsKey) ?? 0;
  }

  /// 是否已对**当前**文案版本同意。
  static Future<bool> isConsented() async {
    return await readVersion() >= kAiPrivacyConsentVersion;
  }

  /// 记录用户对当前文案版本的同意。
  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey, kAiPrivacyConsentVersion);
  }
}
