import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI 对话空状态和加载错误只提供中英文文案', () {
    final zh = AppLocalizationsZh();
    final en = AppLocalizationsEn();

    expect(zh.aiChatEmptyMessages, '暂无消息');
    expect(zh.aiChatMessagesLoadFailed('网络不可用'), '加载失败: 网络不可用');
    expect(en.aiChatEmptyMessages, 'No messages yet');
    expect(en.aiChatMessagesLoadFailed('Network unavailable'),
        'Failed to load messages: Network unavailable');
  });
}
