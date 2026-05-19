import '../db.dart';

/// 交易Repository接口
/// 定义交易相关的所有数据操作
abstract class TransactionRepository {
  /// 获取最近的交易记录
  Stream<List<Transaction>> watchRecentTransactions({
    required int ledgerId,
    int limit = 20,
  });

  /// 获取指定月份的交易记录
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
  });

  /// 批量新增交易，单事务内插入，返回插入条数
  Future<int> insertTransactionsBatch(List<TransactionsCompanion> items);

  /// 插入单条交易（使用 Companion 对象）
  Future<int> insertTransactionCompanion(TransactionsCompanion item);

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

  /// 创建估值调整交易
  Future<int> createAdjustmentTransaction({
    required int ledgerId,
    required int accountId,
    required double amount,
    required DateTime happenedAt,
    String? note,
  });
}
