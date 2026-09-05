import 'package:agentcore/agentcore.dart'
    hide
        AgentMemoryDraft,
        AgentMemoryRecord,
        AgentMemoryRepository,
        AgentToolCallAudit;

import '../../data/repositories/base_repository.dart';
import '../../services/ai/ai_bookkeeper.dart';
import '../../services/data/tag_seed_service.dart';
import '../memory/agent_memory_repository.dart';

final class AgentTransactionSummary {
  const AgentTransactionSummary({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    required this.happenedAt,
    required this.note,
  });

  final int id;
  final int ledgerId;
  final String type;
  final double amount;
  final DateTime happenedAt;
  final String? note;

  Map<String, Object?> toToolData() => {
        'id': id,
        'ledgerId': ledgerId,
        'type': type,
        'amount': amount,
        'happenedAt': happenedAt.toIso8601String(),
        'note': _clip(note, 160),
      };
}

final class AgentBudgetSummary {
  const AgentBudgetSummary({
    required this.daysRemaining,
    required this.dailyAvailable,
    this.used,
    this.budget,
  });

  final int daysRemaining;
  final double dailyAvailable;
  final double? used;
  final double? budget;

  Map<String, Object?> toToolData() => {
        'daysRemaining': daysRemaining,
        'dailyAvailable': dailyAvailable,
        'used': used,
        'budget': budget,
      };
}

final class AgentIncomeExpenseSummary {
  const AgentIncomeExpenseSummary({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;

  Map<String, Object?> toToolData() => {
        'income': income,
        'expense': expense,
        'net': income - expense,
      };
}

final class AgentCategorySpending {
  const AgentCategorySpending({required this.name, required this.total});

  final String name;
  final double total;

  Map<String, Object?> toToolData() => {'name': name, 'total': total};
}

final class AgentRecurringTransactionSummary {
  const AgentRecurringTransactionSummary({
    required this.type,
    required this.amount,
    required this.frequency,
    required this.interval,
    this.note,
  });

  final String type;
  final double amount;
  final String frequency;
  final int interval;
  final String? note;

  Map<String, Object?> toToolData() => {
        'type': type,
        'amount': amount,
        'frequency': frequency,
        'interval': interval,
        if (note != null && note!.trim().isNotEmpty) 'note': _clip(note, 120),
      };
}

final class AgentRecordToolResult {
  const AgentRecordToolResult({
    required this.success,
    this.transactionIds = const [],
    this.bills = const [],
  });

  final bool success;
  final List<int> transactionIds;
  final List<Map<String, Object?>> bills;

  Map<String, Object?> toToolData() => {
        'success': success,
        'transactionIds': transactionIds,
        'bills': bills,
      };
}

/// Narrow app-facing port so tools can be tested without a full repository
/// mock and cannot access any cloud data path.
abstract interface class LocalAgentToolGateway {
  Future<List<AgentTransactionSummary>> queryTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  });
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId);
  Future<AgentIncomeExpenseSummary> getIncomeExpenseSummary({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  });
  Future<List<AgentCategorySpending>> getCategorySpending({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  });
  Future<List<AgentRecurringTransactionSummary>> getRecurringTransactions(
    int ledgerId,
  );
  Future<AgentRecordToolResult> recordTransaction({
    required int ledgerId,
    required String text,
  });
  Future<void> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  });
  Future<void> forgetMemory(int memoryId);
}

/// Production local gateway. It uses the same [AiBookkeeper] path as the
/// legacy chat, preserving bills, undo metadata, statistics refresh and sync.
final class BeeCountLocalAgentToolGateway implements LocalAgentToolGateway {
  BeeCountLocalAgentToolGateway({
    required BaseRepository repository,
    required AiBookkeeper bookkeeper,
    required AgentMemoryRepository memoryRepository,
  })  : _repository = repository,
        _bookkeeper = bookkeeper,
        _memoryRepository = memoryRepository;

  final BaseRepository _repository;
  final AiBookkeeper _bookkeeper;
  final AgentMemoryRepository _memoryRepository;

  @override
  Future<List<AgentTransactionSummary>> queryTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    final transactions = await _repository.getTransactionsByLedgerInRange(
      ledgerId: ledgerId,
      start: start,
      end: end,
    );
    return transactions
        .map(
          (item) => AgentTransactionSummary(
            id: item.id,
            ledgerId: item.ledgerId,
            type: item.type,
            amount: item.amount,
            happenedAt: item.happenedAt,
            note: item.note,
          ),
        )
        .toList();
  }

  @override
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId) async {
    final overview =
        await _repository.getBudgetOverview(ledgerId, DateTime.now());
    final total = overview.totalBudget;
    return AgentBudgetSummary(
      daysRemaining: overview.daysRemaining,
      dailyAvailable: overview.dailyAvailable,
      used: total?.used,
      budget: total?.budget,
    );
  }

  @override
  Future<AgentIncomeExpenseSummary> getIncomeExpenseSummary({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    final totals = await _repository.totalsInRange(
      ledgerId: ledgerId,
      start: start,
      end: end,
    );
    return AgentIncomeExpenseSummary(
      income: totals.$1.abs(),
      expense: totals.$2.abs(),
    );
  }

  @override
  Future<List<AgentCategorySpending>> getCategorySpending({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: start,
      end: end,
    );
    return rows
        .map(
          (row) => AgentCategorySpending(
            name: row.name,
            total: row.total.abs(),
          ),
        )
        .toList();
  }

  @override
  Future<List<AgentRecurringTransactionSummary>> getRecurringTransactions(
    int ledgerId,
  ) async {
    final rows = await _repository.getEnabledRecurringTransactions(ledgerId);
    return rows
        .map(
          (row) => AgentRecurringTransactionSummary(
            type: row.type,
            amount: row.amount,
            frequency: row.frequency,
            interval: row.interval,
            note: row.note,
          ),
        )
        .toList();
  }

  @override
  Future<AgentRecordToolResult> recordTransaction({
    required int ledgerId,
    required String text,
  }) async {
    final result = await _bookkeeper.fromText(
      text: text,
      ledgerId: ledgerId,
      billingTypes: [TagSeedService.billingTypeAi],
    );
    return AgentRecordToolResult(
      success: result.success,
      transactionIds: result.transactionIds,
      bills: result.savedBills
          .map((bill) => Map<String, Object?>.from(bill.toJson()))
          .toList(),
    );
  }

  @override
  Future<void> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  }) =>
      _memoryRepository.saveExplicit(
        AgentMemoryDraft(
          ledgerId: ledgerId,
          kind: 'explicit',
          content: content,
        ),
      );

  @override
  Future<void> forgetMemory(int memoryId) => _memoryRepository.forget(memoryId);
}

/// Builds the P0 allowlisted tools for exactly one foreground ledger scope.
final class LocalAgentTools {
  LocalAgentTools({required this.scope, required this.gateway});

  static const _maximumRows = 20;
  static const _maximumCategories = 8;
  static const _maximumRecurringTransactions = 20;

  final AgentScope scope;
  final LocalAgentToolGateway gateway;
  final Map<String, AgentRecordToolResult> _recordResults = {};

  AgentRecordToolResult? recordResultFor(AgentToolCall call) =>
      _recordResults[call.id];

  Map<String, AgentTool> build() {
    final tools = <String, AgentTool>{
      'query_transactions': _CallbackTool(
        'query_transactions',
        _queryTransactions,
      ),
      'get_spending_summary': _CallbackTool(
        'get_spending_summary',
        _spendingSummary,
      ),
      'get_budget_status': _CallbackTool('get_budget_status', _budgetStatus),
      'get_income_expense_summary': _CallbackTool(
        'get_income_expense_summary',
        _incomeExpenseSummary,
      ),
      'get_category_spending': _CallbackTool(
        'get_category_spending',
        _categorySpending,
      ),
      'get_recurring_transactions': _CallbackTool(
        'get_recurring_transactions',
        _recurringTransactions,
      ),
      'record_transaction_from_text': _CallbackTool(
        'record_transaction_from_text',
        _recordTransaction,
      ),
      'save_explicit_memory': _CallbackTool(
        'save_explicit_memory',
        _saveMemory,
      ),
      'forget_memory': _CallbackTool('forget_memory', _forgetMemory),
    };
    return Map.unmodifiable(tools);
  }

  Future<Map<String, Object?>> _queryTransactions(AgentToolCall call) async {
    final range = _rangeFor(call);
    final transactions = await gateway.queryTransactions(
      ledgerId: _ledgerId,
      start: range.$1,
      end: range.$2,
    );
    final items = transactions
        .where((transaction) => transaction.ledgerId == _ledgerId)
        .take(_maximumRows)
        .map((transaction) => transaction.toToolData())
        .toList();
    return {'items': items};
  }

  Future<Map<String, Object?>> _spendingSummary(AgentToolCall call) async {
    final range = _rangeFor(call);
    final transactions = await gateway.queryTransactions(
      ledgerId: _ledgerId,
      start: range.$1,
      end: range.$2,
    );
    final spending = transactions
        .where((transaction) => transaction.ledgerId == _ledgerId)
        .where((transaction) => transaction.type == 'expense')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    return {
      'total': spending,
      'currency': 'ledger',
      'periodStart': range.$1.toIso8601String(),
      'periodEnd': range.$2.toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _budgetStatus(AgentToolCall call) async =>
      gateway
          .getBudgetStatus(_ledgerId)
          .then((summary) => summary.toToolData());

  Future<Map<String, Object?>> _incomeExpenseSummary(
    AgentToolCall call,
  ) async {
    final range = _rangeFor(call);
    final summary = await gateway.getIncomeExpenseSummary(
      ledgerId: _ledgerId,
      start: range.$1,
      end: range.$2,
    );
    return {
      ...summary.toToolData(),
      'currency': 'ledger',
      'periodStart': range.$1.toIso8601String(),
      'periodEnd': range.$2.toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _categorySpending(AgentToolCall call) async {
    final range = _rangeFor(call);
    final rows = await gateway.getCategorySpending(
      ledgerId: _ledgerId,
      start: range.$1,
      end: range.$2,
    );
    return {
      'items':
          rows.take(_maximumCategories).map((row) => row.toToolData()).toList(),
      'periodStart': range.$1.toIso8601String(),
      'periodEnd': range.$2.toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _recurringTransactions(
    AgentToolCall call,
  ) async {
    final rows = await gateway.getRecurringTransactions(_ledgerId);
    return {
      'items': rows
          .take(_maximumRecurringTransactions)
          .map((row) => row.toToolData())
          .toList(),
    };
  }

  Future<Map<String, Object?>> _recordTransaction(AgentToolCall call) async {
    final text = call.arguments['sourceText'];
    if (text is! String || text.isEmpty || scope.ledgerId == null) {
      return const {'success': false};
    }
    final result =
        await gateway.recordTransaction(ledgerId: _ledgerId, text: text);
    if (call.id.isNotEmpty) _recordResults[call.id] = result;
    return result.toToolData();
  }

  Future<Map<String, Object?>> _saveMemory(AgentToolCall call) async {
    final content = call.arguments['content'];
    if (content is! String || content.trim().isEmpty) {
      return const {'saved': false};
    }
    await gateway.saveExplicitMemory(
        ledgerId: scope.ledgerId, content: content.trim());
    return const {'saved': true};
  }

  Future<Map<String, Object?>> _forgetMemory(AgentToolCall call) async {
    final memoryId = call.arguments['memoryId'];
    if (memoryId is! int) return const {'forgotten': false};
    await gateway.forgetMemory(memoryId);
    return const {'forgotten': true};
  }

  int get _ledgerId => scope.ledgerId!;

  (DateTime, DateTime) _rangeFor(AgentToolCall call) {
    final now = DateTime.now();
    final start = DateTime.tryParse(call.arguments['start'] as String? ?? '') ??
        now.subtract(const Duration(days: 30));
    final end =
        DateTime.tryParse(call.arguments['end'] as String? ?? '') ?? now;
    return (start, end.isBefore(start) ? now : end);
  }
}

final class _CallbackTool implements AgentTool {
  const _CallbackTool(this.name, this._callback);

  @override
  final String name;
  final Future<Map<String, Object?>> Function(AgentToolCall) _callback;

  @override
  Future<Map<String, Object?>> execute(AgentToolCall call) => _callback(call);
}

String? _clip(String? value, int maximumLength) {
  if (value == null || value.length <= maximumLength) return value;
  return '${value.substring(0, maximumLength)}…';
}
