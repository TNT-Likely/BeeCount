import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeGateway gateway;
  late Map<String, AgentTool> tools;

  setUp(() {
    gateway = _FakeGateway();
    tools = LocalAgentTools(
      scope: const AgentScope(id: 'user-1', ledgerId: 1),
      gateway: gateway,
    ).build();
  });

  test('record tool forwards the exact source text to the local recorder',
      () async {
    final result = await tools['record_transaction_from_text']!.execute(
      AgentToolCall(
        name: 'record_transaction_from_text',
        arguments: const {'sourceText': '午饭 35'},
      ),
    );

    expect(gateway.recordedTexts, ['午饭 35']);
    expect(result, {
      'success': true,
      'transactionIds': [42],
      'transactions': [],
      'unconvertedCurrencies': [],
    });
  });

  test('query tool clips local results to twenty rows and keeps scope ledger',
      () async {
    gateway.transactions = [
      for (var index = 0; index < 25; index++)
        AgentTransactionSummary(
          id: index,
          ledgerId: 1,
          type: 'expense',
          amount: -10,
          happenedAt: DateTime(2026, 1, 1),
          note: '项目$index',
        ),
    ];

    final result = await tools['query_transactions']!.execute(
      AgentToolCall(
        name: 'query_transactions',
        arguments: const {'ledgerId': 2},
      ),
    );

    final items = result['items']! as List<Object?>;
    expect(items, hasLength(20));
    expect(gateway.requestedLedgerIds, [1]);
  });

  test('query tool returns amounts in a named currency for the model',
      () async {
    gateway.transactions = [
      AgentTransactionSummary(
        id: 8,
        ledgerId: 1,
        type: 'expense',
        amount: -35,
        happenedAt: DateTime(2026, 9, 6),
        note: '午饭',
      ),
    ];

    final result = await tools['query_transactions']!.execute(
      AgentToolCall(name: 'query_transactions'),
    );

    expect(result['items'], [
      {
        'id': 8,
        'ledgerId': 1,
        'type': 'expense',
        'amount': -35.0,
        'ledgerAmount': -35.0,
        'currency': 'CNY',
        'ledgerCurrency': 'CNY',
        'category': null,
        'account': null,
        'toAccount': null,
        'tags': [],
        'excludeFromStats': false,
        'excludeFromBudget': false,
        'happenedAt': '2026-09-06T00:00:00.000',
        'note': '午饭',
      },
    ]);
  });

  test('tool registry keeps core tools resident and searches optional tools',
      () {
    final registry = LocalAgentTools(
      scope: const AgentScope(id: 'user-1', ledgerId: 1),
      gateway: gateway,
    ).buildRegistry();

    final trend = registry.select('对比各月餐饮支出', maximumTools: 7);
    final budget = registry.select('这个月预算还能花多少', maximumTools: 7);
    final shortRecord = registry.select('午饭35', maximumTools: 7);
    final breakdown = registry.select('本月各分类支出占比', maximumTools: 7);

    expect(trend.names, contains('get_spending_trend'));
    expect(budget.names, contains('get_budget_status'));
    expect(shortRecord.names, contains('record_transaction_from_text'));
    expect(
      breakdown.names,
      contains('get_category_breakdown'),
    );
    expect(budget.names.length, lessThanOrEqualTo(7));
  });

  test('period overview resolves a custom range and returns derived metrics',
      () async {
    final result = await tools['get_period_overview']!.execute(
      AgentToolCall(
        name: 'get_period_overview',
        arguments: const {
          'period': 'custom',
          'start': '2026-08-01T00:00:00.000',
          'end': '2026-08-31T23:59:59.999',
        },
      ),
    );

    expect(result, {
      'currency': 'CNY',
      'period': 'custom',
      'periodStart': '2026-08-01T00:00:00.000',
      'periodEnd': '2026-08-31T23:59:59.999',
      'income': 1200.0,
      'expense': 480.0,
      'balance': 720.0,
      'savingsRate': 0.6,
      'transactionCount': 7,
    });
    final request = gateway.summaryRequests.single;
    expect(request.start, DateTime(2026, 8, 1));
    expect(request.end, DateTime(2026, 8, 31, 23, 59, 59, 999));
    expect(request.types, {'income', 'expense', 'transfer'});
    expect(request.groupBy, 'none');
  });

  test('spending trend forwards category filter and computes point changes',
      () async {
    gateway.summaryResult = const {
      'currency': 'CNY',
      'periodStart': '2026-01-01T00:00:00.000',
      'periodEnd': '2027-01-01T00:00:00.000',
      'totals': {
        'expense': {'amount': 300.0, 'count': 3},
      },
      'groups': [
        {
          'key': {'kind': 'month', 'value': '2026-01'},
          'totals': {
            'expense': {'amount': 100.0, 'count': 1},
          },
        },
        {
          'key': {'kind': 'month', 'value': '2026-02'},
          'totals': {
            'expense': {'amount': 200.0, 'count': 2},
          },
        },
      ],
      'truncated': false,
    };
    final result = await tools['get_spending_trend']!.execute(
      AgentToolCall(
        name: 'get_spending_trend',
        arguments: const {
          'period': 'custom',
          'start': '2026-01-01T00:00:00.000',
          'end': '2027-01-01T00:00:00.000',
          'interval': 'month',
          'categoryNames': [' 餐饮 '],
        },
      ),
    );

    final request = gateway.summaryRequests.single;
    expect(request.types, {'expense'});
    expect(request.groupBy, 'month');
    expect(request.categoryNames, ['餐饮']);
    expect(result['points'], [
      {
        'period': '2026-01',
        'amount': 100.0,
        'count': 1,
        'comparedAmount': null,
        'changeAmount': null,
        'changeRate': null,
      },
      {
        'period': '2026-02',
        'amount': 200.0,
        'count': 2,
        'comparedAmount': 100.0,
        'changeAmount': 100.0,
        'changeRate': 1.0,
      },
    ]);
  });

  test('category breakdown returns locally calculated shares', () async {
    gateway.summaryResult = const {
      'currency': 'CNY',
      'periodStart': '2026-08-01T00:00:00.000',
      'periodEnd': '2026-09-01T00:00:00.000',
      'totals': {
        'expense': {'amount': 400.0, 'count': 4},
      },
      'groups': [
        {
          'key': {'kind': 'category', 'id': 1, 'name': '餐饮'},
          'totals': {
            'expense': {'amount': 100.0, 'count': 2},
          },
        },
      ],
      'truncated': false,
    };
    final result = await tools['get_category_breakdown']!.execute(
      AgentToolCall(
        name: 'get_category_breakdown',
        arguments: const {
          'period': 'custom',
          'start': '2026-08-01T00:00:00.000',
          'end': '2026-09-01T00:00:00.000',
          'categoryLevel': 'top',
        },
      ),
    );

    final request = gateway.summaryRequests.single;
    expect(request.groupBy, 'category');
    expect(request.categoryLevel, 'top');
    expect(result['items'], [
      {
        'category': {'kind': 'category', 'id': 1, 'name': '餐饮'},
        'amount': 100.0,
        'count': 2,
        'share': 0.25,
      },
    ]);
  });

  test('budget tool returns a stable, currency-aware budget snapshot',
      () async {
    final result = await tools['get_budget_status']!.execute(
      AgentToolCall(name: 'get_budget_status'),
    );

    expect(result, {
      'currency': 'CNY',
      'daysRemaining': 10,
      'dailyAvailable': 20.0,
      'total': null,
      'categoryBudgets': [],
    });
  });

  test('forget memory reports false when the current ledger does not own it',
      () async {
    final result = await tools['forget_memory']!.execute(
      AgentToolCall(
        name: 'forget_memory',
        arguments: const {'memoryId': 42},
      ),
    );

    expect(result, {'forgotten': false});
    expect(gateway.forgetMemoryRequests, [
      (ledgerId: 1, memoryId: 42),
    ]);
  });

  test('save memory returns the durable memory ID to the model', () async {
    final result = await tools['save_explicit_memory']!.execute(
      AgentToolCall(
        name: 'save_explicit_memory',
        arguments: const {'content': '我喜欢简洁的汇总'},
      ),
    );

    expect(result, {'saved': true, 'memoryId': 21});
  });

  test('P0 query tools exclude overlapping report summaries', () async {
    expect(tools, isNot(contains('get_income_expense_summary')));
    expect(tools, isNot(contains('get_category_spending')));
    expect(tools, isNot(contains('get_transaction_summary')));
    expect(tools, contains('get_period_overview'));
    expect(tools, contains('get_spending_trend'));
    expect(tools, contains('get_category_breakdown'));

    final recurring = await tools['get_recurring_transactions']!.execute(
      AgentToolCall(name: 'get_recurring_transactions'),
    );

    expect(recurring['items'], [
      {
        'id': null,
        'type': 'expense',
        'amount': 18.0,
        'currency': 'CNY',
        'category': null,
        'account': null,
        'toAccount': null,
        'frequency': 'monthly',
        'interval': 1,
        'dayOfMonth': null,
        'dayOfWeek': null,
        'monthOfYear': null,
        'startDate': null,
        'endDate': null,
        'lastGeneratedDate': null,
        'note': '视频会员',
      },
    ]);
    expect(gateway.requestedLedgerIds, [1]);
  });
}

final class _FakeGateway implements LocalAgentToolGateway {
  final List<String> recordedTexts = [];
  final List<int> requestedLedgerIds = [];
  final List<({int ledgerId, int memoryId})> forgetMemoryRequests = [];
  final List<
      ({
        int ledgerId,
        DateTime start,
        DateTime end,
        Set<String> types,
        String groupBy,
        String categoryLevel,
        List<int> categoryIds,
        List<int> tagIds,
        List<int> accountIds,
        List<String> categoryNames,
        List<String> tagNames,
        List<String> accountNames,
        bool includeExcludedFromStats,
        int groupLimit,
      })> summaryRequests = [];
  List<AgentTransactionSummary> transactions = [];
  String ledgerCurrency = 'CNY';
  Map<String, Object?> summaryResult = const {
    'currency': 'CNY',
    'periodStart': '2026-08-01T00:00:00.000',
    'periodEnd': '2026-08-31T23:59:59.999',
    'types': ['income', 'expense', 'transfer'],
    'totals': {
      'income': {'amount': 1200.0, 'count': 2},
      'expense': {'amount': 480.0, 'count': 4},
      'transfer': {'amount': 300.0, 'count': 1},
    },
    'groupBy': 'none',
    'groups': [],
    'groupsMayOverlap': false,
    'truncated': false,
  };
  final List<AgentRecurringTransactionSummary> recurringTransactions = const [
    AgentRecurringTransactionSummary(
      type: 'expense',
      amount: 18,
      frequency: 'monthly',
      interval: 1,
      note: '视频会员',
    ),
  ];

  @override
  Future<bool> forgetMemory({
    required int ledgerId,
    required int memoryId,
  }) async {
    forgetMemoryRequests.add((ledgerId: ledgerId, memoryId: memoryId));
    return false;
  }

  @override
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId) async =>
      const AgentBudgetSummary(daysRemaining: 10, dailyAvailable: 20);

  @override
  Future<String> getLedgerCurrency(int ledgerId) async => ledgerCurrency;

  @override
  Future<int> getLedgerMonthStartDay(int ledgerId) async => 1;

  @override
  Future<List<AgentRecurringTransactionSummary>> getRecurringTransactions(
    int ledgerId,
  ) async {
    requestedLedgerIds.add(ledgerId);
    return recurringTransactions;
  }

  @override
  Future<List<AgentTransactionSummary>> queryTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    requestedLedgerIds.add(ledgerId);
    return transactions;
  }

  @override
  Future<Map<String, Object?>> summarizeTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    required Set<String> types,
    required String groupBy,
    required String categoryLevel,
    required List<int> categoryIds,
    required List<int> tagIds,
    required List<int> accountIds,
    required List<String> categoryNames,
    required List<String> tagNames,
    required List<String> accountNames,
    required bool includeExcludedFromStats,
    required int groupLimit,
  }) async {
    summaryRequests.add((
      ledgerId: ledgerId,
      start: start,
      end: end,
      types: types,
      groupBy: groupBy,
      categoryLevel: categoryLevel,
      categoryIds: categoryIds,
      tagIds: tagIds,
      accountIds: accountIds,
      categoryNames: categoryNames,
      tagNames: tagNames,
      accountNames: accountNames,
      includeExcludedFromStats: includeExcludedFromStats,
      groupLimit: groupLimit,
    ));
    return summaryResult;
  }

  @override
  Future<AgentRecordToolResult> recordTransaction({
    required int ledgerId,
    required String text,
  }) async {
    recordedTexts.add(text);
    return const AgentRecordToolResult(success: true, transactionIds: [42]);
  }

  @override
  Future<int> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  }) async =>
      21;
}
