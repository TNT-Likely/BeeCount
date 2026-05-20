// OrphanScanner 契约测试 — 各类孤儿场景的检测命中。
//
// 用 in-memory Drift db,setUp 里手动插入"破坏完整性"的行(绕过级联删除路径),
// scan 后检查命中条数。

import 'dart:io';

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/services/maintenance/orphan_record.dart';
import 'package:beecount/services/maintenance/orphan_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late Directory tmp;
  late OrphanScanner scanner;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('orphan_scanner_test_');
    scanner = OrphanScanner(
      db: db,
      attachmentsDirOverride: '${tmp.path}/attachments',
      iconsDirOverride: '${tmp.path}/custom_icons',
    );
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<int> _insertLedger({String name = 'L1', String? syncId}) async {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: name, syncId: d.Value(syncId)));
  }

  Future<int> _insertCategory({
    String name = 'cat',
    String kind = 'expense',
    int? parentId,
    int level = 1,
  }) async {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          name: name,
          kind: kind,
          parentId: d.Value(parentId),
          level: d.Value(level),
        ));
  }

  Future<int> _insertTransaction({
    required int ledgerId,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    String type = 'expense',
    String? syncId,
  }) async {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: type,
          amount: 10.0,
          categoryId: d.Value(categoryId),
          accountId: d.Value(accountId),
          toAccountId: d.Value(toAccountId),
          happenedAt: d.Value(DateTime.now()),
          syncId: d.Value(syncId ?? 'tx-sync'),
        ));
  }

  group('A 类 — DB 孤儿', () {
    test('A1 预算指向已删账本', () async {
      final lid = await _insertLedger();
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
            ledgerId: lid,
            amount: 100,
          ));
      // 绕过 deleteLedger,直接删 ledgers 制造孤儿
      await (db.delete(db.ledgers)..where((t) => t.id.equals(lid))).go();

      final report = await scanner.scanAll();
      expect(report.dbOrphans.where((r) => r.type == OrphanType.budgetMissingLedger)
          .length, 1);
    });

    test('A2 附件行指向已删交易', () async {
      final lid = await _insertLedger();
      final tid = await _insertTransaction(ledgerId: lid);
      await db.into(db.transactionAttachments).insert(
            TransactionAttachmentsCompanion.insert(
              transactionId: tid,
              fileName: 'a.jpg',
            ),
          );
      await (db.delete(db.transactions)..where((t) => t.id.equals(tid))).go();

      final report = await scanner.scanAll();
      expect(report.dbOrphans
          .where((r) => r.type == OrphanType.attachmentMissingTx)
          .length, 1);
    });

    test('A5 tx 失主 account', () async {
      final lid = await _insertLedger();
      final accId = await db.into(db.accounts).insert(
            AccountsCompanion.insert(ledgerId: lid, name: 'A'),
          );
      await _insertTransaction(ledgerId: lid, accountId: accId);
      await (db.delete(db.accounts)..where((t) => t.id.equals(accId))).go();

      final report = await scanner.scanAll();
      final hits = report.dbOrphans
          .where((r) => r.type == OrphanType.txMissingAccount)
          .toList();
      expect(hits.length, 1);
      expect(hits.first.extra?['accountMissing'], true);
      expect(hits.first.extra?['toAccountMissing'], false);
    });

    test('A6 tx 失主 category', () async {
      final lid = await _insertLedger();
      final cid = await _insertCategory();
      await _insertTransaction(ledgerId: lid, categoryId: cid);
      await (db.delete(db.categories)..where((t) => t.id.equals(cid))).go();

      final report = await scanner.scanAll();
      expect(report.dbOrphans.where((r) => r.type == OrphanType.txMissingCategory)
          .length, 1);
    });

    test('A7 二级分类失父', () async {
      final parent = await _insertCategory(name: 'food', level: 1);
      await _insertCategory(name: 'lunch', level: 2, parentId: parent);
      await (db.delete(db.categories)..where((t) => t.id.equals(parent))).go();

      final report = await scanner.scanAll();
      expect(report.dbOrphans
          .where((r) => r.type == OrphanType.categoryMissingParent)
          .length, 1);
    });

    test('A8 预算分类失主', () async {
      final lid = await _insertLedger();
      final cid = await _insertCategory();
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
            ledgerId: lid,
            amount: 50,
            type: const d.Value('category'),
            categoryId: d.Value(cid),
          ));
      await (db.delete(db.categories)..where((t) => t.id.equals(cid))).go();

      final report = await scanner.scanAll();
      expect(report.dbOrphans
          .where((r) => r.type == OrphanType.budgetMissingCategory)
          .length, 1);
    });
  });

  group('B 类 — 文件孤儿', () {
    test('B1 附件原图无引用', () async {
      final dir = Directory('${tmp.path}/attachments');
      await dir.create(recursive: true);
      await File('${dir.path}/orphan.jpg').writeAsBytes([1, 2, 3]);
      // 没在 transaction_attachments 表登记

      final report = await scanner.scanAll();
      final hits = report.fileOrphans
          .where((r) => r.type == OrphanType.fileOrphanAttachment)
          .toList();
      expect(hits.length, 1);
      expect(hits.first.title, 'orphan.jpg');
      expect(hits.first.sizeBytes, 3);
    });

    test('B1 已引用的不算孤儿', () async {
      final lid = await _insertLedger();
      final tid = await _insertTransaction(ledgerId: lid);
      await db.into(db.transactionAttachments).insert(
            TransactionAttachmentsCompanion.insert(
              transactionId: tid,
              fileName: 'used.jpg',
            ),
          );
      final dir = Directory('${tmp.path}/attachments');
      await dir.create(recursive: true);
      await File('${dir.path}/used.jpg').writeAsBytes([1]);

      final report = await scanner.scanAll();
      expect(report.fileOrphans
          .where((r) => r.type == OrphanType.fileOrphanAttachment)
          .length, 0);
    });

    test('B3 共享分类图标缓存无引用', () async {
      final dir = Directory('${tmp.path}/custom_icons');
      await dir.create(recursive: true);
      await File('${dir.path}/shared_abc123.png').writeAsBytes([1]);

      final report = await scanner.scanAll();
      expect(report.fileOrphans
          .where((r) => r.type == OrphanType.fileOrphanSharedIcon)
          .length, 1);
    });
  });

  group('C 类 — 同步孤儿', () {
    test('C1 local_changes 失主实体', () async {
      // unpushed update change,实体不存在
      await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
            entityType: 'transaction',
            entityId: 999,
            entitySyncId: 'ghost-tx',
            ledgerId: 1,
            action: 'update',
          ));

      final report = await scanner.scanAll();
      expect(report.syncOrphans
          .where((r) => r.type == OrphanType.localChangeMissingEntity)
          .length, 1);
    });

    test('delete action 不算孤儿', () async {
      await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
            entityType: 'transaction',
            entityId: 999,
            entitySyncId: 'ghost-tx',
            ledgerId: 1,
            action: 'delete',
          ));

      final report = await scanner.scanAll();
      expect(report.syncOrphans.length, 0);
    });

    test('已 pushed 不算孤儿', () async {
      await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
            entityType: 'transaction',
            entityId: 999,
            entitySyncId: 'pushed-tx',
            ledgerId: 1,
            action: 'update',
            pushedAt: d.Value(DateTime.now()),
          ));

      final report = await scanner.scanAll();
      expect(report.syncOrphans.length, 0);
    });
  });
}
