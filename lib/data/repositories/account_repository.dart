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

  /// 创建账户。撞同名抛 [DuplicateNameException](name 全局唯一)。
  /// 静默路径(import / app-link 等)请用 [upsertAccount](get-or-create 语义)。
  /// [syncId] 可选:seed 类路径显式塞确定性 id,UI 不传走 auto v4。
  Future<int> createAccount({
    required int ledgerId,
    required String name,
    String type = 'cash',
    String currency = 'CNY',
    double initialBalance = 0.0,
    double? creditLimit,
    int? billingDay,
    int? paymentDueDay,
    String? bankName,
    String? cardLastFour,
    String? note,
    String? syncId,
  });

  /// 按 name 取账户(name 全局唯一,账户跨账本可用);不存在则建一条。
  /// 给 import / app-link 等 get-or-create 语义的静默路径用 —— 不会抛
  /// [DuplicateNameException]。
  ///
  /// [ledgerId] 是 legacy 字段(早期 schema 残留),账户实际跨账本可用,默认 0。
  Future<int> upsertAccount({
    required String name,
    int ledgerId = 0,
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
    double? creditLimit,
    int? billingDay,
    int? paymentDueDay,
    bool clearCreditCardFields = false,
    String? bankName,
    String? cardLastFour,
    String? note,
    bool clearMetadataFields = false,
  });

  /// 获取所有信用卡账户
  Future<List<Account>> getCreditCardAccounts();

  /// 获取信用卡已用额度（负余额 = 欠款额度）
  Future<double> getCreditCardUsedAmount(int accountId);

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

  /// 响应式监听账户信息变化
  Stream<Account?> watchAccount(int accountId);

  /// 响应式监听账户相关的所有交易
  Stream<List<Transaction>> watchAccountTransactions(int accountId);

  /// 批量插入账户
  Future<void> batchInsertAccounts(List<AccountsCompanion> accounts);

  /// 批量获取账户信息（通过ID列表）
  Future<List<Account>> getAccountsByIds(List<int> accountIds);

  /// 批量更新账户排序顺序
  Future<void> updateAccountSortOrders(List<({int id, int sortOrder})> updates);

  /// 分页获取账户交易
  Future<List<Transaction>> getAccountTransactions(
    int accountId, {int limit = 50, int offset = 0});

  /// 获取账户每日余额快照（用于余额趋势图）
  Future<List<({DateTime date, double balance})>> getAccountDailyBalances(
    int accountId, {required DateTime startDate, required DateTime endDate});

  /// 获取账户级分类统计（用于分类饼图）
  Future<List<({int? id, String name, String? icon, double total})>>
      getAccountCategoryStats(int accountId, {required String type});

  /// 获取净资产分解（总资产、总负债、净资产）
  Future<({double totalAssets, double totalLiabilities, double netWorth})> getNetWorthBreakdown();

  /// 按币种分组的净资产分解
  Future<Map<String, ({double totalAssets, double totalLiabilities, double netWorth})>> getNetWorthBreakdownByCurrency();

  /// 获取净资产每日余额快照（用于净资产趋势图）
  Future<List<({DateTime date, double balance})>> getNetWorthDailyBalances({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// 获取资产构成（按账户类型分组的余额汇总）
  Future<List<({String type, double totalBalance})>> getAssetCompositionByType();

  /// 更新估值账户的当前估值
  Future<void> updateAccountValuation(int accountId, double newValue);

  // ============================================
  // 共享账本(§7 / v25)— 跨设备共享的 SharedLedgerAccounts 表
  // ============================================

  /// 按 syncId 查 SharedLedgerAccounts 行;Editor 视角下 tx 的
  /// accountSyncIdOverride 走这条反查 → 上层再映射成 synthetic Account。
  Future<SharedLedgerAccount?> getSharedAccountBySyncId(String syncId);
}
