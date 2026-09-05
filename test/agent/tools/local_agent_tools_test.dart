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
    await tools['record_transaction_from_text']!.execute(
      AgentToolCall(
        name: 'record_transaction_from_text',
        arguments: const {'sourceText': '午饭 35'},
      ),
    );

    expect(gateway.recordedTexts, ['午饭 35']);
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

  test('spending summary returns the requested date range to the model',
      () async {
    final result = await tools['get_spending_summary']!.execute(
      AgentToolCall(
        name: 'get_spending_summary',
        arguments: const {
          'start': '2026-08-01T00:00:00.000',
          'end': '2026-08-31T23:59:59.999',
        },
      ),
    );

    expect(result['periodStart'], '2026-08-01T00:00:00.000');
    expect(result['periodEnd'], '2026-08-31T23:59:59.999');
  });

  test('P0 query tools exclude overlapping report summaries', () async {
    expect(tools, isNot(contains('get_income_expense_summary')));
    expect(tools, isNot(contains('get_category_spending')));

    final recurring = await tools['get_recurring_transactions']!.execute(
      AgentToolCall(name: 'get_recurring_transactions'),
    );

    expect(recurring['items'], [
      {
        'type': 'expense',
        'amount': 18.0,
        'frequency': 'monthly',
        'interval': 1,
        'note': '视频会员',
      },
    ]);
    expect(gateway.requestedLedgerIds, [1]);
  });
}

final class _FakeGateway implements LocalAgentToolGateway {
  final List<String> recordedTexts = [];
  final List<int> requestedLedgerIds = [];
  List<AgentTransactionSummary> transactions = [];
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
  Future<void> forgetMemory(int memoryId) async {}

  @override
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId) async =>
      const AgentBudgetSummary(daysRemaining: 10, dailyAvailable: 20);

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
  Future<AgentRecordToolResult> recordTransaction({
    required int ledgerId,
    required String text,
  }) async {
    recordedTexts.add(text);
    return const AgentRecordToolResult(success: true, transactionIds: [42]);
  }

  @override
  Future<void> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  }) async {}
}
