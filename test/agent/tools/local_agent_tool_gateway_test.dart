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
