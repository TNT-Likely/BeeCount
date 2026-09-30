import 'dart:async';
import 'dart:convert';

import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/models/assistant_follow_up_metadata.dart';
import 'package:beecount/models/assistant_execution_metadata.dart';
import 'package:beecount/ai/core/ai_extraction_engine.dart';
import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/ai/ai_chat_page.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/ai/ai_bookkeeper.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:beecount/widgets/ai/agent_brand_mark.dart';
import 'package:beecount/widgets/ai/agent_execution_timeline.dart';
import 'package:beecount/widgets/ai/agent_markdown_text.dart';
import 'package:beecount/widgets/ai/bill_card_widget.dart';
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase database;
  late LocalRepository repository;

  setUp(() {
    // Permission-store futures must not retain a previous test's FakeAsync
    // zone through the shared preferences instance.
    SharedPreferences.setMockInitialValues({
      // This suite tests chat lifecycle, not legacy provider migration (which
      // schedules persistence/log timers independently of the disposed page).
      'ai_capability_binding_v2': '{}',
    });
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
        conversationHistoryLoader: (id) async =>
            (await repository.watchMessages(id).first)
                .map((row) =>
                    <String, Object?>{'role': row.role, 'content': row.content})
                .toList(),
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
        databaseProvider.overrideWithValue(database),
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
  testWidgets('回答后追问持久化且点击进入同一只读对话，旧回复不重复展示', (tester) async {
    final ledgerId = await repository.createLedger(name: '当前账本');
    await database.into(database.transactions).insert(
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 32,
            happenedAt: Value(DateTime.now())));
    final model = _QueryModel();
    await tester.pumpWidget(host(model: model));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '本月收支');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('agent-follow-up-questions'))
            .evaluate()
            .isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-follow-up-questions')),
        findsOneWidget);
    final answers = await (database.select(database.messages)
          ..where((row) => row.role.equals('assistant')))
        .get();
    final questions = AssistantFollowUpMetadata.decode(answers.single.metadata,
        ledgerId: ledgerId);
    expect(questions, hasLength(2));
    expect(AssistantExecutionMetadata.decode(answers.single.metadata),
        hasLength(1));
    await tester.ensureVisible(
        find.byKey(const ValueKey('agent-follow-up-followup-category')));
    await tester
        .tap(find.byKey(const ValueKey('agent-follow-up-followup-category')));
    await _pumpUntil(
        tester,
        () =>
            model.requests.length >= 4 &&
            find
                .byKey(const ValueKey('agent-follow-up-questions'))
                .evaluate()
                .isNotEmpty);
    await tester.pumpAndSettle();
    expect(model.requests[2].text, questions.first.prompt);
    expect(model.requests[2].scope.allowsMutations, isFalse);
    final users = await (database.select(database.messages)
          ..where((row) => row.role.equals('user')))
        .get();
    expect(users.last.content, questions.first.prompt);
    expect(find.byKey(const ValueKey('agent-follow-up-questions')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('agent-follow-up-followup-category')),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(model: model));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-follow-up-questions')),
        findsOneWidget);
    expect(model.requests, hasLength(4)); // Restoring never calls the model.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AIChatPage)));
    container.read(currentLedgerIdProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-follow-up-questions')),
        findsOneWidget); // Generic templates are safe under the current ledger.
    expect(find.byKey(const ValueKey('agent-follow-up-followup-trend')),
        findsNothing);
    expect(find.byKey(const ValueKey('agent-follow-up-followup-compare')),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('最新错误回复不展示历史追问', (tester) async {
    final id = await repository.createConversation(
        ConversationsCompanion.insert(
            title: const Value('测试'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now())));
    const question =
        core.AgentPromptSuggestion(id: 'one', title: '继续', prompt: '本月支出多少？');
    for (final type in ['text', 'error']) {
      await repository.createMessage(MessagesCompanion.insert(
          conversationId: id,
          role: 'assistant',
          content: '回复',
          messageType: type,
          metadata: Value(jsonEncode(
              AssistantFollowUpMetadata.encode([question], ledgerId: 1))),
          createdAt: Value(DateTime.now())));
    }
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('agent-follow-up-questions')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('最新停止回复不显示分析模板，即使历史元数据里有追问', (tester) async {
    final id = await repository.createConversation(
        ConversationsCompanion.insert(title: const Value('测试')));
    await repository.createMessage(MessagesCompanion.insert(
      conversationId: id,
      role: 'assistant',
      content: '本次操作已停止。',
      messageType: 'text',
      metadata: const Value('{"analysisTemplatesAllowed":false}'),
    ));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('agent-follow-up-questions')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('分析模板仅在回答后提供，保存完整问题并进入只读对话', (tester) async {
    await repository.createLedger(name: '当前账本');
    final conversation = await repository.createConversation(
        ConversationsCompanion.insert(title: const Value('测试')));
    await repository.createMessage(MessagesCompanion.insert(
      conversationId: conversation,
      role: 'assistant',
      content: '可以继续聊聊账本。',
      messageType: 'text',
    ));
    final model = _CapturingModel();
    await tester.pumpWidget(host(model: model));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-prompt-suggestion-launcher')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('ai-prompt-suggestion-sheet')), findsNothing);
    final health =
        find.byKey(const ValueKey('agent-follow-up-financial_health'));
    expect(find.byKey(const ValueKey('agent-follow-up-more')), findsNothing);
    await tester.ensureVisible(health);
    await tester.tap(health);
    await tester.runAsync(() async {
      // Allow SQLite work and the normal message-save/run chain to complete.
      for (var attempt = 0; attempt < 50 && model.request == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    final prompt = AppLocalizationsZh().agentSuggestionHealthPrompt;
    expect(model.request?.text, prompt);
    expect(model.request?.toolData, isEmpty);
    expect(model.request?.scope.allowsMutations, isFalse);
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

  testWidgets('查询回答未完成时逐段显示文本，结束后才展示继续了解', (tester) async {
    await repository.createLedger(name: '当前账本');
    final model = _StreamingQueryModel();
    addTearDown(() {
      if (!model.answer.isCompleted) {
        model.answer.complete(const core.AgentTurn.finalText('已停止'));
      }
    });
    await tester.pumpWidget(host(model: model));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-prompt-suggestion-launcher')),
        findsNothing);
    await tester.enterText(find.byType(TextField).first, '本月支出多少？');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _pumpUntil(
        tester,
        () => find
            .byWidgetPredicate((widget) =>
                widget is AgentMarkdownText && widget.data == '查询后的第一段文本')
            .evaluate()
            .isNotEmpty);
    expect(find.byType(AgentExecutionTimeline), findsOneWidget);
    expect(
        find.byKey(const ValueKey('agent-follow-up-questions')), findsNothing);
    final before = await (database.select(database.messages)
          ..where((row) => row.role.equals('assistant')))
        .get();
    expect(before, isEmpty);
    model.answer.complete(const core.AgentTurn.finalText('完整回答：本月支出0元。'));
    await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('agent-follow-up-questions'))
            .evaluate()
            .isNotEmpty);
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((widget) =>
            widget is AgentMarkdownText && widget.data == '查询后的第一段文本'),
        findsNothing);
    expect(find.byType(AgentExecutionTimeline), findsOneWidget);
    expect(find.text('已完成 1 项操作'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is AgentMarkdownText && widget.data == '完整回答：本月支出0元。'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('通栏回答使用可用宽度，复制和更多操作位于回答下方', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final id = await repository.createConversation(
        ConversationsCompanion.insert(title: const Value('阅读')));
    final messageId = await repository.createMessage(MessagesCompanion.insert(
        conversationId: id,
        role: 'assistant',
        content: '可以通栏阅读的回答内容。',
        messageType: 'text'));
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final answer = find.byKey(ValueKey('agent-answer-$messageId'));
    final markdown =
        find.descendant(of: answer, matching: find.byType(AgentMarkdownText));
    expect(tester.getSize(markdown).width, greaterThan(340));
    final copy = find.byKey(ValueKey('agent-answer-copy-$messageId'));
    expect(tester.getTopLeft(copy).dy,
        greaterThan(tester.getBottomLeft(markdown).dy));
    await tester.tap(copy);
    await tester.pump();
    expect(copied, '可以通栏阅读的回答内容。');
    await tester.tap(find.byKey(ValueKey('agent-answer-more-$messageId')));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('历史执行详情可重新展开，回到底部按钮居中悬浮且点击后消失', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final id = await repository.createConversation(
        ConversationsCompanion.insert(title: const Value('历史')));
    for (var index = 0; index < 20; index++) {
      await repository.createMessage(MessagesCompanion.insert(
          conversationId: id,
          role: index.isEven ? 'user' : 'assistant',
          content: '历史消息 $index',
          messageType: 'text'));
    }
    await repository.createMessage(MessagesCompanion.insert(
        conversationId: id,
        role: 'assistant',
        content: '已完成查询。',
        messageType: 'text',
        metadata: Value(jsonEncode(AssistantExecutionMetadata.encode(const [
          AgentActivityStep(
              title: '收支概览',
              status: AgentActivityStatus.completed,
              details: ['2026/9/1—2026/10/1', '已返回 2 笔交易']),
        ])))));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('已完成 1 项操作'), findsOneWidget);
    expect(find.text('收支概览'), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('已返回 2 笔交易'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    final jump = find.byKey(const ValueKey('agent-scroll-to-latest'));
    expect(jump, findsOneWidget);
    expect(tester.getCenter(jump).dx, closeTo(195, 1));
    expect(tester.getBottomLeft(jump).dy,
        lessThan(tester.getTopLeft(find.byType(TextField).first).dy));
    await tester.tap(jump);
    await tester.pumpAndSettle();
    expect(jump, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('记账卡片撤销后保留执行快照和推荐资格，不再次调用模型', (tester) async {
    final ledgerId = await repository.createLedger(name: '当前账本');
    final txId = await database.into(database.transactions).insert(
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 25,
            happenedAt: Value(DateTime.now())));
    final id = await repository.createConversation(
        ConversationsCompanion.insert(title: const Value('记账')));
    final metadata = <String, Object?>{
      'bills': [
        BillInfo(
                amount: -25,
                time: DateTime.now(),
                type: BillType.expense,
                ledgerId: ledgerId)
            .toJson()
      ],
      'txIds': [txId],
      'undoneIds': <int>[],
      'analysisTemplatesAllowed': true,
      ...AssistantExecutionMetadata.encode(const [
        AgentActivityStep(title: '记录交易', status: AgentActivityStatus.completed)
      ]),
    };
    final messageId = await repository.createMessage(MessagesCompanion.insert(
        conversationId: id,
        role: 'assistant',
        content: '已记账',
        messageType: 'bill_card',
        metadata: Value(jsonEncode(metadata))));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('撤销'));
    await tester.tap(find.text('撤销'));
    await tester.runAsync(() => repository.watchMessages(id).firstWhere(
        (rows) => rows.any((row) =>
            (jsonDecode(row.metadata!) as Map)['undoneIds'].contains(txId))));
    await tester.pumpAndSettle();
    final updated = await repository.getMessageById(messageId);
    expect(AssistantExecutionMetadata.decode(updated!.metadata), hasLength(1));
    expect(AssistantFollowUpMetadata.allowsAnalysisTemplates(updated.metadata),
        isTrue);
    expect(await repository.getTransactionById(txId), isNull);
    expect(await database.select(database.agentRuns).get(), isEmpty);
    expect(
        find.byWidgetPredicate(
            (widget) => widget is BillCardWidget && widget.isUndone),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('流式输出期间回看历史不会被后续文本或最终回答拉回底部', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await repository.createLedger(name: '当前账本');
    final id = await repository.createConversation(
        ConversationsCompanion.insert(title: const Value('流式历史')));
    for (var index = 0; index < 20; index++) {
      await repository.createMessage(MessagesCompanion.insert(
          conversationId: id,
          role: index.isEven ? 'user' : 'assistant',
          content: '历史消息 $index',
          messageType: 'text'));
    }
    final model = _StreamingQueryModel();
    addTearDown(() {
      if (!model.answer.isCompleted) {
        model.answer.complete(const core.AgentTurn.finalText('已停止'));
      }
    });
    await tester.pumpWidget(host(model: model));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '本月支出多少？');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _pumpUntil(tester, () => model.answeringRequest != null);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));
    final controller =
        tester.widget<ListView>(find.byType(ListView).first).controller!;
    final readingOffset = controller.offset;
    expect(
        find.byKey(const ValueKey('agent-scroll-to-latest')), findsOneWidget);
    model.answeringRequest!.nativeStreamSink
        ?.call(const core.AgentNativeTextDelta('，这是后续的第二段文本。'));
    await tester.pump();
    await tester.pump();
    expect(controller.offset, closeTo(readingOffset, 2));
    model.answer.complete(const core.AgentTurn.finalText('完整流式回答：本月支出0元。'));
    await tester.runAsync(() => repository.watchMessages(id).firstWhere(
        (rows) => rows.any((row) => row.content == '完整流式回答：本月支出0元。')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.position.extentAfter, greaterThan(50));
    expect(
        find.byKey(const ValueKey('agent-scroll-to-latest')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}

final class _StreamingQueryModel implements core.AgentModel {
  final answer = Completer<core.AgentTurn>();
  core.AgentRequest? answeringRequest;
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    if (request.toolData.isEmpty) {
      return core.AgentTurn.toolCalls([
        core.AgentToolCall(
            id: 'overview',
            name: 'get_period_overview',
            arguments: const {'period': 'current_month'}),
      ]);
    }
    answeringRequest = request;
    request.nativeStreamSink
        ?.call(const core.AgentNativeTextDelta('查询后的第一段文本'));
    return answer.future;
  }
}

final class _QueryModel implements core.AgentModel {
  final requests = <core.AgentRequest>[];
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    requests.add(request);
    if (request.toolData.isNotEmpty) {
      return const core.AgentTurn.finalText('已查询');
    }
    return core.AgentTurn.toolCalls([
      core.AgentToolCall(
          id: 'read',
          name: request.text.contains('一级分类')
              ? 'get_category_breakdown'
              : 'get_period_overview',
          arguments: {
            'period': 'current_month',
            if (request.text.contains('一级分类')) 'categoryLevel': 'top'
          })
    ]);
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  expect(ready(), isTrue, reason: 'Expected conversation state did not arrive');
}

final class _CapturingModel implements core.AgentModel {
  core.AgentRequest? request;
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest value) async {
    request = value;
    return const core.AgentTurn.finalText('未执行查询');
  }
}
