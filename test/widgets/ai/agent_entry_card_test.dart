import 'package:beecount/widgets/ai/agent_brand_mark.dart';
import 'package:beecount/widgets/ai/agent_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('入口卡展示 Agent 品牌并只触发一次点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AgentEntryCard(
              title: '问问 AI',
              subtitle: '查支出、记账，直接说就好',
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('问问 AI'), findsOneWidget);
    expect(find.text('查支出、记账，直接说就好'), findsOneWidget);
    expect(find.byType(AgentBrandMark), findsOneWidget);

    await tester.tap(find.text('问问 AI'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('首页紧凑入口按钮保留 AI 语义和状态点', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AgentEntryButton(
              tooltip: 'AI 助手',
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('AI 助手'), findsOneWidget);
    expect(find.byType(AgentBrandMark), findsOneWidget);
    await tester.tap(find.byType(AgentBrandMark));
    await tester.pump();
    expect(taps, 1);
  });
}
