/// **仅 debug 测试用** — 在本地 DB / 文件系统手动塞各类孤儿数据。
///
/// `OrphanCleanupPage` 在 debug build 的 header actions 露一个 bug 图标按钮,
/// 点一下调 [seedAll],立刻能在清理列表里看到 10+ 项异常,验证 scanner /
/// cleaner / UI 全链路。
///
/// **不要在 release build 调用** — `kDebugMode` 守门,正式包不会暴露入口。
library;

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' as d;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db.dart';
import '../system/logger_service.dart';

class OrphanSeeder {
  OrphanSeeder({required this.db});
  final BeeDatabase db;
  final _rand = Random();

  /// 一键塞 ≥10 项孤儿,覆盖 A/B/C 各大类。返回汇总 log,方便 toast 显示。
  Future<String> seedAll() async {
    final lines = <String>[];
    try {
      lines.add('A1: ${await _seedBudgetMissingLedger()} 个');
      lines.add('A2: ${await _seedAttachmentMissingTx()} 个');
      lines.add('A3/A4: ${await _seedTxTagMissing()} 个');
      lines.add('A5: ${await _seedTxMissingAccount()} 个');
      lines.add('A6: ${await _seedTxMissingCategory()} 个');
      lines.add('A7: ${await _seedCategoryMissingParent()} 个');
      lines.add('A8: ${await _seedBudgetMissingCategory()} 个');
      lines.add('A10: ${await _seedTxTagOverrideMissingTx()} 个');
      lines.add('B1: ${await _seedFileOrphanAttachment()} 个');
      lines.add('B3: ${await _seedFileOrphanSharedIcon()} 个');
      lines.add('C1: ${await _seedLocalChangeMissing()} 个');
    } catch (e, st) {
      logger.error('OrphanSeeder', '种孤儿数据失败', e, st);
      return '失败: $e';
    }
    return lines.join('\n');
  }

  // ────────────── A 类 — 直接绕过级联删主表 ──────────────

  Future<int> _seedBudgetMissingLedger() async {
    final lid = await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: '_seed_ledger_${_rand.nextInt(99999)}',
        syncId: d.Value('seed-l-${_rand.nextInt(99999)}')));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        ledgerId: lid, amount: 123, syncId: const d.Value('seed-b-A1')));
    await (db.delete(db.ledgers)..where((t) => t.id.equals(lid))).go();
    return 1;
  }

  Future<int> _seedAttachmentMissingTx() async {
    final lid = await _ensureLedger();
    final tid = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 9.9,
            happenedAt: d.Value(DateTime.now()),
            syncId: d.Value('seed-tx-${_rand.nextInt(99999)}'),
          ),
        );
    await db.into(db.transactionAttachments).insert(
          TransactionAttachmentsCompanion.insert(
              transactionId: tid, fileName: 'seed_a2.jpg'),
        );
    await (db.delete(db.transactions)..where((t) => t.id.equals(tid))).go();
    return 1;
  }

  Future<int> _seedTxTagMissing() async {
    final lid = await _ensureLedger();
    final tid = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 8.8,
            happenedAt: d.Value(DateTime.now()),
            syncId: d.Value('seed-tx-${_rand.nextInt(99999)}'),
          ),
        );
    final gid = await db.into(db.tags).insert(
          TagsCompanion.insert(
            name: '_seed_tag_${_rand.nextInt(99999)}',
            syncId: d.Value('seed-tag-${_rand.nextInt(99999)}'),
          ),
        );
    // 2 行 transaction_tags: 一行 tx 删 (A3), 一行 tag 删 (A4)
    await db.into(db.transactionTags).insert(
        TransactionTagsCompanion.insert(transactionId: tid, tagId: gid));
    final tid2 = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 8.8,
            happenedAt: d.Value(DateTime.now()),
            syncId: d.Value('seed-tx-${_rand.nextInt(99999)}'),
          ),
        );
    final gid2 = await db.into(db.tags).insert(
          TagsCompanion.insert(
            name: '_seed_tag_${_rand.nextInt(99999)}',
            syncId: d.Value('seed-tag-${_rand.nextInt(99999)}'),
          ),
        );
    await db.into(db.transactionTags).insert(
        TransactionTagsCompanion.insert(transactionId: tid2, tagId: gid2));
    // tid 留着,删 gid → A4;tid2 删 → A3
    await (db.delete(db.tags)..where((t) => t.id.equals(gid))).go();
    await (db.delete(db.transactions)..where((t) => t.id.equals(tid2))).go();
    return 2;
  }

  Future<int> _seedTxMissingAccount() async {
    final lid = await _ensureLedger();
    final accId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(ledgerId: lid, name: '_seed_acc'));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: lid,
          type: 'expense',
          amount: 7.7,
          accountId: d.Value(accId),
          happenedAt: d.Value(DateTime.now()),
          syncId: d.Value('seed-tx-${_rand.nextInt(99999)}'),
        ));
    await (db.delete(db.accounts)..where((t) => t.id.equals(accId))).go();
    return 1;
  }

  Future<int> _seedTxMissingCategory() async {
    final lid = await _ensureLedger();
    final cid = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
            name: '_seed_cat_${_rand.nextInt(99999)}', kind: 'expense'));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: lid,
          type: 'expense',
          amount: 6.6,
          categoryId: d.Value(cid),
          happenedAt: d.Value(DateTime.now()),
          syncId: d.Value('seed-tx-${_rand.nextInt(99999)}'),
        ));
    await (db.delete(db.categories)..where((t) => t.id.equals(cid))).go();
    return 1;
  }

  Future<int> _seedCategoryMissingParent() async {
    final parent = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
            name: '_seed_parent_${_rand.nextInt(99999)}', kind: 'expense'));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '_seed_child_${_rand.nextInt(99999)}',
          kind: 'expense',
          parentId: d.Value(parent),
          level: const d.Value(2),
        ));
    await (db.delete(db.categories)..where((t) => t.id.equals(parent))).go();
    return 1;
  }

  Future<int> _seedBudgetMissingCategory() async {
    final lid = await _ensureLedger();
    final cid = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
            name: '_seed_cat_${_rand.nextInt(99999)}', kind: 'expense'));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: lid,
          amount: 555,
          type: const d.Value('category'),
          categoryId: d.Value(cid),
          syncId: const d.Value('seed-b-A8'),
        ));
    await (db.delete(db.categories)..where((t) => t.id.equals(cid))).go();
    return 1;
  }

  Future<int> _seedTxTagOverrideMissingTx() async {
    final ghostTxSyncId = 'seed-ghost-tx-${_rand.nextInt(99999)}';
    await db.into(db.transactionTagOverrides).insert(
          TransactionTagOverridesCompanion.insert(
            transactionSyncId: ghostTxSyncId,
            tagSyncId: 'seed-tag-syncid-${_rand.nextInt(99999)}',
            createdAt: DateTime.now(),
          ),
        );
    return 1;
  }

  // ────────────── B 类 — 在磁盘塞文件 ──────────────

  Future<int> _seedFileOrphanAttachment() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'attachments'));
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, 'seed_orphan_${_rand.nextInt(99999)}.jpg'));
    await f.writeAsBytes(List.filled(2048, 0));
    return 1;
  }

  Future<int> _seedFileOrphanSharedIcon() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'custom_icons'));
    await dir.create(recursive: true);
    // sha256 风格的假 hash
    final fakeSha =
        List.generate(64, (_) => 'abcdef0123456789'[_rand.nextInt(16)]).join();
    final f = File(p.join(dir.path, 'shared_$fakeSha.png'));
    await f.writeAsBytes(List.filled(1024, 0));
    return 1;
  }

  // ────────────── C 类 ──────────────

  Future<int> _seedLocalChangeMissing() async {
    await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
          entityType: 'transaction',
          entityId: 999990 + _rand.nextInt(1000),
          entitySyncId: 'seed-ghost-tx-c1-${_rand.nextInt(99999)}',
          ledgerId: 1,
          action: 'update',
        ));
    return 1;
  }

  // ────────────── helpers ──────────────

  Future<int> _ensureLedger() async {
    final existing = await (db.select(db.ledgers)..limit(1)).getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: '_seed_holder', syncId: const d.Value('seed-holder')));
  }
}
