import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:beecount/data/db.dart';
import 'package:beecount/agent/runtime/agent_execution_settings.dart';

import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/ai/core/ai_extraction_context.dart';
import 'package:beecount/ai/core/ai_extraction_engine.dart';
import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/ai/ai_bookkeeper.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/ledger_fixture.dart';

class _Model implements core.AgentModel {
  _Model(this.step);
  final core.AgentTurn Function(core.AgentRequest request, int turn) step;
  final List<core.AgentRequest> received = [];
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    received.add(request);
    return step(request, received.length);
  }
}

class _TextExtractor extends DefaultAiExtractionEngine {
  _TextExtractor(this.clock, {this.additional = const []});
  final List<BillInfo> additional;
  final DateTime clock;
  int calls = 0;
  @override
  Future<List<BillInfo>> extractFromText(
      String text, AiExtractionContext context,
      {String billGuard = ''}) async {
    calls++;
    return [
      BillInfo(
          amount: -28,
          type: BillType.expense,
          time: clock,
          category: '午餐',
          currency: 'CNY',
          note: '合成午餐'),
      ...additional
    ];
  }
}

typedef _Reply = ({AIResponse response, int approvals, String runId});

BeeCountLocalAgentToolGateway _writeGateway(
        LedgerEvalFixture fixture, _TextExtractor extractor) =>
    BeeCountLocalAgentToolGateway(
        repository: fixture.repository,
        database: fixture.database,
        memoryRepository: fixture.memory,
        bookkeeper: AiBookkeeper(
            repository: fixture.repository,
            engine: extractor,
            persister: BillCreationService(fixture.repository)));

Future<_Reply> _send(
  LedgerEvalFixture f,
  _Model model,
  String message, {
  LocalAgentToolGateway? gateway,
  bool readOnly = true,
  core.AgentModelCapabilities? capabilities,
  int? sourceId,
  Future<String> Function(String)? textChat,
}) async {
  final facade = AgentAppFacade(
    model: model,
    memoryRepository: f.memory,
    toolGateway: gateway ?? f.gateway,
    now: () => f.now,
    textChat: textChat ?? (_) async => '{}',
    modelCapabilityLoader: () async => capabilities,
    permissionStore: SharedPreferencesAgentToolPermissionStore(
        getPreferences: SharedPreferences.getInstance),
  );
  final chat = AIChatService(repo: f.repository, agentFacade: facade);
  final events = chat.processMessageEvents(message,
      ledgerId: f.ledgers['main']!,
      sourceMessageId: sourceId,
      languageCode: 'zh',
      l10n: AppLocalizationsZh(),
      readOnly: readOnly);
  var approvals = 0;
  await for (final event in events) {
    if (event is AgentToolAuthorizationRequestedEvent) {
      approvals++;
      chat.resolveToolAuthorization(event.request.authorizationId,
          core.AgentToolAuthorizationChoice.allowOnce);
    }
    if (event is AgentRunCompletedEvent) {
      return (
        response: event.result.response,
        approvals: approvals,
        runId: event.result.runId
      );
    }
  }
  throw StateError('Run ended without a response');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerEvalFixture f;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    f = await LedgerEvalFixture.create();
  });
  tearDown(() => f.close());

  Future<int> createSource(String content) async {
    final id =
        await f.repository.createConversation(const ConversationsCompanion());
    return f.repository.createMessage(MessagesCompanion.insert(
        conversationId: id,
        role: 'user',
        content: content,
        messageType: 'text',
        metadata: Value(jsonEncode({'contextLedgerId': f.ledgers['main']}))));
  }

  test(
      'a committed receipt survives finalization timeout, concurrent replay and reopening',
      () async {
    const text = '帮我记午餐 28 元，顺便算算这样吃 20 天要多少钱？';
    final sourceId = await createSource(text);
    final extractor = _TextExtractor(f.now);
    final gateway = _writeGateway(f, extractor);
    final before = await f.transactionCount();
    core.AgentTurn write() => core.AgentTurn.toolCalls([
          core.AgentToolCall(
              id: 'save',
              name: 'record_transaction_from_text',
              arguments: {
                'sourceText': text,
                'entry': {'amount': 28, 'type': 'expense'},
                'receiptOnly': true
              })
        ]);
    final interrupted = await _send(f, _Model((_, turn) {
      if (turn == 1) return write();
      throw const core.AgentNativeToolTimeoutException();
    }), text, sourceId: sourceId, gateway: gateway, readOnly: false);
    expect(interrupted.response.type, 'bill_card');
    expect(interrupted.response.supplementalText, isNotEmpty);
    expect(interrupted.approvals, 1);
    expect(extractor.calls, 1,
        reason:
            'The mixed utterance has two numbers and must use full extraction.');
    final rows = await Future.wait(List.generate(
        2,
        (_) => gateway.recordTransaction(
            ledgerId: f.ledgers['main']!,
            text: text,
            sourceMessageId: sourceId)));
    expect(rows.map((r) => r.transactionIds.single).toSet(),
        {interrupted.response.transactionId});
    final resumed = await _send(
        f,
        _Model((_, turn) => turn == 1
            ? write()
            : const core.AgentTurn.finalText('按 20 天计算是 560 元。')),
        text,
        sourceId: sourceId,
        gateway: gateway,
        readOnly: false);
    expect(resumed.response.supplementalText, contains('560'));
    expect(resumed.response.receiptMessageId,
        interrupted.response.receiptMessageId);
    expect(await f.transactionCount(), before + 1);
    expect(extractor.calls, 1);
    final messages = await f.database.select(f.database.messages).get();
    expect(messages.where((m) => m.role == 'assistant').single.transactionId,
        interrupted.response.transactionId);
    await expectLater(
        gateway.recordTransaction(
            ledgerId: f.ledgers['other']!,
            text: text,
            sourceMessageId: sourceId),
        throwsStateError);
  });

  test(
      'a failed second bill leaves one durable receipt and replay cannot repeat the first bill',
      () async {
    const text = '午餐 28 元，晚餐 45 元。';
    final ledgerId = f.ledgers['main']!;
    final source = await createSource(text);
    final before = await f.transactionCount();
    await f.database.customStatement(
        "CREATE TRIGGER fail_second_bill BEFORE INSERT ON transactions WHEN NEW.note = '故障测试' BEGIN SELECT RAISE(ABORT, 'synthetic write failure'); END");
    final extractor = _TextExtractor(f.now, additional: [
      BillInfo(
          type: BillType.expense,
          amount: -45,
          time: f.now,
          category: '餐饮',
          note: '故障测试')
    ]);
    final gateway = _writeGateway(f, extractor);
    final first = await gateway.recordTransaction(
        ledgerId: ledgerId,
        text: text,
        sourceMessageId: source,
        l10n: AppLocalizationsZh());
    expect(first.failedCount, 1);
    expect(first.transactionIds, hasLength(1));
    final reply = await f.repository.getMessageById(first.receiptMessageId!);
    expect((jsonDecode(reply!.metadata!) as Map)['supplementalText'],
        contains('部分'));
    await f.database.customStatement('DROP TRIGGER fail_second_bill');
    final repeated = await gateway.recordTransaction(
        ledgerId: ledgerId, text: text, sourceMessageId: source);
    expect(repeated.failedCount, 1);
    expect(repeated.transactionIds, first.transactionIds);
    expect(await f.transactionCount(), before + 1);
    expect(extractor.calls, 1);
  });

  test(
      'replaying a receipt for an undone bill reports its current state and never recreates it',
      () async {
    const text = '午餐 28 元';
    final ledgerId = f.ledgers['main']!;
    final gateway = _writeGateway(f, _TextExtractor(f.now));
    final source = await createSource(text);
    final before = await f.transactionCount();
    final original = await gateway.recordTransaction(
        ledgerId: ledgerId, text: text, sourceMessageId: source);
    final id = original.transactionIds.single;
    await (f.database.delete(f.database.transactions)
          ..where((row) => row.id.equals(id)))
        .go();
    final replayed = await gateway.recordTransaction(
        ledgerId: ledgerId, text: text, sourceMessageId: source);
    expect(replayed.receiptMessageId, original.receiptMessageId);
    expect(replayed.toToolData()['noLongerInLedger'], [id]);
    expect(replayed.transactions, isEmpty);
    expect(await f.transactionCount(), before);
  });

  test(
      'new concurrent deliveries perform one write and an independent same-text source can create another',
      () async {
    const text = '午餐 28 元';
    final source = await createSource(text);
    final gateway = _writeGateway(f, _TextExtractor(f.now));
    final before = await f.transactionCount();
    Future<AgentRecordToolResult> submit(int id) => gateway.recordTransaction(
        ledgerId: f.ledgers['main']!, text: text, sourceMessageId: id);
    final receipts = await Future.wait([submit(source), submit(source)]);
    expect(receipts.first.receiptMessageId, receipts.last.receiptMessageId);
    expect(await f.transactionCount(), before + 1);
    await submit(await createSource(text));
    expect(await f.transactionCount(), before + 2);
  });

  test('a single clear entry can finish with a receipt in one model turn',
      () async {
    const text = '午餐 28 元';
    final extractor = _TextExtractor(f.now);
    final model = _Model((_, turn) => core.AgentTurn.toolCalls([
          core.AgentToolCall(
              id: 'single',
              name: 'record_transaction_from_text',
              arguments: {
                'sourceText': text,
                'entry': {
                  'amount': 28,
                  'type': 'expense',
                  'category': '午餐',
                  'note': '午餐'
                },
                'receiptOnly': true
              })
        ]));
    final answer = await _send(f, model, text,
        sourceId: await createSource(text),
        readOnly: false,
        gateway: _writeGateway(f, extractor));
    expect(answer.response.type, 'bill_card');
    expect(answer.approvals, 1);
    expect(model.received, hasLength(1));
    expect(extractor.calls, 0);
  });

  test('a scoped result can be replayed, paged and excluded without a write',
      () async {
    final ledger = f.ledgers['main']!;
    LocalAgentTools tools(int id, String run,
            {List<Map<String, Object?>> previous = const []}) =>
        LocalAgentTools(
            scope:
                core.AgentScope(id: run, ledgerId: id, allowsMutations: false),
            gateway: f.gateway,
            now: () => f.now,
            previous: previous);
    final first = tools(ledger, 'first');
    Future<Map<String, Object?>> read(
            LocalAgentTools t, String name, Map<String, Object?> args) =>
        t
            .build()[name]!
            .execute(core.AgentToolCall(name: name, arguments: args));
    final original = await f.transactionCount();
    final dining = await read(first, 'get_period_overview', {
      'period': 'current_month',
      'categoryNames': ['吃饭']
    });
    expect(dining['expense'], 120);
    final follow = tools(ledger, 'follow', previous: first.evidence.current);
    final cash = await read(follow, 'get_period_overview', {
      'baseQuery': dining['queryRef'],
      'accountNames': ['现金']
    });
    expect(cash['expense'], 50);
    final excluding = await read(follow, 'get_period_overview',
        {'baseQuery': dining['queryRef'], 'excludeQuery': cash['queryRef']});
    expect(excluding['expense'], 70);
    final shop = await read(follow, 'query_transactions', {
      'period': 'current_month',
      'categoryNames': ['购物'],
      'limit': 2
    });
    expect(shop['totalCount'] as int, greaterThan(20));
    expect((shop['items'] as List).length, 2);
    final next = await read(follow, 'query_transactions', {
      'baseQuery': shop['queryRef'],
      'cursor': shop['nextCursor'],
      'limit': 2
    });
    expect(next['totalCount'], shop['totalCount']);
    expect((next['items'] as List).first['id'],
        isNot((shop['items'] as List).last['id']));
    final foreign = await read(
        tools(f.ledgers['other']!, 'other', previous: first.evidence.current),
        'get_period_overview',
        {'baseQuery': dining['queryRef']});
    expect(foreign['error'], 'unknown_query_reference');
    final mismatched = await read(follow, 'query_transactions',
        {'baseQuery': cash['queryRef'], 'cursor': shop['nextCursor']});
    expect(mismatched['error'], 'invalid_detail_cursor');
    final unknown = await read(follow, 'get_period_overview', {
      'period': 'current_month',
      'accountNames': ['不存在的账户']
    });
    expect(unknown['matchStatus'], 'unmatched');
    final zero = await read(follow, 'get_period_overview',
        {'baseQuery': cash['queryRef'], 'minAmount': 99999});
    expect(zero['expense'], 0);
    expect(zero['matchStatus'], 'matched');
    expect(await f.transactionCount(), original);
  });

  test(
      'historical Insights filters reach detail and historical budget dates with explicit overrides',
      () async {
    final ledger = f.ledgers['main']!;
    final tools = LocalAgentTools(
        scope: core.AgentScope(id: 'insights', ledgerId: ledger),
        gateway: f.gateway,
        now: () => f.now,
        view: {
          'ledgerId': ledger,
          'flow': 'income',
          'start': '2026-08-01',
          'end': '2026-09-01'
        }).build();
    Future<Map<String, Object?>> run(String name,
            [Map<String, Object?> args = const {}]) =>
        tools[name]!.execute(core.AgentToolCall(name: name, arguments: args));
    final details = await run('query_transactions');
    expect(details['periodStart'], '2026-08-01T00:00:00.000');
    expect(details['totalCount'], 0);
    expect((details['filters'] as Map)['flowType'], 'income');
    final expense = await run('query_transactions', {'flowType': 'expense'});
    expect(expense['totalLedgerAmount'], 1300);
    final budget = await run('get_budget_status');
    expect(budget['asOf'], startsWith('2026-08-31'));
    final overridden = await run('get_budget_status', {'at': '2026-09-15'});
    expect(overridden['asOf'], startsWith('2026-09-15'));
  });

  test('plain arithmetic works on a text-only provider without a ledger action',
      () async {
    final model =
        _Model((_, __) => throw StateError('Unexpected native model call'));
    final result = await _send(f, model, '一天 28 元，20 天是多少钱？',
        capabilities: core.AgentModelCapabilities(
            text: core.AgentCapabilitySupport.supported,
            nativeToolCalls: core.AgentCapabilitySupport.unsupported),
        textChat: (_) async => '{"answer":"20 天一共是 560 元。"}');
    expect(result.response.text, contains('560'));
    expect(model.received, isEmpty);
    expect(result.approvals, 0);
  });

  test(
      'adaptive budgets preserve an explicit depth and expose all six reads to colloquial requests',
      () async {
    expect(AgentExecutionSettings().budgetFor('帮我复盘'), (turns: 6, calls: 8));
    expect(AgentExecutionSettings().budgetFor('你好'), (turns: 4, calls: 6));
    expect(AgentExecutionSettings(maximumModelTurns: 2).budgetFor('帮我复盘'),
        (turns: 2, calls: 4));
    final model = _Model((_, __) => const core.AgentTurn.finalText('好'));
    await _send(f, model, '每个月自动记的和花钱上限呢？');
    final names = model.received.single.availableToolNames!;
    expect(names, hasLength(6));
    expect(names,
        containsAll(['get_recurring_transactions', 'get_budget_status']));
  });
}
