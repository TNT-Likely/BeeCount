// RecurringTransactionService 生成逻辑回归测试。
//
// 锁死两件事:
//  1. issue #135:历史开始日期不回溯补生成脏数据(从未生成只产出"今天"一笔)。
//  2. 2026-06「每天周期不生效」修复:从未生成过的周期账单首笔落在"今天"(含今天),
//     而非被推到明天导致永远不触发。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
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

  // ==========================================================================
  // 账户隐藏(#240)E2:关联账户被隐藏 → 生成器跳过该周期账单,不推进
  // lastGeneratedDate;账户恢复后自动补上遗漏周期。
  // ==========================================================================

  test('关联账户(accountId)已隐藏 → 本次扫描跳过生成,不推进 lastGeneratedDate (E2)',
      () async {
    final accountId = await repo.createAccount(ledgerId: ledgerId, name: 'A');
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      accountId: accountId,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    await repo.setAccountHidden(accountId, true);

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, isEmpty, reason: '隐藏账户本次扫描应跳过生成(E2)');
    final all = await repo.getAllRecurringTransactions();
    final r = all.firstWhere((r) => r.id == id);
    expect(r.lastGeneratedDate, isNull,
        reason: '跳过时不应推进 lastGeneratedDate,否则恢复后无法补生成遗漏周期');
  });

  test('转账周期:转入账户(toAccountId)已隐藏 → 同样跳过 (E2)', () async {
    final fromId = await repo.createAccount(ledgerId: ledgerId, name: 'From');
    final toId = await repo.createAccount(ledgerId: ledgerId, name: 'To');
    await repo.setAccountHidden(toId, true);
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'transfer',
      amount: 10,
      accountId: fromId,
      toAccountId: toId,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, isEmpty, reason: '转入账户隐藏也应跳过生成(E2)');
  });

  test('恢复隐藏账户后 → 周期生成恢复正常,补上遗漏的一笔', () async {
    final accountId = await repo.createAccount(ledgerId: ledgerId, name: 'A');
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      accountId: accountId,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    await repo.setAccountHidden(accountId, true);

    final service = RecurringTransactionService(repo);
    var generated = await service.generatePendingTransactions();
    expect(generated, isEmpty);

    await repo.setAccountHidden(accountId, false);
    generated = await service.generatePendingTransactions();

    expect(generated, hasLength(1));
    expectIsToday(generated.first.happenedAt);
  });

  // ==========================================================================
  // 2026-11 周期记账巩固与 #584 漏触发修复回归测试
  // ==========================================================================

  test('同日 22:30 新建月度规则(带时分秒) → 归一化零点后当天立即生成首笔,不跳下月 (B2a)',
      () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 99,
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: 18,
      startDate: DateTime(2026, 11, 18, 22, 30, 45),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions(
      now: DateTime(2026, 11, 18, 22, 31, 0),
    );

    expect(generated, hasLength(1));
    expect(generated.single.happenedAt, DateTime(2026, 11, 18));
    expect(generated.single.recurringId, id);
  });

  test('首期未在当天冷启动,次日打开正常补记首期账单,不再整月跳过 (#584 / B2b)', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'income',
      amount: 15000,
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: 15,
      startDate: DateTime(2026, 11, 1),
    );

    final service = RecurringTransactionService(repo);
    // 11月15日未打开,11月16日才启动扫描
    final generated = await service.generatePendingTransactions(
      now: DateTime(2026, 11, 16, 9, 0),
    );

    expect(generated, hasLength(1));
    expect(generated.single.happenedAt, DateTime(2026, 11, 15));
    expect(generated.single.recurringId, id);

    final updated =
        (await repo.getAllRecurringTransactions()).firstWhere((r) => r.id == id);
    expect(updated.lastGeneratedDate, DateTime(2026, 11, 15));
  });

  test('远古未生成月度规则(2020年起)首次扫描只补当期最近1笔,不刷70条历史脏账 (#135+#584)',
      () async {
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 50,
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: 15,
      startDate: DateTime(2020, 1, 1),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions(
      now: DateTime(2026, 11, 20, 10, 0),
    );

    expect(generated, hasLength(1));
    expect(generated.single.happenedAt, DateTime(2026, 11, 15));
  });

  test('编辑规则金额或备注默认保留 lastGeneratedDate,不清空执行游标 (B3)', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 100,
      frequency: 'monthly',
      interval: 3,
      dayOfMonth: 15,
      startDate: DateTime(2026, 8, 15),
    );
    await repo.updateLastGeneratedDate(id, DateTime(2026, 11, 15));

    await repo.updateRecurringTransaction(
      id: id,
      ledgerId: ledgerId,
      type: 'expense',
      amount: 120,
      note: '涨价后备注',
      frequency: 'monthly',
      interval: 3,
      dayOfMonth: 15,
      startDate: DateTime(2026, 8, 15),
    );

    final after =
        (await repo.getAllRecurringTransactions()).firstWhere((r) => r.id == id);
    expect(after.lastGeneratedDate, DateTime(2026, 11, 15));

    // 同月再次扫描不应重复生成第二笔
    final generated = await RecurringTransactionService(repo)
        .generatePendingTransactions(now: DateTime(2026, 11, 20));
    expect(generated, isEmpty);
  });

  test('结束日当天下午打开正常生成最后一期;结束日后打开仍补齐结束日前漏期 (B5)', () async {
    final id1 = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 30,
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: 30,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 11, 30),
    );
    await repo.updateLastGeneratedDate(id1, DateTime(2026, 10, 30));

    final service = RecurringTransactionService(repo);
    // 11月30日 15:30 打开(> endDate 00:00)
    final genOnEndDay = await service.generatePendingTransactions(
      now: DateTime(2026, 11, 30, 15, 30),
    );
    expect(genOnEndDay, hasLength(1));
    expect(genOnEndDay.single.happenedAt, DateTime(2026, 11, 30));

    // 另一条规则在 12月5日(> endDate)才打开,仍补记 11月30日那期并停止
    final id2 = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 40,
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: 30,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 11, 30),
    );
    await repo.updateLastGeneratedDate(id2, DateTime(2026, 10, 30));

    final genAfterEnd = await service.generatePendingTransactions(
      now: DateTime(2026, 12, 5, 9, 0),
    );
    expect(genAfterEnd, hasLength(1));
    expect(genAfterEnd.single.happenedAt, DateTime(2026, 11, 30));
  });

  test('年度规则忽略历史残留 dayOfMonth(monthOfYear==null),严格锚定 startDate 月日 (B6)',
      () async {
    // 模拟旧版编辑器在 17 日创建 startDate=12月25日 的年度规则,意外写入 dayOfMonth=17
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 88,
      frequency: 'yearly',
      interval: 1,
      dayOfMonth: 17,
      monthOfYear: null,
      startDate: DateTime(2026, 12, 25),
    );

    final rules = await repo.getAllRecurringTransactions();
    final upcoming = RecurringTransactionService.previewUpcomingOccurrences(
      RecurringScheduleSpec.fromModel(rules.single),
      count: 2,
      now: DateTime(2026, 11, 18),
    );
    expect(upcoming.map((e) => e.date).toList(), [
      DateTime(2026, 12, 25),
      DateTime(2027, 12, 25),
    ]);
  });

  test('月末 31 日跨小月与平年 2 月推演自动月末对齐且次月恢复 31 日,无漂移', () {
    final spec = RecurringScheduleSpec(
      frequency: RecurringFrequency.monthly,
      interval: 1,
      dayOfMonth: 31,
      startDate: DateTime(2026, 6, 30),
      lastGeneratedDate: DateTime(2026, 10, 31),
    );
    final upcoming = RecurringTransactionService.previewUpcomingOccurrences(
      spec,
      count: 5,
      now: DateTime(2026, 11, 18),
    );
    expect(upcoming.map((e) => e.date).toList(), [
      DateTime(2026, 11, 30),
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 31),
      DateTime(2027, 2, 28),
      DateTime(2027, 3, 31),
    ]);
    expect(upcoming[0].adjustedForMonthEnd, isTrue);
    expect(upcoming[0].nominalDayOfMonth, 31);
    expect(upcoming[1].adjustedForMonthEnd, isFalse);
    expect(upcoming[3].adjustedForMonthEnd, isTrue);
    expect(upcoming[4].adjustedForMonthEnd, isFalse);
  });

  test('多账本异常隔离 + ChangeTracker 登记 + SingleFlight 并发防重 + 删改账本级联 (#584/B4/B7)',
      () async {
    final tracker = ChangeTracker(db);
    final trackedRepo = LocalRepository(db, changeTracker: tracker);
    final ledgerB = await trackedRepo.createLedger(name: 'B', currency: 'CNY');

    // A 账本挂一个已删除的不存在账户(accountId=999),应被安全隔离跳过
    await trackedRepo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 50,
      accountId: 999,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now(),
    );
    // B 账本正常规则同一天应照常生成并写入 local_changes
    final validRuleId = await trackedRepo.addRecurringTransaction(
      ledgerId: ledgerB,
      type: 'income',
      amount: 888,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now(),
    );

    // 并发调用两次静态生成,SingleFlight 保证只生成 1 笔
    final results = await Future.wait([
      RecurringTransactionService.generatePendingTransactionsStatic(
        repository: trackedRepo,
      ),
      RecurringTransactionService.generatePendingTransactionsStatic(
        repository: trackedRepo,
      ),
    ]);
    expect({...results[0], ...results[1]}, {ledgerB});

    final bTxs = await trackedRepo.getTransactionsByLedger(ledgerB);
    expect(bTxs, hasLength(1));
    expect(bTxs.single.recurringId, validRuleId);

    final unpushed = await tracker.getUnpushedChangesForLedger(ledgerB);
    expect(
      unpushed.where((c) => c.entityType == 'transaction' && c.action == 'create'),
      hasLength(1),
    );

    // reassignLedgerId 同步迁移 recurring_transactions.ledger_id
    await trackedRepo.reassignLedgerId(fromId: ledgerB, toId: 99);
    expect(
      (await trackedRepo.getRecurringTransactionsByLedger(99)).single.id,
      validRuleId,
    );

    // deleteLedger 级联清理该账本下的 recurring_transactions
    await trackedRepo.deleteLedger(99);
    expect(await trackedRepo.getRecurringTransactionsByLedger(99), isEmpty);
  });
}
