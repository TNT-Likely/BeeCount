import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/widgets.dart' show WidgetsBinding;
import '../l10n/app_localizations.dart';

/// 无 BuildContext 场景(顶层恢复路径、后台服务、Provider)解析本地化文案。
///
/// 两级匹配:先精确 locale(语言+地区),再仅语言码;都不中则兜底
/// `AppLocalizations.supportedLocales.first`(en),与 MaterialApp 未提供
/// localeListResolutionCallback 时的默认解析结果一致。
///
/// 应用内语言覆盖:languageProvider 在加载/切换语言时同步到此,使所有
/// 无 BuildContext 路径(通知/异常/导出/生物识别)与界面语言保持一致;
/// 空表示跟随系统。纯单测(未初始化 binding)经 [_platformLocale] 退回
/// dart:ui 静态,并可用 `localeTestValue` 固定 locale。
Locale? _appLocaleOverride;

/// 由 [LanguageNotifier]-侧在加载与切换语言时同步(见 language_provider)。
void setAppLocaleOverride(Locale? locale) => _appLocaleOverride = locale;

/// 已知局限:跟随系统时只读 binding platformDispatcher 的单一首选语言,
/// 不遍历完整系统语言偏好列表(与 widget 层 resolver 相同)。
AppLocalizations resolveAppLocalizations(Locale? explicitLocale) {
  final candidate = explicitLocale ?? _appLocaleOverride ?? _platformLocale();

  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == candidate.languageCode &&
        supported.countryCode == candidate.countryCode) {
      return lookupAppLocalizations(supported);
    }
  }
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == candidate.languageCode) {
      return lookupAppLocalizations(supported);
    }
  }
  return lookupAppLocalizations(AppLocalizations.supportedLocales.first);
}

Locale _platformLocale() {
  // 纯单测可能未初始化 binding(WidgetsBinding.instance 会抛);此时退回
  // dart:ui 静态(测试环境下即真实系统 locale)。
  try {
    return WidgetsBinding.instance.platformDispatcher.locale;
  } catch (_) {
    return PlatformDispatcher.instance.locale;
  }
}
