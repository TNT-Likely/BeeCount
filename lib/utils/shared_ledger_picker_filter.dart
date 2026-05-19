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

import 'package:drift/drift.dart' show OrderingTerm;

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
  Future<List<Account>> filterAccountsForLedger(
    List<Account> all,
    LedgerPickerContext? ctx,
  ) async {
    if (ctx == null || !ctx.isEditorInShared || ctx.ledgerSyncId == null) {
      return all;
    }
    final shared = await (select(sharedLedgerAccounts)
          ..where((t) => t.ledgerSyncId.equals(ctx.ledgerSyncId!)))
        .get();
    return shared.map(_sharedAccountAsMain).toList();
  }

  /// 拿 picker 用的 tags。规则同 categories。
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

