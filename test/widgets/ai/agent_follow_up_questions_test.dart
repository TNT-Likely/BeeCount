import 'package:agentcore/agentcore.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/ai/agent_follow_up_questions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const suggestion = AgentPromptSuggestion(
      id: 'category',
      title: '查看分类占比',
      prompt: '查询 2026-09-15 至 2026-10-15（不含结束时间）的一级分类支出占比。');
  Widget host(Widget child) => ProviderScope(
          child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ));
  testWidgets('回答后追问显示短标题，点击发送完整范围问题', (tester) async {
    AgentPromptSuggestion? selected;
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [suggestion],
        onSuggestionTap: (item) => selected = item)));
    expect(find.text('继续了解'), findsOneWidget);
    await tester.tap(find.text('查看分类占比'));
    expect(selected?.prompt, suggestion.prompt);
    expect(selected?.prompt, isNot(suggestion.title));
  });
  testWidgets('空追问不显示标题，禁用状态不可点击', (tester) async {
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [],
        onSuggestionTap: (_) => fail('No suggestions'))));
    expect(find.text('继续了解'), findsNothing);
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: const [suggestion],
        enabled: false,
        onSuggestionTap: (_) => fail('Disabled suggestion'))));
    await tester.tap(find.text('查看分类占比'));
  });
}
