import 'dart:convert';

import '../../data/db.dart';

/// 实体序列化工具
/// 将本地 Drift 实体转为 JSON payload（用于 sync push）
/// 以及从 JSON payload 还原为本地实体
class EntitySerializer {
  // ==================== Transaction ====================

  static Map<String, dynamic> serializeTransaction(
    Transaction tx, {
    String? categoryName,
    String? categoryKind,
    String? categorySyncId,
    String? accountName,
    String? accountSyncId,
    String? fromAccountName,
    String? fromAccountSyncId,
    String? toAccountName,
    String? toAccountSyncId,
    String? ledgerSyncId,
    List<String>? tagNames,
    List<String>? tagSyncIds,
    List<Map<String, dynamic>>? attachments,
  }) {
    // 同时带 *Name 和 *Id（syncId）到服务端。服务端的 read 会优先按 id 反查
    // snapshot 里当前 entity 的名字，名字字段只作为历史/兼容兜底。这样任何
    // 实体重命名都不依赖"每个引用位点的 cascade 改写"，兑现"按 id 取实时
    // 名字"的承诺。
    //
    // ledgerSyncId 是跨设备关键：change log 外层的 ledger_id 是推送方的本地
    // int id，对端设备可能匹配不上；payload 里带上 ledger 的 syncId，对端
    // apply 时能先按 syncId 找到本地账本，再用 int id 兜底。
    return {
      'syncId': tx.syncId,
      'type': tx.type,
      'amount': tx.amount,
      'happenedAt': tx.happenedAt.toUtc().toIso8601String(),
      'note': tx.note,
      if (ledgerSyncId != null && ledgerSyncId.isNotEmpty)
        'ledgerSyncId': ledgerSyncId,
      'categoryName': categoryName,
      'categoryKind': categoryKind,
      if (categorySyncId != null && categorySyncId.isNotEmpty)
        'categoryId': categorySyncId,
      // null 时用空串而不是省略字段 / null。server _merge_from_spec 过滤
      // None 不过滤空串,空串到 upsert_tx 里 _as_str("") → None,projection
      // 写 NULL。这是"用户在 mobile 选'不选账户'/'清空账户'"能传达给 server
      // 的唯一路径 — 字段省略 / None 都会被 merge 视为"不更新",老 account
      // 永远保留。account_name 也必须空串,否则会看到 account_sync_id=NULL
      // 但 account_name="现金"的不一致状态(web 显示账户名还在 = 像没刷新)。
      // tx 没账户的初始状态(从来没选过)等价于"清空",也走这条逻辑,无害。
      'accountName': accountName ?? '',
      'accountId': accountSyncId ?? '',
      'fromAccountName': fromAccountName ?? '',
      'fromAccountId': fromAccountSyncId ?? '',
      'toAccountName': toAccountName ?? '',
      'toAccountId': toAccountSyncId ?? '',
      if (tagNames != null && tagNames.isNotEmpty) 'tags': tagNames.join(','),
      if (tagSyncIds != null && tagSyncIds.isNotEmpty) 'tagIds': tagSyncIds,
      // 即使是 `[]` 也必须写出来，不能变 null 后被 if-spread 过滤掉。否则
      // A 端删光所有附件时 payload 里完全没有 attachments 字段 → B 端没法
      // 区分"没发送附件信息"和"全删光了"，B 就永远同步不到删除。
      if (attachments != null) 'attachments': attachments,
    };
  }

  // ==================== Account ====================

  static Map<String, dynamic> serializeAccount(Account account) {
    return {
      'syncId': account.syncId,
      'name': account.name,
      'type': account.type,
      'currency': account.currency,
      'initialBalance': account.initialBalance,
      'sortOrder': account.sortOrder,
      if (account.creditLimit != null) 'creditLimit': account.creditLimit,
      if (account.billingDay != null) 'billingDay': account.billingDay,
      if (account.paymentDueDay != null) 'paymentDueDay': account.paymentDueDay,
      if (account.bankName != null) 'bankName': account.bankName,
      if (account.cardLastFour != null) 'cardLastFour': account.cardLastFour,
      if (account.note != null) 'note': account.note,
    };
  }

  // ==================== Category ====================

  static Map<String, dynamic> serializeCategory(
    Category category, {
    String? parentName,
    String? parentSyncId,
    String? iconCloudFileId,
    String? iconCloudSha256,
  }) {
    return {
      'syncId': category.syncId,
      'name': category.name,
      'kind': category.kind,
      'level': category.level,
      'sortOrder': category.sortOrder,
      'icon': category.icon,
      'iconType': category.iconType,
      if (category.customIconPath != null) 'customIconPath': category.customIconPath,
      if (category.communityIconId != null) 'communityIconId': category.communityIconId,
      // 自定义图标上传到云后的引用，让 web 端能直接拉到对应文件。
      if (iconCloudFileId != null) 'iconCloudFileId': iconCloudFileId,
      if (iconCloudSha256 != null) 'iconCloudSha256': iconCloudSha256,
      if (parentName != null) 'parentName': parentName,
      // 共享账本二级分类:parent 的稳定 syncId,server 端 projection.upsert_category
      // 直接用,不再依赖 parent_name 反查(同名 + 重命名场景更稳)。
      if (parentSyncId != null) 'parentSyncId': parentSyncId,
    };
  }

  // ==================== Tag ====================

  static Map<String, dynamic> serializeTag(Tag tag) {
    return {
      'syncId': tag.syncId,
      'name': tag.name,
      if (tag.color != null) 'color': tag.color,
      'sortOrder': tag.sortOrder,
    };
  }

  // ==================== Ledger ====================

  /// 账本元数据(名字 / 币种)的跨设备 payload。字段名对齐 server
  /// `WriteLedgerMetaUpdateRequest`,server materialize 时会用这些字段
  /// 更新 `ledger_snapshot` 的 top-level `ledgerName` / `currency`。
  static Map<String, dynamic> serializeLedger(Ledger ledger) {
    return {
      'syncId': ledger.syncId,
      'ledgerName': ledger.name,
      'currency': ledger.currency,
    };
  }

  // ==================== Budget ====================

  /// 预算的跨设备同步 payload。ledgerSyncId / categorySyncId 用于对端 apply
  /// 时把本地 int id 对齐过去(跟 transaction payload 同一套思路)。categoryId
  /// 仅分类预算有值。
  static Map<String, dynamic> serializeBudget(
    Budget budget, {
    String? ledgerSyncId,
    String? categorySyncId,
  }) {
    return {
      'syncId': budget.syncId,
      if (ledgerSyncId != null && ledgerSyncId.isNotEmpty)
        'ledgerSyncId': ledgerSyncId,
      'type': budget.type,
      if (categorySyncId != null && categorySyncId.isNotEmpty)
        'categoryId': categorySyncId,
      'amount': budget.amount,
      'period': budget.period,
      'startDay': budget.startDay,
      'enabled': budget.enabled,
    };
  }

  // ==================== JSON Encode ====================

  static String toJsonString(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }

  static Map<String, dynamic> fromJsonString(String json) {
    return jsonDecode(json) as Map<String, dynamic>;
  }
}
