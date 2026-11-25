import '../../ai/core/bill_info.dart';
import '../../services/ai/chat_receipt_store.dart';
import '../../utils/app_localizations_resolver.dart';
import '../../l10n/app_localizations.dart';
import 'ledger_query_evidence.dart';
import 'package:agentcore/agentcore.dart'
    hide
        AgentMemoryDraft,
        AgentMemoryRecord,
        AgentMemoryRepository,
        AgentToolCallAudit;

import '../../data/db.dart'
    show Account, BeeDatabase, Category, Ledger, Tag, Transaction;
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../services/ai/ai_bookkeeper.dart';
import '../../services/data/tag_seed_service.dart';
import '../../utils/month_range.dart';
import '../memory/agent_memory_repository.dart';
import 'local_agent_tool_catalog.dart';
import 'local_agent_transaction_summary.dart';

final class AgentCategoryReference {
  const AgentCategoryReference({
    required this.id,
    required this.name,
    this.icon,
  });

  final int id;
  final String name;
  final String? icon;

  Map<String, Object?> toToolData() => {
        'id': id,
        'name': name,
        if (icon != null && icon!.trim().isNotEmpty) 'icon': icon,
      };
}

final class AgentAccountReference {
  const AgentAccountReference({
    required this.id,
    required this.name,
    required this.currency,
  });

  final int id;
  final String name;
  final String currency;

  Map<String, Object?> toToolData() => {
        'id': id,
        'name': name,
        'currency': currency,
      };
}

final class AgentTagReference {
  const AgentTagReference({required this.id, required this.name});

  final int id;
  final String name;

  Map<String, Object?> toToolData() => {'id': id, 'name': name};
}

final class AgentTransactionSummary {
  const AgentTransactionSummary({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    required this.happenedAt,
    required this.note,
    this.ledgerAmount,
    this.currency = 'CNY',
    this.ledgerCurrency = 'CNY',
    this.category,
    this.account,
    this.toAccount,
    this.tags = const [],
    this.excludeFromStats = false,
    this.excludeFromBudget = false,
  });

  final int id;
  final int ledgerId;
  final String type;
  final double amount;
  final DateTime happenedAt;
  final String? note;
  final double? ledgerAmount;
  final String currency;
  final String ledgerCurrency;
  final AgentCategoryReference? category;
  final AgentAccountReference? account;
  final AgentAccountReference? toAccount;
  final List<AgentTagReference> tags;
  final bool excludeFromStats;
  final bool excludeFromBudget;

  Map<String, Object?> toToolData() => {
        'id': id,
        'ledgerId': ledgerId,
        'type': type,
        'amount': amount,
        'ledgerAmount': ledgerAmount ?? amount,
        'currency': currency,
        'ledgerCurrency': ledgerCurrency,
        'category': category?.toToolData(),
        'account': account?.toToolData(),
        'toAccount': toAccount?.toToolData(),
        'tags': tags.map((tag) => tag.toToolData()).toList(),
        'excludeFromStats': excludeFromStats,
        'excludeFromBudget': excludeFromBudget,
        'happenedAt': happenedAt.toIso8601String(),
        'note': _clip(note, 160),
      };
}

final class AgentBudgetUsageSummary {
  const AgentBudgetUsageSummary({
    required this.used,
    required this.budget,
    required this.remaining,
    required this.rate,
    required this.status,
  });

  final double used;
  final double budget;
  final double remaining;
  final double rate;
  final String status;

  Map<String, Object?> toToolData() => {
        'used': used,
        'budget': budget,
        'remaining': remaining,
        'rate': rate,
        'status': status,
      };
}

final class AgentCategoryBudgetSummary {
  const AgentCategoryBudgetSummary({
    required this.budgetId,
    required this.category,
    required this.usage,
  });

  final int budgetId;
  final AgentCategoryReference category;
  final AgentBudgetUsageSummary usage;

  Map<String, Object?> toToolData() => {
        'budgetId': budgetId,
        'category': category.toToolData(),
        'usage': usage.toToolData(),
      };
}

final class AgentBudgetSummary {
  const AgentBudgetSummary({
    required this.daysRemaining,
    required this.dailyAvailable,
    this.currency = 'CNY',
    this.total,
    this.categoryBudgets = const [],
  });

  final int daysRemaining;
  final double dailyAvailable;
  final String currency;
  final AgentBudgetUsageSummary? total;
  final List<AgentCategoryBudgetSummary> categoryBudgets;

  Map<String, Object?> toToolData() => {
        'currency': currency,
        'daysRemaining': daysRemaining,
        'dailyAvailable': dailyAvailable,
        'total': total?.toToolData(),
        'categoryBudgets': categoryBudgets
            .map((categoryBudget) => categoryBudget.toToolData())
            .toList(),
      };
}

final class AgentRecurringTransactionSummary {
  const AgentRecurringTransactionSummary({
    required this.type,
    required this.amount,
    required this.frequency,
    required this.interval,
    this.id,
    this.currency = 'CNY',
    this.category,
    this.account,
    this.toAccount,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    this.startDate,
    this.endDate,
    this.lastGeneratedDate,
    this.note,
  });

  final int? id;
  final String type;
  final double amount;
  final String currency;
  final AgentCategoryReference? category;
  final AgentAccountReference? account;
  final AgentAccountReference? toAccount;
  final String frequency;
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? lastGeneratedDate;
  final String? note;

  Map<String, Object?> toToolData() => {
        'id': id,
        'type': type,
        'amount': amount,
        'currency': currency,
        'category': category?.toToolData(),
        'account': account?.toToolData(),
        'toAccount': toAccount?.toToolData(),
        'frequency': frequency,
        'interval': interval,
        'dayOfMonth': dayOfMonth,
        'dayOfWeek': dayOfWeek,
        'monthOfYear': monthOfYear,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
        'note': note == null || note!.trim().isEmpty ? null : _clip(note, 120),
      };
}

final class AgentRecordToolResult {
  const AgentRecordToolResult({
    required this.success,
    this.transactionIds = const [],
    this.bills = const [],
    this.transactions = const [],
    this.unconvertedCurrencies = const [],
    this.receiptMessageId,
    this.unavailableIds = const [],
    this.failedCount = 0,
  });

  final int? receiptMessageId;
  final List<int> unavailableIds;
  final int failedCount;
  final bool success;
  final List<int> transactionIds;

  /// UI 卡片继续使用已保存的 BillInfo 快照，模型只接收 [transactions] 的
  /// 最终落库数据，避免把 AI 解析阶段的猜测当成事实。
  final List<Map<String, Object?>> bills;
  final List<AgentTransactionSummary> transactions;
  final List<String> unconvertedCurrencies;

  Map<String, Object?> toToolData() => {
        'success': success,
        if (failedCount > 0) 'failedCount': failedCount,
        if (unavailableIds.isNotEmpty) 'noLongerInLedger': unavailableIds,
        'transactionIds': transactionIds,
        'transactions': transactions
            .map((transaction) => transaction.toToolData())
            .toList(),
        'unconvertedCurrencies': unconvertedCurrencies,
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
  Future<Map<String, Object?>> summarizeTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    required Set<String> types,
    required String groupBy,
    required String categoryLevel,
    required List<int> categoryIds,
    required List<String> categoryNames,
    required List<int> tagIds,
    required List<String> tagNames,
    required List<int> accountIds,
    required List<String> accountNames,
    required bool includeExcludedFromStats,
    required int groupLimit,
    Map<String, Object?> filters = const {},
  });
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId, {DateTime? at});
  Future<String> getLedgerCurrency(int ledgerId);
  Future<int> getLedgerMonthStartDay(int ledgerId);
  Future<List<AgentRecurringTransactionSummary>> getRecurringTransactions(
    int ledgerId,
  );
  Future<AgentRecordToolResult> recordTransaction({
    required int ledgerId,
    required String text,
    int? sourceMessageId,
    BillInfo? entry,
    AppLocalizations? l10n,
  });
  Future<int> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  });
  Future<bool> forgetMemory({
    required int ledgerId,
    required int memoryId,
  });
}

/// Production local gateway. It uses the same [AiBookkeeper] path as the
/// legacy chat, preserving bills, undo metadata, statistics refresh and sync.
final class BeeCountLocalAgentToolGateway implements LocalAgentToolGateway {
  BeeCountLocalAgentToolGateway({
    required BaseRepository repository,
    required BeeDatabase database,
    required AiBookkeeper bookkeeper,
    required AgentMemoryRepository memoryRepository,
  })  : _repository = repository,
        _database = database,
        _summaryDataSource = LocalAgentTransactionSummaryDataSource(database),
        _bookkeeper = bookkeeper,
        _memoryRepository = memoryRepository;

  final BeeDatabase _database;
  final BaseRepository _repository;
  final LocalAgentTransactionSummaryDataSource _summaryDataSource;
  final AiBookkeeper _bookkeeper;
  final AgentMemoryRepository _memoryRepository;

  @override
  Future<List<AgentTransactionSummary>> queryTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    final ledgerFuture = _repository.getLedgerById(ledgerId);
    final transactions = await _repository.getTransactionsWithCategoryInRange(
      ledgerId: ledgerId,
      start: start,
      end: end,
    );
    return _summarizeTransactions(transactions, ledger: await ledgerFuture);
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
    required List<String> categoryNames,
    required List<int> tagIds,
    required List<String> tagNames,
    required List<int> accountIds,
    required List<String> accountNames,
    required bool includeExcludedFromStats,
    required int groupLimit,
    Map<String, Object?> filters = const {},
  }) {
    Future<Map<String, Object?>> read() async {
      final result = await _summaryDataSource.summarizeTransactions(
        ledgerId: ledgerId,
        start: start,
        end: end,
        types: types,
        groupBy: groupBy,
        categoryLevel: categoryLevel,
        categoryIds: categoryIds,
        categoryNames: categoryNames,
        tagIds: tagIds,
        tagNames: tagNames,
        accountIds: accountIds,
        accountNames: accountNames,
        includeExcludedFromStats: includeExcludedFromStats,
        groupLimit: groupLimit,
        filters: filters,
      );
      if (groupBy == 'details' && !result.containsKey('error')) {
        final ids = (result.remove('pageIds') as List).cast<int>();
        final rows = await _summarizeTransactionsByIds(ledgerId, ids);
        result['items'] = rows.map((row) => row.toToolData()).toList();
      }
      return result;
    }

    return _database.transaction(read);
  }

  @override
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId,
      {DateTime? at}) async {
    final overview =
        await _repository.getBudgetOverview(ledgerId, at ?? DateTime.now());
    final ledger = await _repository.getLedgerById(ledgerId);
    final total = overview.totalBudget;
    return AgentBudgetSummary(
      daysRemaining: overview.daysRemaining,
      dailyAvailable: overview.dailyAvailable,
      currency: _ledgerCurrency(ledger),
      total: total == null ? null : _budgetUsage(total),
      categoryBudgets: overview.categoryBudgets
          .map(
            (categoryBudget) => AgentCategoryBudgetSummary(
              budgetId: categoryBudget.budgetId,
              category: AgentCategoryReference(
                id: categoryBudget.categoryId,
                name: categoryBudget.categoryName,
                icon: categoryBudget.categoryIcon,
              ),
              usage: _budgetUsage(categoryBudget.usage),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<String> getLedgerCurrency(int ledgerId) async =>
      _ledgerCurrency(await _repository.getLedgerById(ledgerId));

  @override
  Future<int> getLedgerMonthStartDay(int ledgerId) async =>
      ((await _repository.getLedgerById(ledgerId))?.monthStartDay ?? 1)
          .clamp(1, 28);

  @override
  Future<List<AgentRecurringTransactionSummary>> getRecurringTransactions(
    int ledgerId,
  ) async {
    final ledgerFuture = _repository.getLedgerById(ledgerId);
    final categoriesFuture = _repository.getAllCategoriesIncludingShared();
    final rows = await _repository.getEnabledRecurringTransactions(ledgerId);
    final accountIds = {
      for (final row in rows) ...[
        if (row.accountId != null) row.accountId!,
        if (row.toAccountId != null) row.toAccountId!,
      ],
    };
    final accountsFuture = _repository.getAccountsByIds(accountIds.toList());
    final ledgerCurrency = _ledgerCurrency(await ledgerFuture);
    final categoriesById = {
      for (final category in await categoriesFuture) category.id: category,
    };
    final accountsById = {
      for (final account in await accountsFuture) account.id: account,
    };
    return rows.map(
      (row) {
        final account =
            row.accountId == null ? null : accountsById[row.accountId!];
        return AgentRecurringTransactionSummary(
          id: row.id,
          type: row.type,
          amount: row.amount,
          currency: _currencyOr(
            row.currencyCode,
            fallback: account?.currency ?? ledgerCurrency,
          ),
          category: _categoryReference(
            row.categoryId == null ? null : categoriesById[row.categoryId!],
          ),
          account: _accountReference(account, fallbackCurrency: ledgerCurrency),
          toAccount: _accountReference(
            row.toAccountId == null ? null : accountsById[row.toAccountId!],
            fallbackCurrency: ledgerCurrency,
          ),
          frequency: row.frequency,
          interval: row.interval,
          dayOfMonth: row.dayOfMonth,
          dayOfWeek: row.dayOfWeek,
          monthOfYear: row.monthOfYear,
          startDate: row.startDate,
          endDate: row.endDate,
          lastGeneratedDate: row.lastGeneratedDate,
          note: row.note,
        );
      },
    ).toList();
  }

  @override
  Future<AgentRecordToolResult> recordTransaction({
    required int ledgerId,
    required String text,
    int? sourceMessageId,
    BillInfo? entry,
    AppLocalizations? l10n,
  }) async {
    final store = ChatReceiptStore(_database);
    Future<AgentRecordToolResult> restore(Map receipt) async {
      final ids = (receipt['txIds'] as List).cast<int>();
      final transactions = await _summarizeTransactionsByIds(ledgerId, ids);
      final present = transactions.map((row) => row.id).toSet();
      return AgentRecordToolResult(
          success: ids.isNotEmpty,
          transactionIds: ids,
          unavailableIds: ids.where((id) => !present.contains(id)).toList(),
          bills: [
            for (final b in receipt['bills'] as List)
              Map<String, Object?>.from(b as Map)
          ],
          transactions: transactions,
          receiptMessageId: receipt['replyId'] as int?,
          failedCount: receipt['failedCount'] as int? ?? 0,
          unconvertedCurrencies:
              (receipt['unconvertedCurrencies'] as List?)?.cast<String>() ??
                  []);
    }

    if (sourceMessageId != null) {
      final original = await store.source(sourceMessageId, ledgerId, text);
      if (original.metadata['agentReceipt'] case final Map receipt) {
        return restore(receipt);
      }
    }
    final bills = await _bookkeeper.extractTextBills(
        text: text, ledgerId: ledgerId, entry: entry);
    return _database.transaction(() async {
      // Acquire the SQLite writer before rechecking the operation across connections.
      if (sourceMessageId != null) {
        await _database.customStatement(
            'UPDATE messages SET id=id WHERE id=?', [sourceMessageId]);
      }
      final original = sourceMessageId == null
          ? null
          : await store.source(sourceMessageId, ledgerId, text);
      if (original?.metadata['agentReceipt'] case final Map receipt) {
        return restore(receipt);
      }
      final result = await _bookkeeper.persistBills(
          bills: bills,
          ledgerId: ledgerId,
          billingTypes: [TagSeedService.billingTypeAi],
          l10n: l10n,
          atomicBill: (save) => _database.transaction(save));
      if (original != null && result.success) {
        return restore(await store.save(original.source, original.metadata,
            result, ledgerId, l10n ?? resolveAppLocalizations(null)));
      }
      return AgentRecordToolResult(
          success: result.success,
          transactionIds: result.transactionIds,
          bills: result.savedBills.map((b) => b.toJson()).toList(),
          transactions: await _summarizeTransactionsByIds(
              ledgerId, result.transactionIds),
          failedCount: result.failedCount,
          unconvertedCurrencies: result.unconvertedCurrencies);
    });
  }

  Future<List<AgentTransactionSummary>> _summarizeTransactionsByIds(
    int ledgerId,
    List<int> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return const [];
    final ledgerFuture = _repository.getLedgerById(ledgerId);
    final rows = await _repository.getTransactionsWithCategoryByIds(
      ledgerId: ledgerId,
      transactionIds: transactionIds,
    );
    final summaries =
        await _summarizeTransactions(rows, ledger: await ledgerFuture);
    final summaryById = {for (final summary in summaries) summary.id: summary};
    return [
      for (final transactionId in transactionIds)
        if (summaryById[transactionId] case final summary?) summary,
    ];
  }

  Future<List<AgentTransactionSummary>> _summarizeTransactions(
    List<
            ({
              Transaction t,
              Category? category,
              Account? account,
              Account? toAccount,
            })>
        rows, {
    required Ledger? ledger,
  }) async {
    final tagsByTransaction = await _repository.getTagsForTransactions(
      rows.map((row) => row.t.id).toList(),
    );
    final ledgerCurrency = _ledgerCurrency(ledger);
    return rows
        .map(
          (row) => _agentTransactionSummary(
            transaction: row.t,
            category: row.category,
            account: row.account,
            toAccount: row.toAccount,
            tags: tagsByTransaction[row.t.id] ?? const [],
            ledgerCurrency: ledgerCurrency,
          ),
        )
        .toList();
  }

  @override
  Future<int> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  }) =>
      _memoryRepository
          .saveExplicit(
            AgentMemoryDraft(
              ledgerId: ledgerId,
              kind: 'explicit',
              content: content,
            ),
          )
          .then((memory) => memory.id);

  @override
  Future<bool> forgetMemory({
    required int ledgerId,
    required int memoryId,
  }) =>
      _memoryRepository.forget(memoryId, ledgerId: ledgerId);
}

String _ledgerCurrency(Ledger? ledger) {
  final currency = ledger?.currency.trim().toUpperCase();
  return currency == null || currency.isEmpty ? 'CNY' : currency;
}

AgentBudgetUsageSummary _budgetUsage(BudgetUsage usage) =>
    AgentBudgetUsageSummary(
      used: usage.used,
      budget: usage.budget,
      remaining: usage.remaining,
      rate: usage.rate,
      status: usage.status,
    );

AgentTransactionSummary _agentTransactionSummary({
  required Transaction transaction,
  required Category? category,
  required Account? account,
  required Account? toAccount,
  required List<Tag> tags,
  required String ledgerCurrency,
}) {
  final currency = _currencyOr(
    transaction.currencyCode,
    fallback: account?.currency ?? ledgerCurrency,
  );
  final tagReferences = tags
      .map((tag) => AgentTagReference(id: tag.id, name: tag.name))
      .toList()
    ..sort((left, right) => left.name.compareTo(right.name));
  return AgentTransactionSummary(
    id: transaction.id,
    ledgerId: transaction.ledgerId,
    type: transaction.type,
    amount: transaction.amount,
    ledgerAmount: transaction.nativeAmount ?? transaction.amount,
    currency: currency,
    ledgerCurrency: ledgerCurrency,
    category: category == null
        ? null
        : AgentCategoryReference(
            id: category.id,
            name: category.name,
            icon: category.icon,
          ),
    account: _accountReference(account, fallbackCurrency: ledgerCurrency),
    toAccount: _accountReference(toAccount, fallbackCurrency: ledgerCurrency),
    tags: tagReferences,
    excludeFromStats: transaction.excludeFromStats,
    excludeFromBudget: transaction.excludeFromBudget,
    happenedAt: transaction.happenedAt,
    note: transaction.note,
  );
}

AgentAccountReference? _accountReference(
  Account? account, {
  required String fallbackCurrency,
}) =>
    account == null
        ? null
        : AgentAccountReference(
            id: account.id,
            name: account.name,
            currency: _currencyOr(account.currency, fallback: fallbackCurrency),
          );

AgentCategoryReference? _categoryReference(Category? category) =>
    category == null
        ? null
        : AgentCategoryReference(
            id: category.id,
            name: category.name,
            icon: category.icon,
          );

String _currencyOr(String? value, {required String fallback}) {
  final normalized = value?.trim().toUpperCase();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}

/// Builds the P0 allowlisted tools for exactly one foreground ledger scope.
final class LocalAgentTools {
  LocalAgentTools({
    required this.scope,
    required this.gateway,
    DateTime Function()? now,
    this.sourceMessageId,
    this.l10n,
    List<Map<String, Object?>> previous = const [],
    Map<String, Object?> view = const {},
  })  : evidence = LedgerQueryEvidence(scope, previous: previous, view: view),
        _now = now ?? DateTime.now;
  final LedgerQueryEvidence evidence;
  final int? sourceMessageId;
  final AppLocalizations? l10n;
  AgentRecordToolResult? savedRecord;

  static const _maximumRows = 20;
  static const _maximumRecurringTransactions = 20;

  final AgentScope scope;
  final LocalAgentToolGateway gateway;
  final DateTime Function() _now;
  final Map<String, AgentRecordToolResult> _recordResults = {};

  AgentRecordToolResult? recordResultFor(AgentToolCall call) =>
      _recordResults[call.id];

  Map<String, AgentTool> build() {
    final tools = <String, AgentTool>{
      'query_transactions': _CallbackTool(
        'query_transactions',
        (call) => evidence.execute(call, _queryTransactions),
      ),
      'get_period_overview': _CallbackTool(
        'get_period_overview',
        (call) => evidence.execute(call, _periodOverview),
      ),
      'get_spending_trend': _CallbackTool(
        'get_spending_trend',
        (call) => evidence.execute(call, _spendingTrend),
      ),
      'get_category_breakdown': _CallbackTool(
        'get_category_breakdown',
        (call) => evidence.execute(call, _categoryBreakdown),
      ),
      'get_budget_status': _CallbackTool('get_budget_status', _budgetStatus),
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

  AgentToolRegistry buildRegistry() {
    final tools = build();
    AgentToolDescriptor descriptor(
      String name, {
      bool resident = false,
      List<String> terms = const [],
      bool singleUse = false,
      bool deduplicate = false,
      AgentToolQueryMatcher? matcher,
    }) =>
        AgentToolDescriptor(
          definition: LocalAgentToolCatalog.definition(name),
          tool: tools[name]!,
          isResident: resident,
          selectionTerms: terms,
          singleUse: singleUse,
          deduplicate: deduplicate,
          selectionMatcher: matcher,
        );

    return AgentToolRegistry([
      descriptor(
        'record_transaction_from_text',
        resident: true,
        terms: const [
          '记一笔',
          '记账',
          '买了',
          '花了',
          '消费',
          '工资到账',
          '收入了',
          '支出了',
          'record',
        ],
        singleUse: true,
        matcher: _looksLikeTransactionEntry,
      ),
      descriptor(
        'query_transactions',
        resident: true,
        terms: const ['最近几笔', '明细', '交易记录', '账单', '哪几笔', 'details'],
      ),
      descriptor(
        'get_period_overview',
        resident: true,
        terms: const [
          '花了多少',
          '支出多少',
          '收入多少',
          '结余',
          '收支',
          '总支出',
          '总收入',
          '合计',
          '本月',
          '上月',
          '这个月',
          '今年',
          '去年',
          'overview',
        ],
        deduplicate: true,
      ),
      descriptor(
        'get_spending_trend',
        resident: true,
        terms: const [
          '趋势',
          '各月',
          '各个月',
          '按月',
          '每月',
          '逐月',
          '环比',
          '同比',
          '月度对比',
          'trend',
          'month by month',
        ],
        deduplicate: true,
      ),
      descriptor(
        'get_category_breakdown',
        resident: true,
        terms: const [
          '分类占比',
          '支出构成',
          '分类排行',
          '哪类最多',
          '分类对比',
          '明细分类',
          'breakdown',
        ],
        deduplicate: true,
        matcher: _looksLikeCategoryBreakdown,
      ),
      descriptor(
        'get_budget_status',
        terms: const ['预算', '额度', '还能花', 'budget'],
        deduplicate: true,
      ),
      descriptor(
        'get_recurring_transactions',
        terms: const ['周期', '定期', '订阅', '自动记账', 'recurring', 'subscription'],
        deduplicate: true,
      ),
      descriptor(
        'save_explicit_memory',
        terms: const ['记住', '记下来', '保存记忆', 'remember', 'memorize'],
        singleUse: true,
      ),
      descriptor(
        'forget_memory',
        terms: const ['忘记', '忘掉', '删除记忆', '清除记忆', 'forget memory'],
        singleUse: true,
      ),
    ]);
  }

  Future<Map<String, Object?>> _queryTransactions(AgentToolCall call) async {
    final range = call.arguments.containsKey('period')
        ? await _financialRangeFor(call, defaultPeriod: 'current_month')
        : _rangeFor(call);
    final rawFlow = call.arguments['flowType'];
    return _summary(call,
        range: range,
        types:
            rawFlow is String ? {rawFlow} : {'expense', 'income', 'transfer'},
        groupBy: 'details',
        categoryLevel: 'leaf',
        groupLimit: _boundedIntArgument(call, 'limit', fallback: _maximumRows)
            .clamp(1, _maximumRows),
        includeExcluded: true);
  }

  Future<Map<String, Object?>> _periodOverview(AgentToolCall call) async {
    final range =
        await _financialRangeFor(call, defaultPeriod: 'current_month');
    final rawFlow = call.arguments['flowType'];
    final summary = await _summary(call,
        range: range,
        types:
            rawFlow is String ? {rawFlow} : {'income', 'expense', 'transfer'},
        groupBy: 'none',
        categoryLevel: 'leaf',
        groupLimit: 1);
    final totals = summary['totals'] as Map<String, Object?>? ?? const {};
    final income = _summaryAmount(totals, 'income');
    final expense = _summaryAmount(totals, 'expense');
    final transactionCount = const ['income', 'expense', 'transfer']
        .fold<int>(0, (sum, type) => sum + _summaryCount(totals, type));
    final balance = income - expense;
    return {
      'currency': summary['currency'],
      for (final k in [
        'matchStatus',
        'matchedCategories',
        'requestedName',
        'candidates'
      ])
        if (summary.containsKey(k)) k: summary[k],
      'period': call.arguments['period'] ?? 'current_month',
      'periodStart': summary['periodStart'],
      'periodEnd': summary['periodEnd'],
      'income': income,
      'expense': expense,
      'balance': balance,
      'savingsRate': income == 0 ? null : balance / income,
      'transactionCount': transactionCount,
      'incomeCount': _summaryCount(totals, 'income'),
      'expenseCount': _summaryCount(totals, 'expense'),
      'transferCount': _summaryCount(totals, 'transfer'),
    };
  }

  Future<Map<String, Object?>> _spendingTrend(AgentToolCall call) async {
    final range = await _financialRangeFor(call, defaultPeriod: 'current_year');
    final interval = _trendIntervalFor(call);
    final flowType = _flowTypeFor(call);
    final summary = await _flowSummary(
      call,
      range: range,
      groupBy: interval,
      flowType: flowType,
      groupLimit: 50,
    );
    final comparison = switch (call.arguments['comparison']) {
      'none' => 'none',
      'previous_year' => 'previous_year',
      _ => 'previous_point',
    };
    Map<String, Map<String, Object?>> previousYearGroups = const {};
    if (comparison == 'previous_year') {
      final previous = await _flowSummary(
        call,
        range: (_shiftYear(range.$1, -1), _shiftYear(range.$2, -1)),
        groupBy: interval,
        flowType: flowType,
        groupLimit: 50,
      );
      previousYearGroups = _groupsByPeriod(previous);
    }
    final rawGroups = (summary['groups'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .where((item) => _periodValue(item) != null)
        .toList();
    final points = <Map<String, Object?>>[];
    for (var index = 0; index < rawGroups.length; index++) {
      final item = rawGroups[index];
      final period = _periodValue(item)!;
      final amount = _groupAmount(item, flowType);
      final count = _groupCount(item, flowType);
      double? comparedAmount;
      if (comparison == 'previous_point' && index > 0) {
        comparedAmount = _groupAmount(rawGroups[index - 1], flowType);
      } else if (comparison == 'previous_year') {
        final previousKey = _previousYearPeriod(period, interval);
        final previous =
            previousKey == null ? null : previousYearGroups[previousKey];
        if (previous != null) {
          comparedAmount = _groupAmount(previous, flowType);
        }
      }
      final change = comparedAmount == null ? null : amount - comparedAmount;
      points.add({
        'period': period,
        'amount': amount,
        'count': count,
        'comparedAmount': comparedAmount,
        'changeAmount': change,
        'changeRate': comparedAmount == null || comparedAmount == 0
            ? null
            : change! / comparedAmount,
      });
    }
    return {
      'currency': summary['currency'],
      for (final k in [
        'matchStatus',
        'matchedCategories',
        'requestedName',
        'candidates'
      ])
        if (summary.containsKey(k)) k: summary[k],
      'flowType': flowType,
      'period': call.arguments['period'] ?? 'current_year',
      'periodStart': summary['periodStart'],
      'periodEnd': summary['periodEnd'],
      'interval': interval,
      'transactionCount': _summaryCount(
          summary['totals'] as Map<String, Object?>? ?? const {}, flowType),
      'categoryNames': _stringListArgument(call, 'categoryNames'),
      'comparison': comparison,
      if (flowType == 'income')
        'totalIncome': _summaryAmount(
          summary['totals'] as Map<String, Object?>? ?? const {},
          'income',
        )
      else
        'totalExpense': _summaryAmount(
          summary['totals'] as Map<String, Object?>? ?? const {},
          'expense',
        ),
      'points': points,
      'truncated': summary['truncated'] == true,
    };
  }

  Future<Map<String, Object?>> _categoryBreakdown(
    AgentToolCall call,
  ) async {
    final range =
        await _financialRangeFor(call, defaultPeriod: 'current_month');
    final flowType = _flowTypeFor(call);
    final summary = await _flowSummary(
      call,
      range: range,
      groupBy: 'category',
      flowType: flowType,
      categoryLevel: call.arguments['categoryLevel'] == 'leaf' ? 'leaf' : 'top',
      groupLimit: _boundedIntArgument(call, 'limit', fallback: 20),
    );
    final total = _summaryAmount(
      summary['totals'] as Map<String, Object?>? ?? const {},
      flowType,
    );
    final items = <Map<String, Object?>>[];
    for (final raw
        in (summary['groups'] as List? ?? const []).whereType<Map>()) {
      final group = Map<String, Object?>.from(raw);
      final amount = _groupAmount(group, flowType);
      items.add({
        'category': group['key'],
        'amount': amount,
        'count': _groupCount(group, flowType),
        'share': total == 0 ? null : amount / total,
      });
    }
    return {
      'currency': summary['currency'],
      for (final k in [
        'matchStatus',
        'matchedCategories',
        'requestedName',
        'candidates'
      ])
        if (summary.containsKey(k)) k: summary[k],
      'flowType': flowType,
      'period': call.arguments['period'] ?? 'current_month',
      'periodStart': summary['periodStart'],
      'periodEnd': summary['periodEnd'],
      'categoryLevel':
          call.arguments['categoryLevel'] == 'leaf' ? 'leaf' : 'top',
      'categoryNames': _stringListArgument(call, 'categoryNames'),
      if (flowType == 'income') 'totalIncome': total else 'totalExpense': total,
      'items': items,
      'truncated': summary['truncated'] == true,
    };
  }

  /// 用户未显式指定资金方向时默认统计支出（与历史行为一致）。
  String _flowTypeFor(AgentToolCall call) =>
      call.arguments['flowType'] == 'income' ? 'income' : 'expense';

  Future<Map<String, Object?>> _flowSummary(
    AgentToolCall call, {
    required (DateTime, DateTime) range,
    required String groupBy,
    required String flowType,
    String categoryLevel = 'leaf',
    required int groupLimit,
  }) =>
      _summary(call,
          range: range,
          types: {flowType},
          groupBy: groupBy,
          categoryLevel: categoryLevel,
          groupLimit: groupLimit);

  Future<Map<String, Object?>> _summary(AgentToolCall call,
      {required (DateTime, DateTime) range,
      required Set<String> types,
      required String groupBy,
      required String categoryLevel,
      required int groupLimit,
      bool includeExcluded = false}) {
    List<int> ids(String key) =>
        (call.arguments[key] as List?)?.whereType<int>().toSet().toList() ?? [];
    return gateway.summarizeTransactions(
        ledgerId: _ledgerId,
        start: range.$1,
        end: range.$2,
        types: types,
        groupBy: groupBy,
        categoryLevel: categoryLevel,
        groupLimit: groupLimit,
        categoryNames: _stringListArgument(call, 'categoryNames'),
        categoryIds: ids('categoryIds'),
        accountNames: _stringListArgument(call, 'accountNames'),
        accountIds: ids('accountIds'),
        tagNames: _stringListArgument(call, 'tagNames'),
        tagIds: ids('tagIds'),
        includeExcludedFromStats:
            call.arguments['includeExcludedFromStats'] as bool? ??
                includeExcluded,
        filters: call.arguments);
  }

  Future<Map<String, Object?>> _budgetStatus(AgentToolCall call) async {
    final today = _now();
    final view = evidence.view;
    final viewEnd = view['ledgerId'] == _ledgerId
        ? DateTime.tryParse(view['end']?.toString() ?? '')
        : null;
    final defaultDate = viewEnd != null && !viewEnd.isAfter(today)
        ? viewEnd.subtract(const Duration(microseconds: 1))
        : today;
    final date = call.arguments['at'] == null
        ? defaultDate
        : DateTime.tryParse(call.arguments['at'].toString());
    if (date == null) return {'error': 'invalid_date', 'retryable': true};
    return {
      ...(await gateway.getBudgetStatus(_ledgerId, at: date)).toToolData(),
      'asOf': date.toIso8601String(),
      if (l10n case final labels?)
        'settingsPath': [
          labels.ledgersTitle,
          labels.commonMore,
          labels.budgetManagement
        ],
    };
  }

  Future<Map<String, Object?>> _recurringTransactions(
    AgentToolCall call,
  ) async {
    final rows = await gateway.getRecurringTransactions(_ledgerId);
    return {
      'totalCount': rows.length,
      if (l10n case final labels?)
        'settingsPath': [
          labels.tabMine,
          labels.automation,
          labels.mineRecurringTransactions
        ],
      'truncated': rows.length > _maximumRecurringTransactions,
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
    BillInfo? entry;
    if (call.arguments['entry'] case final Map draft) {
      final bill = BillInfo.fromJson(Map<String, dynamic>.from(draft));
      final amount = bill.amount?.abs();
      final numbers = RegExp(r'(?<![\d.])\d+(?:\.\d+)?(?![\d.])')
          .allMatches(text.replaceAll(',', ''))
          .map((match) => double.parse(match.group(0)!))
          .toList();
      if (amount != null &&
          amount.isFinite &&
          amount > 0 &&
          numbers.length == 1 &&
          numbers.single == amount &&
          (bill.type == BillType.expense || bill.type == BillType.income)) {
        entry = bill;
      }
    }
    final result = await gateway.recordTransaction(
        ledgerId: _ledgerId,
        text: text,
        sourceMessageId: sourceMessageId,
        entry: entry,
        l10n: l10n);
    if (result.success) savedRecord = result;
    if (call.id.isNotEmpty) _recordResults[call.id] = result;
    return result.toToolData();
  }

  Future<Map<String, Object?>> _saveMemory(AgentToolCall call) async {
    final content = call.arguments['content'];
    if (content is! String || content.trim().isEmpty) {
      return const {'saved': false};
    }
    final memoryId = await gateway.saveExplicitMemory(
        ledgerId: scope.ledgerId, content: content.trim());
    return {'saved': true, 'memoryId': memoryId};
  }

  Future<Map<String, Object?>> _forgetMemory(AgentToolCall call) async {
    final memoryId = call.arguments['memoryId'];
    if (memoryId is! int) return const {'forgotten': false};
    final forgotten = await gateway.forgetMemory(
      ledgerId: _ledgerId,
      memoryId: memoryId,
    );
    return {'forgotten': forgotten};
  }

  int get _ledgerId => scope.ledgerId!;

  (DateTime, DateTime) _rangeFor(AgentToolCall call) {
    final now = _now();
    final start = DateTime.tryParse(call.arguments['start'] as String? ?? '') ??
        now.subtract(const Duration(days: 30));
    final end =
        DateTime.tryParse(call.arguments['end'] as String? ?? '') ?? now;
    return (start, end.isBefore(start) ? now : end);
  }

  List<String> _stringListArgument(AgentToolCall call, String key) {
    final raw = call.arguments[key];
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<(DateTime, DateTime)> _financialRangeFor(
    AgentToolCall call, {
    required String defaultPeriod,
  }) async {
    final now = _now();
    final monthStartDay = await gateway.getLedgerMonthStartDay(_ledgerId);
    final rawPeriod = call.arguments['period'];
    final period = rawPeriod is String ? rawPeriod : defaultPeriod;
    if (period == 'custom') {
      final start = DateTime.tryParse(call.arguments['start'] as String? ?? '');
      final end = DateTime.tryParse(call.arguments['end'] as String? ?? '');
      if (start != null && end != null && end.isAfter(start)) {
        return (start, end);
      }
    }
    final currentLabel = labelForDate(now, monthStartDay);
    return switch (period) {
      'previous_month' => _periodTuple(
          periodForLabel(
            currentLabel.year,
            currentLabel.month - 1,
            monthStartDay,
          ),
        ),
      'current_year' =>
        _periodTuple(yearRangeFor(currentLabel.year, monthStartDay)),
      'previous_year' =>
        _periodTuple(yearRangeFor(currentLabel.year - 1, monthStartDay)),
      'last_30_days' => (now.subtract(const Duration(days: 30)), now),
      'last_90_days' => (now.subtract(const Duration(days: 90)), now),
      'last_3_months' => _rollingMonthRange(
          currentLabel,
          monthStartDay: monthStartDay,
          months: 3,
        ),
      'last_6_months' => _rollingMonthRange(
          currentLabel,
          monthStartDay: monthStartDay,
          months: 6,
        ),
      'last_12_months' => _rollingMonthRange(
          currentLabel,
          monthStartDay: monthStartDay,
          months: 12,
        ),
      _ => _periodTuple(
          periodForLabel(
            currentLabel.year,
            currentLabel.month,
            monthStartDay,
          ),
        ),
    };
  }

  String _trendIntervalFor(AgentToolCall call) {
    const supported = {'day', 'week', 'month', 'year'};
    final raw = call.arguments['interval'];
    return raw is String && supported.contains(raw) ? raw : 'month';
  }

  int _boundedIntArgument(
    AgentToolCall call,
    String key, {
    required int fallback,
  }) {
    final raw = call.arguments[key];
    return raw is int ? raw.clamp(1, 50) : fallback;
  }
}

(DateTime, DateTime) _periodTuple(DateRange range) => (range.start, range.end);

(DateTime, DateTime) _rollingMonthRange(
  DateTime currentLabel, {
  required int monthStartDay,
  required int months,
}) {
  final start = periodForLabel(
    currentLabel.year,
    currentLabel.month - months + 1,
    monthStartDay,
  ).start;
  final end = periodForLabel(
    currentLabel.year,
    currentLabel.month,
    monthStartDay,
  ).end;
  return (start, end);
}

double _summaryAmount(Map<String, Object?> totals, String type) {
  final value = totals[type];
  return value is Map && value['amount'] is num
      ? (value['amount'] as num).toDouble()
      : 0;
}

int _summaryCount(Map<String, Object?> totals, String type) {
  final value = totals[type];
  return value is Map && value['count'] is num
      ? (value['count'] as num).toInt()
      : 0;
}

double _groupAmount(Map<String, Object?> group, String type) {
  final totals = group['totals'];
  return totals is Map
      ? _summaryAmount(Map<String, Object?>.from(totals), type)
      : 0;
}

int _groupCount(Map<String, Object?> group, String type) {
  final totals = group['totals'];
  return totals is Map
      ? _summaryCount(Map<String, Object?>.from(totals), type)
      : 0;
}

String? _periodValue(Map<String, Object?> group) {
  final key = group['key'];
  if (key is! Map) return null;
  final value = key['value'];
  return value is String ? value : null;
}

Map<String, Map<String, Object?>> _groupsByPeriod(
  Map<String, Object?> summary,
) =>
    {
      for (final raw
          in (summary['groups'] as List? ?? const []).whereType<Map>())
        if (_periodValue(Map<String, Object?>.from(raw)) case final value?)
          value: Map<String, Object?>.from(raw),
    };

String? _previousYearPeriod(String value, String interval) {
  if (interval == 'year') {
    final year = int.tryParse(value);
    return year == null ? null : '${year - 1}';
  }
  final match = RegExp(r'^(\d{4})(.*)$').firstMatch(value);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  return year == null ? null : '${year - 1}${match.group(2)!}';
}

DateTime _shiftYear(DateTime value, int years) {
  final targetYear = value.year + years;
  final lastDay = DateTime(targetYear, value.month + 1, 0).day;
  return DateTime(
    targetYear,
    value.month,
    value.day.clamp(1, lastDay),
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
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

bool _looksLikeTransactionEntry(String query) {
  if (!RegExp(r'\d+(?:\.\d+)?').hasMatch(query)) return false;
  const cues = <String>[
    '记账',
    '买',
    '花',
    '消费',
    '支付',
    '付了',
    '午饭',
    '早餐',
    '晚饭',
    '打车',
    '咖啡',
    '奶茶',
    '收入',
    '工资',
    '奖金',
    '报销',
    'record',
    'spent',
    'paid',
  ];
  return cues.any(query.contains);
}

bool _looksLikeCategoryBreakdown(String query) {
  const categoryCues = <String>['分类', '类别', '各类', '哪类', '品类', 'category'];
  const breakdownCues = <String>[
    '占比',
    '比例',
    '构成',
    '分布',
    '排行',
    '排名',
    '最多',
    'breakdown',
    'share',
  ];
  return categoryCues.any(query.contains) && breakdownCues.any(query.contains);
}
