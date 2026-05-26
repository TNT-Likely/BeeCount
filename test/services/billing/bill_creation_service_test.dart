// BillCreationService 契约测试。
//
// 锁死:
// - AI 分类完全匹配 / 模糊匹配 / 规则匹配的优先级
// - 「其他」分类兜底,无「其他」时使用最后一个
// - 账户完全 / 模糊 / 类型映射匹配,以及同账本币种过滤
// - 转账场景的双账户匹配 + 同账户去重
// - 类型推断:BillType 显式 > category 含转账字样 > 默认 expense
// - amount 无效直接返回 null
// - 默认账户币种校验

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late BillCreationService service;
  late int ledgerId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    service = BillCreationService(repo);
    ledgerId = await repo.createLedger(name: 'test', currency: 'CNY');
  });

  tearDown(() async {
    await db.close();
  });

  // ============================================================
  // amount 校验
  // ============================================================

  group('amount 校验', () {
    test('amount=null → 返回 null', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(time: DateTime(2026, 5, 26)),
        ledgerId: ledgerId,
      );
      expect(txId, isNull);
    });

    test('amount=0 → 返回 null', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(amount: 0, time: DateTime(2026, 5, 26)),
        ledgerId: ledgerId,
      );
      expect(txId, isNull);
    });

    test('amount 绝对值入库,正负只影响 type', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30, // 负值
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      expect(txId, isNotNull);
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.amount, 30); // abs
      expect(tx?.type, 'expense');
    });
  });

  // ============================================================
  // 类型推断
  // ============================================================

  group('类型推断 _resolveType', () {
    setUp(() async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      await repo.createCategory(name: '工资', kind: 'income');
      await repo.createCategory(name: '转账', kind: 'expense');
    });

    test('显式 BillType.expense → expense', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.type, 'expense');
    });

    test('显式 BillType.income → income', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 5000,
          time: DateTime(2026, 5, 26),
          type: BillType.income,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.type, 'income');
    });

    test('显式 BillType.transfer → transfer', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 800,
          time: DateTime(2026, 5, 26),
          type: BillType.transfer,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.type, 'transfer');
    });

    test('type=null + category="转账" → transfer', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 800,
          time: DateTime(2026, 5, 26),
          category: '转账',
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.type, 'transfer');
    });

    test('type=null + category="轉帳"(繁体) → transfer', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 800,
          time: DateTime(2026, 5, 26),
          category: '轉帳',
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.type, 'transfer');
    });

    test('type=null + 无 category → 默认 expense', () async {
      final txId = await service.createFromBill(
        bill: BillInfo(amount: -30, time: DateTime(2026, 5, 26)),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.type, 'expense');
    });
  });

  // ============================================================
  // 分类匹配
  // ============================================================

  group('分类匹配', () {
    test('AI 分类名完全相等 → 直接命中', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      await repo.createCategory(name: '咖啡', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '咖啡',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      final cat = await repo.getCategoryById(tx!.categoryId!);
      expect(cat?.name, '咖啡');
    });

    test('AI 分类名被本地分类包含(模糊) → 命中', () async {
      // 本地有「餐饮美食」,AI 给「餐饮」,模糊匹配应命中
      await repo.createCategory(name: '餐饮美食', kind: 'expense');
      await repo.createCategory(name: '其他', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      final cat = await repo.getCategoryById(tx!.categoryId!);
      expect(cat?.name, '餐饮美食');
    });

    test('AI 分类名都不匹配 → 兜底「其他」', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      await repo.createCategory(name: '其他', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '完全没有这个分类',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      final cat = await repo.getCategoryById(tx!.categoryId!);
      expect(cat?.name, '其他');
    });

    test('「其它」也作为兜底候选(全角)', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      await repo.createCategory(name: '其它', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '无',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      final cat = await repo.getCategoryById(tx!.categoryId!);
      expect(cat?.name, '其它');
    });

    test('无「其他」时使用最后一个分类作为兜底', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense', sortOrder: 1);
      await repo.createCategory(name: '购物', kind: 'expense', sortOrder: 2);
      await repo.createCategory(name: '娱乐', kind: 'expense', sortOrder: 3);
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '完全没有',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      // 应使用 sortOrder 最大的那个(列表 last)
      final cat = await repo.getCategoryById(tx!.categoryId!);
      expect(cat?.name, '娱乐');
    });
  });

  // ============================================================
  // 账户匹配
  // ============================================================

  group('账户匹配', () {
    setUp(() async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      // 关闭账户功能默认 = 启用
      SharedPreferences.setMockInitialValues({'account_feature_enabled': true});
    });

    test('AI 账户名完全相等 → 命中(限同账本币种)', () async {
      final acc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '支付宝',
        currency: 'CNY',
      );
      // 另一币种账户不参与匹配
      await repo.createAccount(
        ledgerId: ledgerId,
        name: '支付宝',
        currency: 'USD',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          account: '支付宝',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, acc);
    });

    test('AI 账户名模糊匹配(account 名是 AI 名的超集)', () async {
      // 本地账户名 "招行卡",AI 给 "招行" → account.contains(ai) ⇒ 命中
      final acc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '招行卡',
        currency: 'CNY',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          account: '招行',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, acc);
    });

    test('AI 账户名模糊匹配(AI 名是 account 名的超集)', () async {
      // 本地账户名 "建行",AI 给 "建行储蓄卡" → ai.contains(account) ⇒ 命中
      final acc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '建行',
        currency: 'CNY',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          account: '建行储蓄卡',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, acc);
    });

    test('账户类型映射:余额宝 → 支付宝', () async {
      final acc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '支付宝',
        currency: 'CNY',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          account: '余额宝',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, acc);
    });

    test('账户类型映射:零钱通 → 微信', () async {
      final acc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '微信钱包',
        currency: 'CNY',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          account: '零钱通',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, acc);
    });

    test('账户功能关闭 → 不匹配', () async {
      SharedPreferences.setMockInitialValues(
          {'account_feature_enabled': false});
      await repo.createAccount(
        ledgerId: ledgerId,
        name: '支付宝',
        currency: 'CNY',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          account: '支付宝',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, isNull);
    });
  });

  // ============================================================
  // 转账场景
  // ============================================================

  group('转账场景', () {
    test('双账户都匹配 → from / to 分别落库', () async {
      await repo.createCategory(name: '转账', kind: 'expense');
      final fromAcc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '建行',
        currency: 'CNY',
      );
      final toAcc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '微信零钱',
        currency: 'CNY',
      );

      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 800,
          time: DateTime(2026, 5, 26),
          category: '转账',
          type: BillType.transfer,
          fromAccount: '建行',
          toAccount: '微信零钱',
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.type, 'transfer');
      expect(tx?.accountId, fromAcc);
      expect(tx?.toAccountId, toAcc);
    });

    test('from 和 to 匹配到同一账户 → toAccountId 置空', () async {
      await repo.createCategory(name: '转账', kind: 'expense');
      final acc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '支付宝',
        currency: 'CNY',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 800,
          time: DateTime(2026, 5, 26),
          category: '转账',
          type: BillType.transfer,
          fromAccount: '支付宝',
          toAccount: '支付宝',
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, acc);
      expect(tx?.toAccountId, isNull);
    });

    test('转账场景 fromAccount 缺失,fallback 到 account', () async {
      await repo.createCategory(name: '转账', kind: 'expense');
      final acc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '建行',
        currency: 'CNY',
      );
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 800,
          time: DateTime(2026, 5, 26),
          category: '转账',
          type: BillType.transfer,
          account: '建行', // 没填 fromAccount,用 account 兜底
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, acc);
    });
  });

  // ============================================================
  // 默认账户
  // ============================================================

  group('默认账户', () {
    test('AI 未指定账户 + 已设默认账户(同币种) → 用默认', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      final defaultAcc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '默认支出账户',
        currency: 'CNY',
      );
      SharedPreferences.setMockInitialValues({
        'account_feature_enabled': true,
        'default_expense_account_id': defaultAcc,
      });

      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, defaultAcc);
    });

    test('默认账户币种不匹配 → 不使用', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      final usdAcc = await repo.createAccount(
        ledgerId: ledgerId,
        name: 'USD 账户',
        currency: 'USD',
      );
      SharedPreferences.setMockInitialValues({
        'account_feature_enabled': true,
        'default_expense_account_id': usdAcc,
      });

      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
        ),
        ledgerId: ledgerId, // CNY 账本
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, isNull);
    });

    test('收入和支出的默认账户分开走', () async {
      await repo.createCategory(name: '工资', kind: 'income');
      final incomeAcc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '工资卡',
        currency: 'CNY',
      );
      final expenseAcc = await repo.createAccount(
        ledgerId: ledgerId,
        name: '日常支出卡',
        currency: 'CNY',
      );
      SharedPreferences.setMockInitialValues({
        'account_feature_enabled': true,
        'default_income_account_id': incomeAcc,
        'default_expense_account_id': expenseAcc,
      });

      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: 5000,
          time: DateTime(2026, 5, 26),
          category: '工资',
          type: BillType.income,
        ),
        ledgerId: ledgerId,
      );
      final tx = await repo.getTransactionById(txId!);
      expect(tx?.accountId, incomeAcc);
    });
  });

  // ============================================================
  // 标签关联
  // ============================================================

  group('标签自动添加', () {
    test('billingTypes 自定义标签都不传 → 不挂标签', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
      );
      final tags = await repo.getTagsForTransaction(txId!);
      expect(tags, isEmpty);
    });

    test('customTagNames 传入 → 创建并关联', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
        customTagNames: const ['朋友聚餐', '商务'],
      );
      final tags = await repo.getTagsForTransaction(txId!);
      expect(tags.map((t) => t.name).toSet(),
          containsAll({'朋友聚餐', '商务'}));
    });

    test('BillInfo.tags 也会被作为标签挂上', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
          tags: const ['出差'],
        ),
        ledgerId: ledgerId,
      );
      final tags = await repo.getTagsForTransaction(txId!);
      expect(tags.map((t) => t.name), contains('出差'));
    });

    test('autoAddTags=false → 即使有 customTagNames 也不挂', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      final txId = await service.createFromBill(
        bill: BillInfo(
          amount: -30,
          time: DateTime(2026, 5, 26),
          category: '餐饮',
          type: BillType.expense,
        ),
        ledgerId: ledgerId,
        customTagNames: const ['朋友聚餐'],
        autoAddTags: false,
      );
      final tags = await repo.getTagsForTransaction(txId!);
      expect(tags, isEmpty);
    });
  });
}
