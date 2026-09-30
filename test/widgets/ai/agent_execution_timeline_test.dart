import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/ai/agent_execution_timeline.dart';
import 'package:beecount/widgets/ai/agent_markdown_text.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
  testWidgets('执行详情默认折叠，展开后仅显示可读查询范围和摘要', (tester) async {
    await tester.pumpWidget(
        host(const AgentExecutionTimeline(isStreaming: false, steps: [
      AgentExecutionStep(
          toolName: 'query_transactions',
          arguments: {
            'start': '2026-09-01T00:00:00.000',
            'end': '2026-10-01T00:00:00.000',
            'apiKey': 'secret-value',
          },
          result: {
            'items': [
              {'note': 'private note'},
              {'amount': 18}
            ],
            'raw': 'secret-value'
          },
          status: AgentExecutionStepStatus.completed),
    ])));
    expect(find.text('已完成 1 项操作'), findsOneWidget);
    expect(find.text('查询交易'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('查询交易'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(find.text('已返回 2 笔交易'), findsOneWidget);
    expect(find.textContaining('secret-value'), findsNothing);
    expect(find.textContaining('private note'), findsNothing);
    expect(find.textContaining('items'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('查询交易'), findsNothing);
  });

  testWidgets('执行阶段展示具体操作，不再使用思考中标题', (tester) async {
    await tester.pumpWidget(
        host(const AgentExecutionTimeline(isStreaming: true, steps: [
      AgentExecutionStep(
          toolName: 'record_transaction_from_text',
          arguments: {'sourceText': '早饭花了8元'},
          status: AgentExecutionStepStatus.running),
    ])));
    expect(find.text('正在执行：记录交易'), findsOneWidget);
    expect(find.textContaining('思考中'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('准备与整理回答是不同状态，正文不随过程折叠', (tester) async {
    await tester.pumpWidget(
        host(const AgentExecutionTimeline(isStreaming: true, steps: [])));
    expect(find.text('正在处理你的问题…'), findsOneWidget);
    await tester.pumpWidget(host(const AgentExecutionTimeline(
        isStreaming: true,
        streamingText: '逐段输出的回答',
        steps: [
          AgentExecutionStep(
              toolName: 'get_period_overview',
              arguments: {},
              status: AgentExecutionStepStatus.completed),
        ])));
    expect(find.text('正在整理回答…'), findsOneWidget);
    expect(find.byType(AgentMarkdownText), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    expect(find.text('收支概览'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    expect(find.byType(AgentMarkdownText), findsOneWidget);
  });

  testWidgets('结束时失败或未批准操作不能显示成功，也不暴露原始异常', (tester) async {
    await tester.pumpWidget(
        host(const AgentExecutionTimeline(isStreaming: false, steps: [
      AgentExecutionStep(
          toolName: 'query_transactions',
          arguments: {},
          status: AgentExecutionStepStatus.failed,
          error: 'apiKey=secret-value raw stack'),
      AgentExecutionStep(
          toolName: 'record_transaction_from_text',
          arguments: {'sourceText': 'private note'},
          status: AgentExecutionStepStatus.waiting),
    ])));
    expect(find.text('部分操作未完成'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('执行失败：查询交易'), findsOneWidget);
    expect(find.textContaining('secret-value'), findsNothing);
    expect(find.textContaining('private note'), findsNothing);
    expect(find.textContaining('等待'), findsNothing);
  });
}
