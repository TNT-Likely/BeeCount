import '../db.dart';

/// 批量按 syncId 更新交易时的单条 update payload。
class TransactionUpdateBySyncIdData {
  final String syncId;
  final String type;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final DateTime happenedAt;
  final String? note;

  const TransactionUpdateBySyncIdData({
    required this.syncId,
    required this.type,
    required this.amount,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    required this.happenedAt,
    this.note,
  });
}

/// 批量插入交易时附带的附件元数据。交易行还没插入,txId 未知,
/// repo 内部按 batch 内 index 找到刚插入的 txId 再组装 AttachmentsCompanion。
class BatchAttachmentData {
  final String fileName;
  final String? originalName;
  final int? fileSize;
  final int? width;
  final int? height;
  final int sortOrder;
  final String? cloudFileId;
  final String? cloudSha256;

  const BatchAttachmentData({
    required this.fileName,
    this.originalName,
    this.fileSize,
    this.width,
    this.height,
    this.sortOrder = 0,
    this.cloudFileId,
    this.cloudSha256,
  });
}

/// 交易Repository接口
/// 定义交易相关的所有数据操作
abstract class TransactionRepository {
  /// 获取最近的交易记录
  Stream<List<Transaction>> watchRecentTransactions({
    required int ledgerId,
    int limit = 20,
  });

  /// 获取指定月份的交易记录
  ///
  /// [month] 为周期标签,约定传 DateTime(year, month, 1);实际范围由账本
  /// monthStartDay 决定:[y-m-起始日, y-(m+1)-起始日)。
  Stream<List<Transaction>> watchTransactionsInMonth({
    required int ledgerId,
    required DateTime month,
  });

  /// 获取所有交易记录（带分类信息）
  /// [ledgerId] 可选，不传则获取所有账本的交易
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsWithCategoryAll({
    int? ledgerId,
  });

  /// 获取所有交易记录（带分类信息）- 非 Stream 版本
  /// [ledgerId] 可选，不传则获取所有账本的交易
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> transactionsWithCategoryAll({
    int? ledgerId,
  });

  /// 获取最近的交易记录（带分类信息）- 用于预加载
  Future<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> getRecentTransactionsWithCategory({
    required int ledgerId,
    required int limit,
  });

  /// 根据ID获取单条交易
  Future<Transaction?> getTransactionById(int id);

  /// 获取指定月份的交易记录（带分类信息）
  ///
  /// [month] 为周期标签,约定传 DateTime(year, month, 1);实际范围由账本
  /// monthStartDay 决定:[y-m-起始日, y-(m+1)-起始日)。
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  });

  /// 获取指定年份的交易记录（带分类信息）
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  });

  /// 获取指定分类和时间范围的交易记录（带分类信息）
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type,
  });

  /// 添加交易
  ///
  /// §7 v25 共享账本:Editor 选 Owner 的 SharedLedger* 行时,categoryId /
  /// accountId / toAccountId 留 null,改填 *SyncIdOverride 字符串。
  /// Owner / 单人账本场景:走 categoryId int(老路径),override 留 null。
  Future<int> addTransaction({
    required int ledgerId,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    required DateTime happenedAt,
    String? note,
    String? syncId,
    String? categorySyncIdOverride,
    String? accountSyncIdOverride,
    String? toAccountSyncIdOverride,
    bool excludeFromStats = false,
    bool excludeFromBudget = false,
  });

  /// 批量新增交易，单事务内插入，返回插入条数。
  ///
  /// [recordChanges] 默认 true,会逐条登记 changeTracker.recordLedgerChange。
  /// FullPull 路径需要传 false 避免"从云端拉下来的数据又被反向 push 回去"。
  Future<int> insertTransactionsBatch(
    List<TransactionsCompanion> items, {
    bool recordChanges = true,
  });

  /// 插入单条交易（使用 Companion 对象）
  ///
  /// [recordChanges] 同 [insertTransactionsBatch]。
  Future<int> insertTransactionCompanion(
    TransactionsCompanion item, {
    bool recordChanges = true,
  });

  /// 批量插入交易 + 关联数据(tag / attachment),全部在单事务内完成。
  ///
  /// 用于带标签 / 带附件的 import 路径 — 原本的"单条 insert + 单条
  /// updateTransactionTags + 单条 createAttachment"会引发 N+1 + 嵌套事务,
  /// 1 万条带标签数据耗时数十分钟;本方法把 N 次单条事务折叠成 1 次,
  /// 并用 `db.batch` 合并 tag / attachment / local_changes 的 INSERT。
  ///
  /// [tagIdsByIndex] - 批次内 index → tagId 列表。调用方需保证 tagIds 去重
  ///   (TransactionTags 表无 UNIQUE 约束,本方法不做 select 防重)。
  /// [attachmentsByIndex] - 批次内 index → 附件元数据列表。
  /// [recordChanges] - 同 [insertTransactionsBatch]。
  ///
  /// 返回插入的 tx id 列表,顺序跟 [transactions] 输入对齐。
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    Map<int, List<int>> tagIdsByIndex = const {},
    Map<int, List<BatchAttachmentData>> attachmentsByIndex = const {},
    bool recordChanges = true,
  });

  /// 更新交易
  Future<void> updateTransaction({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    String? note,
    DateTime? happenedAt,
    dynamic accountId,
    String? categorySyncIdOverride,
    String? accountSyncIdOverride,
    String? toAccountSyncIdOverride,
    bool? excludeFromStats,
    bool? excludeFromBudget,
  });

  /// 删除交易
  Future<void> deleteTransaction(int id);

  /// 获取指定类型和时间范围内的交易数量
  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  });

  /// 获取账本的所有交易记录
  Future<List<Transaction>> getTransactionsByLedger(int ledgerId);

  /// 获取账本在指定时间范围内的交易记录
  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  });

  /// 更新交易(通过 ID 和字段)。
  /// accountId / toAccountId 接 dynamic:dart `null` = absent(不更新);
  /// `d.Value<int?>(null)` = 显式清空;`int` = 写值。共享账本 Editor 写
  /// synthetic 账户时,accountId 写 null,通过 writeAccountSyncIdOverride
  /// + accountSyncIdOverride 写 Owner 账户的 syncId override。
  Future<void> updateTransactionFields({
    required int id,
    dynamic accountId,
    dynamic toAccountId,
    String? accountSyncIdOverride,
    String? toAccountSyncIdOverride,
    bool writeAccountSyncIdOverride,
    bool writeToAccountSyncIdOverride,
  });

  /// 获取账本的首笔交易（按时间排序）
  Future<Transaction?> getFirstTransactionByLedger(int ledgerId);

  /// 获取账本的末笔交易（按时间排序）
  Future<Transaction?> getLastTransactionByLedger(int ledgerId);

  /// 全局最早一笔交易的发生时间（不限账本，用于净值趋势「全部」范围的起点）。无交易返回 null。
  Future<DateTime?> getEarliestTransactionDate();

  /// 更新交易的账本
  Future<void> updateTransactionLedger({
    required int id,
    required int ledgerId,
  });

  // ==================== 日历功能相关 ====================

  /// 获取指定月份的每日交易统计
  /// 返回 Map<日期字符串, (收入, 支出)>
  /// 例: {"2025-01-15": (500.0, 1200.0), ...}
  Future<Map<String, (double income, double expense)>> getDailyTotalsByMonth({
    required int ledgerId,
    required DateTime month,
  });

  /// 获取指定日期的所有交易（含分类、标签、附件、账户）
  Future<List<({
    Transaction t,
    Category? category,
    List<Tag> tags,
    List<TransactionAttachment> attachments,
    Account? account,
  })>> getTransactionsByDate({
    required int ledgerId,
    required DateTime date,
  });

  /// 获取指定时间范围的交易列表（用于日历当月列表）
  Future<List<({
    Transaction t,
    Category? category,
    List<Tag> tags,
    List<TransactionAttachment> attachments,
    Account? account,
  })>> getTransactionsByDateRange({
    required int ledgerId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// 获取指定月份所有有交易的日期列表
  /// 返回 ["2025-01-15", "2025-01-16", ...]
  Future<List<String>> getTransactionDatesByMonth({
    required int ledgerId,
    required DateTime month,
  });

  /// 根据 syncId 获取交易
  Future<Transaction?> getTransactionBySyncId(String syncId);

  /// 根据 syncId 更新交易的全部字段
  Future<void> updateTransactionBySyncId({
    required String syncId,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    required DateTime happenedAt,
    String? note,
  });

  /// 根据 syncId 删除交易
  Future<void> deleteTransactionBySyncId(String syncId);

  /// 批量按 syncId 删除交易(WebDAV/Supabase 同步从远端拉账本时,如果本地有
  /// 旧账本 + 用户选择"以远端为准"覆盖,N 条 delete by syncId 单条 await 会
  /// 跑几分钟;本方法用单条 `DELETE WHERE syncId IN (...)` 一次性删除)。
  ///
  /// [recordChanges] 默认 true,wrapper 会批量补 transaction:delete change log。
  /// 返回实际删除的条数。
  Future<int> deleteTransactionsBatchBySyncIds(
    List<String> syncIds, {
    bool recordChanges = true,
  });

  /// 批量按 syncId 更新交易主表字段。同事务内逐条 UPDATE,N 次跨 isolate
  /// boundary 但 BEGIN/COMMIT 只跑一次。
  ///
  /// **不涉及 tag 更新** — caller 拿到 returned `Map<syncId, txId>` 后自己批量
  /// 调 `updateTransactionTags`(或者更高效的 batch 接口,如果将来加的话)。
  Future<Map<String, int>> updateTransactionsBatchBySyncId(
    List<TransactionUpdateBySyncIdData> updates, {
    bool recordChanges = true,
  });

  /// 创建估值调整交易
  Future<int> createAdjustmentTransaction({
    required int ledgerId,
    required int accountId,
    required double amount,
    required DateTime happenedAt,
    String? note,
  });
}
