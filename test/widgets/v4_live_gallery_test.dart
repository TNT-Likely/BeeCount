import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/dev/component_gallery/bindings/live_business_preview.dart';
import 'package:beecount/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实数据 binding 从同一 Repository 读取账本、账户、交易与历史折算', () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final local = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id,name,currency) VALUES (1,'真实绑定账本','CNY')");
    final category = await local.createCategory(
        name: '真实分类', kind: 'expense', icon: 'restaurant');
    await local.createSubCategory(
        parentId: category, name: '真实子分类', kind: 'expense', icon: 'restaurant');
    final account = await local.createAccount(
        ledgerId: 1, name: '真实账户', currency: 'CNY', initialBalance: 100);
    await local.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        categoryId: category,
        accountId: account,
        happenedAt: DateTime.now(),
        note: '真实绑定交易',
        currencyCode: 'CNY',
        nativeAmount: 12);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(local),
      accountFeatureEnabledProvider.overrideWith((ref) async => true)
    ]);
    final sub = container.listen(galleryLedgerDataProvider(1), (_, __) {});
    try {
      final value = await container.read(galleryLedgerDataProvider(1).future);
      expect(value.ledger.name, '真实绑定账本');
      expect(
          value.categories.map((c) => c.name), containsAll(['真实分类', '真实子分类']));
      expect(value.accounts.single.name, '真实账户');
      expect(value.balances[account], 88);
      expect(value.rows.single.t.note, '真实绑定交易');
      expect(value.txCount, 1);
      expect(value.rows.single.t.nativeAmount, 12);
      await local.addTransaction(
          ledgerId: 1,
          type: 'income',
          amount: 5,
          accountId: account,
          happenedAt: DateTime.now(),
          note: '第二笔真实交易');
      container.invalidate(galleryLedgerDataProvider(1));
      final updated = await container.read(galleryLedgerDataProvider(1).future);
      expect(updated.txCount, 2);
      expect(updated.balances[account], 93);
      expect(updated.rows.length, 2);
      expect((await local.getCountsForLedger(ledgerId: 1)).txCount, 2);
      final foreign = await local.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 2,
          happenedAt: DateTime.now(),
          note: '历史外币',
          currencyCode: 'USD',
          nativeAmount: 14,
          excludeFromStats: true,
          excludeFromBudget: true);
      final tag = await local.createTag(name: '真实标签', color: '#209C9C');
      await local.updateTransactionTags(transactionId: foreign, tagIds: [tag]);
      await db.customStatement(
          'INSERT INTO transaction_attachments (transaction_id,file_name) VALUES (?,?)',
          [foreign, 'synthetic.png']);
      container.invalidate(galleryLedgerDataProvider(1));
      final withForeign =
          await container.read(galleryLedgerDataProvider(1).future);
      final fx = withForeign.rows.firstWhere((r) => r.t.id == foreign).t;
      expect(fx.currencyCode, 'USD');
      expect(fx.nativeAmount, 14);
      expect(fx.excludeFromStats && fx.excludeFromBudget, isTrue);
      expect(withForeign.tags[foreign]!.single.name, '真实标签');
      expect(withForeign.attachments[foreign], 1);
    } finally {
      sub.close();
      container.dispose();
      await db.close();
    }
  });
  test('切换当前账本 Provider 后读取对应真实行与币种，不混用其他账本', () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id,name,currency) VALUES (1,'生活测试账本','CNY'),(2,'旅行测试账本','USD')");
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime.now(),
        note: '人民币真实交易',
        currencyCode: 'CNY',
        nativeAmount: 12);
    await repo.addTransaction(
        ledgerId: 2,
        type: 'expense',
        amount: 3,
        happenedAt: DateTime.now(),
        note: '美元真实交易',
        currencyCode: 'USD',
        nativeAmount: 3);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      accountFeatureEnabledProvider.overrideWith((ref) async => true)
    ]);
    final current = Provider((ref) => ref
        .watch(galleryLedgerDataProvider(ref.watch(currentLedgerIdProvider))));
    final sub = container.listen(current, (_, __) {});
    try {
      await container.read(galleryLedgerDataProvider(1).future);
      expect(container.read(current).value!.rows.single.t.note, '人民币真实交易');
      container.read(currentLedgerIdProvider.notifier).state = 2;
      await container.read(galleryLedgerDataProvider(2).future);
      final value = container.read(current).value!;
      expect(value.ledger.currency, 'USD');
      expect(value.rows.single.t.note, '美元真实交易');
      expect(value.rows.single.t.nativeAmount, 3);
    } finally {
      sub.close();
      container.dispose();
      await db.close();
    }
  });
}
