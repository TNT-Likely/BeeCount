import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/ai/agent_execution_timeline.dart';

void main() {
  testWidgets('执行时间线展示工具名称、参数、结果和状态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AgentExecutionTimeline(
          isStreaming: false,
          steps: [
            AgentExecutionStep(
              toolName: 'query_transactions',
              arguments: const {
                'start': '2026-09-01T00:00:00.000',
                'end': '2026-09-30T23:59:59.999',
              },
              result: const {'count': 2, 'total': 18.0},
              status: AgentExecutionStepStatus.completed,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('查询交易'), findsOneWidget);
    expect(find.textContaining('2026-09-01'), findsOneWidget);
    expect(find.textContaining('count'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('工具执行期间阶段标题展示具体工具而不是思考中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AgentExecutionTimeline(
          isStreaming: true,
          steps: [
            AgentExecutionStep(
              toolName: 'record_transaction_from_text',
              arguments: const {'sourceText': '早饭花了8元'},
              status: AgentExecutionStepStatus.running,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('agent-execution-phase')),
      findsOneWidget,
    );
    expect(find.text('正在执行：记录交易'), findsAtLeastNWidgets(1));
    expect(find.text('思考中'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
