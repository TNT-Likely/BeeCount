import 'dart:ui';

/// 官网 URL 管理
///
/// 统一管理官网链接，方便未来域名变更
class WebsiteUrls {
  WebsiteUrls._();

  /// 官网基础域名
  /// 未来换域名时只需修改这里
  static const String baseUrl = 'https://count.beejz.com';

  /// 获取语言前缀
  /// 中文不需要前缀，英文需要 /en 前缀
  static String _langPrefix(Locale? locale) {
    if (locale == null) return '';
    // 简体中文和繁体中文使用默认路径
    if (locale.languageCode == 'zh') return '';
    // 其他语言使用 /en 路径
    return '/en';
  }

  /// 官网首页
  static String home([Locale? locale]) => '$baseUrl${_langPrefix(locale)}';

  /// 使用帮助/文档首页
  static String docs([Locale? locale]) =>
      '$baseUrl${_langPrefix(locale)}/docs/intro';

  /// 文档首页 — App 内嵌(embed)模式。
  /// 文档站会隐藏 navbar/footer 等带外链的 chrome(审核风险),并跟随 App 的
  /// 暗黑模式与主题色,站点侧实现见 BeeCount-Website docusaurus.config.ts。
  static String docsEmbed(Locale? locale,
          {required bool dark, required String primaryHex}) =>
      '$baseUrl${_langPrefix(locale)}/docs/intro'
      '?embed=1&theme=${dark ? 'dark' : 'light'}&primary=$primaryHex';

  /// 功能介绍
  static String docsFeature(String feature, [Locale? locale]) =>
      '$baseUrl${_langPrefix(locale)}/docs/features/$feature';

  /// 记账相关文档
  static String docsRecord(String topic, [Locale? locale]) =>
      '$baseUrl${_langPrefix(locale)}/docs/record/$topic';

  /// AI 相关文档
  static String docsAi(String topic, [Locale? locale]) =>
      '$baseUrl${_langPrefix(locale)}/docs/ai/$topic';

  /// 云同步相关文档
  static String docsCloudSync(String topic, [Locale? locale]) =>
      '$baseUrl${_langPrefix(locale)}/docs/cloud-sync/$topic';

  /// 云同步文档 — App 内嵌(embed)模式。
  /// 用于登录页「注册指引」按当前云后端跳对应文档(supabase / beecount-cloud /
  /// overview 兜底),复用帮助中心同款 embed 体验(隐藏外链 chrome、跟随暗黑与
  /// 主题色),站点侧实现见 BeeCount-Website docusaurus.config.ts。
  static String docsCloudSyncEmbed(String topic, Locale? locale,
          {required bool dark, required String primaryHex}) =>
      '$baseUrl${_langPrefix(locale)}/docs/cloud-sync/$topic'
      '?embed=1&theme=${dark ? 'dark' : 'light'}&primary=$primaryHex';

  /// FAQ
  static String faq([Locale? locale]) =>
      '$baseUrl${_langPrefix(locale)}/docs/faq';

  /// 更新日志
  static String changelog([Locale? locale]) =>
      '$baseUrl${_langPrefix(locale)}/docs/changelog';

  /// 隐私政策 — App 内嵌(embed)模式(隐藏 navbar/footer 外链,跟随暗黑与主题色)。
  static String privacy(Locale? locale,
          {required bool dark, required String primaryHex}) =>
      '$baseUrl${_langPrefix(locale)}/privacy'
      '?embed=1&theme=${dark ? 'dark' : 'light'}&primary=$primaryHex';
}
