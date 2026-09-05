import 'package:beecount/widgets/ai/agent_brand_mark.dart';
import 'package:beecount/widgets/ai/agent_ai_mark.dart';
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

  testWidgets('首页紧凑入口按钮展示 AI 图标并保留语义', (tester) async {
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
    expect(find.byType(AgentAiMark), findsOneWidget);
    await tester.tap(find.byType(AgentAiMark));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('首页紧凑入口使用22px AI字标且保留32px点击区域', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentEntryButton(
            tooltip: 'AI 助手',
            onTap: () {},
          ),
        ),
      ),
    );

    final mark = tester.widget<AgentAiMark>(find.byType(AgentAiMark));
    expect(mark.size, 22);
    expect(tester.getSize(find.byType(InkWell)), const Size(32, 32));
  });

  testWidgets('首页 AI 标识填满紧凑入口的视觉尺寸', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentEntryButton(
            tooltip: 'AI 助手',
            onTap: () {},
          ),
        ),
      ),
    );

    final aiText = tester.widget<Text>(find.text('AI'));
    expect(aiText.style?.fontSize, 19.8);
    expect(aiText.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('首页入口图标继承页头颜色，避免与背景同色不可见', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconTheme(
            data: const IconThemeData(color: Colors.black),
            child: AgentEntryButton(
              tooltip: 'AI 助手',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final mark = tester.widget<AgentAiMark>(find.byType(AgentAiMark));
    expect(mark.color, Colors.black);
  });
}
