// #443 回归:共享账本 Editor 的「最近使用」标签不能等于「全部标签」。
//
// 旧实现把 getRecentlyUsedTags 的子集喂给 filterTagsForLedger,后者在 Editor
// 分支整个丢弃入参、返回全量 mirror,于是两个区块内容一字不差。本测试直接比对
// recentTagsForCurrentLedgerProvider 与 tagsForCurrentLedgerProvider 的结果。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/tag_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  ProviderContainer containerFor(int ledgerId) {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => ledgerId),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('共享账本 Editor:最近使用是真子集,不等于全部标签', () async {
    const ledgerSyncId = 'ledger-ext-1';
    final ledgerId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '共享账本',
          type: const Value('shared'),
          syncId: const Value(ledgerSyncId),
          myRole: const Value('editor'),
          isShared: const Value(true),
        ));
    // Owner mirror 下来 4 个标签
    for (var i = 1; i <= 4; i++) {
      await db.into(db.sharedLedgerTags).insert(
            SharedLedgerTagsCompanion.insert(
              ledgerSyncId: ledgerSyncId,
              syncId: 'tag-$i',
              name: '标签$i',
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    }
    // Editor 只用过其中 1 个(关联落在 override 表,不在主表 transaction_tags)
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 12.0,
          happenedAt: Value(DateTime.utc(2026, 8, 1)),
          syncId: const Value('tx-1'),
        ));
    await db
        .into(db.transactionTagOverrides)
        .insert(TransactionTagOverridesCompanion.insert(
          transactionSyncId: 'tx-1',
          tagSyncId: 'tag-3',
          createdAt: DateTime.utc(2026, 8, 1),
        ));

    final c = containerFor(ledgerId);
    final recent = await c.read(recentTagsForCurrentLedgerProvider.future);
    final all = await c.read(tagsForCurrentLedgerProvider.future);

    expect(all.map((t) => t.name).toList(), ['标签1', '标签2', '标签3', '标签4']);
    expect(recent.map((t) => t.name).toList(), ['标签3']);
    // 修复前这两行是相等的 —— 「最近使用」被放大成了全量 mirror
    expect(recent.map((t) => t.id).toList(),
        isNot(equals(all.map((t) => t.id).toList())));
    // synthetic id 口径与「全部标签」一致,picker 选中态才对得上
    expect(recent.single.id, all.firstWhere((t) => t.syncId == 'tag-3').id);
  });

  test('单人账本:仍走主表 transaction_tags 的最近使用', () async {
    final ledgerId = await db
        .into(db.ledgers)
        .insert(LedgersCompanion.insert(name: '我的账本'));
    final tagUsed = await repo.createTag(name: '用过的');
    await repo.createTag(name: '没用过的');
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 8.0,
            happenedAt: Value(DateTime.utc(2026, 8, 2)),
            syncId: const Value('tx-personal'),
          ),
        );
    await repo.updateTransactionTags(transactionId: txId, tagIds: [tagUsed]);

    final c = containerFor(ledgerId);
    final recent = await c.read(recentTagsForCurrentLedgerProvider.future);
    expect(recent.map((t) => t.name).toList(), ['用过的']);
  });
}
