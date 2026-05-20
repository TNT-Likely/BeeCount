/// 本地孤儿数据扫描器。
///
/// 13 个 `scanXxx()` 方法各自独立,只查不改;`scanAll()` 一次跑完返
/// [OrphanScanReport]。逻辑严格按 plan A1..A10 / B1..B3 / C1 实现。
///
/// 注意:
/// - 文件类(B)依赖 `path_provider` 拿 app docs dir,测试时如要替换路径,
///   传入 `iconsDirOverride` / `attachmentsDirOverride`。
/// - DB 类用 Drift `customSelect` + LEFT JOIN,跨 `transaction()` 不必要,
///   纯读不会污染状态。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db.dart';
import '../system/logger_service.dart';
import 'orphan_record.dart';

class OrphanScanner {
  OrphanScanner({
    required this.db,
    this.attachmentsDirOverride,
    this.iconsDirOverride,
  });

  final BeeDatabase db;

  /// 测试用:覆盖附件目录路径。生产环境从 path_provider 拿。
  final String? attachmentsDirOverride;

  /// 测试用:覆盖自定义图标目录路径。
  final String? iconsDirOverride;

  /// 跑全部 13 项检测。
  Future<OrphanScanReport> scanAll() async {
    final dbOrphans = <OrphanRecord>[
      ...await scanBudgetMissingLedger(),
      ...await scanAttachmentMissingTx(),
      ...await scanTxTagMissingTx(),
      ...await scanTxTagMissingTag(),
      ...await scanTxMissingAccount(),
      ...await scanTxMissingCategory(),
      ...await scanCategoryMissingParent(),
      ...await scanBudgetMissingCategory(),
      ...await scanSharedCategoryMissingParent(),
      ...await scanTxTagOverrideMissingTx(),
    ];
    final fileOrphans = <OrphanRecord>[
      ...await scanFileOrphanAttachments(),
      ...await scanFileOrphanCustomIcons(),
      ...await scanFileOrphanSharedIcons(),
    ];
    final syncOrphans = <OrphanRecord>[
      ...await scanLocalChangeMissingEntity(),
    ];
    return OrphanScanReport(
      dbOrphans: dbOrphans,
      fileOrphans: fileOrphans,
      syncOrphans: syncOrphans,
    );
  }

  // ─────────────────────────── A. DB 孤儿 ───────────────────────────

  /// A1 — 预算的 `ledger_id` 在 ledgers 表不存在。
  Future<List<OrphanRecord>> scanBudgetMissingLedger() async {
    final rows = await db.customSelect(
      '''
      SELECT b.id AS budget_id, b.ledger_id, b.type, b.amount, b.sync_id
      FROM budgets b
      LEFT JOIN ledgers l ON l.id = b.ledger_id
      WHERE l.id IS NULL
      ''',
      readsFrom: {db.budgets, db.ledgers},
    ).get();
    return rows.map((row) {
      final budgetId = row.read<int>('budget_id');
      final ledgerId = row.read<int>('ledger_id');
      final amount = row.readNullable<double>('amount') ?? 0;
      final budgetType = row.readNullable<String>('type') ?? 'total';
      return OrphanRecord(
        type: OrphanType.budgetMissingLedger,
        localId: budgetId,
        syncId: row.readNullable<String>('sync_id'),
        title: '预算 #$budgetId',
        subtitle: '$budgetType · ¥${amount.toStringAsFixed(0)} · 账本已删 (ledgerId=$ledgerId)',
      );
    }).toList();
  }

  /// A2 — 附件行的 `transaction_id` 在 transactions 表不存在。
  Future<List<OrphanRecord>> scanAttachmentMissingTx() async {
    final rows = await db.customSelect(
      '''
      SELECT a.id AS att_id, a.transaction_id, a.file_name, a.file_size
      FROM transaction_attachments a
      LEFT JOIN transactions t ON t.id = a.transaction_id
      WHERE t.id IS NULL
      ''',
      readsFrom: {db.transactionAttachments, db.transactions},
    ).get();
    return rows.map((row) {
      final attId = row.read<int>('att_id');
      final txId = row.read<int>('transaction_id');
      final fileName = row.readNullable<String>('file_name') ?? '';
      final size = row.readNullable<int>('file_size');
      return OrphanRecord(
        type: OrphanType.attachmentMissingTx,
        localId: attId,
        title: '附件行 #$attId',
        subtitle: '$fileName · 交易已删 (txId=$txId)',
        sizeBytes: size,
        extra: {'fileName': fileName},
      );
    }).toList();
  }

  /// A3 — `transaction_tags.transaction_id` 在 transactions 表不存在。
  Future<List<OrphanRecord>> scanTxTagMissingTx() async {
    final rows = await db.customSelect(
      '''
      SELECT tt.id AS link_id, tt.transaction_id, tt.tag_id
      FROM transaction_tags tt
      LEFT JOIN transactions t ON t.id = tt.transaction_id
      WHERE t.id IS NULL
      ''',
      readsFrom: {db.transactionTags, db.transactions},
    ).get();
    return rows.map((row) {
      final linkId = row.read<int>('link_id');
      final txId = row.read<int>('transaction_id');
      final tagId = row.read<int>('tag_id');
      return OrphanRecord(
        type: OrphanType.txTagMissingTx,
        localId: linkId,
        title: '标签关联 #$linkId',
        subtitle: '交易已删 (txId=$txId, tagId=$tagId)',
      );
    }).toList();
  }

  /// A4 — `transaction_tags.tag_id` 在 tags 表不存在。
  Future<List<OrphanRecord>> scanTxTagMissingTag() async {
    final rows = await db.customSelect(
      '''
      SELECT tt.id AS link_id, tt.transaction_id, tt.tag_id
      FROM transaction_tags tt
      LEFT JOIN tags g ON g.id = tt.tag_id
      WHERE g.id IS NULL
      ''',
      readsFrom: {db.transactionTags, db.tags},
    ).get();
    return rows.map((row) {
      final linkId = row.read<int>('link_id');
      final txId = row.read<int>('transaction_id');
      final tagId = row.read<int>('tag_id');
      return OrphanRecord(
        type: OrphanType.txTagMissingTag,
        localId: linkId,
        title: '标签关联 #$linkId',
        subtitle: '标签已删 (txId=$txId, tagId=$tagId)',
      );
    }).toList();
  }

  /// A5 — 交易的 `account_id` / `to_account_id` 在 accounts 表不存在。
  ///
  /// Editor 在共享账本下记的 tx,主表 accountId 是 null + override 走 syncId,
  /// 不算孤儿,这里只命中**非 null 的 account_id**。
  Future<List<OrphanRecord>> scanTxMissingAccount() async {
    final rows = await db.customSelect(
      '''
      SELECT t.id AS tx_id, t.amount, t.type,
             t.account_id, t.to_account_id,
             a.id AS a_hit, ta.id AS ta_hit
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      WHERE (t.account_id IS NOT NULL AND a.id IS NULL)
         OR (t.to_account_id IS NOT NULL AND ta.id IS NULL)
      ''',
      readsFrom: {db.transactions, db.accounts},
    ).get();
    return rows.map((row) {
      final txId = row.read<int>('tx_id');
      final amount = row.readNullable<double>('amount') ?? 0;
      final txType = row.readNullable<String>('type') ?? '';
      final accId = row.readNullable<int>('account_id');
      final toAccId = row.readNullable<int>('to_account_id');
      final accHit = row.readNullable<int>('a_hit');
      final toAccHit = row.readNullable<int>('ta_hit');
      final missing = <String>[
        if (accId != null && accHit == null) 'accountId=$accId',
        if (toAccId != null && toAccHit == null) 'toAccountId=$toAccId',
      ].join(', ');
      return OrphanRecord(
        type: OrphanType.txMissingAccount,
        localId: txId,
        title: '交易 #$txId',
        subtitle: '$txType · ¥${amount.toStringAsFixed(2)} · $missing 已删',
        extra: {
          'accountMissing': accId != null && accHit == null,
          'toAccountMissing': toAccId != null && toAccHit == null,
        },
      );
    }).toList();
  }

  /// A6 — 交易的 `category_id` 在 categories 表不存在(非 null)。
  Future<List<OrphanRecord>> scanTxMissingCategory() async {
    final rows = await db.customSelect(
      '''
      SELECT t.id AS tx_id, t.amount, t.type, t.category_id
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.category_id IS NOT NULL AND c.id IS NULL
      ''',
      readsFrom: {db.transactions, db.categories},
    ).get();
    return rows.map((row) {
      final txId = row.read<int>('tx_id');
      final amount = row.readNullable<double>('amount') ?? 0;
      final txType = row.readNullable<String>('type') ?? '';
      final catId = row.read<int>('category_id');
      return OrphanRecord(
        type: OrphanType.txMissingCategory,
        localId: txId,
        title: '交易 #$txId',
        subtitle: '$txType · ¥${amount.toStringAsFixed(2)} · 分类已删 (categoryId=$catId)',
      );
    }).toList();
  }

  /// A7 — 二级分类 `parent_id` 在 categories 表不存在。
  Future<List<OrphanRecord>> scanCategoryMissingParent() async {
    final rows = await db.customSelect(
      '''
      SELECT c.id AS cat_id, c.name, c.parent_id, c.kind
      FROM categories c
      LEFT JOIN categories p ON p.id = c.parent_id
      WHERE c.level = 2 AND c.parent_id IS NOT NULL AND p.id IS NULL
      ''',
      readsFrom: {db.categories},
    ).get();
    return rows.map((row) {
      final catId = row.read<int>('cat_id');
      final name = row.readNullable<String>('name') ?? '';
      final parentId = row.read<int>('parent_id');
      final kind = row.readNullable<String>('kind') ?? '';
      return OrphanRecord(
        type: OrphanType.categoryMissingParent,
        localId: catId,
        title: '二级分类「$name」#$catId',
        subtitle: '$kind · 父分类已删 (parentId=$parentId)',
      );
    }).toList();
  }

  /// A8 — 预算的 `category_id` 在 categories 表不存在(非 null)。
  Future<List<OrphanRecord>> scanBudgetMissingCategory() async {
    final rows = await db.customSelect(
      '''
      SELECT b.id AS budget_id, b.amount, b.type, b.category_id
      FROM budgets b
      LEFT JOIN categories c ON c.id = b.category_id
      WHERE b.category_id IS NOT NULL AND c.id IS NULL
      ''',
      readsFrom: {db.budgets, db.categories},
    ).get();
    return rows.map((row) {
      final budgetId = row.read<int>('budget_id');
      final amount = row.readNullable<double>('amount') ?? 0;
      final budgetType = row.readNullable<String>('type') ?? 'category';
      final catId = row.read<int>('category_id');
      return OrphanRecord(
        type: OrphanType.budgetMissingCategory,
        localId: budgetId,
        title: '预算 #$budgetId',
        subtitle: '$budgetType · ¥${amount.toStringAsFixed(0)} · 分类已删 (categoryId=$catId)',
      );
    }).toList();
  }

  /// A9 — 共享二级分类的 `parent_sync_id` 在同 ledger 的 SharedLedgerCategories
  /// 范围内不存在。复合主键 (ledger_sync_id, sync_id) → 用 NOT IN 子查询。
  Future<List<OrphanRecord>> scanSharedCategoryMissingParent() async {
    final rows = await db.customSelect(
      '''
      SELECT child.ledger_sync_id, child.sync_id, child.name, child.parent_sync_id
      FROM shared_ledger_categories child
      WHERE COALESCE(child.level, 1) = 2
        AND child.parent_sync_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM shared_ledger_categories parent
          WHERE parent.ledger_sync_id = child.ledger_sync_id
            AND parent.sync_id = child.parent_sync_id
            AND COALESCE(parent.level, 1) = 1
        )
      ''',
      readsFrom: {db.sharedLedgerCategories},
    ).get();
    return rows.map((row) {
      final ledgerSyncId = row.read<String>('ledger_sync_id');
      final syncId = row.read<String>('sync_id');
      final name = row.readNullable<String>('name') ?? '';
      final parentSyncId = row.readNullable<String>('parent_sync_id') ?? '';
      return OrphanRecord(
        type: OrphanType.sharedCategoryMissingParent,
        syncId: syncId,
        title: '共享二级分类「$name」',
        subtitle: '父分类已删 (parentSyncId=$parentSyncId)',
        extra: {'ledgerSyncId': ledgerSyncId},
      );
    }).toList();
  }

  /// A10 — `TransactionTagOverrides.transaction_sync_id` 在 transactions 表
  /// 不存在。
  Future<List<OrphanRecord>> scanTxTagOverrideMissingTx() async {
    final rows = await db.customSelect(
      '''
      SELECT o.transaction_sync_id, o.tag_sync_id
      FROM transaction_tag_overrides o
      LEFT JOIN transactions t ON t.sync_id = o.transaction_sync_id
      WHERE t.id IS NULL
      ''',
      readsFrom: {db.transactionTagOverrides, db.transactions},
    ).get();
    return rows.map((row) {
      final txSyncId = row.read<String>('transaction_sync_id');
      final tagSyncId = row.read<String>('tag_sync_id');
      return OrphanRecord(
        type: OrphanType.txTagOverrideMissingTx,
        syncId: txSyncId,
        title: '共享标签 override',
        subtitle: '交易已删 (txSyncId=$txSyncId, tagSyncId=$tagSyncId)',
        extra: {'tagSyncId': tagSyncId},
      );
    }).toList();
  }

  // ─────────────────────────── B. 文件孤儿 ───────────────────────────

  /// B1 — `attachments/` 目录里的文件不在 `transaction_attachments.file_name`。
  Future<List<OrphanRecord>> scanFileOrphanAttachments() async {
    final dir = Directory(await _attachmentsDirPath());
    if (!await dir.exists()) return const [];
    final filesOnDisk = await dir
        .list(followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .toList();
    if (filesOnDisk.isEmpty) return const [];
    final referenced = (await db
            .customSelect(
              'SELECT DISTINCT file_name FROM transaction_attachments',
              readsFrom: {db.transactionAttachments},
            )
            .get())
        .map((r) => r.read<String>('file_name'))
        .toSet();
    final result = <OrphanRecord>[];
    for (final f in filesOnDisk) {
      final name = p.basename(f.path);
      if (referenced.contains(name)) continue;
      int? size;
      try {
        size = await f.length();
      } catch (_) {
        size = null;
      }
      result.add(OrphanRecord(
        type: OrphanType.fileOrphanAttachment,
        title: name,
        subtitle: '附件文件无 DB 引用',
        filePath: f.path,
        sizeBytes: size,
      ));
    }
    return result;
  }

  /// B2 — `custom_icons/<file>` 不在 `categories.custom_icon_path`。
  ///
  /// `custom_icon_path` 存的是相对路径(如 `custom_icons/6_xxx.png`),取
  /// basename 比对磁盘文件名。
  /// 不包括 `shared_<sha>.png`(那是 B3 共享缓存,独立处理)。
  Future<List<OrphanRecord>> scanFileOrphanCustomIcons() async {
    final dir = Directory(await _iconsDirPath());
    if (!await dir.exists()) return const [];
    final filesOnDisk = await dir
        .list(followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .where((f) => !p.basename(f.path).startsWith('shared_'))
        .toList();
    if (filesOnDisk.isEmpty) return const [];
    final referenced = (await db
            .customSelect(
              "SELECT DISTINCT custom_icon_path FROM categories "
              "WHERE custom_icon_path IS NOT NULL AND custom_icon_path != ''",
              readsFrom: {db.categories},
            )
            .get())
        .map((r) => p.basename(r.read<String>('custom_icon_path')))
        .toSet();
    final result = <OrphanRecord>[];
    for (final f in filesOnDisk) {
      final name = p.basename(f.path);
      if (referenced.contains(name)) continue;
      int? size;
      try {
        size = await f.length();
      } catch (_) {
        size = null;
      }
      result.add(OrphanRecord(
        type: OrphanType.fileOrphanCustomIcon,
        title: name,
        subtitle: '分类自定义图标无 DB 引用',
        filePath: f.path,
        sizeBytes: size,
      ));
    }
    return result;
  }

  /// B3 — `custom_icons/shared_<sha>.png` 的 sha 不在
  /// `SharedLedgerCategories.icon_cloud_sha256`。
  Future<List<OrphanRecord>> scanFileOrphanSharedIcons() async {
    final dir = Directory(await _iconsDirPath());
    if (!await dir.exists()) return const [];
    final filesOnDisk = await dir
        .list(followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .where((f) => p.basename(f.path).startsWith('shared_'))
        .toList();
    if (filesOnDisk.isEmpty) return const [];
    final referenced = (await db
            .customSelect(
              "SELECT DISTINCT icon_cloud_sha256 FROM shared_ledger_categories "
              "WHERE icon_cloud_sha256 IS NOT NULL AND icon_cloud_sha256 != ''",
              readsFrom: {db.sharedLedgerCategories},
            )
            .get())
        .map((r) => r.read<String>('icon_cloud_sha256'))
        .toSet();
    final result = <OrphanRecord>[];
    for (final f in filesOnDisk) {
      final name = p.basename(f.path);
      // 解析 shared_<sha>.png
      if (!name.startsWith('shared_')) continue;
      final dotIdx = name.lastIndexOf('.');
      final sha = dotIdx > 7 ? name.substring(7, dotIdx) : name.substring(7);
      if (referenced.contains(sha)) continue;
      int? size;
      try {
        size = await f.length();
      } catch (_) {
        size = null;
      }
      result.add(OrphanRecord(
        type: OrphanType.fileOrphanSharedIcon,
        title: name,
        subtitle: '共享分类图标缓存无 DB 引用',
        filePath: f.path,
        sizeBytes: size,
      ));
    }
    return result;
  }

  // ─────────────────────────── C. 同步孤儿 ───────────────────────────

  /// C1 — `local_changes.entity_sync_id` 对应的本地实体已不存在(且未推送)。
  ///
  /// entity_type 分支:
  /// - transaction → transactions.sync_id
  /// - account → accounts.sync_id
  /// - category → categories.sync_id
  /// - tag → tags.sync_id
  /// - budget → budgets.sync_id
  /// - ledger_snapshot / ledger → ledgers.sync_id
  ///
  /// 注:`action = 'delete'` 的 change 不算孤儿(它的语义就是删除,实体本来该
  /// 不在了)。
  Future<List<OrphanRecord>> scanLocalChangeMissingEntity() async {
    final rows = await db.customSelect(
      '''
      SELECT lc.id AS lc_id, lc.entity_type, lc.entity_sync_id, lc.action,
             lc.created_at
      FROM local_changes lc
      WHERE lc.pushed_at IS NULL
        AND lc.action != 'delete'
        AND NOT EXISTS (
          SELECT 1 FROM transactions t
            WHERE lc.entity_type = 'transaction' AND t.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM accounts a
            WHERE lc.entity_type = 'account' AND a.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM categories c
            WHERE lc.entity_type = 'category' AND c.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM tags g
            WHERE lc.entity_type = 'tag' AND g.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM budgets b
            WHERE lc.entity_type = 'budget' AND b.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM ledgers l
            WHERE lc.entity_type IN ('ledger', 'ledger_snapshot')
              AND l.sync_id = lc.entity_sync_id
        )
      ''',
      readsFrom: {
        db.localChanges,
        db.transactions,
        db.accounts,
        db.categories,
        db.tags,
        db.budgets,
        db.ledgers,
      },
    ).get();
    return rows.map((row) {
      final lcId = row.read<int>('lc_id');
      final entityType = row.read<String>('entity_type');
      final entitySyncId = row.read<String>('entity_sync_id');
      final action = row.read<String>('action');
      return OrphanRecord(
        type: OrphanType.localChangeMissingEntity,
        localId: lcId,
        syncId: entitySyncId,
        title: '同步变更 #$lcId',
        subtitle: '$entityType · $action · 实体已删 (syncId=$entitySyncId)',
      );
    }).toList();
  }

  // ─────────────────────────── helpers ───────────────────────────

  Future<String> _attachmentsDirPath() async {
    if (attachmentsDirOverride != null) return attachmentsDirOverride!;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'attachments');
    } catch (e) {
      logger.warning('OrphanScanner', '解析 attachments 目录失败: $e');
      return '';
    }
  }

  Future<String> _iconsDirPath() async {
    if (iconsDirOverride != null) return iconsDirOverride!;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'custom_icons');
    } catch (e) {
      logger.warning('OrphanScanner', '解析 custom_icons 目录失败: $e');
      return '';
    }
  }
}
