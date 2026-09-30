import 'package:agentcore/agentcore.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/models/assistant_prompt_suggestions.dart';
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

  testWidgets('默认三项，更多问题原地展开全部模板且点击返回完整文本', (tester) async {
    AgentPromptSuggestion? selected;
    final items = AssistantPromptSuggestions.continuations(AppLocalizationsZh(),
        contextual: const [suggestion]);
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: items, onSuggestionTap: (item) => selected = item)));
    expect(find.byType(ActionChip), findsNWidgets(3));
    expect(find.text('查看分类占比'), findsOneWidget);
    expect(find.text('省钱小贴士'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-follow-up-more')));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNWidgets(7));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('收起问题'), findsOneWidget);
    await tester.tap(find.text('省钱小贴士'));
    expect(selected?.prompt, AppLocalizationsZh().agentSuggestionSavingPrompt);
    await tester.tap(find.byKey(const ValueKey('agent-follow-up-more')));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNWidgets(3));
  });

  testWidgets('更换回答的推荐范围后恢复折叠，禁用时不能展开', (tester) async {
    final items =
        AssistantPromptSuggestions.continuations(AppLocalizationsZh());
    await tester.pumpWidget(host(
        AgentFollowUpQuestions(suggestions: items, onSuggestionTap: (_) {})));
    await tester.tap(find.byKey(const ValueKey('agent-follow-up-more')));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNWidgets(6));
    await tester.pumpWidget(host(AgentFollowUpQuestions(
        suggestions: [suggestion, ...items],
        enabled: false,
        onSuggestionTap: (_) => fail('Disabled'))));
    expect(find.byType(ActionChip), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('agent-follow-up-more')));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNWidgets(3));
  });

  testWidgets('长分类标题在窄屏大字号下不会溢出', (tester) async {
    await tester.pumpWidget(host(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Center(
          child: SizedBox(
        width: 240,
        child: AgentFollowUpQuestions(suggestions: [
          AgentPromptSuggestion(
              id: 'long', title: '查看${'很长的分类' * 16}明细', prompt: '完整范围问题'),
        ], onSuggestionTap: (_) {}),
      )),
    )));
    expect(tester.takeException(), isNull);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('agent-follow-up-long')))
            .width,
        lessThanOrEqualTo(240));
  });
}
