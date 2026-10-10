import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_localizations_resolver.dart';

// 语言设置提供者
final languageProvider = StateNotifierProvider<LanguageNotifier, Locale?>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<Locale?> {
  LanguageNotifier() : super(null) {
    _loadLanguage();
  }

  static const String _languageKey = 'selected_language';

  /// 偏好键的公开别名:供无 BuildContext 的冷启动路径(如提醒恢复)读取
  /// 同一组偏好,与应用内语言保持一致。
  static const String languagePrefKey = _languageKey;
  static const String languagePrefCountryKey = '${_languageKey}_country';

  // 加载保存的语言设置
  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey);
      final countryCode = prefs.getString('${_languageKey}_country');
      if (languageCode != null) {
        state = Locale(languageCode, countryCode);
      }
      // 同步无 context 路径的应用内语言(通知/异常/导出等)。
      setAppLocaleOverride(state);
    } catch (e) {
      // 如果加载失败，保持默认值（null，跟随系统）
    }
  }

  // 设置语言
  Future<void> setLanguage(Locale? locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        // 跟随系统语言
        await prefs.remove(_languageKey);
        await prefs.remove('${_languageKey}_country');
      } else {
        // 设置特定语言
        await prefs.setString(_languageKey, locale.languageCode);
        if (locale.countryCode != null) {
          await prefs.setString('${_languageKey}_country', locale.countryCode!);
        } else {
          await prefs.remove('${_languageKey}_country');
        }
      }
      state = locale;
      // 同步无 context 路径的应用内语言。
      setAppLocaleOverride(locale);
    } catch (e) {
      // 设置失败时不更新状态
    }
  }

  // 获取当前语言的显示名称
  String getLanguageDisplayName(BuildContext context, Locale? locale) {
    final l10n = AppLocalizations.of(context);

    if (locale == null) {
      return l10n.languageSystemDefault;
    }

    switch (locale.languageCode) {
      case 'zh':
        if (locale.countryCode == 'TW') {
          return '繁體中文';
        }
        return l10n.languageChinese;
      case 'en':
        return l10n.languageEnglish;
      case 'ko':
        return '한국어';
      default:
        return locale.languageCode;
    }
  }
}