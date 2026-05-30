// RecurringTransactionService 生成逻辑回归测试。
//
// 锁死 issue #135:历史开始日期不再回溯补生成脏数据。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'test', currency: 'CNY');
  });

  tearDown(() async {
    await db.close();
  });

  test('历史开始日期 + 从未生成 → 不回溯补历史账单(issue #135)', () async {
    // daily 周期账单,开始日期在 30 天前,lastGeneratedDate 为 null。
    // 修复前:会从 startDate 一路补到今天(约 30 笔脏数据);
    // 修复后:基准锁定今天零点,daily 第一笔落在明天(未来),本次不生成。
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

    expect(generated, isEmpty);
  });

  test('已生成过(lastGeneratedDate 非空)→ 正常 catch-up 不受影响', () async {
    // 开始 30 天前、昨天生成过一笔的 daily 账单:应正常补出"今天"这一笔,
    // 证明历史保护只拦"从未生成"的回溯,不误伤正常的错过补齐。
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
  });
}
