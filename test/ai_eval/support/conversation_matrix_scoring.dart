/// Observable acceptance checks for the four Chinese conversations on ledger-v1.
/// Language checks cover explicit claims. Keep the raw answers and tool results
/// alongside the checks so that a reviewer can inspect ambiguous wording.
Map<String, Object?> scoreMatrixSample(Map sample) {
  final observation = sample['observation'] as Map;
  final turns = (observation['turns'] as List).cast<Map>();
  final task = sample['task'] as String;
  final responses =
      turns.map((turn) => _normalize(turn['text'] as String)).toList();
  final first = responses.isEmpty ? '' : responses.first;
  final last = responses.isEmpty ? '' : responses.last;
  final calls = turns
      .expand((turn) => (turn['calls'] as List).cast<Map>())
      .where((call) =>
          call['succeeded'] == true &&
          call['result'] is Map &&
          !(call['result'] as Map).containsKey('error'))
      .toList();
  Iterable<Map> results(String name) => calls
      .where((call) => call['name'] == name)
      .map((call) => call['result'] as Map);
  final details = results('query_transactions')
      .expand(
          (result) => (result['items'] as List? ?? const []).whereType<Map>())
      .toList();
  final allExpenses = _monthlyExpenses(calls, dining: false);
  final diningExpenses = _monthlyExpenses(calls, dining: true);
  final checks = <String, bool>{
    'answer_delivered': turns.length == (task == 'cash-followup' ? 2 : 1) &&
        turns.every((turn) =>
            turn['responseType'] == 'text' &&
            (turn['text'] as String).trim().isNotEmpty),
    'ledger_unchanged': observation['transactionsUnchanged'] == true,
  };
  switch (task) {
    case 'cash-followup':
      final firstReads = turns.isEmpty
          ? <Map>[]
          : (turns.first['calls'] as List)
              .whereType<Map>()
              .where((c) =>
                  c['succeeded'] == true &&
                  c['result'] is Map &&
                  !(c['result'] as Map).containsKey('error'))
              .toList();
      checks['dining_total_evidence'] =
          _monthlyExpenses(firstReads, dining: true)['2026-09']
                  ?.contains(120) ==
              true;
      checks['dining_120'] = _nearMoney(first, '餐饮|吃饭|伙食', 120);
      for (final (account, amount) in [('现金', 50), ('储蓄卡', 70)]) {
        final prefix = account == '现金' ? 'cash' : 'bank';
        checks['${prefix}_amount'] = _accountAmount(last, account, amount);
        checks['${prefix}_evidence'] = results('get_period_overview').any((r) =>
                (r['filters'] as Map?)?['accountNames'] is List &&
                ((r['filters'] as Map)['accountNames'] as List)
                    .contains(account) &&
                r['expense'] == amount) ||
            details.any((row) =>
                (row['account'] as Map?)?['name'] == account &&
                ['早餐', '午餐', '餐饮']
                    .contains((row['category'] as Map?)?['name']) &&
                row['ledgerAmount'] == amount);
      }
      checks['no_false_whole_month_share'] = !RegExp(
              r'(占|等于|就是)(本月|当月|9月)(总?支出|消费)(的)?(全部|所有|100%)|占(全部|所有)(月度|当月|本月)支出')
          .hasMatch(first);
    case 'paged-count':
      checks['all_28_bills'] = RegExp(r'(?<!\d)28(?:笔|条)').hasMatch(last);
      checks['all_100052'] = _money(100052).hasMatch(last);
      for (final (day, amount) in [(21, 99999), (20, 1)]) {
        checks['september_${day}_amount'] = _dateAmount(last, day, amount);
        checks['september_${day}_evidence'] = details.any((bill) =>
            bill['ledgerAmount'] == amount &&
            (bill['happenedAt'] as String).startsWith('2026-09-$day') &&
            (bill['category'] as Map?)?['name'] == '购物' &&
            (day != 20 || bill['note'] == '批量小额 25'));
      }
      checks['full_aggregate_evidence'] = results('query_transactions').any(
              (r) =>
                  r['totalCount'] == 28 && r['totalLedgerAmount'] == 100052) ||
          results('get_period_overview').any(
              (r) => r['transactionCount'] == 28 && r['expense'] == 100052);
    case 'monthly-review':
      checks['period_totals_evidence'] =
          allExpenses['2026-08']?.contains(1300) == true &&
              allExpenses['2026-09']?.contains(1295) == true;
      checks['dining_totals_evidence'] =
          diningExpenses['2026-08']?.contains(300) == true &&
              diningExpenses['2026-09']?.contains(120) == true;
      checks['expense_down_5'] =
          _deltaInSection(last, r'总支出|支出|整体', r'餐饮|花钱上限|预算', 5);
      checks['dining_down_180'] =
          _deltaInSection(last, '餐饮|吃饭', '总支出|花钱上限|预算|自动记账', 180);
      checks['no_36_expenses_claim'] = !RegExp(
              r'(?:1295(?:\.0+)?(?:元|CNY)?[（(](?:共|计)?36笔(?!交易)|36笔(?:为|是)?支出|支出[：:为共计]{0,3}36笔)')
          .hasMatch(last);
      checks['budget_unset_answer'] =
          _unsetInSection(last, '花钱上限|预算', '自动记账|周期记账');
      checks['recurring_unset_answer'] =
          _unsetInSection(last, '周期记账|自动记账|重复交易|周期规则', '预算|花钱上限');
      checks['budget_unset_evidence'] = results('get_budget_status').any((r) =>
          r.containsKey('total') &&
          r['total'] == null &&
          r['categoryBudgets'] is List &&
          (r['categoryBudgets'] as List).isEmpty &&
          (r['asOf'] == null || (r['asOf'] as String).startsWith('2026-09')));
      checks['recurring_unset_evidence'] = results('get_recurring_transactions')
          .any((r) =>
              r['items'] is List &&
              (r['items'] as List).isEmpty &&
              (r['totalCount'] ?? 0) == 0);
    case 'conditional-review':
      const diningByMonth = [100, 150, 0, 80, 200, 0, 100, 300, 120];
      checks['peak_and_next_month_evidence'] = diningByMonth.indexed.every(
          (point) =>
              diningExpenses['2026-0${point.$1 + 1}']?.contains(point.$2) ==
              true);
      checks['peak_august_300'] =
          _nearMoney(last, r'(?:2026年)?(?:0?8月|八月)', 300);
      checks['next_september_120'] =
          _nearMoney(last, r'(?:2026年)?(?:0?9月|九月|下个?月|次月)', 120);
      checks['decrease_180'] = _declinesBy(last, 180);
      checks['largest_meal_70_on_bank'] = _sections(
              last, '午餐|最贵|最高.{0,4}一笔|最大.{0,4}一笔|储蓄卡', r'早餐|[。；;]|除餐饮|非餐饮',
              span: 90)
          .any((s) =>
              _money(70).hasMatch(s) &&
              s.contains('储蓄卡') &&
              RegExp('午餐|最贵|最大|最高').hasMatch(s));
      checks['largest_meal_evidence'] = details.any((row) =>
          row['ledgerAmount'] == 70 &&
          (row['happenedAt'] as String).startsWith('2026-09-07') &&
          (row['account'] as Map?)?['name'] == '储蓄卡' &&
          (row['category'] as Map?)?['name'] == '午餐');
      checks['bank_excluding_dining_zero'] =
          _sections(last, '除餐饮|除去餐饮|非餐饮|其他支出|其它支出|其余支出|储蓄卡', r'(?!)', span: 116)
              .any((section) =>
                  RegExp(r'(?:除餐饮|除去餐饮|非餐饮|其他|其它|其余|除此之外)').hasMatch(section) &&
                  (_money(0).hasMatch(section) ||
                      RegExp(r'没有(?:任何)?[其别][他它的]|无其他|为零').hasMatch(section)));
      checks['bank_remainder_evidence'] =
          results('get_period_overview').any((r) {
                final filters = r['filters'] as Map?;
                if (filters == null ||
                    !(filters['accountNames'] as List? ?? []).contains('储蓄卡')) {
                  return false;
                }
                return (filters['exclude'] is Map && r['expense'] == 0) ||
                    (filters['categoryNames'] == null && r['expense'] == 70);
              }) ||
              results('query_transactions').any((r) {
                final filters = r['filters'] as Map?;
                return filters != null &&
                    (filters['accountNames'] as List? ?? []).contains('储蓄卡') &&
                    (filters['categoryNames'] as List? ?? []).isEmpty &&
                    (r['totalCount'] == 0 ||
                        (r['totalCount'] == 1 && r['totalLedgerAmount'] == 70));
              });
    default:
      throw ArgumentError.value(
          task, 'task', 'Unknown ledger-v1 matrix conversation');
  }
  return {
    'passed': checks.values.every((value) => value),
    'checks': checks,
    'failedChecks': [
      for (final check in checks.entries)
        if (!check.value) check.key
    ]
  };
}

/// Tracks which amounts the executed reads actually supplied for each month.
/// An account-specific result cannot establish a whole-ledger monthly total.
Map<String, Set<num>> _monthlyExpenses(List<Map> calls,
    {required bool dining}) {
  final amounts = <String, Set<num>>{};
  void record(Object? month, Object? amount) {
    if (month is String && amount is num) (amounts[month] ??= {}).add(amount);
  }

  for (final call in calls) {
    final result = call['result'] as Map;
    final filters =
        (result['filters'] as Map?) ?? (call['arguments'] as Map? ?? {});
    const narrowing = [
      'accountNames',
      'accountIds',
      'tagNames',
      'tagIds',
      'exclude',
      'currency',
      'minAmount',
      'maxAmount'
    ];
    if (narrowing.any((key) => filters.containsKey(key)) ||
        filters['includeExcludedFromStats'] == true) {
      continue;
    }
    final names =
        (filters['categoryNames'] as List? ?? []).whereType<String>().toSet();
    final diningFilter =
        names.isNotEmpty && names.every({'餐饮', '吃饭', '伙食'}.contains);
    final overview = call['name'] == 'get_period_overview';
    final breakdown = call['name'] == 'get_category_breakdown';
    if (call['name'] == 'get_spending_trend' &&
        (filters['flowType'] ?? result['flowType'] ?? 'expense') == 'expense') {
      if (dining ? !diningFilter : names.isNotEmpty) continue;
      for (final point
          in (result['points'] as List? ?? const []).whereType<Map>()) {
        record(point['period'], point['amount']);
      }
    }
    if (!overview && !breakdown) continue;
    final start = DateTime.tryParse('${result['periodStart']}');
    final end = DateTime.tryParse('${result['periodEnd']}');
    if (start == null ||
        start.day != 1 ||
        end != DateTime(start.year, start.month + 1)) {
      continue;
    }
    final month = start.toIso8601String().substring(0, 7);
    if (overview && (dining ? diningFilter : names.isEmpty)) {
      record(month, result['expense']);
    }
    if (breakdown && result['flowType'] == 'expense') {
      if (dining ? diningFilter : names.isEmpty) {
        record(month, result['totalExpense']);
      }
      if (!dining || names.isNotEmpty) continue;
      for (final row
          in (result['items'] as List? ?? const []).whereType<Map>()) {
        if ((row['category'] as Map?)?['name'] == '餐饮') {
          record(month, row['amount']);
        }
      }
    }
  }
  return amounts;
}

String _normalize(String text) => text
    .replaceAll(RegExp(r'[*`_ \t]'), '')
    .replaceAll(RegExp(r'(?<=\d)[,，](?=\d{3}(?:\D|$))'), '')
    .replaceAll('−', '-');

/// Captures money only. A date, count, percentage or rounded fraction cannot
/// satisfy a check merely by containing the expected digits.
RegExp _money(int amount) =>
    RegExp('(?<![\\d.])$amount(?:\\.0+)?(?![\\d.％%年月日笔条])');
bool _nearMoney(String text, String label, int amount) {
  final value = _money(amount).pattern;
  return RegExp(
          '(?:$label)[^。；;\\n]{0,34}?$value|$value(?:元|块|人民币|CNY)?[（(，,：:的·]{0,4}(?:$label)')
      .hasMatch(text);
}

bool _accountAmount(String text, String name, int amount) {
  final other = name == '现金' ? '储蓄卡' : '现金';
  return _sections(text, name, other, span: 45).any(
          (s) => _money(amount).hasMatch(s.split(RegExp(r'[。；;\n]')).first)) ||
      RegExp('${_money(amount).pattern}(?:元|块)(?:的|由|用|是)?$name')
          .hasMatch(text);
}

bool _dateAmount(String text, int day, int amount) {
  final date = '(?:9月|0?9[-/.])0?$day(?:日|号)?';
  return _sections(text, date, r'(?<!\d)(?:09[-/.]|9[-/]|9月)\d{1,2}(?!\d)',
          span: 90)
      .any((s) => _money(amount).hasMatch(s
          .replaceFirst(RegExp(date), '')
          .replaceAll(RegExp(r'\d{1,2}:\d{2}(:\d{2})?'), '')));
}

Iterable<String> _sections(String text, String label, String boundary,
    {int span = 142}) sync* {
  for (final match in RegExp(label).allMatches(text)) {
    final tail = text.substring(match.end);
    final end = RegExp(boundary).firstMatch(tail)?.start ?? tail.length;
    yield text.substring(match.start, match.end + end.clamp(0, span).toInt());
  }
}

bool _declinesBy(String text, int amount) {
  final value = _money(amount).pattern;
  final increase = '(?:多|高|增加|超)(?:花|了|出)?[¥￥约]*$value';
  final decrease = '(?:少|低|减少)(?:花|了|出)?[¥￥约]*$value';
  if (RegExp(
          '9月(?:比|较)8月[^。；;，,\\n]{0,9}?$increase|8月(?:比|较)9月[^。；;，,\\n]{0,9}?$decrease')
      .hasMatch(text)) {
    return false;
  }
  if (RegExp('8月(?:比|较)9月[^。；;，,\\n]{0,9}?$increase').hasMatch(text)) {
    return true;
  }
  return _decline(amount).hasMatch(text);
}

RegExp _decline(int amount) {
  final value = _money(amount).pattern;
  return RegExp(
      '(?:少(?:花|支出|了|花了)?|下降|降低|减少|节省|少付|降幅|回落|低(?:了)?|[-↓▼])[¥￥为约:：共计]*$value(?!%)|'
      '$value(?:元|块|CNY)?[^。；;\\n]{0,14}?(?:9月(?:略|更)?少|下降|减少)');
}

bool _deltaInSection(
        String text, String subject, String boundary, int amount) =>
    _sections(text, subject, boundary, span: 240).any((s) =>
        _declinesBy(s, amount) ||
        (RegExp('(?:相差|差额|减少额)[：:]?¥?$amount(?:\\.0+)?(?:元|块)').hasMatch(s) &&
            RegExp('9月(?:比8月)?(?:略)?(?:少|低)|下降').hasMatch(s)));
bool _unsetInSection(String text, String subject, String boundary) =>
    _sections(text, subject, boundary).any((s) =>
        RegExp(r'未设置|未设|未配置|没有|无预算|暂无|为空|都是空|零项|为0|0条|0项').hasMatch(s)) ||
    RegExp('(?:未设(?:置)?|没有(?:设置|配置)?|暂无|无)(?:任何|相应|启用中|启用|按月的)?(?:$subject)')
        .hasMatch(text);

/// Each sample is one complete scenario including all user messages, repair
/// turns and wait time. Usage sums describe only requests with provider usage.
Map<String, Object?> summarizeMatrixSamples(List<Map> samples) {
  final ms = samples.map((s) => s['elapsedMs'] as int).toList()..sort();
  int sum(String key) => samples.fold(0, (n, s) => n + ((s[key] as int?) ?? 0));
  int metrics(String key) => samples.fold(
      0, (n, s) => n + (((s['metrics'] as Map)[key] as int?) ?? 0));
  final metered = sum('meteredResponses');
  return {
    'scenarios': samples.length,
    'passed': samples
        .where((s) =>
            ((s['quality'] as Map?) ?? scoreMatrixSample(s))['passed'] == true)
        .length,
    'modelTurns': metrics('modelTurns'),
    'toolCalls': metrics('toolCalls'),
    'requests': sum('requests'),
    'meteredResponses': metered,
    if (metered > 0) 'observedInputTokens': sum('inputTokens'),
    if (metered > 0) 'observedOutputTokens': sum('outputTokens'),
    if (ms.isNotEmpty)
      'medianScenarioMs': (ms[(ms.length - 1) ~/ 2] + ms[ms.length ~/ 2]) / 2,
  };
}
