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

  test('transaction summary delegates an all-type aggregate without rows',
      () async {
    final result = await tools['get_transaction_summary']!.execute(
      AgentToolCall(
        name: 'get_transaction_summary',
        arguments: const {
          'start': '2026-08-01T00:00:00.000',
          'end': '2026-08-31T23:59:59.999',
        },
      ),
    );

    expect(result, {
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
    });
    expect(gateway.summaryRequests, [
      (
        ledgerId: 1,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31, 23, 59, 59, 999),
        types: const {'income', 'expense', 'transfer'},
        groupBy: 'none',
        categoryLevel: 'leaf',
        categoryIds: const <int>[],
        tagIds: const <int>[],
        accountIds: const <int>[],
        includeExcludedFromStats: false,
        groupLimit: 20,
      ),
    ]);
  });

  test('transaction summary forwards filters and the requested grouping',
      () async {
    await tools['get_transaction_summary']!.execute(
      AgentToolCall(
        name: 'get_transaction_summary',
        arguments: const {
          'types': ['expense'],
          'groupBy': 'tag',
          'tagIds': [7],
          'includeExcludedFromStats': true,
          'groupLimit': 12,
        },
      ),
    );

    final request = gateway.summaryRequests.single;
    expect(request.types, {'expense'});
    expect(request.groupBy, 'tag');
    expect(request.tagIds, [7]);
    expect(request.includeExcludedFromStats, isTrue);
    expect(request.groupLimit, 12);
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
    expect(tools, contains('get_transaction_summary'));

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
        bool includeExcludedFromStats,
        int groupLimit,
      })> summaryRequests = [];
  List<AgentTransactionSummary> transactions = [];
  String ledgerCurrency = 'CNY';
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
      includeExcludedFromStats: includeExcludedFromStats,
      groupLimit: groupLimit,
    ));
    return const {
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
