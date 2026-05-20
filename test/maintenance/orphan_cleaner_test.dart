// OrphanCleaner 契约测试 — 验证孤儿被清理 + tx 失主时只清 FK 不删 tx。

import 'dart:io';

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/services/maintenance/orphan_cleaner.dart';
import 'package:beecount/services/maintenance/orphan_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late Directory tmp;
  late OrphanScanner scanner;
  late OrphanCleaner cleaner;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('orphan_cleaner_test_');
    scanner = OrphanScanner(
      db: db,
      attachmentsDirOverride: '${tmp.path}/attachments',
      iconsDirOverride: '${tmp.path}/custom_icons',
    );
    cleaner = OrphanCleaner(db: db);
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('扫到 → 清理 → 重扫为空(A1 + A2 + A7)', () async {
    // A1 — 孤儿预算
    final lid = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'L', syncId: const d.Value('l-sync')));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: lid,
          amount: 100,
        ));
    await (db.delete(db.ledgers)..where((t) => t.id.equals(lid))).go();

    // A2 — 孤儿附件行
    final lid2 = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'L2', syncId: const d.Value('l2-sync')));
    final tid = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid2,
            type: 'expense',
            amount: 5,
            happenedAt: d.Value(DateTime.now()),
            syncId: const d.Value('tx-1'),
          ),
        );
    await db.into(db.transactionAttachments).insert(
          TransactionAttachmentsCompanion.insert(
            transactionId: tid,
            fileName: 'a.jpg',
          ),
        );
    await (db.delete(db.transactions)..where((t) => t.id.equals(tid))).go();

    // A7 — 孤儿二级分类
    final parent = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'food', kind: 'expense'),
        );
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'lunch',
          kind: 'expense',
          parentId: d.Value(parent),
          level: const d.Value(2),
        ));
    await (db.delete(db.categories)..where((t) => t.id.equals(parent))).go();

    final before = await scanner.scanAll();
    expect(before.dbOrphans.length, 3);

    final result = await cleaner.clean(before.dbOrphans);
    expect(result.successCount, 3);
    expect(result.failures, isEmpty);

    final after = await scanner.scanAll();
    expect(after.dbOrphans, isEmpty);
  });

  test('A5 tx 失主 account → 不删 tx,只把 account_id 置 null', () async {
    final lid = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'L', syncId: const d.Value('l-sync')));
    final accId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(ledgerId: lid, name: 'A'));
    final tid = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 5,
            accountId: d.Value(accId),
            happenedAt: d.Value(DateTime.now()),
            syncId: const d.Value('tx-1'),
          ),
        );
    await (db.delete(db.accounts)..where((t) => t.id.equals(accId))).go();

    final before = await scanner.scanAll();
    expect(before.dbOrphans.length, 1);

    await cleaner.clean(before.dbOrphans);

    // tx 本体应仍在
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(tid)))
        .getSingleOrNull();
    expect(tx, isNotNull);
    expect(tx!.accountId, isNull);

    // 重扫无孤儿
    final after = await scanner.scanAll();
    expect(after.dbOrphans, isEmpty);
  });

  test('B1 文件孤儿清理 — 删磁盘文件', () async {
    final dir = Directory('${tmp.path}/attachments');
    await dir.create(recursive: true);
    final f = File('${dir.path}/orphan.jpg');
    await f.writeAsBytes([1, 2, 3]);

    final before = await scanner.scanAll();
    expect(before.fileOrphans.length, 1);

    final result = await cleaner.clean(before.fileOrphans);
    expect(result.successCount, 1);
    expect(await f.exists(), false);

    final after = await scanner.scanAll();
    expect(after.fileOrphans, isEmpty);
  });

  test('C1 local_changes 清理 — 删行', () async {
    await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
          entityType: 'transaction',
          entityId: 999,
          entitySyncId: 'ghost-tx',
          ledgerId: 1,
          action: 'update',
        ));

    final before = await scanner.scanAll();
    expect(before.syncOrphans.length, 1);

    final result = await cleaner.clean(before.syncOrphans);
    expect(result.successCount, 1);

    final after = await scanner.scanAll();
    expect(after.syncOrphans, isEmpty);
  });

  test('空 records 调用 → empty result', () async {
    final result = await cleaner.clean(const []);
    expect(result.successCount, 0);
    expect(result.failures, isEmpty);
  });
}
