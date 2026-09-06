import 'package:beecount/agent/memory/agent_memory_repository.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/agent_activity_page.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late LocalAgentMemoryRepository repository;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = LocalAgentMemoryRepository(db);
    await repository.createRun(
      runId: 'activity-run',
      ledgerId: 1,
      userMessage: '本月花了多少',
    );
    await repository.finishRun(runId: 'activity-run', status: 'completed');
    await repository.recordToolCall(
      const AgentToolCallAudit(
        runId: 'activity-run',
        callId: 'summary-call',
        toolName: 'get_spending_summary',
        status: 'completed',
      ),
    );
  });

  tearDown(() => db.close());

  testWidgets('shows local run and tool history for the selected ledger',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentMemoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const AgentActivityPage(ledgerId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近活动'), findsOneWidget);
    expect(find.text('本月花了多少'), findsOneWidget);
    expect(find.text('汇总支出'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .byKey(const ValueKey('agent-activity-tool-status-summary-call')),
        matching: find.text('已完成'),
      ),
      findsOneWidget,
    );
  });
}
