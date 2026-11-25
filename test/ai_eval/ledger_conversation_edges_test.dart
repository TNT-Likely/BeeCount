import 'dart:convert';

import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/agent/runtime/shared_preferences_agent_execution_settings_store.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/ledger_fixture.dart';

class _ScriptedAgentModel implements core.AgentModel {
  _ScriptedAgentModel(this.turn);
  final core.AgentTurn Function(core.AgentRequest, int) turn;
  final requests = <core.AgentRequest>[];
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    requests.add(request);
    return turn(request, requests.length);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerEvalFixture fixture;
  late LocalAgentTools toolbox;
  late int ledgerId;
  late int callSequence;
  setUp(() async {
    callSequence = 0;
    SharedPreferences.setMockInitialValues({});
    fixture = await LedgerEvalFixture.create();
    ledgerId = fixture.ledgers['main']!;
    toolbox = LocalAgentTools(
      scope: core.AgentScope(
          id: 'synthetic-query', ledgerId: ledgerId, allowsMutations: false),
      gateway: fixture.gateway,
      now: () => fixture.now,
    );
  });
  tearDown(() => fixture.close());

  Future<Map<String, Object?>> details(Map<String, Object?> filters) {
    const tool = 'query_transactions';
    return toolbox
        .build()[tool]!
        .execute(core.AgentToolCall(name: tool, arguments: filters));
  }

  test(
      'same-named child categories need a parent choice, preserve known zero and do not leak another ledger',
      () async {
    final children = <int>[];
    for (final pair in [('合成A', 17.0, 'expense'), ('合成B', 38.0, 'income')]) {
      final parent =
          await fixture.repository.createCategory(name: pair.$1, kind: pair.$3);
      final child = await fixture.repository.createCategory(
          name: '同名便当', kind: pair.$3, parentId: parent, level: 2);
      children.add(child);
      await fixture.repository.addTransaction(
          ledgerId: ledgerId,
          type: pair.$3,
          amount: pair.$2,
          categoryId: child,
          happenedAt: fixture.now);
    }
    await fixture.repository.addTransaction(
        ledgerId: fixture.ledgers['other']!,
        type: 'expense',
        amount: 999.0,
        categoryId: children.first,
        happenedAt: fixture.now);
    final before = await fixture.transactionCount();
    final ambiguous = await details({
      'period': 'current_month',
      'categoryNames': ['同名便当']
    });
    expect(ambiguous['matchStatus'], 'ambiguous');
    expect(ambiguous['queryRef'], isNull);
    final candidates = (ambiguous['candidates'] as List).cast<Map>();
    expect(candidates.map((r) => r['parent']), unorderedEquals(['合成A', '合成B']));
    expect(candidates.map((r) => r['id']), unorderedEquals(children));
    expect(ambiguous['items'], isEmpty);
    final chosen = await details({
      'period': 'current_month',
      'categoryIds': [children.first]
    });
    expect(chosen['totalCount'], 1);
    expect(chosen['totalLedgerAmount'], 17.0);
    expect(chosen['queryRef'], isNotNull);
    final unknown = await details({
      'period': 'current_month',
      'categoryNames': ['无此便当']
    });
    expect(unknown['matchStatus'], 'unmatched');
    expect(unknown['queryRef'], isNull);
    final empty =
        await details({'baseQuery': chosen['queryRef'], 'minAmount': 18.0});
    expect(empty['matchStatus'], 'matched');
    expect(empty['totalCount'], 0);
    expect(empty['totalLedgerAmount'], 0.0);
    expect(empty['queryRef'], isNotNull);
    expect(await fixture.transactionCount(), before);
  });

  test(
      'all 27 shopping rows paginate without overlap and each page keeps the 53 CNY full total',
      () async {
    final before = await fixture.transactionCount();
    final first = await details({
      'period': 'current_month',
      'categoryNames': ['购物'],
      'limit': 7,
      'includeExcludedFromStats': false
    });
    final ids = <Object?>{};
    final sizes = <int>[];
    var reloadedAmount = 0.0;
    var page = first;
    while (true) {
      final rows = (page['items'] as List).cast<Map>();
      sizes.add(rows.length);
      expect(page['totalCount'], 27);
      expect(page['totalLedgerAmount'], 53);
      for (final row in rows) {
        expect(ids.add(row['id']), isTrue);
        reloadedAmount += (row['ledgerAmount'] as num).toDouble();
      }
      if (page['nextCursor'] == null) break;
      expect(sizes.length, lessThan(5));
      page = await details({
        'baseQuery': first['queryRef'],
        'cursor': page['nextCursor'],
        'limit': 7
      });
    }
    expect(sizes, [7, 7, 7, 6]);
    expect(ids, hasLength(27));
    expect(reloadedAmount, 53);
    expect(await fixture.transactionCount(), before);
  });

  test(
      'original currency amount requires a currency and returns the separate CNY ledger total',
      () async {
    final filters = {
      'period': 'current_month',
      'accountNames': ['美元现金'],
      'minAmount': 10.0,
      'maxAmount': 10.0,
      'amountBasis': 'original'
    };
    expect((await details(filters))['error'], 'original_currency_required');
    final page = await details({...filters, 'currency': 'USD'});
    expect(page['totalCount'], 1);
    expect(page['totalLedgerAmount'], 72);
    final row = (page['items'] as List).single as Map;
    expect(row['amount'], 10);
    expect(row['ledgerAmount'], 72);
    expect((await details({...filters, 'amountBasis': 'ledger'}))['totalCount'],
        0);
  });

  AIChatService chat(_ScriptedAgentModel model,
          {AgentConversationHistoryLoader? history,
          SharedPreferencesAgentExecutionSettingsStore? settings}) =>
      AIChatService(
          repo: fixture.repository,
          agentFacade: AgentAppFacade(
            memoryRepository: fixture.memory,
            toolGateway: fixture.gateway,
            model: model,
            permissionStore: SharedPreferencesAgentToolPermissionStore(
                getPreferences: SharedPreferences.getInstance),
            executionSettingsStore: settings,
            conversationHistoryLoader: history,
            now: () => fixture.now,
            textChat: (_) => throw StateError('unexpected text fallback'),
          ));

  Future<AIResponse> sendReadOnly(AIChatService chat, String text,
          {int? conversation}) =>
      chat.processMessage(text,
          ledgerId: ledgerId,
          readOnly: true,
          languageCode: 'zh',
          l10n: AppLocalizationsZh(),
          conversationId: conversation);

  core.AgentToolCall ask(String name, Map<String, Object?> parameters) =>
      core.AgentToolCall(
          id: 'call-${++callSequence}', name: name, arguments: parameters);

  test(
      'manual cap saves a pending read and a fresh chat service continues it through the production history loader',
      () async {
    final settings = SharedPreferencesAgentExecutionSettingsStore(
        getPreferences: SharedPreferences.getInstance);
    await settings.setMaximumModelTurns(2);
    final state = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(fixture.database),
      repositoryProvider.overrideWithValue(fixture.repository),
      localAgentToolGatewayProvider.overrideWithValue(fixture.gateway),
    ]);
    addTearDown(state.dispose);
    final history =
        state.read(agentAppFacadeProvider).conversationHistoryLoader!;
    final conversation = await fixture.repository
        .createConversation(const ConversationsCompanion());
    const firstInput = '复盘本月餐饮支出，根据金额逐步筛选';
    const secondInput = '继续刚才未完成的查询';
    Future<void> persist(String role, String content,
        {Map<String, Object?>? queryContext}) async {
      await fixture.repository.createMessage(MessagesCompanion.insert(
          conversationId: conversation,
          role: role,
          content: content,
          messageType: 'text',
          metadata: Value(jsonEncode({
            'contextLedgerId': ledgerId,
            if (queryContext != null) 'queryContext': queryContext
          }))));
    }

    final before = await fixture.transactionCount();
    await persist('user', firstInput);
    final model = _ScriptedAgentModel((request, turn) {
      if (!request.allowToolCalls) {
        return const core.AgentTurn.finalText('已完成前几项查询。');
      }
      if (turn == 1) {
        return core.AgentTurn.toolCalls([
          ask('get_period_overview', {
            'period': 'current_month',
            'categoryNames': ['餐饮']
          })
        ]);
      }
      final ref = (request.toolData.single['data'] as Map)['queryRef'];
      return core.AgentTurn.toolCalls([
        for (final amount in [10, 20, 30, 40])
          ask('query_transactions', {'baseQuery': ref, 'minAmount': amount})
      ]);
    });
    final first = await sendReadOnly(
        chat(model, history: history, settings: settings), firstInput,
        conversation: conversation);
    expect(model.requests.map((r) => r.allowToolCalls), [true, true, false]);
    expect(first.text, contains(AppLocalizationsZh().agentQueryPartial));
    expect(first.queryContext['limit'], 'toolCallLimitReached');
    expect(first.queryContext['displayRefs'], hasLength(4));
    final pending = (first.queryContext['pending'] as List).single as Map;
    expect(pending['tool'], 'query_transactions');
    expect((pending['arguments'] as Map)['minAmount'], 40);
    await persist('assistant', first.text, queryContext: first.queryContext);
    await persist('user', secondInput);
    final again = _ScriptedAgentModel((request, turn) {
      if (turn == 1) {
        final next = (request.context['pendingQueries'] as List).single as Map;
        return core.AgentTurn.toolCalls([
          ask(next['tool'] as String,
              Map<String, Object?>.from(next['arguments'] as Map))
        ]);
      }
      final result = request.toolData.single['data'] as Map;
      return core.AgentTurn.finalText(
          '${result['totalCount']} 笔，${result['totalLedgerAmount']} 元。');
    });
    final second = await sendReadOnly(
        chat(again, history: history, settings: settings), secondInput,
        conversation: conversation);
    expect(again.requests, hasLength(2));
    expect((again.requests.first.context['previousQueries'] as List),
        hasLength(4));
    expect(second.text, contains('2 笔，120'));
    expect(second.queryContext['pending'], isNull);
    expect(second.queryContext['displayRefs'], hasLength(1));
    expect(await fixture.transactionCount(), before);
  });

  test(
      'declining the first write leaves SQLite unchanged and allowing the same saved message once creates exactly one receipt',
      () async {
    const input = '午餐 28 元';
    final conversation = await fixture.repository
        .createConversation(const ConversationsCompanion());
    final source = await fixture.repository.createMessage(
        MessagesCompanion.insert(
            conversationId: conversation,
            role: 'user',
            content: input,
            messageType: 'text',
            metadata: Value(jsonEncode({'contextLedgerId': ledgerId}))));
    final before = await fixture.transactionCount();
    Future<AIResponse> run(core.AgentToolAuthorizationChoice choice) async {
      final model = _ScriptedAgentModel((request, turn) => turn == 1
          ? core.AgentTurn.toolCalls([
              ask('record_transaction_from_text', {
                'sourceText': input,
                'receiptOnly': true,
                'entry': {
                  'amount': 28,
                  'type': 'expense',
                  'category': '午餐',
                  'note': '午餐'
                }
              })
            ])
          : const core.AgentTurn.finalText('本次操作结束。'));
      final service = chat(model);
      var approvals = 0;
      await for (final event in service.processMessageEvents(input,
          ledgerId: ledgerId,
          conversationId: conversation,
          sourceMessageId: source,
          languageCode: 'zh',
          l10n: AppLocalizationsZh())) {
        if (event is AgentToolAuthorizationRequestedEvent) {
          approvals++;
          expect(
              service.resolveToolAuthorization(
                  event.request.authorizationId, choice),
              isTrue);
        }
        if (event is AgentRunCompletedEvent) {
          expect(approvals, 1);
          return event.result.response;
        }
      }
      throw StateError('missing committed result');
    }

    final rejection = await run(core.AgentToolAuthorizationChoice.deny);
    expect(rejection.bills, isEmpty);
    expect(await fixture.transactionCount(), before);
    final approved = await run(core.AgentToolAuthorizationChoice.allowOnce);
    expect(approved.type, 'bill_card');
    expect(approved.receiptMessageId, isNotNull);
    expect(approved.transactionIds, hasLength(1));
    expect(await fixture.transactionCount(), before + 1);
    final replay = await fixture.gateway.recordTransaction(
        ledgerId: ledgerId, sourceMessageId: source, text: input);
    expect(replay.receiptMessageId, approved.receiptMessageId);
    expect(replay.transactionIds, approved.transactionIds);
    expect(await fixture.transactionCount(), before + 1);
  });
  for (final batch in [false, true]) {
    test(
        batch
            ? 'automatic upper bound executes ten reads and keeps the eleventh pending'
            : 'automatic upper bound stops at eight model turns and reserves text finalization',
        () async {
      final before = await fixture.transactionCount();
      final model = _ScriptedAgentModel((request, turn) {
        if (!request.allowToolCalls) {
          return const core.AgentTurn.finalText('已按范围查询。');
        }
        final amounts =
            batch ? List.generate(11, (i) => i / 10) : [(turn - 1) / 10];
        return core.AgentTurn.toolCalls([
          for (final amount in amounts)
            ask('query_transactions', {
              'period': 'current_month',
              'categoryNames': ['购物'],
              'minAmount': amount
            })
        ]);
      });
      final result = await sendReadOnly(chat(model), '复盘本月购物支出');
      expect(result.queryContext['displayRefs'], hasLength(batch ? 10 : 8));
      expect(result.queryContext['limit'],
          batch ? 'toolCallLimitReached' : 'modelTurnLimitReached');
      expect(model.requests.where((r) => r.allowToolCalls),
          hasLength(batch ? 1 : 8));
      expect(model.requests.last.allowToolCalls, isFalse);
      if (batch) {
        final pending = (result.queryContext['pending'] as List).single as Map;
        expect((pending['arguments'] as Map)['minAmount'], 1.0);
        expect(result.text, contains(AppLocalizationsZh().agentQueryPartial));
      }
      expect(await fixture.transactionCount(), before);
    });
  }
}
