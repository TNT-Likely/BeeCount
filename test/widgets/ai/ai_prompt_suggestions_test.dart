import 'package:agentcore/agentcore.dart' show AgentPromptSuggestion;
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/widgets/ai/ai_prompt_suggestions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {Color? primaryColor}) => ProviderScope(
        overrides: [
          if (primaryColor != null)
            primaryColorProvider.overrideWith((ref) => primaryColor)
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('只展示三个推荐问题，点击返回完整问题而非标题', (tester) async {
    AgentPromptSuggestion? selected;
    await tester.pumpWidget(host(AIPromptSuggestions(
        onSuggestionTap: (suggestion) => selected = suggestion)));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      expect(
          find.byKey(ValueKey('ai-prompt-suggestion-$index')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('ai-prompt-suggestion-3')), findsNothing);
    expect(find.text('财务健康分析'), findsNothing);
    expect(find.text('预算规划建议'), findsNothing);
    expect(find.text('异常支出提醒'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ai-prompt-suggestion-0')));
    expect(selected?.title, '本月收支');
    expect(selected?.prompt, '总结本月收入、支出和结余。');
  });

  testWidgets('推荐问题保持紧凑两行布局和主题色', (tester) async {
    const primary = Color(0xFF7E57C2);
    await tester.pumpWidget(host(
        Center(
            child: SizedBox(
                width: 360,
                child: AIPromptSuggestions(onSuggestionTap: (_) {}))),
        primaryColor: primary));
    final first = find.byKey(const ValueKey('ai-prompt-suggestion-0'));
    final second = find.byKey(const ValueKey('ai-prompt-suggestion-1'));
    final third = find.byKey(const ValueKey('ai-prompt-suggestion-2'));
    expect(tester.getSize(first).height, lessThanOrEqualTo(48));
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(
        tester.getTopLeft(third).dy, greaterThan(tester.getTopLeft(first).dy));
    final icon = tester.widget<Container>(
        find.byKey(const ValueKey('ai-prompt-suggestion-icon-0')));
    expect((icon.decoration! as BoxDecoration).color,
        primary.withValues(alpha: 0.14));
  });

  testWidgets('输入框面板只保留三个问题，选择后关闭并返回真实问题', (tester) async {
    const primary = Color(0xFF7E57C2);
    AgentPromptSuggestion? selected;
    await tester.pumpWidget(host(
        AIPromptSuggestionLauncher(
            onSuggestionTap: (suggestion) => selected = suggestion),
        primaryColor: primary));
    await tester
        .tap(find.byKey(const ValueKey('ai-prompt-suggestion-launcher')));
    await tester.pumpAndSettle();
    expect(find.text('推荐提问'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-prompt-suggestion-sheet-item-2')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ai-prompt-suggestion-sheet-item-3')),
        findsNothing);
    final icon = tester.widget<Container>(
        find.byKey(const ValueKey('ai-prompt-suggestion-sheet-header-icon')));
    expect((icon.decoration! as BoxDecoration).color,
        primary.withValues(alpha: 0.14));
    await tester
        .tap(find.byKey(const ValueKey('ai-prompt-suggestion-sheet-item-2')));
    await tester.pumpAndSettle();
    expect(selected?.prompt, '按月列出最近六个月的支出。');
    expect(
        find.byKey(const ValueKey('ai-prompt-suggestion-sheet')), findsNothing);
  });

  testWidgets('执行中禁用推荐入口', (tester) async {
    await tester.pumpWidget(host(AIPromptSuggestionLauncher(
        enabled: false,
        onSuggestionTap: (_) => fail('Disabled entry opened'))));
    await tester
        .tap(find.byKey(const ValueKey('ai-prompt-suggestion-launcher')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('ai-prompt-suggestion-sheet')), findsNothing);
  });
}
