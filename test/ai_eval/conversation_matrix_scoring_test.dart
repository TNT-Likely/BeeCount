import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/conversation_matrix_scoring.dart';

void main() {
  test('matrix references use all ledger-v1 rows and ledger-currency amounts',
      () async {
    final fixture = jsonDecode(
            await File('test/ai_eval/fixtures/ledger_v1.json').readAsString())
        as Map;
    final months = (fixture['transactions'] as List)
        .cast<Map>()
        .where((row) =>
            row['ledger'] == 'main' &&
            row['type'] == 'expense' &&
            (row['date'] as String).startsWith('2026-'))
        .toList();
    List<Map> month(String name) => months
        .where((r) => (r['date'] as String).startsWith('2026-$name'))
        .toList();
    num sum(Iterable<Map> rows) => rows.fold<num>(
        0, (total, r) => total + ((r['nativeAmount'] ?? r['amount']) as num));
    bool dining(Map r) =>
        ['dining', 'lunch', 'breakfast'].contains(r['category']);
    final september = month('09');
    final august = month('08');
    final septemberStats =
        september.where((r) => r['excludeFromStats'] != true);
    final diningRows = september.where(dining);
    expect([sum(august), sum(septemberStats), septemberStats.length],
        [1300, 1295, 33]);
    expect([sum(august.where(dining)), sum(diningRows)], [300, 120]);
    expect(sum(diningRows.where((r) => r['account'] == 'cash')), 50);
    expect(sum(diningRows.where((r) => r['account'] == 'bank')), 70);
    expect(
        sum(septemberStats.where((r) => r['account'] == 'bank' && !dining(r))),
        0);
    final monthlyRestaurant = [
      for (var i = 1; i <= 9; i++)
        sum(month(i.toString().padLeft(2, '0')).where(dining))
    ];
    expect(
        monthlyRestaurant
                .indexOf(monthlyRestaurant.reduce((a, b) => a > b ? a : b)) +
            1,
        8);
    final shopping =
        september.where((r) => r['category'] == 'shopping').toList();
    expect([shopping.length, sum(shopping)], [28, 100052]);
    final latest = shopping.indexed.toList()
      ..sort((a, b) {
        final dates =
            (b.$2['date'] as String).compareTo(a.$2['date'] as String);
        return dates == 0 ? b.$1.compareTo(a.$1) : dates;
      });
    expect(latest.first.$2['amount'], 99999);
    expect([latest[1].$2['amount'], latest[1].$2['note']], [1, '批量小额 25']);
  });

  Map turn(String text, [List<Map> calls = const []]) =>
      {'text': text, 'responseType': 'text', 'calls': calls};

  Map<String, bool> checks(String task, List<Map> turns) => (scoreMatrixSample({
        'task': task,
        'observation': {'turns': turns, 'transactionsUnchanged': true}
      })['checks'] as Map)
          .cast<String, bool>();

  test(
      'account amounts, share and date-specific amounts require the right labels',
      () {
    Map account(String reply) =>
        checks('cash-followup', [turn('餐饮共120元。'), turn(reply)]);
    expect(account('现金支付1笔，50元。储蓄卡支付1笔，70元。')['bank_amount'], true);
    expect(account('现金70元，储蓄卡50元。')['bank_amount'], false);
    expect(account('现金70元，储蓄卡50元。')['cash_amount'], false);
    expect(
        checks('cash-followup', [
          turn('餐饮120元，占本月支出全部。'),
          turn('现金50元，储蓄卡70元。')
        ])['no_false_whole_month_share'],
        false);
    final right = checks('paged-count',
        [turn('总计28笔100,052元。\n9月21日 ¥99,999.00\n9月20日 ¥1.00 批量小额25')]);
    expect(right['september_21_amount'], true);
    expect(right['september_20_amount'], true);
    final wrong = checks(
        'paged-count', [turn('合计28笔100,052元。\n09-21 ¥1.00\n09-20 ¥99,999.00')]);
    expect(wrong['september_21_amount'], false);
    expect(wrong['september_20_amount'], false);
  });

  test(
      'conditional comparison follows the direction and the payment account of the meal',
      () {
    Map verdict(String words) => checks('conditional-review', [turn(words)]);
    expect(verdict('8月比9月多180元。9月7日午餐70元，使用储蓄卡。')['decrease_180'], true);
    expect(verdict('8月比9月少180元。')['decrease_180'], false);
    expect(verdict('最贵的是午餐70元，由现金支付。储蓄卡其他支出为0元。')['largest_meal_70_on_bank'],
        false);
  });

  test(
      'the monthly review checks direction, count attribution and evidence for missing settings',
      () {
    const text = '9月支出1,295（36笔），比8月少5元。餐饮增加180元。预算未设置，自动记账也未设置。';
    final result = checks('monthly-review', [
      turn(text, [
        {
          'name': 'get_budget_status',
          'succeeded': true,
          'result': {'asOf': '2026-09-30', 'total': null, 'categoryBudgets': []}
        }
      ])
    ]);
    expect(result['expense_down_5'], true);
    expect(result['dining_down_180'], false);
    expect(result['no_36_expenses_claim'], false);
    expect(result['budget_unset_evidence'], true);
    expect(result['recurring_unset_evidence'], false);
    expect(
        checks('monthly-review', [turn('共36笔交易，其中33笔支出。')])[
            'no_36_expenses_claim'],
        true);
  });
}
