/// 共享账本 picker 过滤工具(v25 重写)。
///
/// §7 决策最终方案:**不 mirror 主表**,SharedLedger{Categories,Accounts,Tags}
/// 是 Editor 在共享账本下使用的唯一源。
///
/// picker 数据源策略:
/// - **单人账本 / Owner 视角**:直接读主表(本来就是用户自己 user-global)。
/// - **共享账本 + Editor 视角**:**完全替换** — 主表内容丢弃,把
///   SharedLedger* 行转 synthetic Category/Account/Tag 返回,id 用负数
///   (`-syncId.hashCode`)避免跟本地 int 冲突。
///   tx 写入时调用方判断 if (selected.id < 0) → 写 override 字段。
///
/// Synthetic id 规则:`_syntheticIdForSyncId(syncId)` 一律负数,稳定可复现。
library;

import 'package:drift/drift.dart' show OrderingTerm, Variable;

import '../data/db.dart';

/// 由 syncId 字符串稳定地派生一个负数 int,用作 synthetic Category/Account/Tag
/// 的本地 id。负数避开 Drift autoIncrement(始终正数),所以"id < 0"是 picker
/// 选项来自 SharedLedger* 的可靠标识。
///
/// 用 hashCode 做基础,clamp 到非零负数。极小概率不同 syncId 哈希冲突,UI 选中
/// 后实际用 syncId 字符串走 override 路径,所以即使 id 重复也不破坏数据正确性。
int syntheticIdForSyncId(String syncId) {
  final h = syncId.hashCode;
  if (h == 0) return -1;
  return h > 0 ? -h : h;
}

/// 当前 ledger 上下文 — 由 picker 调用方解析后传入。
class LedgerPickerContext {
  const LedgerPickerContext({
    required this.ledgerSyncId,
    required this.isShared,
    required this.myRole,
  });

  /// 当前 ledger 的 server external_id(syncId)。null 时不过滤(单人账本兜底)。
  final String? ledgerSyncId;
  final bool isShared;
  final String myRole;

  bool get isEditorInShared => isShared && myRole != 'owner';
}

extension SharedLedgerPickerFilter on BeeDatabase {
  /// 从本地 ledgers 表解析当前 ledger 的 picker 上下文。
  Future<LedgerPickerContext?> loadLedgerPickerContext(int? ledgerId) async {
    if (ledgerId == null) return null;
    final l = await (select(ledgers)..where((t) => t.id.equals(ledgerId)))
        .getSingleOrNull();
    if (l == null) return null;
    return LedgerPickerContext(
      ledgerSyncId: l.syncId,
      isShared: l.isShared,
      myRole: l.myRole,
    );
  }

  /// 拿 picker 用的 categories:Editor + 共享账本 → SharedLedger* 转 synthetic;
  /// 单人账本 / Owner → 主表 raw 数据。
  ///
  /// 调用方传入主表 raw `all`(`repo.getTopLevelCategories(...)` 拉的),
  /// 本方法决定保留 / 替换。`kind` 传非空时,SharedLedger* 数据按 kind 过滤
  /// (income/expense/transfer),跟 raw 调用 getTopLevelCategories(kind) 对齐。
  ///
  /// `topLevelOnly`:true 时(默认)只返 level=1,跟 mobile 主表 getTopLevel
  /// Categories 语义一致;false 时返所有,给二级分类反查用。
  Future<List<Category>> filterCategoriesForLedger(
    List<Category> all,
    LedgerPickerContext? ctx, {
    String? kind,
    bool topLevelOnly = true,
  }) async {
    if (ctx == null || !ctx.isEditorInShared || ctx.ledgerSyncId == null) {
      return all;
    }
    // Editor + 共享账本 — 用 SharedLedger* 数据替换主表数据
    final q = select(sharedLedgerCategories)
      ..where((t) => t.ledgerSyncId.equals(ctx.ledgerSyncId!))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    if (kind != null && kind.isNotEmpty) {
      q.where((t) => t.kind.equals(kind));
    }
    if (topLevelOnly) {
      q.where((t) => t.level.equals(1));
    }
    final shared = await q.get();
    return shared.map(_sharedCategoryAsMain).toList();
  }

  /// 共享账本下,根据 synthetic 父分类 id 反查 level=2 子分类。
  /// `parentSyntheticId` 是 picker 上呈现的负 int(syntheticIdForSyncId 派生)。
  ///
  /// 实现:扫 SharedLedgerCategories,先找到 syntheticIdForSyncId(syncId) ==
  /// parentSyntheticId 的父行拿到 parent syncId,再按 parent_sync_id 反查子行。
  Future<List<Category>> getSharedSubCategoriesBySyntheticParentId(
      int parentSyntheticId, String ledgerSyncId) async {
    final all = await (select(sharedLedgerCategories)
          ..where((t) => t.ledgerSyncId.equals(ledgerSyncId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    String? parentSyncId;
    for (final s in all) {
      if (syntheticIdForSyncId(s.syncId) == parentSyntheticId) {
        parentSyncId = s.syncId;
        break;
      }
    }
    if (parentSyncId == null) return const [];
    return all
        .where((c) => c.parentSyncId == parentSyncId)
        .map(_sharedCategoryAsMain)
        .toList();
  }

  /// 拿 picker 用的 accounts。规则同 categories。
  ///
  /// 账户隐藏(#240):单人账本 / Owner 视角(早退分支)排除 `hidden` 账户 ——
  /// 该分支返回的是主表 raw 账户,记账 [AccountSelector] 与转账 [transfer_form]
  /// 共用本方法,一处生效两处。共享账本 Editor 分支(SharedLedgerAccounts 镜像)
  /// 没有 hidden 概念(隐藏是 Owner 侧个人状态,不随镜像同步),不过滤。
  /// 编辑历史交易时"钉住"已隐藏账户(E1)留给调用方在拿到结果后自行补回,本
  /// 方法不感知调用场景。
  Future<List<Account>> filterAccountsForLedger(
    List<Account> all,
    LedgerPickerContext? ctx,
  ) async {
    if (ctx == null || !ctx.isEditorInShared || ctx.ledgerSyncId == null) {
      return all.where((a) => !a.hidden).toList();
    }
    final shared = await (select(sharedLedgerAccounts)
          ..where((t) => t.ledgerSyncId.equals(ctx.ledgerSyncId!)))
        .get();
    return shared.map(_sharedAccountAsMain).toList();
  }

  /// 拿 picker 用的 tags。规则同 categories。
  ///
  /// ⚠️ Editor 分支**整个丢弃入参 `all`**、返回该账本的全量 mirror tags —— 这是
  /// "完全替换"语义(见文件头 §7),所以 `all` 只能传主表**全量**列表。传子集
  /// (如「最近使用」的 10 条)会被静默放大成全量,#443 就是这么来的:
  /// 「最近使用」区块拿到了跟「全部标签」一模一样的内容。子集场景请改用
  /// [recentSharedTagsForLedger] 这类专用取数。
  Future<List<Tag>> filterTagsForLedger(
    List<Tag> all,
    LedgerPickerContext? ctx,
  ) async {
    if (ctx == null || !ctx.isEditorInShared || ctx.ledgerSyncId == null) {
      return all;
    }
    final shared = await (select(sharedLedgerTags)
          ..where((t) => t.ledgerSyncId.equals(ctx.ledgerSyncId!)))
        .get();
    return shared.map(_sharedTagAsMain).toList();
  }

  /// 共享账本 Editor 视角的「最近使用」tags(#443)。
  ///
  /// 不能复用 `getRecentlyUsedTags`:那边查的是 `tags` ⨝ `transaction_tags` 主表
  /// 关联,而 Editor 记账时 tag 关联落在 [TransactionTagOverrides](按
  /// `tag_sync_id`),主表里一条都没有 —— 直接用会永远是空。
  ///
  /// 这里从 override 表 join **当前账本**的 transactions,按 `MAX(happened_at)`
  /// 取最近 [limit] 个 `tag_sync_id`,再用 SharedLedgerTags 映射成 synthetic
  /// Tag。映射复用 [_sharedTagAsMain],保证 id 口径与 [filterTagsForLedger] 返回
  /// 的「全部标签」一致 —— picker 的选中态是按 `tag.id` 比的,口径不一致会错位。
  ///
  /// mirror 还没到齐(pull 未完成)导致某个 syncId 查不到时跳过该条;全都查不到
  /// 就返回空列表,调用方 tag_selector 已有 `recentTags.isEmpty →
  /// SizedBox.shrink()`,区块会自然隐藏。
  Future<List<Tag>> recentSharedTagsForLedger({
    required int ledgerId,
    required String ledgerSyncId,
    int limit = 10,
  }) async {
    final rows = await customSelect(
      '''
      SELECT o.tag_sync_id AS tag_sync_id, MAX(tx.happened_at) AS last_used
      FROM transaction_tag_overrides o
      INNER JOIN transactions tx ON tx.sync_id = o.transaction_sync_id
      WHERE tx.ledger_id = ?
      GROUP BY o.tag_sync_id
      ORDER BY last_used DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(ledgerId), Variable.withInt(limit)],
      readsFrom: {transactionTagOverrides, transactions, sharedLedgerTags},
    ).get();
    if (rows.isEmpty) return const [];
    final orderedSyncIds = [
      for (final r in rows) r.read<String>('tag_sync_id'),
    ];
    final mirror = await (select(sharedLedgerTags)
          ..where((t) => t.ledgerSyncId.equals(ledgerSyncId))
          ..where((t) => t.syncId.isIn(orderedSyncIds)))
        .get();
    final bySyncId = {for (final t in mirror) t.syncId: t};
    return [
      for (final syncId in orderedSyncIds)
        if (bySyncId[syncId] != null) _sharedTagAsMain(bySyncId[syncId]!),
    ];
  }

  /// 把 SharedLedgerCategory 转成 Category(synthetic id < 0,syncId 来自 Owner)。
  /// parent_sync_id 非空时,parentId = syntheticIdForSyncId(parent_sync_id),让
  /// picker 能识别 level=2 子分类的父级。
  Category _sharedCategoryAsMain(SharedLedgerCategory c) {
    return Category(
      id: syntheticIdForSyncId(c.syncId),
      name: c.name,
      kind: c.kind,
      icon: c.icon,
      sortOrder: c.sortOrder,
      parentId: (c.parentSyncId != null && c.parentSyncId!.isNotEmpty)
          ? syntheticIdForSyncId(c.parentSyncId!)
          : null,
      level: c.level,
      iconType: c.iconType,
      customIconPath: c.iconType == 'custom' && c.iconCloudSha256 != null
          ? 'custom_icons/shared_${c.iconCloudSha256}.png'
          : null,
      communityIconId: null,
      syncId: c.syncId,
    );
  }

  Account _sharedAccountAsMain(SharedLedgerAccount a) {
    return Account(
      id: syntheticIdForSyncId(a.syncId),
      ledgerId: 0,
      name: a.name,
      type: a.accountType,
      currency: a.currency,
      initialBalance: a.initialBalance ?? 0.0,
      createdAt: null,
      updatedAt: null,
      sortOrder: 0,
      creditLimit: a.creditLimit,
      billingDay: a.billingDay,
      paymentDueDay: a.paymentDueDay,
      bankName: a.bankName,
      cardLastFour: a.cardLastFour,
      note: a.note,
      syncId: a.syncId,
      // SharedLedgerAccounts 镜像表没有 hidden 概念(隐藏是 Owner 侧个人状态,
      // 不随共享账本镜像同步),synthetic 账户固定按「未隐藏」处理。
      hidden: false,
    );
  }

  Tag _sharedTagAsMain(SharedLedgerTag t) {
    return Tag(
      id: syntheticIdForSyncId(t.syncId),
      name: t.name,
      color: t.color,
      sortOrder: 0,
      createdAt: DateTime.now(),
      syncId: t.syncId,
    );
  }

  /// 按 synthetic id 反查 Category — 给 tx editor "initial selected" 用。
  /// 正数 id → 主表 Categories;负数 id → 扫 SharedLedgerCategories 找
  /// syntheticIdForSyncId 命中。
  Future<Category?> findCategoryBySyntheticId(int id) async {
    if (id >= 0) {
      return (select(categories)..where((c) => c.id.equals(id)))
          .getSingleOrNull();
    }
    final all = await select(sharedLedgerCategories).get();
    for (final s in all) {
      if (syntheticIdForSyncId(s.syncId) == id) {
        return _sharedCategoryAsMain(s);
      }
    }
    return null;
  }

  /// 按 synthetic id 反查 Account。
  Future<Account?> findAccountBySyntheticId(int id) async {
    if (id >= 0) {
      return (select(accounts)..where((a) => a.id.equals(id)))
          .getSingleOrNull();
    }
    final all = await select(sharedLedgerAccounts).get();
    for (final s in all) {
      if (syntheticIdForSyncId(s.syncId) == id) {
        return _sharedAccountAsMain(s);
      }
    }
    return null;
  }
}

