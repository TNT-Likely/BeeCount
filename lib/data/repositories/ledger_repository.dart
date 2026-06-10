import '../db.dart';

/// 账本Repository接口
/// 定义账本相关的所有数据操作
abstract class LedgerRepository {
  /// 监听所有账本列表
  Stream<List<Ledger>> watchLedgers();

  /// 获取所有账本列表（一次性查询）
  Future<List<Ledger>> getAllLedgers();

  /// 根据ID获取单个账本
  Future<Ledger?> getLedgerById(int id);

  /// 获取账本数量
  Future<int> getLedgerCount();

  /// 获取账本数量（别名方法）
  Future<int> ledgerCount();

  /// 获取指定账本的统计信息（记账天数、交易笔数）
  Future<({int dayCount, int txCount})> getCountsForLedger({
    required int ledgerId,
  });

  /// 获取所有账本的聚合统计（记账天数、交易笔数）
  Future<({int dayCount, int txCount})> getCountsAll();

  /// 获取账本统计信息（余额、交易数等）
  Future<({double balance, int transactionCount})> getLedgerStats({
    required int ledgerId,
    bool accountFeatureEnabled = true,
    List<Transaction>? transactions,
  });

  /// 创建账本
  Future<int> createLedger({
    required String name,
    String currency = 'CNY',
  });

  /// 更新账本名称
  Future<void> updateLedgerName({
    required int id,
    required String name,
  });

  /// 更新账本信息
  Future<void> updateLedger({
    required int id,
    String? name,
    String? currency,
    int? monthStartDay,
  });

  /// 监听单个账本(sync pull 改了 ledger 行时自动通知 watcher)
  Stream<Ledger?> watchLedger(int id);

  /// 删除账本（同时删除关联的所有交易）
  Future<void> deleteLedger(int id);

  /// 获取当前最大账本ID
  Future<int> getMaxLedgerId();

  /// 获取下一个未占用的账本ID
  Future<int> getNextFreeLedgerId();

  /// 将账本ID从 fromId 迁移到 toId（同时更新关联的 accounts/transactions）
  Future<void> reassignLedgerId({
    required int fromId,
    required int toId,
  });

  /// 清空指定账本的所有交易记录，返回删除的条数
  Future<int> clearLedgerTransactions(int ledgerId);

  /// 获取指定账本的所有账户初始资金总额
  Future<double> getTotalInitialBalance(int ledgerId);
}
