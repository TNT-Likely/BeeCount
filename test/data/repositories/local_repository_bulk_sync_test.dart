// LocalRepository 批量方法的变更记录契约测试。
//
// 锁死:
//   - insertTransactionsBatch / clearLedgerTransactions / deleteLedger
//     等批量方法必须为每行实体登记一条 local_changes,SyncEngine 才能把
//     它们推到云端。
//   - changeTracker == null 时(本地 only / 未配置 cloud)不记录、不抛错。
//
// 历史 bug(2026-04 修复前):
//   - CSV 导入交易走 insertTransactionsBatch,但 wrapper 直接 delegate 没
//     登记 local_changes,导入完云端永远拿不到数据。
//   - "清空账本"走 clearLedgerTransactions 裸 SQL bulk delete,UI 调了
//     PostProcessor.sync 但 ChangeTracker 是空的,云端继续保留所有交易。
//   - "删除账本"只登记 ledger_snapshot:delete 一条,级联删除的 transactions
//     没有 transaction:delete 变更。
//
// 这里用 in-memory Drift DB + 真实 ChangeTracker 跑端到端断言。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() async {
    await db.close();
  });

  group('insertTransactionsBatch', () {
    test('为每条插入的交易登记 transaction:create change', () async {
      // 先建账本,batch insert 才能挂在它下面
      final ledgerId = await repo.createLedger(name: 'test');

      final n = await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 10,
        ),
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'income',
          amount: 20,
        ),
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 30,
        ),
      ]);

      expect(n, 3);
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      // ledger 创建本身也会登记一条 ledger:update —— 数据库仓库层 createLedger
      // 走的子仓库直接 insert 没经过 wrapper,所以这里只看到 transaction:create 三条
      final txChanges =
          changes.where((c) => c.entityType == 'transaction').toList();
      expect(txChanges.length, 3);
      for (final c in txChanges) {
        expect(c.action, 'create');
        expect(c.ledgerId, ledgerId);
        expect(c.entitySyncId.isNotEmpty, isTrue);
      }
    });

    test('changeTracker 为 null 时不记录、不抛错', () async {
      final repoNoTracker = LocalRepository(db);
      final ledgerId = await repoNoTracker.createLedger(name: 'no-track');

      final n = await repoNoTracker.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 5,
        ),
      ]);

      expect(n, 1);
      // tracker 还是同一个,但 repoNoTracker 没注入它,所以它看不到任何 change
      final changes = await tracker.getUnpushedChanges();
      expect(changes, isEmpty);
    });

    test('items 已经带 syncId 时复用,不覆盖', () async {
      final ledgerId = await repo.createLedger(name: 'reuse');

      const presetSyncId = 'preset-uuid-123';
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1,
          syncId: const Value(presetSyncId),
        ),
      ]);

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final txChange = changes.firstWhere((c) => c.entityType == 'transaction');
      expect(txChange.entitySyncId, presetSyncId);
    });
  });

  group('clearLedgerTransactions', () {
    test('为每条被清空的交易登记 transaction:delete change', () async {
      final ledgerId = await repo.createLedger(name: 'test');

      // 先插 5 条交易
      await repo.insertTransactionsBatch([
        for (var i = 0; i < 5; i++)
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: i.toDouble(),
          ),
      ]);
      // 清掉之前的 create change,只看 clear 产生的 delete change
      final beforeIds =
          (await tracker.getUnpushedChanges()).map((c) => c.id).toList();
      await tracker.markPushed(beforeIds);

      final n = await repo.clearLedgerTransactions(ledgerId);

      expect(n, 5);
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final deletes = changes
          .where((c) => c.entityType == 'transaction' && c.action == 'delete')
          .toList();
      expect(deletes.length, 5);
    });

    test('changeTracker 为 null 时只删,不记录、不抛错', () async {
      final repoNoTracker = LocalRepository(db);
      final ledgerId = await repoNoTracker.createLedger(name: 'no-track');
      await repoNoTracker.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1,
        ),
      ]);

      final n = await repoNoTracker.clearLedgerTransactions(ledgerId);
      expect(n, 1);
    });
  });

  group('deleteLedger', () {
    test('登记级联 transaction:delete + ledger_snapshot:delete', () async {
      final ledgerId = await repo.createLedger(name: 'test');
      // 取出 ledger.syncId,后面验证 ledger_snapshot:delete 的 entitySyncId
      // 必须等于这个值,不能是 id.toString() —— 否则 server 找不到要删的 ledger。
      final ledgerRow = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      final expectedLedgerSyncId = ledgerRow.syncId!;

      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 100,
        ),
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'income',
          amount: 200,
        ),
      ]);
      // 清掉 create change,只看 delete 后产生的
      final beforeIds =
          (await tracker.getUnpushedChanges()).map((c) => c.id).toList();
      await tracker.markPushed(beforeIds);

      await repo.deleteLedger(ledgerId);

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final txDeletes = changes
          .where((c) => c.entityType == 'transaction' && c.action == 'delete')
          .toList();
      final snapshotDeletes = changes
          .where(
              (c) => c.entityType == 'ledger_snapshot' && c.action == 'delete')
          .toList();

      expect(txDeletes.length, 2, reason: '级联删除的 2 条交易需要登记 transaction:delete');
      expect(snapshotDeletes.length, 1,
          reason: '账本本身需要登记 1 条 ledger_snapshot:delete');
      // 关键修复:必须用 ledger.syncId 作为 entity_sync_id,server 才能按
      // external_id 找到要删的 ledger。之前用 id.toString() 导致云端 ledger
      // 永远删不掉,远端账本列表还显示已删账本。
      expect(snapshotDeletes.first.entitySyncId, expectedLedgerSyncId);
    });
  });

  group('insertTransactionCompanion (单条插入,带标签/附件路径)', () {
    test('登记 transaction:create change(修复带标签交易导入不同步)', () async {
      final ledgerId = await repo.createLedger(name: 'with-tags');

      await repo.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 50,
        ),
      );

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final creates = changes
          .where((c) => c.entityType == 'transaction' && c.action == 'create')
          .toList();
      expect(creates.length, 1,
          reason: 'data_import_service 给带标签/附件的交易走这条单条插入路径,'
              '必须登记 transaction:create change 才能同步到云端');
    });

    test('changeTracker 为 null 时不记录、不抛错', () async {
      final repoNoTracker = LocalRepository(db);
      final ledgerId = await repoNoTracker.createLedger(name: 'no-track');

      await repoNoTracker.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 10,
        ),
      );

      final changes = await tracker.getUnpushedChanges();
      expect(changes, isEmpty);
    });
  });
}
