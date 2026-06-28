import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/website_urls.dart';

/// WebsiteUrls.docsCloudSyncEmbed 单测 —— 登录页「注册指引」按后端跳转时,
/// 用内嵌(embed)模式打开云同步文档所需的 URL 拼接。
///
/// 断言当前实现:
/// - 中文(zh / zh_TW)无语言前缀,其它语言带 /en;
/// - 路径为 `/docs/cloud-sync/<topic>`;
/// - embed 参数齐全:embed=1 + theme(dark/light) + primary(主题色 hex)。
void main() {
  group('WebsiteUrls.docsCloudSyncEmbed', () {
    test('中文无前缀 + supabase topic + 浅色', () {
      final url = WebsiteUrls.docsCloudSyncEmbed(
        'supabase',
        const Locale('zh'),
        dark: false,
        primaryHex: 'ffcc00',
      );
      expect(
        url,
        'https://count.beejz.com/docs/cloud-sync/supabase'
        '?embed=1&theme=light&primary=ffcc00',
      );
    });

    test('繁体中文同样无前缀 + beecount-cloud topic + 暗黑', () {
      final url = WebsiteUrls.docsCloudSyncEmbed(
        'beecount-cloud',
        const Locale('zh', 'TW'),
        dark: true,
        primaryHex: '123456',
      );
      expect(
        url,
        'https://count.beejz.com/docs/cloud-sync/beecount-cloud'
        '?embed=1&theme=dark&primary=123456',
      );
    });

    test('英文带 /en 前缀', () {
      final url = WebsiteUrls.docsCloudSyncEmbed(
        'overview',
        const Locale('en'),
        dark: false,
        primaryHex: 'abcdef',
      );
      expect(
        url,
        'https://count.beejz.com/en/docs/cloud-sync/overview'
        '?embed=1&theme=light&primary=abcdef',
      );
    });

    test('locale 为 null 时无前缀', () {
      final url = WebsiteUrls.docsCloudSyncEmbed(
        'supabase',
        null,
        dark: true,
        primaryHex: '000000',
      );
      expect(
        url,
        'https://count.beejz.com/docs/cloud-sync/supabase'
        '?embed=1&theme=dark&primary=000000',
      );
    });
  });
}
