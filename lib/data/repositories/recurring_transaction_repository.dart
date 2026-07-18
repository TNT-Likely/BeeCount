import '../db.dart';

/// 周期记账 Repository 接口
abstract class RecurringTransactionRepository {
  /// 获取所有周期记账
  Future<List<RecurringTransaction>> getAllRecurringTransactions();

  /// 获取指定账本的周期记账
  Future<List<RecurringTransaction>> getRecurringTransactionsByLedger(
      int ledgerId);

  /// 获取指定账本的启用的周期记账
  Future<List<RecurringTransaction>> getEnabledRecurringTransactions(
      int ledgerId);

  /// 添加周期记账
  Future<int> addRecurringTransaction({
    required int ledgerId,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    String? note,
    required String frequency,
    required int interval,
    int? dayOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    required DateTime startDate,
    DateTime? endDate,
    bool enabled = true,
  });

  /// 更新周期记账
  Future<void> updateRecurringTransaction({
    required int id,
    required int ledgerId,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    String? note,
    required String frequency,
    required int interval,
    int? dayOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    required DateTime startDate,
    DateTime? endDate,
    bool? enabled,
  });

  /// 删除周期记账
  Future<void> deleteRecurringTransaction(int id);

  /// 启用/禁用周期记账
  Future<void> toggleRecurringTransaction(int id, bool enabled);

  /// 更新最后生成日期
  Future<void> updateLastGeneratedDate(int id, DateTime date);

  /// 引用该账户的**活跃**(enabled=true)周期记账数量(转出/转入任一端命中即算)。
  /// 账户隐藏 #240 E2:隐藏确认框用此数提示「有 N 个周期账单在用此账户」。
  Future<int> getActiveRecurringCountByAccount(int accountId);

  /// 监听所有周期记账变化
  Stream<List<RecurringTransaction>> watchAllRecurringTransactions();

  /// 监听指定账本的周期记账变化
  Stream<List<RecurringTransaction>> watchRecurringTransactionsByLedger(
      int ledgerId);

  /// 批量插入周期记账
  Future<void> batchInsertRecurringTransactions(
      List<RecurringTransactionsCompanion> items);
}
