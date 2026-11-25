import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/model/agent_prompt_builder.dart';
import 'package:beecount/agent/model/ledger_query_replay.dart';
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/data/db.dart' show TransactionsCompanion;
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('only a complete same-ledger read definition is replayable', () {
    final original = {
      'ref': 'first/1',
      'ledgerId': 3,
      'tool': 'get_period_overview',
      'options': <String, Object?>{},
      'filters': {
        'period': 'custom',
        'start': '2026-09-10',
        'end': '2026-09-20'
      },
      'snapshot': {
        'pages': ['old amounts']
      },
    };
    expect(LedgerQueryReplay.definitions([original], 3).single,
        isNot(contains('snapshot')));
    for (final q in [
      {...original, 'ledgerId': 9},
      {...original, 'tool': 'record_transaction_from_text'},
      {
        ...original,
        'options': {'sourceText': 'unsafe'}
      },
      {...original}..remove('options')
    ]) {
      expect(LedgerQueryReplay.definitions([q], 3), isEmpty);
    }
  });

  test(
      'repeat uses original dates and filters on new rows, then asks the model once with fresh totals',
      () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await LedgerEvalFixture.create();
    addTearDown(ledger.close);
    final id = ledger.ledgers['main']!;
    final db = ledger.database;
    Future<int> add(int book, double amount, int day) =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
            ledgerId: book,
            type: 'expense',
            amount: amount,
            happenedAt: Value(DateTime(2031, 4, day))));
    final row = await add(id, 28, 10);
    await add(id, 999, 29);
    final model = _RereadModel();
    final facade = AgentAppFacade(
        toolGateway: ledger.gateway,
        memoryRepository: ledger.memory,
        permissionStore: SharedPreferencesAgentToolPermissionStore(
            getPreferences: SharedPreferences.getInstance),
        model: model);
    final first = await facade.processMessage(
        message: '这段时间支出多少？', ledgerId: id, readOnly: true);
    final queries = (first.response.queryContext['queries'] as List)
        .cast<Map<String, Object?>>();
    final frozen = jsonEncode(first.response.queryContext);
    expect(first.response.queryContext['completeReplay'], isTrue);
    expect((model.requests.last.toolData.single['data'] as Map)['expense'], 28);
    await (db.update(db.transactions)..where((t) => t.id.equals(row)))
        .write(const TransactionsCompanion(amount: Value(32)));
    final repeat = await facade.processMessage(
        message: '这段时间支出多少？',
        ledgerId: id,
        readOnly: true,
        context: {
          'repeatQueries': queries,
          'view': {'ledgerId': id, 'start': '2032-01-01', 'end': '2032-12-31'}
        });
    expect(repeat.type, 'text');
    expect(model.requests.length, 3);
    final last = model.requests.last;
    expect(last.allowToolCalls, false);
    expect(last.scope.allowsMutations, false);
    expect(last.toolData, isEmpty);
    final fresh = last.context['recheckedResults'] as List;
    expect(fresh.single['data']['expense'], 32);
    expect(fresh.single['data']['periodStart'], startsWith('2031-04-01'));
    expect(fresh.single['data']['periodEnd'], startsWith('2031-04-15'));
    expect(const AgentPromptBuilder().buildNative(last),
        isNot(contains('"pages":')));
    expect(jsonEncode(first.response.queryContext), frozen);
    expect((repeat.response.queryContext['displayRefs'] as List).single,
        isNot(queries.single['ref']));
  });
}

final class _RereadModel implements AgentModel {
  final requests = <AgentRequest>[];
  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    requests.add(request);
    if (!request.allowToolCalls || request.toolData.isNotEmpty) {
      return const AgentTurn.finalText('已按查到的金额作答。');
    }
    return AgentTurn.toolCalls([
      AgentToolCall(id: 'lookup', name: 'get_period_overview', arguments: {
        'period': 'custom',
        'start': '2031-04-01',
        'end': '2031-04-15'
      })
    ]);
  }
}
