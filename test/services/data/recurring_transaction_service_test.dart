// RecurringTransactionService 生成逻辑回归测试。
//
// 锁死两件事:
//  1. issue #135:历史开始日期不回溯补生成脏数据(从未生成只产出"今天"一笔)。
//  2. 2026-06「每天周期不生效」修复:从未生成过的周期账单首笔落在"今天"(含今天),
//     而非被推到明天导致永远不触发。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    // LoggerService(被周期服务调用)内部走 SharedPreferences,单测需提供 mock,
    // 否则 logger.info 触发 MissingPluginException 让测试在完成后异步失败。
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'test', currency: 'CNY');
  });

  tearDown(() async {
    await db.close();
  });

  // 断言某 DateTime 是"今天"(本地零点)。
  void expectIsToday(DateTime d) {
    final now = DateTime.now();
    expect(d.year, now.year);
    expect(d.month, now.month);
    expect(d.day, now.day);
  }

  test('历史开始日期(30天前)+ 从未生成 → 只产出今天一笔,不回溯补历史(#135 + 含今天)',
      () async {
    // 修复前(老 bug):base 锁今天、daily 首笔=明天 → isAfter(now) → 一笔都不生成,
    // 且 lastGeneratedDate 永远为 null → 永久卡死("每天周期不生效")。
    // 修复后:首笔=基准日(今天),生成且仅生成"今天"这一笔,不补 30 天历史。
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, hasLength(1)); // 仅今天,不是 30 笔,也不是 0 笔
    expectIsToday(generated.first.happenedAt);
  });

  test('开始日期=昨天 + 从未生成 → 今天打开生成今天一笔(用户反馈场景)', () async {
    // 用户反馈:起始时间设为昨天,今天打开无法生成 —— 同一根因。
    // 修复后:生成"今天"这一笔(昨天那笔按 #135 不回溯)。
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, hasLength(1));
    expectIsToday(generated.first.happenedAt);
  });

  test('已生成过(lastGeneratedDate=昨天)→ 正常补出今天一笔', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    await repo.updateLastGeneratedDate(id, yesterday);

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    // 昨天 → 今天一笔(daily);明天还没到,停在这。
    expect(generated, hasLength(1));
    expectIsToday(generated.first.happenedAt);
  });

  test('今天已生成过(lastGeneratedDate=今天)→ 不重复生成', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.updateLastGeneratedDate(id, today);

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, isEmpty); // 今天已生成,明天才下一笔
  });

  test('开始日期在未来(明天)→ 今天不生成', () async {
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().add(const Duration(days: 1)),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, isEmpty); // 未来开始,首笔在明天
  });
}
