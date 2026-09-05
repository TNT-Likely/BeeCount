import 'package:beecount/agent/memory/agent_memory_repository.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/agent_memory_page.dart';
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
    await repository.saveExplicit(
      const AgentMemoryDraft(
        ledgerId: 1,
        kind: 'preference',
        content: '午饭优先使用现金账户',
      ),
    );
  });

  tearDown(() => db.close());

  Widget host() => ProviderScope(
        overrides: [
          agentMemoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const AgentMemoryPage(ledgerId: 1),
        ),
      );

  testWidgets('shows and removes local memories from the selected ledger',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('本地记忆'), findsOneWidget);
    expect(find.text('午饭优先使用现金账户'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-memory-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(find.text('午饭优先使用现金账户'), findsNothing);
    expect(await repository.listActive(ledgerId: 1), isEmpty);
  });
}
