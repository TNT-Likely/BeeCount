import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/pages/ai/chat/widgets/agent_chat_shell.dart';
import 'package:beecount/pages/ai/chat/widgets/agent_brand_mark.dart';
import 'package:beecount_ui/beecount_ui.dart';

void main() {
  testWidgets('对话壳使用v4标题与皮肤并保留核心操作', (tester) async {
    var backCount = 0;
    var permissionCount = 0;
    var clearCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AgentChatShell(
            title: 'AI 助手',
            onBack: () => backCount++,
            onOpenPermissions: () => permissionCount++,
            onClearHistory: () => clearCount++,
            child: const SizedBox(
              key: ValueKey('agent-chat-content'),
              height: 600,
              child: Text('消息区'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('AI 助手'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-chat-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-chat-back')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-chat-permissions')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-chat-clear')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BeePageHeader), findsOneWidget);
    expect(find.byType(AgentBrandMark), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-chat-back')));
    await tester.tap(find.byKey(const ValueKey('agent-chat-permissions')));
    await tester.tap(find.byKey(const ValueKey('agent-chat-clear')));

    expect(backCount, 1);
    expect(permissionCount, 1);
    expect(clearCount, 1);
  });
}
