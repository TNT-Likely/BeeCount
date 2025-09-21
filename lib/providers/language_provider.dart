import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

// 语言设置提供者
final languageProvider = StateNotifierProvider<LanguageNotifier, Locale?>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<Locale?> {
  LanguageNotifier() : super(null) {
    _loadLanguage();
  }

  static const String _languageKey = 'selected_language';

  // 加载保存的语言设置
  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey);
      if (languageCode != null) {
        state = Locale(languageCode);
      }
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
      } else {
        // 设置特定语言
        await prefs.setString(_languageKey, locale.languageCode);
      }
      state = locale;
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
        return l10n.languageChinese;
      case 'en':
        return l10n.languageEnglish;
      default:
        return locale.languageCode;
    }
  }
}