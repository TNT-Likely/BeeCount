/// 账户隐藏(issue #240)— Repository 层 + 选择器过滤 helper 测试。
///
/// 覆盖:
/// - `updateAccount(id, hidden: true)` 落值且记 user-global change(同步依赖)。
/// - `setAccountHidden` 便捷法往返(true → false),内部走 `updateAccount`。
/// - `updateAccount` 只改 name 时,`hidden` 不被动(absent 保护,不能被无意抹掉)。
/// - `filterAccountsForLedger`(记账 `AccountSelector` / 转账 `transfer_form`
///   共用的过滤 helper)排除 `hidden` 账户。
///
/// 关键风险(见 CLAUDE.md 数据库访问规则 + 02-tech-design-app.md §三.1):隐藏开关
/// 必须走会记 change 的 `updateAccount`,不能像 `updateAccountSortOrders` /
/// `updateAccountValuation` 那样直接委托底层、不记 change、不同步。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';

void main() {
  // repo.createAccount 内部会 logger.debug(...),logger 单例首次使用时会
  // 建原生桥接 MethodChannel + 读 SharedPreferences,需要 binding 先初始化
  // 且 mock 好 SharedPreferences(同 transaction_exclude_flags_apply_test.dart
  // 等既有测试)。
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('updateAccount(id, hidden: true) 落值且记 change', () async {
    final tracker = ChangeTracker(db);
    final trackedRepo = LocalRepository(db, changeTracker: tracker);
    final lid = await trackedRepo.createLedger(name: 'L');
    final aid = await trackedRepo.createAccount(
        ledgerId: lid, name: 'A', syncId: 'ax-hidden-1');

    await trackedRepo.updateAccount(aid, hidden: true);

    final a = await trackedRepo.getAccount(aid);
    expect(a!.hidden, true);

    final changes = await (db.select(db.localChanges)
          ..where((c) => c.entityType.equals('account'))
          ..where((c) => c.entitySyncId.equals('ax-hidden-1'))
          ..where((c) => c.action.equals('update')))
        .get();
    expect(changes, isNotEmpty,
        reason:
            '隐藏必须走会记 change 的 updateAccount,否则隐藏状态不会 push 到云端');
  });

  test('setAccountHidden 便捷法往返(true → false)', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(ledgerId: lid, name: 'A');

    await repo.setAccountHidden(aid, true);
    var a = await repo.getAccount(aid);
    expect(a!.hidden, true);

    await repo.setAccountHidden(aid, false);
    a = await repo.getAccount(aid);
    expect(a!.hidden, false);
  });

  test('setAccountHidden 落值且走 updateAccount;只改 name 不动 hidden', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(ledgerId: lid, name: 'A');
    await repo.setAccountHidden(aid, true);
    var a = await repo.getAccount(aid);
    expect(a!.hidden, true);
    await repo.updateAccount(aid, name: 'A2'); // 不传 hidden
    a = await repo.getAccount(aid);
    expect(a!.hidden, true); // 未被抹
    expect(a.name, 'A2');
  });

  test('filterAccountsForLedger 排除 hidden 账户(单人账本/Owner 视角)', () async {
    final lid = await repo.createLedger(name: 'L');
    final visibleId = await repo.createAccount(ledgerId: lid, name: '可见');
    final hiddenId = await repo.createAccount(ledgerId: lid, name: '隐藏');
    await repo.setAccountHidden(hiddenId, true);

    final all = await repo.getAllAccounts();
    // ctx=null 模拟单人账本(记账/转账最常见场景)。
    final filtered = await db.filterAccountsForLedger(all, null);

    expect(filtered.map((a) => a.id), contains(visibleId));
    expect(filtered.map((a) => a.id), isNot(contains(hiddenId)));
  });

  // ==========================================================================
  // D1 反向断言(账户隐藏 #240 统计层不动红线):隐藏账户仍计入净资产/资产构成。
  // 对齐 02-tech-design-app.md §七 / 账单标记 plan 的同类反向断言。
  // ==========================================================================

  test('隐藏账户后 getNetWorthBreakdown 数值不变 (D1)', () async {
    final lid = await repo.createLedger(name: 'L');
    await repo.createAccount(ledgerId: lid, name: 'A', initialBalance: 1000);
    final hiddenId = await repo.createAccount(
        ledgerId: lid, name: 'B', initialBalance: 500);

    final before = await repo.getNetWorthBreakdown();

    await repo.setAccountHidden(hiddenId, true);
    final after = await repo.getNetWorthBreakdown();

    expect(after.totalAssets, before.totalAssets,
        reason: '隐藏不是删除,总资产不应变化(D1)');
    expect(after.netWorth, before.netWorth,
        reason: '隐藏账户仍计入净资产(D1)');
  });

  test('隐藏账户后 getAssetCompositionByType 数值不变 (D1)', () async {
    final lid = await repo.createLedger(name: 'L');
    await repo.createAccount(
        ledgerId: lid, name: 'A', type: 'cash', initialBalance: 1000);
    final hiddenId = await repo.createAccount(
        ledgerId: lid, name: 'B', type: 'cash', initialBalance: 500);

    final before = await repo.getAssetCompositionByType();
    final beforeCash =
        before.firstWhere((e) => e.type == 'cash').totalBalance;

    await repo.setAccountHidden(hiddenId, true);
    final after = await repo.getAssetCompositionByType();
    final afterCash = after.firstWhere((e) => e.type == 'cash').totalBalance;

    expect(afterCash, beforeCash, reason: '隐藏账户仍计入资产构成(D1)');
  });

  // ==========================================================================
  // getActiveRecurringCountByAccount(账户隐藏 #240 E2):隐藏确认框计数依赖。
  // ==========================================================================

  test('getActiveRecurringCountByAccount 统计引用该账户的活跃周期(转出/转入任一端)',
      () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(ledgerId: lid, name: 'A');
    final bid = await repo.createAccount(ledgerId: lid, name: 'B');

    // 命中:accountId = aid,启用
    await repo.addRecurringTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 10,
      accountId: aid,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime.now(),
    );
    // 命中:toAccountId = aid(转账转入端),启用
    await repo.addRecurringTransaction(
      ledgerId: lid,
      type: 'transfer',
      amount: 10,
      accountId: bid,
      toAccountId: aid,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime.now(),
    );
    // 不命中:关联账户是 bid,与 aid 无关
    await repo.addRecurringTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 10,
      accountId: bid,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime.now(),
    );
    // 不命中:关联 aid 但已禁用(enabled=false 不算"活跃")
    final disabledId = await repo.addRecurringTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 10,
      accountId: aid,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime.now(),
    );
    await repo.toggleRecurringTransaction(disabledId, false);

    final count = await repo.getActiveRecurringCountByAccount(aid);
    expect(count, 2);
  });
}
