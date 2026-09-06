import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/ai/core/ai_extraction_context.dart';
import 'package:beecount/ai/core/ai_extraction_engine.dart';
import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/ai/ai_bookkeeper.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repository;
  late BeeCountLocalAgentToolGateway gateway;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = LocalRepository(db);
    gateway = BeeCountLocalAgentToolGateway(
      repository: repository,
      database: db,
      bookkeeper: AiBookkeeper(
        repository: repository,
        engine: const DefaultAiExtractionEngine(),
        persister: BillCreationService(repository),
      ),
      memoryRepository: LocalAgentMemoryRepository(db),
    );
  });

  tearDown(() => db.close());

  test('query gateway returns canonical transaction relations and currencies',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    final categoryId = await repository.createCategory(
      name: '餐饮',
      kind: 'expense',
      icon: 'food',
    );
    final fromAccountId = await repository.createAccount(
      ledgerId: ledgerId,
      name: '美元现金',
      currency: 'USD',
    );
    final toAccountId = await repository.createAccount(
      ledgerId: ledgerId,
      name: '储蓄卡',
      currency: 'CNY',
    );
    final tagId = await repository.createTag(name: '出差');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      categoryId: categoryId,
      accountId: fromAccountId,
      toAccountId: toAccountId,
      happenedAt: DateTime(2026, 9, 6, 12),
      note: '午饭',
      currencyCode: 'USD',
      nativeAmount: 72,
      excludeFromStats: true,
      excludeFromBudget: true,
    );
    await repository.updateTransactionTags(
      transactionId: transactionId,
      tagIds: [tagId],
    );

    final result = await gateway.queryTransactions(
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
    );

    expect(result, hasLength(1));
    expect(result.single.toToolData(), {
      'id': transactionId,
      'ledgerId': ledgerId,
      'type': 'expense',
      'amount': 10.0,
      'ledgerAmount': 72.0,
      'currency': 'USD',
      'ledgerCurrency': 'CNY',
      'category': {'id': categoryId, 'name': '餐饮', 'icon': 'food'},
      'account': {'id': fromAccountId, 'name': '美元现金', 'currency': 'USD'},
      'toAccount': {'id': toAccountId, 'name': '储蓄卡', 'currency': 'CNY'},
      'tags': [
        {'id': tagId, 'name': '出差'},
      ],
      'excludeFromStats': true,
      'excludeFromBudget': true,
      'happenedAt': '2026-09-06T12:00:00.000',
      'note': '午饭',
    });
  });

  test(
      'transaction summary aggregates every matching row instead of the twenty-row detail limit',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    for (var index = 0; index < 21; index++) {
      await repository.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 10,
        happenedAt: DateTime(2026, 9, 1, 12, index),
      );
    }
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'income',
      amount: 1000,
      happenedAt: DateTime(2026, 9, 2),
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'transfer',
      amount: 300,
      happenedAt: DateTime(2026, 9, 3),
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 99,
      excludeFromStats: true,
      happenedAt: DateTime(2026, 9, 4),
    );

    final result = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
    );

    expect(result, {
      'currency': 'CNY',
      'periodStart': '2026-09-01T00:00:00.000',
      'periodEnd': '2026-10-01T00:00:00.000',
      'types': ['income', 'expense', 'transfer'],
      'totals': {
        'income': {'amount': 1000.0, 'count': 1},
        'expense': {'amount': 210.0, 'count': 21},
        'transfer': {'amount': 300.0, 'count': 1},
      },
      'groupBy': 'none',
      'groups': [],
      'groupsMayOverlap': false,
      'truncated': false,
    });
  });

  test('transaction summary groups native aggregates by category and tag',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    final foodId = await repository.createCategory(
      name: '餐饮',
      kind: 'expense',
      icon: 'food',
    );
    final salaryId = await repository.createCategory(
      name: '工资',
      kind: 'income',
      icon: 'payments',
    );
    final tripTagId = await repository.createTag(name: '出差');
    final taggedExpenseId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 60,
      categoryId: foodId,
      happenedAt: DateTime(2026, 9, 1),
    );
    await repository.updateTransactionTags(
      transactionId: taggedExpenseId,
      tagIds: [tripTagId],
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 40,
      categoryId: foodId,
      happenedAt: DateTime(2026, 9, 2),
    );
    final taggedIncomeId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'income',
      amount: 100,
      categoryId: salaryId,
      happenedAt: DateTime(2026, 9, 3),
    );
    await repository.updateTransactionTags(
      transactionId: taggedIncomeId,
      tagIds: [tripTagId],
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 20,
      happenedAt: DateTime(2026, 9, 4),
    );

    final byCategory = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
      groupBy: 'category',
    );
    final categoryGroups = byCategory['groups']! as List<Object?>;
    expect(
      categoryGroups,
      contains(
        _summaryGroup(
          key: {'kind': 'category', 'id': foodId, 'name': '餐饮', 'icon': 'food'},
          totals: const {
            'income': {'amount': 0.0, 'count': 0},
            'expense': {'amount': 100.0, 'count': 2},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );
    expect(
      categoryGroups,
      contains(
        _summaryGroup(
          key: {
            'kind': 'category',
            'id': salaryId,
            'name': '工资',
            'icon': 'payments'
          },
          totals: const {
            'income': {'amount': 100.0, 'count': 1},
            'expense': {'amount': 0.0, 'count': 0},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );
    expect(
      categoryGroups,
      contains(
        _summaryGroup(
          key: const {
            'kind': 'category',
            'id': null,
            'name': '未分类',
            'icon': null,
          },
          totals: const {
            'income': {'amount': 0.0, 'count': 0},
            'expense': {'amount': 20.0, 'count': 1},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );

    final byTag = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
      groupBy: 'tag',
    );
    expect(byTag['groupsMayOverlap'], isTrue);
    expect(
      byTag['groups'],
      contains(
        _summaryGroup(
          key: {'kind': 'tag', 'id': tripTagId, 'name': '出差'},
          totals: const {
            'income': {'amount': 100.0, 'count': 1},
            'expense': {'amount': 60.0, 'count': 1},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );
    expect(
      byTag['groups'],
      contains(
        _summaryGroup(
          key: const {'kind': 'tag', 'id': null, 'name': '未标记'},
          totals: const {
            'income': {'amount': 0.0, 'count': 0},
            'expense': {'amount': 60.0, 'count': 2},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );
  });

  test('transaction summary supports category, tag, and stat-scope filters',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    final foodId = await repository.createCategory(
      name: '餐饮',
      kind: 'expense',
    );
    final tripTagId = await repository.createTag(name: '出差');
    final matchingId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 60,
      categoryId: foodId,
      happenedAt: DateTime(2026, 9, 1),
    );
    await repository.updateTransactionTags(
      transactionId: matchingId,
      tagIds: [tripTagId],
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 40,
      categoryId: foodId,
      happenedAt: DateTime(2026, 9, 2),
    );
    final excludedId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 5,
      categoryId: foodId,
      excludeFromStats: true,
      happenedAt: DateTime(2026, 9, 3),
    );
    await repository.updateTransactionTags(
      transactionId: excludedId,
      tagIds: [tripTagId],
    );

    final filtered = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
      types: const {'expense'},
      categoryIds: [foodId],
      tagIds: [tripTagId],
    );
    final filteredTotals = filtered['totals'] as Map<String, Object?>;
    expect(filteredTotals['expense'], {'amount': 60.0, 'count': 1});

    final includingExcluded = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
      types: const {'expense'},
      categoryIds: [foodId],
      tagIds: [tripTagId],
      includeExcludedFromStats: true,
    );
    final includingTotals = includingExcluded['totals'] as Map<String, Object?>;
    expect(includingTotals['expense'], {'amount': 65.0, 'count': 2});
  });

  test('transaction summary rolls leaf categories up to their top category',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    final parentId = await repository.createCategory(
      name: '生活',
      kind: 'expense',
      icon: 'home',
    );
    final childId = await repository.createSubCategory(
      parentId: parentId,
      name: '餐饮',
      kind: 'expense',
      icon: 'food',
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 35,
      categoryId: childId,
      happenedAt: DateTime(2026, 9, 1),
    );

    final result = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
      groupBy: 'category',
      categoryLevel: 'top',
    );
    expect(
      result['groups'],
      contains(
        _summaryGroup(
          key: {
            'kind': 'category',
            'id': parentId,
            'name': '生活',
            'icon': 'home'
          },
          totals: const {
            'income': {'amount': 0.0, 'count': 0},
            'expense': {'amount': 35.0, 'count': 1},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );
  });

  test('transaction summary groups accounts with directional transfers',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    final cashId = await repository.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      currency: 'CNY',
    );
    final bankId = await repository.createAccount(
      ledgerId: ledgerId,
      name: '银行卡',
      currency: 'CNY',
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 40,
      accountId: cashId,
      happenedAt: DateTime(2026, 9, 1),
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'income',
      amount: 100,
      accountId: bankId,
      happenedAt: DateTime(2026, 9, 2),
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'transfer',
      amount: 30,
      accountId: cashId,
      toAccountId: bankId,
      happenedAt: DateTime(2026, 9, 3),
    );

    final result = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
      groupBy: 'account',
    );
    expect(result['groupsMayOverlap'], isTrue);
    expect(
      result['groups'],
      contains(
        _accountSummaryGroup(
          key: {
            'kind': 'account',
            'id': cashId,
            'name': '现金',
            'currency': 'CNY'
          },
          totals: const {
            'income': {'amount': 0.0, 'count': 0},
            'expense': {'amount': 40.0, 'count': 1},
            'transfer': {'amount': 0.0, 'count': 0},
          },
          transferOut: const {'amount': 30.0, 'count': 1},
          transferIn: const {'amount': 0.0, 'count': 0},
        ),
      ),
    );
    expect(
      result['groups'],
      contains(
        _accountSummaryGroup(
          key: {
            'kind': 'account',
            'id': bankId,
            'name': '银行卡',
            'currency': 'CNY'
          },
          totals: const {
            'income': {'amount': 100.0, 'count': 1},
            'expense': {'amount': 0.0, 'count': 0},
            'transfer': {'amount': 0.0, 'count': 0},
          },
          transferOut: const {'amount': 0.0, 'count': 0},
          transferIn: const {'amount': 30.0, 'count': 1},
        ),
      ),
    );
  });

  test('transaction summary groups native totals by local calendar period',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 12,
      happenedAt: DateTime(2026, 9, 1, 23, 30),
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 8,
      happenedAt: DateTime(2026, 9, 2, 0, 30),
    );

    final result = await _summarizeGateway(
      gateway,
      ledgerId: ledgerId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
      groupBy: 'day',
    );
    expect(
      result['groups'],
      contains(
        _summaryGroup(
          key: const {'kind': 'day', 'value': '2026-09-01'},
          totals: const {
            'income': {'amount': 0.0, 'count': 0},
            'expense': {'amount': 12.0, 'count': 1},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );
    expect(
      result['groups'],
      contains(
        _summaryGroup(
          key: const {'kind': 'day', 'value': '2026-09-02'},
          totals: const {
            'income': {'amount': 0.0, 'count': 0},
            'expense': {'amount': 8.0, 'count': 1},
            'transfer': {'amount': 0.0, 'count': 0},
          },
        ),
      ),
    );
  });

  test('recurring gateway returns schedule and related transaction context',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    final categoryId = await repository.createCategory(
      name: '订阅',
      kind: 'expense',
      icon: 'subscriptions',
    );
    final fromAccountId = await repository.createAccount(
      ledgerId: ledgerId,
      name: '美元信用卡',
      currency: 'USD',
    );
    final toAccountId = await repository.createAccount(
      ledgerId: ledgerId,
      name: '电子钱包',
      currency: 'CNY',
    );
    final recurringId = await repository.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 12,
      categoryId: categoryId,
      accountId: fromAccountId,
      toAccountId: toAccountId,
      note: '视频会员',
      frequency: 'monthly',
      interval: 2,
      dayOfMonth: 5,
      dayOfWeek: null,
      monthOfYear: null,
      startDate: DateTime(2026, 1, 5),
      endDate: DateTime(2026, 12, 5),
      currencyCode: 'USD',
    );
    await repository.updateLastGeneratedDate(
      recurringId,
      DateTime(2026, 9, 5),
    );

    final result = await gateway.getRecurringTransactions(ledgerId);

    expect(result, hasLength(1));
    expect(result.single.toToolData(), {
      'id': recurringId,
      'type': 'expense',
      'amount': 12.0,
      'currency': 'USD',
      'category': {'id': categoryId, 'name': '订阅', 'icon': 'subscriptions'},
      'account': {'id': fromAccountId, 'name': '美元信用卡', 'currency': 'USD'},
      'toAccount': {'id': toAccountId, 'name': '电子钱包', 'currency': 'CNY'},
      'frequency': 'monthly',
      'interval': 2,
      'dayOfMonth': 5,
      'dayOfWeek': null,
      'monthOfYear': null,
      'startDate': '2026-01-05T00:00:00.000',
      'endDate': '2026-12-05T00:00:00.000',
      'lastGeneratedDate': '2026-09-05T00:00:00.000',
      'note': '视频会员',
    });
  });

  test(
      'budget gateway returns total and category budget usage in ledger currency',
      () async {
    final ledgerId = await repository.createLedger(
      name: '美元账本',
      currency: 'USD',
    );
    final categoryId = await repository.createCategory(
      name: '餐饮',
      kind: 'expense',
      icon: 'food',
    );
    await repository.createBudget(
      ledgerId: ledgerId,
      type: 'total',
      amount: 100,
    );
    await repository.createBudget(
      ledgerId: ledgerId,
      type: 'category',
      categoryId: categoryId,
      amount: 40,
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 25,
      categoryId: categoryId,
      happenedAt: DateTime.now(),
      currencyCode: 'USD',
      nativeAmount: 25,
    );

    final result = await gateway.getBudgetStatus(ledgerId);
    final data = result.toToolData();

    expect(data['currency'], 'USD');
    expect(data['total'], {
      'used': 25.0,
      'budget': 100.0,
      'remaining': 75.0,
      'rate': 0.25,
      'status': 'normal',
    });
    expect(data['categoryBudgets'], [
      {
        'budgetId': 2,
        'category': {'id': categoryId, 'name': '餐饮', 'icon': 'food'},
        'usage': {
          'used': 25.0,
          'budget': 40.0,
          'remaining': 15.0,
          'rate': 0.625,
          'status': 'normal',
        },
      },
    ]);
  });

  test(
      'record gateway returns the canonical transaction instead of AI draft data',
      () async {
    final ledgerId = await repository.createLedger(name: '测试账本');
    final categoryId = await repository.createCategory(
      name: '餐饮',
      kind: 'expense',
      icon: 'food',
    );
    final accountId = await repository.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      currency: 'CNY',
    );
    final recordingGateway = BeeCountLocalAgentToolGateway(
      repository: repository,
      database: db,
      bookkeeper: AiBookkeeper(
        repository: repository,
        engine: _StaticExtractionEngine([
          BillInfo(
            amount: -30,
            time: DateTime(2026, 9, 6, 12),
            category: '餐饮',
            account: '现金',
            type: BillType.expense,
            note: '午饭',
          ),
        ]),
        persister: BillCreationService(repository),
      ),
      memoryRepository: LocalAgentMemoryRepository(db),
    );

    final result = await recordingGateway.recordTransaction(
      ledgerId: ledgerId,
      text: '午饭 30',
    );

    expect(result.success, isTrue);
    expect(result.bills, hasLength(1));
    expect(result.toToolData(), {
      'success': true,
      'transactionIds': result.transactionIds,
      'transactions': [
        {
          'id': result.transactionIds.single,
          'ledgerId': ledgerId,
          'type': 'expense',
          'amount': 30.0,
          'ledgerAmount': 30.0,
          'currency': 'CNY',
          'ledgerCurrency': 'CNY',
          'category': {'id': categoryId, 'name': '餐饮', 'icon': 'food'},
          'account': {'id': accountId, 'name': '现金', 'currency': 'CNY'},
          'toAccount': null,
          'tags': [],
          'excludeFromStats': false,
          'excludeFromBudget': false,
          'happenedAt': '2026-09-06T12:00:00.000',
          'note': '午饭',
        },
      ],
      'unconvertedCurrencies': [],
    });
  });
}

Future<Map<String, Object?>> _summarizeGateway(
  BeeCountLocalAgentToolGateway gateway, {
  required int ledgerId,
  required DateTime start,
  required DateTime end,
  String groupBy = 'none',
  Set<String> types = const {'income', 'expense', 'transfer'},
  String categoryLevel = 'leaf',
  List<int> categoryIds = const [],
  List<int> tagIds = const [],
  List<int> accountIds = const [],
  bool includeExcludedFromStats = false,
  int groupLimit = 20,
}) async {
  final dynamic result = await (gateway as dynamic).summarizeTransactions(
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
  );
  return Map<String, Object?>.from(result as Map);
}

Matcher _summaryGroup({
  required Map<String, Object?> key,
  required Map<String, Object?> totals,
}) =>
    isA<Map>()
        .having((value) => value['key'], 'key', equals(key))
        .having((value) => value['totals'], 'totals', equals(totals));

Matcher _accountSummaryGroup({
  required Map<String, Object?> key,
  required Map<String, Object?> totals,
  required Map<String, Object?> transferOut,
  required Map<String, Object?> transferIn,
}) =>
    isA<Map>()
        .having((value) => value['key'], 'key', equals(key))
        .having((value) => value['totals'], 'totals', equals(totals))
        .having(
            (value) => value['transferOut'], 'transferOut', equals(transferOut))
        .having(
            (value) => value['transferIn'], 'transferIn', equals(transferIn));

final class _StaticExtractionEngine implements AiExtractionEngine {
  const _StaticExtractionEngine(this.bills);

  final List<BillInfo> bills;

  @override
  Future<List<BillInfo>> extractFromText(
    String text,
    AiExtractionContext context, {
    String billGuard = '',
  }) async =>
      bills;

  @override
  Future<List<BillInfo>> extractFromImage(
    File image,
    AiExtractionContext context, {
    String billGuard = '',
  }) async =>
      bills;

  @override
  Future<AudioExtractionResult> extractFromAudio(
    File audio,
    AiExtractionContext context,
  ) async =>
      AudioExtractionResult(bills: bills);

  @override
  Future<String?> speechToText(File audio) async => null;
}
