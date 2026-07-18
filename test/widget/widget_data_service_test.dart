/// `WidgetDataService.gatherGlance` 的今日/本月收支取数(从
/// `WidgetManager.updateWidget()` 迁移而来,P1 渲染管线参数化的一部分)。
/// 用内存 Drift 库验证:自然月 + 账本自定义 monthStartDay 两种口径下,
/// 求和范围与既有 `totalsByCategory` 语义一致。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/utils/month_range.dart';
import 'package:beecount/widget/widget_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('自然月(monthStartDay 默认 1):今日 + 本月收支求和', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 15);

    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 20, happenedAt: now);
    await repo.addTransaction(
        ledgerId: 1, type: 'income', amount: 50, happenedAt: now);
    // 上个月一笔支出,不应计入「本月」
    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 999, happenedAt: lastMonth);

    final data =
        await WidgetDataService.gatherGlance(repository: repo, ledgerId: 1);

    expect(data.todayExpenseTotal, 20);
    expect(data.todayIncomeTotal, 50);
    expect(data.monthExpenseTotal, 20);
    expect(data.monthIncomeTotal, 50);
  });

  test('账本自定义 monthStartDay:按自定义周期而非自然月求和', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency, month_start_day) "
        "VALUES (2, 'L2', 'CNY', 10)");
    final range = periodContaining(DateTime.now(), 10);
    final justBeforeRange = range.start.subtract(const Duration(days: 1));

    // 本周期内一笔支出
    await repo.addTransaction(
        ledgerId: 2, type: 'expense', amount: 30, happenedAt: range.start);
    // 上一周期最后一天一笔支出,不应计入本周期
    await repo.addTransaction(
        ledgerId: 2,
        type: 'expense',
        amount: 999,
        happenedAt: justBeforeRange);

    final data =
        await WidgetDataService.gatherGlance(repository: repo, ledgerId: 2);

    expect(data.monthExpenseTotal, 30);
  });

  test('账本不存在(getLedgerById 返回 null)时按自然月兜底,不抛异常', () async {
    final data = await WidgetDataService.gatherGlance(
        repository: repo, ledgerId: 999);

    expect(data.todayExpenseTotal, 0);
    expect(data.todayIncomeTotal, 0);
    expect(data.monthExpenseTotal, 0);
    expect(data.monthIncomeTotal, 0);
  });
}
