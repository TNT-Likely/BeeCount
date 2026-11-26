import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/model/ledger_query_replay.dart';
import 'package:beecount/agent/tools/ledger_query_snapshot.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/data/db.dart' show TransactionsCompanion;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'overview, companion queries and replay use the verified cutoff of the ledger period',
      () async {
    final fixture = await LedgerEvalFixture.create();
    addTearDown(fixture.close);
    final ledger =
        fixture.ledgers['cycle']!; // The accounting month starts on the 15th.
    final db = fixture.database;
    Future<int> add(String type, DateTime day, double amount,
            {bool excluded = false}) =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
              ledgerId: ledger,
              type: type,
              amount: amount,
              happenedAt: Value(day),
              excludeFromStats: Value(excluded),
            ));
    await add('expense', DateTime(2031, 11, 14), 30);
    await add('expense', DateTime(2031, 11, 15), 4);
    await add('expense', DateTime(2031, 11, 26, 23, 59, 59), 7);
    await add('expense', DateTime(2031, 11, 27), 200);
    await add('income', DateTime(2031, 11, 20), 100);
    await add('transfer', DateTime(2031, 11, 22), 50);
    await add('expense', DateTime(2031, 11, 18), 16, excluded: true);
    var clock = DateTime(2031, 11, 26, 8);
    LocalAgentTools tools(String id,
            {List<Map<String, Object?>> previous = const [],
            Map<String, Object?> view = const {}}) =>
        LocalAgentTools(
            scope: AgentScope(id: id, ledgerId: ledger),
            gateway: fixture.gateway,
            now: () => clock,
            previous: previous,
            view: view);
    Future<Map<String, Object?>> run(LocalAgentTools local, String tool,
            Map<String, Object?> arguments) =>
        local
            .build()[tool]!
            .execute(AgentToolCall(name: tool, arguments: arguments));
    const overview = 'get_period_overview';
    final local = tools('first');
    final expense = await run(local, overview,
        {'period': 'current_month', 'answerMetric': 'expense'});
    expect(expense['periodStart'], '2031-11-15T00:00:00.000');
    expect(expense['periodEnd'], '2031-11-27T00:00:00.000');
    expect(expense['expense'], 11);
    expect(expense['expenseCount'], 2);
    expect(expense['transferCount'], 1);
    final q = local.evidence.current.single;
    expect(q['answerMetric'], 'expense');
    expect(q['answerPeriod'], 'current_month');
    expect(q['asOf'], '2031-11-26');
    final snapshot = local.evidence.snapshots[q['ref']]!;
    expect(LedgerQuerySnapshot.valid(snapshot, ledger), isTrue);
    final visible = LedgerQuerySnapshot.page(snapshot, 0, flow: 'expense');
    expect(visible, hasLength(2));
    expect(visible.map((row) => row['native_amount'] ?? row['amount']),
        unorderedEquals([4, 7]));
    final detail = await run(local, 'query_transactions',
        {'baseQuery': q['ref'], 'flowType': 'expense'});
    expect(detail['totalCount'], 2);
    final full = await run(local, overview, {
      'period': 'current_month',
      'answerMetric': 'overview',
      'rangeMode': 'full_period'
    });
    expect(full['periodEnd'], '2031-12-15T00:00:00.000');
    expect(full['expense'], 211);
    expect(full.containsKey('asOf'), isFalse);
    final coupled = await run(local, 'get_category_breakdown', {
      'period': 'current_month',
      'categoryLevel': 'top',
      'rangeMode': 'to_date'
    });
    expect(coupled['totalExpense'], 11);
    expect(coupled['periodEnd'], expense['periodEnd']);
    final selected = tools('selected',
        view: {'ledgerId': ledger, 'start': '2031-10-15', 'end': '2031-11-15'});
    final last = await run(selected, overview, {'answerMetric': 'expense'});
    expect(last['expense'], 30);
    expect(last.containsKey('asOf'), isFalse);
    expect(last['periodEnd'], '2031-11-15T00:00:00.000');
    final custom = await run(local, overview, {
      'answerMetric': 'balance',
      'period': 'custom',
      'start': '2031-11-22',
      'end': '2031-12-04'
    });
    expect(custom['periodEnd'], '2031-12-04T00:00:00.000');
    expect(custom.containsKey('asOf'), isFalse);
    final todayView = tools('this-view',
        view: {'ledgerId': ledger, 'start': '2031-11-15', 'end': '2031-12-15'});
    final fromView = await run(todayView, overview, {'answerMetric': 'income'});
    expect(fromView['incomeCount'], 1);
    expect(todayView.evidence.current.single['answerPeriod'], 'current_month');
    expect(fromView['periodEnd'], expense['periodEnd']);

    final saved = LedgerQueryReplay.definitions([q], ledger);
    final freshCall = LedgerQueryReplay.callsFor(saved).single;
    clock = DateTime(2032, 1, 3);
    final repeat = tools('replay', previous: saved);
    final result = await repeat.build()[overview]!.execute(freshCall);
    expect(result['expense'], 11);
    expect(result['periodEnd'], expense['periodEnd']);
    expect(repeat.evidence.current.single,
        containsPair('answerMetric', 'expense'));
    expect(repeat.evidence.current.single, containsPair('asOf', '2031-11-26'));
    expect(repeat.evidence.current.single,
        containsPair('answerPeriod', 'current_month'));
    final wholeOriginalMonth = await run(repeat, overview, {
      'baseQuery': q['ref'],
      'answerMetric': 'expense',
      'rangeMode': 'full_period'
    });
    expect(wholeOriginalMonth['periodEnd'], full['periodEnd']);
    expect(wholeOriginalMonth['expense'], full['expense']);

    final invalid = tools('invalid');
    for (final args in [
      {'answerMetric': 'made_up'},
      {'answerMetric': 'balance', 'flowType': 'income'},
      {'answerMetric': 'expense', 'rangeMode': 'whatever'}
    ]) {
      final failure = await run(invalid, overview, args);
      expect(failure, containsPair('retryable', true));
    }
    expect(invalid.evidence.current, isEmpty);
    await run(invalid, overview, {'period': 'previous_month'});
    expect(invalid.evidence.current.single,
        containsPair('answerMetric', 'unspecified'));
  });
}
