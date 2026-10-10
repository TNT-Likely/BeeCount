import 'dart:ui' show Locale, PlatformDispatcher;

import '../l10n/app_localizations.dart';

/// 无 BuildContext 场景(顶层恢复路径、后台服务、Provider)解析本地化文案。
///
/// 两级匹配:先精确 locale(语言+地区),再仅语言码;都不中则兜底
/// `AppLocalizations.supportedLocales.first`(en),与 MaterialApp 未提供
/// localeListResolutionCallback 时的默认解析结果一致。
///
/// 已知局限:跟随系统时只看 `PlatformDispatcher.instance.locale` 单一首选
/// 语言,不遍历完整系统语言偏好列表(与 widget 层 resolver 相同)。
AppLocalizations resolveAppLocalizations(Locale? explicitLocale) {
  final candidate = explicitLocale ?? PlatformDispatcher.instance.locale;

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
