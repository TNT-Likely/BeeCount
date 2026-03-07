import '../db.dart';

/// 账户Repository接口
/// 定义账户相关的所有数据操作
abstract class AccountRepository {
  /// 获取指定账本下的所有账户（Stream版本）
  Stream<List<Account>> watchAccountsForLedger(int ledgerId);

  /// 获取所有账户（不限账本，Stream版本）
  Stream<List<Account>> watchAllAccounts();

  /// 获取所有账户（不限账本，Future版本）
  Future<List<Account>> getAllAccounts();

  /// 获取单个账户信息
  Future<Account?> getAccount(int accountId);

  /// 获取账本可用的账户（通过币种过滤）
  Future<List<Account>> getAvailableAccountsForLedger(int ledgerId);

  /// 获取某币种的所有账户
  Future<List<Account>> getAccountsByCurrency(String currency);

  /// 按币种分组获取账户统计
  Future<Map<String, List<Account>>> getAccountsGroupedByCurrency();

  /// 创建账户
  Future<int> createAccount({
    required int ledgerId,
    required String name,
    String type = 'cash',
    String currency = 'CNY',
    double initialBalance = 0.0,
  });

  /// 更新账户
  Future<void> updateAccount(
    int id, {
    String? name,
    String? type,
    String? currency,
    double? initialBalance,
  });

  /// 删除账户
  Future<void> deleteAccount(int id);

  /// 获取账户余额（收入 - 支出 + 转入 - 转出）
  Future<double> getAccountBalance(int accountId);

  /// 获取账户全局余额（跨所有账本）
  Future<double> getAccountGlobalBalance(int accountId);

  /// 获取账户在某账本的余额
  Future<double> getAccountBalanceInLedger(int accountId, int ledgerId);

  /// 批量获取所有账户余额
  Future<Map<int, double>> getAllAccountBalances(int ledgerId);

  /// 获取账户的交易数量
  Future<int> getTransactionCountByAccount(int accountId);

  /// 获取单个账户的消费金额
  Future<double> getAccountExpense(int accountId);

  /// 获取单个账户的收入金额
  Future<double> getAccountIncome(int accountId);

  /// 获取单个账户的统计信息（余额、消费金额、收入金额）
  Future<({double balance, double expense, double income})> getAccountStats(int accountId);

  /// 批量获取所有账户的统计信息
  Future<Map<int, ({double balance, double expense, double income})>> getAllAccountStats();

  /// 获取所有账户的汇总统计（总余额、总支出、总收入）
  Future<({double totalBalance, double totalExpense, double totalIncome})> getAllAccountsTotalStats();

  /// 获取账户在多个账本中的使用情况
  Future<Map<int, int>> getAccountUsageInLedgers(int accountId);

  /// 账户迁移（将fromAccountId的所有交易迁移到toAccountId）
  Future<int> migrateAccount({
    required int fromAccountId,
    required int toAccountId,
  });

  /// 检查账户是否有交易记录
  Future<bool> hasTransactions(int accountId);

  /// 创建账户平账交易
  /// [accountId] 账户ID
  /// [ledgerId] 账本ID
  /// [amount] 平账金额（正数表示增加余额，负数表示减少余额）
  /// [note] 备注信息
  Future<int> createAdjustmentTransaction({
    required int accountId,
    required int ledgerId,
    required double amount,
    String? note,
  });

  /// 响应式监听账户信息变化
  Stream<Account?> watchAccount(int accountId);

  /// 响应式监听账户相关的所有交易
  Stream<List<Transaction>> watchAccountTransactions(int accountId);

  /// 批量插入账户
  Future<void> batchInsertAccounts(List<AccountsCompanion> accounts);

  /// 批量获取账户信息（通过ID列表）
  Future<List<Account>> getAccountsByIds(List<int> accountIds);
}
