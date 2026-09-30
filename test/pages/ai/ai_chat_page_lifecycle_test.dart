import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/ai/core/ai_extraction_engine.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/ai_chat_page.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/ai/ai_bookkeeper.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:beecount/widgets/ai/agent_brand_mark.dart';
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase database;
  late LocalRepository repository;

  setUp(() {
    database = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = LocalRepository(database);
  });

  tearDown(() => database.close());

  Widget host({core.AgentModel? model}) {
    final memory = LocalAgentMemoryRepository(database);
    final bookkeeper = AiBookkeeper(
      repository: repository,
      engine: const DefaultAiExtractionEngine(),
      persister: BillCreationService(repository),
    );
    final chatService = AIChatService(
      repo: repository,
      agentFacade: AgentAppFacade(
        model: model,
        memoryRepository: memory,
        toolGateway: BeeCountLocalAgentToolGateway(
          repository: repository,
          database: database,
          bookkeeper: bookkeeper,
          memoryRepository: memory,
        ),
        permissionStore: SharedPreferencesAgentToolPermissionStore(
          getPreferences: SharedPreferences.getInstance,
        ),
      ),
    );
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(chatService),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const AIChatPage(),
      ),
    );
  }

  testWidgets('离开 AI 对话页不会在 dispose 后读取 ref', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('加载已有长对话后会自动定位到最后一条消息', (tester) async {
    final conversationId = await repository.createConversation(
      ConversationsCompanion.insert(
        title: const Value('历史对话'),
        createdAt: Value(DateTime(2026, 9, 6)),
        updatedAt: Value(DateTime(2026, 9, 6)),
      ),
    );
    for (var index = 0; index < 40; index++) {
      await repository.createMessage(
        MessagesCompanion.insert(
          conversationId: conversationId,
          role: index.isEven ? 'user' : 'assistant',
          content: '历史消息 $index',
          messageType: 'text',
          createdAt: Value(DateTime(2026, 9, 6, 12, index)),
        ),
      );
    }

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .singleWhere((state) => state.position.maxScrollExtent > 0);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('当前周期没有交易时，空会话引导用户记下第一笔账', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('暂无消息'), findsNothing);
    expect(find.byType(AgentBrandMark), findsOneWidget);
    expect(find.text('从今天的第一笔开始'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-prompt-suggestion-0')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('当前周期已有交易时，空会话展示账本摘要', (tester) async {
    final ledgerId = await repository.createLedger(name: '当前账本');
    await database.into(database.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 32,
            happenedAt: Value(DateTime.now()),
          ),
        );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('从一笔账，或一个问题开始'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('已记录交易'), findsOneWidget);
    expect(find.text('¥32'), findsOneWidget);
    expect(find.text('1 笔'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-prompt-suggestion-0')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('推荐提问保存完整问题，模型收到相同问题而非预载数据', (tester) async {
    await repository.createLedger(name: '当前账本');
    final model = _CapturingModel();
    await tester.pumpWidget(host(model: model));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('ai-prompt-suggestion-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本月收支'));
    await tester.runAsync(() async {
      // Allow SQLite work and the normal message-save/run chain to complete.
      for (var attempt = 0; attempt < 50 && model.request == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    const prompt = '总结本月收入、支出和结余。';
    expect(model.request?.text, prompt);
    expect(model.request?.toolData, isEmpty);
    final users = await (database.select(database.messages)
          ..where((row) => row.role.equals('user')))
        .get();
    expect(users.single.content, prompt);
    final runs = await database.select(database.agentRuns).get();
    expect(runs.single.userMessage, prompt);
    expect(find.text(prompt), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

final class _CapturingModel implements core.AgentModel {
  core.AgentRequest? request;
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest value) async {
    request = value;
    return const core.AgentTurn.finalText('未执行查询');
  }
}
