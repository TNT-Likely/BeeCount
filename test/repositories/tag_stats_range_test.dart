// #461 标签详情页按 月/年/全部 时间维度筛选:
// getTagStats / watchTransactionsByTag 增加可选 [start, end) 半开区间过滤。
// 共享账本 synthetic tag(负 id)分支同样生效。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart'
    show syntheticIdForSyncId;

void main() {
  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> seedLedger() {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: const Value(1),
        ));
  }

  /// 造一笔带标签的交易,返回交易 id。
  Future<int> seedTaggedTx({
    required int ledgerId,
    required int tagId,
    required DateTime happenedAt,
    String type = 'expense',
    double amount = 100,
    bool excludeFromStats = false,
    String? currencyCode,
    double? nativeAmount,
  }) async {
    final txId = await repo.addTransaction(
      ledgerId: ledgerId,
      type: type,
      amount: amount,
      happenedAt: happenedAt,
      excludeFromStats: excludeFromStats,
      currencyCode: currencyCode,
      nativeAmount: nativeAmount,
    );
    await repo.addTagToTransaction(transactionId: txId, tagId: tagId);
    return txId;
  }

  test('getTagStats 带 [start,end) 只统计范围内交易,边界半开', () async {
    final lid = await seedLedger();
    final tagId = await repo.createTag(name: '旅行');

    // 范围外(5 月末)
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 5, 31), amount: 1);
    // == start,应计入
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 6, 1), amount: 10);
    // 范围内收入
    await seedTaggedTx(
        ledgerId: lid,
        tagId: tagId,
        happenedAt: DateTime(2026, 6, 15),
        type: 'income',
        amount: 200);
    // == end,不计入
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 7, 1), amount: 1000);

    final stats = await repo.getTagStats(
      tagId,
      ledgerId: lid,
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 7, 1),
    );

    expect(stats.count, 2);
    expect(stats.expense, 10.0);
    expect(stats.income, 200.0);
  });

  test('getTagStats 不带范围仍返回全量(回归)', () async {
    final lid = await seedLedger();
    final tagId = await repo.createTag(name: '旅行');
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2006, 1, 1), amount: 7);
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 6, 1), amount: 3);

    final stats = await repo.getTagStats(tagId, ledgerId: lid);

    expect(stats.count, 2);
    expect(stats.expense, 10.0);
  });

  test('getTagStats 范围内 excludeFromStats 金额仍被排除,笔数照常', () async {
    final lid = await seedLedger();
    final tagId = await repo.createTag(name: '旅行');
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 6, 2), amount: 100);
    await seedTaggedTx(
        ledgerId: lid,
        tagId: tagId,
        happenedAt: DateTime(2026, 6, 3),
        amount: 500,
        excludeFromStats: true);

    final stats = await repo.getTagStats(
      tagId,
      ledgerId: lid,
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 7, 1),
    );

    expect(stats.count, 2);
    expect(stats.expense, 100.0);
  });

  test('watchTransactionsByTag 带 [start,end) 只返回范围内交易', () async {
    final lid = await seedLedger();
    final tagId = await repo.createTag(name: '旅行');
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 5, 31));
    final inRangeId = await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 6, 15));
    await seedTaggedTx(
        ledgerId: lid, tagId: tagId, happenedAt: DateTime(2026, 7, 1));

    final list = await repo
        .watchTransactionsByTag(
          tagId,
          ledgerId: lid,
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 7, 1),
        )
        .first;

    expect(list.map((t) => t.id).toList(), [inRangeId]);
  });

  test('watchTransactionsByTag 返回完整字段(currencyCode/nativeAmount)', () async {
    final lid = await seedLedger();
    final tagId = await repo.createTag(name: '旅行');
    await seedTaggedTx(
      ledgerId: lid,
      tagId: tagId,
      happenedAt: DateTime(2026, 6, 15),
      amount: 100,
      currencyCode: 'USD',
      nativeAmount: 720,
    );

    final list = await repo.watchTransactionsByTag(tagId, ledgerId: lid).first;

    expect(list, hasLength(1));
    expect(list.single.currencyCode, 'USD');
    expect(list.single.nativeAmount, 720.0);
  });

  group('共享账本 synthetic tag', () {
    const ledgerSyncId = 'ledger-ext-1';
    const tagSyncId = 'tag-s1';

    Future<int> seedSharedLedger() async {
      final lid = await db.into(db.ledgers).insert(LedgersCompanion.insert(
            name: '共享账本',
            type: const Value('shared'),
            syncId: const Value(ledgerSyncId),
            myRole: const Value('editor'),
            isShared: const Value(true),
          ));
      await db.into(db.sharedLedgerTags).insert(SharedLedgerTagsCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            syncId: tagSyncId,
            name: '共享标签',
            updatedAt: DateTime.utc(2026, 1, 1),
          ));
      return lid;
    }

    Future<void> seedSharedTx({
      required int ledgerId,
      required String txSyncId,
      required DateTime happenedAt,
      double amount = 100,
    }) async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: amount,
            happenedAt: Value(happenedAt),
            syncId: Value(txSyncId),
          ));
      await db
          .into(db.transactionTagOverrides)
          .insert(TransactionTagOverridesCompanion.insert(
            transactionSyncId: txSyncId,
            tagSyncId: tagSyncId,
            createdAt: DateTime.utc(2026, 1, 1),
          ));
    }

    test('getTagStats 对 synthetic tag 同样按范围过滤', () async {
      final lid = await seedSharedLedger();
      await seedSharedTx(
          ledgerId: lid,
          txSyncId: 'tx-1',
          happenedAt: DateTime(2026, 6, 10),
          amount: 30);
      await seedSharedTx(
          ledgerId: lid,
          txSyncId: 'tx-2',
          happenedAt: DateTime(2026, 7, 10),
          amount: 500);

      final synthId = syntheticIdForSyncId(tagSyncId);
      final stats = await repo.getTagStats(
        synthId,
        ledgerId: lid,
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
      );

      expect(stats.count, 1);
      expect(stats.expense, 30.0);
    });

    test('watchTransactionsByTag 对 synthetic tag 同样按范围过滤', () async {
      final lid = await seedSharedLedger();
      await seedSharedTx(
          ledgerId: lid, txSyncId: 'tx-1', happenedAt: DateTime(2026, 6, 10));
      await seedSharedTx(
          ledgerId: lid, txSyncId: 'tx-2', happenedAt: DateTime(2026, 7, 10));

      final synthId = syntheticIdForSyncId(tagSyncId);
      final list = await repo
          .watchTransactionsByTag(
            synthId,
            ledgerId: lid,
            start: DateTime(2026, 6, 1),
            end: DateTime(2026, 7, 1),
          )
          .first;

      expect(list.map((t) => t.syncId).toList(), ['tx-1']);
    });
  });
}
