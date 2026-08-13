// 共享账本 Editor「最近使用」标签取数契约测试(#443)。
//
// 锁死三件事:
// 1. Editor 的 recent 从 transaction_tag_overrides 取,不是主表 transaction_tags
//    (主表在 Editor 下永远空)。
// 2. recent 是真子集 —— 不能退化成 filterTagsForLedger 的全量 mirror,否则
//    「最近使用」跟「全部标签」一模一样。
// 3. synthetic id 与 filterTagsForLedger 同口径,picker 选中态才不会错位。

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;

  const ledgerSyncId = 'ledger-ext-1';
  const otherLedgerSyncId = 'ledger-ext-2';
  late int ledgerId;
  late int otherLedgerId;

  /// 造一条 Editor 视角的 tx(categoryId/accountId 留空,只关心 tag override)。
  Future<void> insertTx({
    required int inLedgerId,
    required String syncId,
    required DateTime happenedAt,
    required List<String> tagSyncIds,
  }) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: inLedgerId,
          type: 'expense',
          amount: 10.0,
          happenedAt: Value(happenedAt),
          syncId: Value(syncId),
        ));
    for (final tagSyncId in tagSyncIds) {
      await db
          .into(db.transactionTagOverrides)
          .insert(TransactionTagOverridesCompanion.insert(
            transactionSyncId: syncId,
            tagSyncId: tagSyncId,
            createdAt: happenedAt,
          ));
    }
  }

  Future<void> insertMirrorTag(String ledger, String syncId, String name) {
    return db.into(db.sharedLedgerTags).insert(
          SharedLedgerTagsCompanion.insert(
            ledgerSyncId: ledger,
            syncId: syncId,
            name: name,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    ledgerId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '共享账本',
          type: const Value('shared'),
          syncId: const Value(ledgerSyncId),
          myRole: const Value('editor'),
          isShared: const Value(true),
        ));
    otherLedgerId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '另一个共享账本',
          type: const Value('shared'),
          syncId: const Value(otherLedgerSyncId),
          myRole: const Value('editor'),
          isShared: const Value(true),
        ));
    // mirror:5 个标签,其中只有一部分会被 tx 用到
    for (var i = 1; i <= 5; i++) {
      await insertMirrorTag(ledgerSyncId, 'tag-$i', '标签$i');
    }
  });

  tearDown(() async {
    await db.close();
  });

  test('Editor 的最近使用只含真正用过的标签,不等于全量 mirror', () async {
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-1',
      happenedAt: DateTime.utc(2026, 8, 1),
      tagSyncIds: ['tag-2'],
    );
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-2',
      happenedAt: DateTime.utc(2026, 8, 3),
      tagSyncIds: ['tag-4'],
    );

    final recent = await db.recentSharedTagsForLedger(
      ledgerId: ledgerId,
      ledgerSyncId: ledgerSyncId,
    );
    final ctx = await db.loadLedgerPickerContext(ledgerId);
    final all = await db.filterTagsForLedger(const [], ctx);

    // 最近使用:按 happened_at 倒序 → tag-4 在前
    expect(recent.map((t) => t.name).toList(), ['标签4', '标签2']);
    // 全部标签仍是全量 5 个 —— 两个区块内容必须不同(#443 的核心症状)
    expect(all.length, 5);
    expect(recent.length, lessThan(all.length));
  });

  test('synthetic id 与 filterTagsForLedger 同口径(选中态不错位)', () async {
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-1',
      happenedAt: DateTime.utc(2026, 8, 1),
      tagSyncIds: ['tag-3'],
    );

    final recent = await db.recentSharedTagsForLedger(
      ledgerId: ledgerId,
      ledgerSyncId: ledgerSyncId,
    );
    final ctx = await db.loadLedgerPickerContext(ledgerId);
    final all = await db.filterTagsForLedger(const [], ctx);

    final fromAll = all.firstWhere((t) => t.syncId == 'tag-3');
    expect(recent.single.id, fromAll.id);
    expect(recent.single.id, syntheticIdForSyncId('tag-3'));
    expect(recent.single.id, isNegative);
  });

  test('同一标签多次使用只出现一次,按最后一次使用时间排序', () async {
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-1',
      happenedAt: DateTime.utc(2026, 8, 1),
      tagSyncIds: ['tag-1'],
    );
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-2',
      happenedAt: DateTime.utc(2026, 8, 2),
      tagSyncIds: ['tag-2'],
    );
    // tag-1 又用了一次,时间最新 → 应排到最前
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-3',
      happenedAt: DateTime.utc(2026, 8, 5),
      tagSyncIds: ['tag-1'],
    );

    final recent = await db.recentSharedTagsForLedger(
      ledgerId: ledgerId,
      ledgerSyncId: ledgerSyncId,
    );
    expect(recent.map((t) => t.name).toList(), ['标签1', '标签2']);
  });

  test('limit 生效', () async {
    for (var i = 1; i <= 5; i++) {
      await insertTx(
        inLedgerId: ledgerId,
        syncId: 'tx-$i',
        happenedAt: DateTime.utc(2026, 8, i),
        tagSyncIds: ['tag-$i'],
      );
    }
    final recent = await db.recentSharedTagsForLedger(
      ledgerId: ledgerId,
      ledgerSyncId: ledgerSyncId,
      limit: 2,
    );
    expect(recent.map((t) => t.name).toList(), ['标签5', '标签4']);
  });

  test('其它账本用过的标签不混进来', () async {
    await insertMirrorTag(otherLedgerSyncId, 'tag-9', '别的账本标签');
    await insertTx(
      inLedgerId: otherLedgerId,
      syncId: 'tx-other',
      happenedAt: DateTime.utc(2026, 8, 9),
      tagSyncIds: ['tag-9'],
    );
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-mine',
      happenedAt: DateTime.utc(2026, 8, 1),
      tagSyncIds: ['tag-1'],
    );

    final recent = await db.recentSharedTagsForLedger(
      ledgerId: ledgerId,
      ledgerSyncId: ledgerSyncId,
    );
    expect(recent.map((t) => t.name).toList(), ['标签1']);
  });

  test('mirror 未到齐时跳过查不到的 syncId,全查不到则返回空', () async {
    await insertTx(
      inLedgerId: ledgerId,
      syncId: 'tx-1',
      happenedAt: DateTime.utc(2026, 8, 1),
      tagSyncIds: ['tag-not-mirrored-yet'],
    );

    final recent = await db.recentSharedTagsForLedger(
      ledgerId: ledgerId,
      ledgerSyncId: ledgerSyncId,
    );
    expect(recent, isEmpty);
  });

  test('没有任何 override 关联时返回空(区块自然隐藏)', () async {
    final recent = await db.recentSharedTagsForLedger(
      ledgerId: ledgerId,
      ledgerSyncId: ledgerSyncId,
    );
    expect(recent, isEmpty);
  });
}
