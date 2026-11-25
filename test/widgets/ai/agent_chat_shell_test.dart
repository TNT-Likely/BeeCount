import 'package:beecount/pages/ai/chat/widgets/agent_chat_shell.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('标题和账本共用 4.x 页头，导航与对话操作均可点击', (tester) async {
    var back = 0, more = 0;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: AgentChatShell(
      title: 'AI 助手',
      ledgerName: '家庭账本',
      moreLabel: '对话操作',
      onBack: () => back++,
      onMore: () => more++,
      child: const Text('消息区'),
    ))));
    expect(find.byType(BeePageHeader), findsOneWidget);
    expect(find.text('AI 助手'), findsOneWidget);
    expect(find.text('家庭账本'), findsOneWidget);
    expect(find.text('消息区'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-chat-back')));
    await tester.tap(find.byTooltip('对话操作'));
    expect((back, more), (1, 1));
  });
}
