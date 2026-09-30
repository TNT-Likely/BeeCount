import 'package:agentcore/agentcore.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/models/assistant_prompt_suggestions.dart';
import 'package:beecount/widgets/ai/agent_follow_up_questions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const question = AgentPromptSuggestion(
      id: 'category',
      title: '查看分类占比',
      prompt: '查询 2026-09-15 至 2026-10-15（不含结束时间）的一级分类支出占比。');
  final templates = AssistantPromptSuggestions.localized(AppLocalizationsZh());
  Widget host(Widget child) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)));

  testWidgets('浅色独立区域显示短标题，整行点击发送完整问题', (tester) async {
    AgentPromptSuggestion? selected;
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [question],
        onSuggestionTap: (item) => selected = item)));
    expect(find.text('继续了解'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('agent-follow-up-surface')), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    await tester.tap(find.text('查看分类占比'));
    expect(selected?.prompt, question.prompt);
  });

  testWidgets('空候选无区域，禁用时不能点击或换一组', (tester) async {
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [], onSuggestionTap: (_) => fail('Empty'))));
    expect(find.text('继续了解'), findsNothing);
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [question],
        templates: templates,
        enabled: false,
        onSuggestionTap: (_) => fail('Disabled'))));
    await tester.tap(find.text('查看分类占比'));
    await tester.tap(find.byKey(const ValueKey('agent-follow-up-rotate')));
    await tester.pumpAndSettle();
    expect(find.text('查看分类占比'), findsOneWidget);
  });

  testWidgets('六类完整模板合入轮换，无全部分析主题入口', (tester) async {
    AgentPromptSuggestion? selected;
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [question],
        templates: templates,
        onSuggestionTap: (item) => selected = item)));
    expect(find.text('全部分析主题'), findsNothing);
    expect(find.byKey(const ValueKey('agent-follow-up-more')), findsNothing);
    final seen = <String>{};
    for (var i = 0; i < 7; i++) {
      for (final item in templates) {
        if (find.text(item.title).evaluate().isNotEmpty) {
          seen.add(item.id);
          await tester.tap(find.text(item.title));
          expect(selected?.prompt, item.prompt);
        }
      }
      await tester.tap(find.byKey(const ValueKey('agent-follow-up-rotate')));
      await tester.pumpAndSettle();
    }
    expect(seen, templates.map((item) => item.id).toSet());
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('优先两条上下文追问，候选变更重置轮换', (tester) async {
    final items = [
      for (var i = 0; i < 3; i++)
        AgentPromptSuggestion(id: 'q$i', title: '追问$i', prompt: '完整问题$i')
    ];
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: items,
        templates: templates,
        onSuggestionTap: (_) => fail('No model calls'))));
    expect(find.text('追问0'), findsOneWidget);
    expect(find.text('追问1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-follow-up-rotate')));
    await tester.pumpAndSettle();
    expect(find.text('追问2'), findsOneWidget);
    expect(find.text('财务健康分析'), findsOneWidget);
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [question],
        templates: templates,
        onSuggestionTap: (_) {})));
    expect(find.text('查看分类占比'), findsOneWidget);
  });

  testWidgets('长标题和完整模板在窄屏大字号下不溢出', (tester) async {
    await tester.pumpWidget(host(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: SizedBox(
            width: 240,
            child: AgentFollowUpQuestions(suggestions: [
              AgentPromptSuggestion(
                  id: 'long', title: '查看${'很长的分类' * 16}明细', prompt: '完整范围问题')
            ], templates: templates, onSuggestionTap: (_) {})))));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('agent-follow-up-rotate')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
