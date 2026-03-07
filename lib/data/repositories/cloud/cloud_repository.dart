import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';

import '../../db.dart';
import '../base_repository.dart';
import '../budget_repository.dart';
import 'cloud_ledger_repository.dart';
import 'cloud_transaction_repository.dart';
import 'cloud_category_repository.dart';
import 'cloud_account_repository.dart';
import 'cloud_statistics_repository.dart';
import 'cloud_recurring_transaction_repository.dart';

/// 云端 Repository 组合类
/// 将所有云端 Repository 实现组合在一起
class CloudRepository extends BaseRepository {
  final SupabaseProvider supabase;
  final CloudLedgerRepository _ledger;
  final CloudTransactionRepository _transaction;
  final CloudCategoryRepository _category;
  final CloudAccountRepository _account;
  final CloudStatisticsRepository _statistics;
  final CloudRecurringTransactionRepository _recurringTransaction;

  CloudRepository(this.supabase)
      : _ledger = CloudLedgerRepository(supabase),
        _transaction = CloudTransactionRepository(supabase),
        _category = CloudCategoryRepository(supabase),
        _account = CloudAccountRepository(supabase),
        _statistics = CloudStatisticsRepository(supabase),
        _recurringTransaction = CloudRecurringTransactionRepository(supabase);

  // ============================================
  // LedgerRepository 接口实现（委托给 _ledger）
  // ============================================

  @override
  Stream<List<Ledger>> watchLedgers() => _ledger.watchLedgers();

  @override
  Future<List<Ledger>> getAllLedgers() => _ledger.getAllLedgers();

  @override
  Future<Ledger?> getLedgerById(int id) => _ledger.getLedgerById(id);

  @override
  Future<int> getLedgerCount() => _ledger.getLedgerCount();

  @override
  Future<int> ledgerCount() => _ledger.getLedgerCount();

  @override
  Future<({int dayCount, int txCount})> getCountsForLedger({
    required int ledgerId,
  }) =>
      _ledger.getCountsForLedger(ledgerId: ledgerId);

  @override
  Future<({int dayCount, int txCount})> getCountsAll() => _ledger.getCountsAll();

  @override
  Future<({double balance, int transactionCount})> getLedgerStats({
    required int ledgerId,
    bool accountFeatureEnabled = true,
    List<Transaction>? transactions,
  }) =>
      _ledger.getLedgerStats(
        ledgerId: ledgerId,
        accountFeatureEnabled: accountFeatureEnabled,
        transactions: transactions,
      );

  @override
  Future<int> createLedger({
    required String name,
    String currency = 'CNY',
  }) =>
      _ledger.createLedger(name: name, currency: currency);

  @override
  Future<void> updateLedgerName({
    required int id,
    required String name,
  }) =>
      _ledger.updateLedgerName(id: id, name: name);

  @override
  Future<void> updateLedger({
    required int id,
    String? name,
    String? currency,
  }) =>
      _ledger.updateLedger(id: id, name: name, currency: currency);

  @override
  Future<void> deleteLedger(int id) => _ledger.deleteLedger(id);

  @override
  Future<int> getMaxLedgerId() => _ledger.getMaxLedgerId();

  @override
  Future<int> getNextFreeLedgerId() => _ledger.getNextFreeLedgerId();

  @override
  Future<void> reassignLedgerId({
    required int fromId,
    required int toId,
  }) =>
      _ledger.reassignLedgerId(fromId: fromId, toId: toId);

  @override
  Future<int> clearLedgerTransactions(int ledgerId) =>
      _ledger.clearLedgerTransactions(ledgerId);

  @override
  Future<double> getTotalInitialBalance(int ledgerId) =>
      _ledger.getTotalInitialBalance(ledgerId);

  // ============================================
  // TransactionRepository 接口实现（委托给 _transaction）
  // ============================================

  @override
  Stream<List<Transaction>> watchRecentTransactions({
    required int ledgerId,
    int limit = 20,
  }) =>
      _transaction.watchRecentTransactions(ledgerId: ledgerId, limit: limit);

  @override
  Stream<List<Transaction>> watchTransactionsInMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transaction.watchTransactionsInMonth(ledgerId: ledgerId, month: month);

  @override
  Stream<List<({Transaction t, Category? category})>>
      watchTransactionsWithCategoryAll({
    int? ledgerId,
  }) =>
          _transaction.watchTransactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Stream<List<({Transaction t, Category? category})>>
      watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
          _transaction.watchTransactionsWithCategoryInMonth(
            ledgerId: ledgerId,
            month: month,
          );

  @override
  Stream<List<({Transaction t, Category? category})>>
      watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  }) =>
          _transaction.watchTransactionsWithCategoryInYear(
            ledgerId: ledgerId,
            year: year,
          );

  @override
  Stream<List<({Transaction t, Category? category})>>
      watchTransactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type,
  }) =>
          _transaction.watchTransactionsForCategoryInRange(
            ledgerId: ledgerId,
            start: start,
            end: end,
            categoryId: categoryId,
            type: type,
          );

  /// 兼容旧方法名
  Stream<List<({Transaction t, Category? category})>> transactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      watchTransactionsWithCategoryInMonth(ledgerId: ledgerId, month: month);

  /// 兼容旧方法名
  Stream<List<({Transaction t, Category? category})>> transactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  }) =>
      watchTransactionsWithCategoryInYear(ledgerId: ledgerId, year: year);

  /// 兼容旧方法名
  @override
  Stream<List<({Transaction t, Category? category})>> transactionsWithCategoryAll({
    int? ledgerId,
  }) =>
      _transaction.transactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Future<List<({Transaction t, Category? category})>> getRecentTransactionsWithCategory({
    required int ledgerId,
    required int limit,
  }) =>
      _transaction.getRecentTransactionsWithCategory(ledgerId: ledgerId, limit: limit);

  @override
  Future<int> addTransaction({
    required int ledgerId,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    required DateTime happenedAt,
    String? note,
  }) =>
      _transaction.addTransaction(
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        happenedAt: happenedAt,
        note: note,
      );

  @override
  Future<int> insertTransactionsBatch(List<TransactionsCompanion> items) =>
      _transaction.insertTransactionsBatch(items);

  @override
  Future<int> insertTransactionCompanion(TransactionsCompanion item) =>
      _transaction.insertTransactionCompanion(item);

  @override
  Future<void> updateTransaction({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    String? note,
    DateTime? happenedAt,
    dynamic accountId,
  }) =>
      _transaction.updateTransaction(
        id: id,
        type: type,
        amount: amount,
        categoryId: categoryId,
        note: note,
        happenedAt: happenedAt,
        accountId: accountId,
      );

  @override
  Future<void> deleteTransaction(int id) =>
      _transaction.deleteTransaction(id);

  @override
  Future<Transaction?> getTransactionById(int id) =>
      _transaction.getTransactionById(id);

  @override
  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _transaction.countByTypeInRange(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  // 其他接口方法同样暂时抛出未实现异常...
  // Category, Account, Statistics 等

  @override
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) =>
      _category.createCategory(
        name: name,
        kind: kind,
        icon: icon,
        sortOrder: sortOrder,
      );

  @override
  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) =>
      _category.createSubCategory(
        parentId: parentId,
        name: name,
        kind: kind,
        icon: icon,
        sortOrder: sortOrder,
      );

  @override
  Future<void> updateCategory(
    int id, {
    String? name,
    String? icon,
    int? parentId,
    int? level,
  }) =>
      _category.updateCategory(
        id,
        name: name,
        icon: icon,
        parentId: parentId,
        level: level,
      );

  @override
  Future<void> deleteCategory(int id) =>
      _category.deleteCategory(id);

  @override
  Future<void> deleteCategoriesByIds(List<int> ids) =>
      _category.deleteCategoriesByIds(ids);

  @override
  Future<int> upsertCategory({
    required String name,
    required String kind,
  }) =>
      _category.upsertCategory(
        name: name,
        kind: kind,
      );

  @override
  Future<Category?> getCategoryById(int categoryId) =>
      _category.getCategoryById(categoryId);

  @override
  Future<List<Category>> getAllCategories() async {
    throw UnimplementedError('getAllCategories 在云端模式下暂不可用');
  }

  @override
  Future<List<Category>> getTopLevelCategories(String kind) =>
      _category.getTopLevelCategories(kind);

  @override
  Future<List<Category>> getSubCategories(int parentId) =>
      _category.getSubCategories(parentId);

  @override
  Future<List<Category>> getUsableCategories(String kind) =>
      _category.getUsableCategories(kind);

  @override
  Future<bool> isCategoryNameDuplicate({
    required String name,
    int? excludeId,
  }) =>
      _category.isCategoryNameDuplicate(
        name: name,
        excludeId: excludeId,
      );

  @override
  Future<bool> hasSubCategories(int categoryId) =>
      _category.hasSubCategories(categoryId);

  @override
  Future<int> getSubCategoryCount(int categoryId) =>
      _category.getSubCategoryCount(categoryId);

  @override
  Future<int> getTransactionCountByCategory(int categoryId) =>
      _category.getTransactionCountByCategory(categoryId);

  @override
  Future<Map<int, int>> getAllCategoryTransactionCounts() =>
      _category.getAllCategoryTransactionCounts();

  @override
  Future<({int totalCount, double totalAmount, double averageAmount})>
      getCategorySummary(int categoryId) =>
          _category.getCategorySummary(categoryId);

  @override
  Future<List<Transaction>> getTransactionsByCategory(int categoryId) =>
      _category.getTransactionsByCategory(categoryId);

  @override
  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time',
    bool ascending = false,
  }) =>
      _category.getTransactionsByCategoryWithSort(
        categoryId,
        sortBy: sortBy,
        ascending: ascending,
      );

  @override
  Future<int> migrateCategory({
    required int fromCategoryId,
    required int toCategoryId,
  }) =>
      _category.migrateCategory(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

  @override
  Future<({int migratedTransactions, int migratedSubCategories})>
      migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  }) =>
          _category.migrateCategoryTransactions(
            fromCategoryId: fromCategoryId,
            toCategoryId: toCategoryId,
          );

  @override
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  }) =>
      _category.getCategoryMigrationInfo(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

  @override
  Future<void> updateCategorySortOrders(
          List<({int id, int sortOrder})> updates) =>
      _category.updateCategorySortOrders(updates);

  @override
  Future<String> getCategoryFullName(int categoryId) =>
      _category.getCategoryFullName(categoryId);

  @override
  Stream<Category?> watchCategory(int categoryId) =>
      _category.watchCategory(categoryId);

  @override
  Stream<List<Transaction>> watchTransactionsByCategory(int categoryId,
          {int? ledgerId}) =>
      _category.watchTransactionsByCategory(categoryId, ledgerId: ledgerId);

  @override
  Stream<List<Category>> watchCategoryWithSubs(int categoryId) =>
      _category.watchCategoryWithSubs(categoryId);

  @override
  Stream<List<({Category category, int transactionCount})>>
      watchCategoriesWithCount() =>
          _category.watchCategoriesWithCount();

  // Account Repository 方法
  @override
  Stream<List<Account>> watchAccountsForLedger(int ledgerId) =>
      _account.watchAccountsForLedger(ledgerId);

  @override
  Stream<List<Account>> watchAllAccounts() =>
      _account.watchAllAccounts();

  @override
  Future<List<Account>> getAllAccounts() =>
      _account.getAllAccounts();

  @override
  Future<Account?> getAccount(int accountId) =>
      _account.getAccount(accountId);

  @override
  Future<List<Account>> getAvailableAccountsForLedger(int ledgerId) =>
      _account.getAvailableAccountsForLedger(ledgerId);

  @override
  Future<List<Account>> getAccountsByCurrency(String currency) =>
      _account.getAccountsByCurrency(currency);

  @override
  Future<Map<String, List<Account>>> getAccountsGroupedByCurrency() =>
      _account.getAccountsGroupedByCurrency();

  @override
  Future<int> createAccount({
    required int ledgerId,
    required String name,
    String type = 'cash',
    String currency = 'CNY',
    double initialBalance = 0.0,
  }) =>
      _account.createAccount(
        ledgerId: ledgerId,
        name: name,
        type: type,
        currency: currency,
        initialBalance: initialBalance,
      );

  @override
  Future<void> updateAccount(
    int id, {
    String? name,
    String? type,
    String? currency,
    double? initialBalance,
  }) =>
      _account.updateAccount(
        id,
        name: name,
        type: type,
        currency: currency,
        initialBalance: initialBalance,
      );

  @override
  Future<void> deleteAccount(int id) =>
      _account.deleteAccount(id);

  @override
  Future<double> getAccountBalance(int accountId) =>
      _account.getAccountBalance(accountId);

  @override
  Future<double> getAccountGlobalBalance(int accountId) =>
      _account.getAccountGlobalBalance(accountId);

  @override
  Future<double> getAccountBalanceInLedger(int accountId, int ledgerId) =>
      _account.getAccountBalanceInLedger(accountId, ledgerId);

  @override
  Future<Map<int, double>> getAllAccountBalances(int ledgerId) =>
      _account.getAllAccountBalances(ledgerId);

  @override
  Future<int> getTransactionCountByAccount(int accountId) =>
      _account.getTransactionCountByAccount(accountId);

  @override
  Future<double> getAccountExpense(int accountId) =>
      _account.getAccountExpense(accountId);

  @override
  Future<double> getAccountIncome(int accountId) =>
      _account.getAccountIncome(accountId);

  @override
  Future<({double balance, double expense, double income})> getAccountStats(
          int accountId) =>
      _account.getAccountStats(accountId);

  @override
  Future<Map<int, ({double balance, double expense, double income})>>
      getAllAccountStats() =>
          _account.getAllAccountStats();

  @override
  Future<({double totalBalance, double totalExpense, double totalIncome})>
      getAllAccountsTotalStats() =>
          _account.getAllAccountsTotalStats();

  @override
  Future<Map<int, int>> getAccountUsageInLedgers(int accountId) =>
      _account.getAccountUsageInLedgers(accountId);

  @override
  Future<int> migrateAccount({
    required int fromAccountId,
    required int toAccountId,
  }) =>
      _account.migrateAccount(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
      );

  @override
  Future<bool> hasTransactions(int accountId) =>
      _account.hasTransactions(accountId);

  @override
  Stream<Account?> watchAccount(int accountId) =>
      _account.watchAccount(accountId);

  @override
  Stream<List<Transaction>> watchAccountTransactions(int accountId) =>
      _account.watchAccountTransactions(accountId);

  @override
  Future<int> createAdjustmentTransaction({
    required int accountId,
    required int ledgerId,
    required double amount,
    String? note,
  }) =>
      _account.createAdjustmentTransaction(
        accountId: accountId,
        ledgerId: ledgerId,
        amount: amount,
        note: note,
      );

  // Statistics Repository 方法
  @override
  Future<List<({int? id, String name, String? icon, double total})>>
      totalsByCategory({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
          _statistics.totalsByCategory(
            ledgerId: ledgerId,
            type: type,
            start: start,
            end: end,
          );

  @override
  Future<
      List<
          ({
            int? id,
            String name,
            String? icon,
            int? parentId,
            int level,
            double total
          })>> totalsByCategoryWithHierarchy({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _statistics.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  @override
  Future<List<({DateTime day, double total})>> totalsByDay({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _statistics.totalsByDay(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  @override
  Future<List<({DateTime month, double total})>> totalsByMonth({
    required int ledgerId,
    required String type,
    required int year,
  }) =>
      _statistics.totalsByMonth(
        ledgerId: ledgerId,
        type: type,
        year: year,
      );

  @override
  Future<List<({int year, double total})>> totalsByYearSeries({
    required int ledgerId,
    required String type,
  }) =>
      _statistics.totalsByYearSeries(
        ledgerId: ledgerId,
        type: type,
      );

  @override
  Future<(double income, double expense)> totalsInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) =>
      _statistics.totalsInRange(
        ledgerId: ledgerId,
        start: start,
        end: end,
      );

  @override
  Future<(double income, double expense)> monthlyTotals({
    required int ledgerId,
    required DateTime month,
  }) =>
      _statistics.monthlyTotals(
        ledgerId: ledgerId,
        month: month,
      );

  @override
  Future<(double income, double expense)> yearlyTotals({
    required int ledgerId,
    required int year,
  }) =>
      _statistics.yearlyTotals(
        ledgerId: ledgerId,
        year: year,
      );

  // ============================================
  // RecurringTransactionRepository 接口实现（委托给 _recurringTransaction）
  // ============================================

  @override
  Future<List<RecurringTransaction>> getAllRecurringTransactions() =>
      _recurringTransaction.getAllRecurringTransactions();

  @override
  Future<List<RecurringTransaction>> getRecurringTransactionsByLedger(
          int ledgerId) =>
      _recurringTransaction.getRecurringTransactionsByLedger(ledgerId);

  @override
  Future<List<RecurringTransaction>> getEnabledRecurringTransactions(
          int ledgerId) =>
      _recurringTransaction.getEnabledRecurringTransactions(ledgerId);

  @override
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
  }) =>
      _recurringTransaction.addRecurringTransaction(
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        note: note,
        frequency: frequency,
        interval: interval,
        dayOfMonth: dayOfMonth,
        dayOfWeek: dayOfWeek,
        monthOfYear: monthOfYear,
        startDate: startDate,
        endDate: endDate,
        enabled: enabled,
      );

  @override
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
  }) =>
      _recurringTransaction.updateRecurringTransaction(
        id: id,
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        note: note,
        frequency: frequency,
        interval: interval,
        dayOfMonth: dayOfMonth,
        dayOfWeek: dayOfWeek,
        monthOfYear: monthOfYear,
        startDate: startDate,
        endDate: endDate,
        enabled: enabled,
      );

  @override
  Future<void> deleteRecurringTransaction(int id) =>
      _recurringTransaction.deleteRecurringTransaction(id);

  @override
  Future<void> toggleRecurringTransaction(int id, bool enabled) =>
      _recurringTransaction.toggleRecurringTransaction(id, enabled);

  @override
  Future<void> updateLastGeneratedDate(int id, DateTime date) =>
      _recurringTransaction.updateLastGeneratedDate(id, date);

  @override
  Stream<List<RecurringTransaction>> watchAllRecurringTransactions() =>
      _recurringTransaction.watchAllRecurringTransactions();

  @override
  Stream<List<RecurringTransaction>> watchRecurringTransactionsByLedger(
          int ledgerId) =>
      _recurringTransaction.watchRecurringTransactionsByLedger(ledgerId);

  // ============================================
  // AIRepository 接口实现（云端模式不支持 AI 功能）
  // ============================================

  @override
  Future<Conversation?> getActiveConversation() async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<Conversation?> getConversationById(int id) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<int> createConversation(ConversationsCompanion conversation) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<void> updateConversation(Conversation conversation) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<void> deleteConversation(int id) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Stream<List<Message>> watchMessages(int conversationId) {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<Message?> getMessageById(int id) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<int> createMessage(MessagesCompanion message) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<void> updateMessage(Message message) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<void> deleteMessagesByConversation(int conversationId) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<void> deleteMessage(int id) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  @override
  Future<Message?> getMessageByTransactionId(int transactionId) async {
    throw UnimplementedError('AI 功能在云端模式下不可用');
  }

  // ============================================
  // 新增方法委托
  // ============================================

  @override
  Future<void> batchInsertAccounts(List<AccountsCompanion> accounts) =>
      _account.batchInsertAccounts(accounts);

  @override
  Future<List<Account>> getAccountsByIds(List<int> accountIds) =>
      _account.getAccountsByIds(accountIds);

  @override
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories) =>
      _category.batchInsertCategories(categories);

  @override
  Future<int> insertCategory(CategoriesCompanion category) =>
      _category.insertCategory(category);

  @override
  Future<void> updateCategoryIcon(
    int id, {
    required String iconType,
    String? icon,
    String? customIconPath,
    String? communityIconId,
  }) =>
      _category.updateCategoryIcon(
        id,
        iconType: iconType,
        icon: icon,
        customIconPath: customIconPath,
        communityIconId: communityIconId,
      );

  @override
  Future<void> clearCategoryCustomIcon(int id, {String? materialIcon}) =>
      _category.clearCategoryCustomIcon(id, materialIcon: materialIcon);

  @override
  Future<List<String>> getCustomIconPaths() => _category.getCustomIconPaths();

  @override
  Future<Category> getTransferCategory() => _category.getTransferCategory();

  @override
  Future<void> batchInsertRecurringTransactions(
          List<RecurringTransactionsCompanion> items) =>
      _recurringTransaction.batchInsertRecurringTransactions(items);

  @override
  Future<List<Transaction>> getTransactionsByLedger(int ledgerId) =>
      _transaction.getTransactionsByLedger(ledgerId);

  @override
  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) =>
      _transaction.getTransactionsByLedgerInRange(
        ledgerId: ledgerId,
        start: start,
        end: end,
      );

  @override
  Future<void> updateTransactionFields({
    required int id,
    int? accountId,
    int? toAccountId,
  }) =>
      _transaction.updateTransactionFields(
        id: id,
        accountId: accountId,
        toAccountId: toAccountId,
      );

  @override
  Future<Transaction?> getFirstTransactionByLedger(int ledgerId) =>
      _transaction.getFirstTransactionByLedger(ledgerId);

  @override
  Future<Transaction?> getLastTransactionByLedger(int ledgerId) =>
      _transaction.getLastTransactionByLedger(ledgerId);

  @override
  Future<void> updateTransactionLedger({
    required int id,
    required int ledgerId,
  }) =>
      _transaction.updateTransactionLedger(id: id, ledgerId: ledgerId);

  // ==================== 日历功能相关 ====================

  @override
  Future<Map<String, (double income, double expense)>> getDailyTotalsByMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transaction.getDailyTotalsByMonth(ledgerId: ledgerId, month: month);

  @override
  Future<List<({
    Transaction t,
    Category? category,
    List<Tag> tags,
    List<TransactionAttachment> attachments,
    Account? account,
  })>> getTransactionsByDate({
    required int ledgerId,
    required DateTime date,
  }) =>
      _transaction.getTransactionsByDate(ledgerId: ledgerId, date: date);

  @override
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
  }) =>
      _transaction.getTransactionsByDateRange(
          ledgerId: ledgerId, startDate: startDate, endDate: endDate);

  @override
  Future<List<String>> getTransactionDatesByMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transaction.getTransactionDatesByMonth(ledgerId: ledgerId, month: month);

  // ============================================
  // TagRepository 接口实现（云端模式暂不支持标签功能）
  // ============================================

  @override
  Future<int> createTag({
    required String name,
    String? color,
    int sortOrder = 0,
  }) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> updateTag(
    int id, {
    String? name,
    String? color,
    int? sortOrder,
  }) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> deleteTag(int id) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<Tag?> getTagById(int id) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<Tag?> getTagByName(String name) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<List<Tag>> getAllTags() async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> batchInsertTags(List<TagsCompanion> tags) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> addTagToTransaction({
    required int transactionId,
    required int tagId,
  }) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> addTagsToTransaction({
    required int transactionId,
    required List<int> tagIds,
  }) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> removeTagFromTransaction({
    required int transactionId,
    required int tagId,
  }) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> removeAllTagsFromTransaction(int transactionId) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> updateTransactionTags({
    required int transactionId,
    required List<int> tagIds,
  }) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<List<Tag>> getTagsForTransaction(int transactionId) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<Map<int, List<Tag>>> getTagsForTransactions(List<int> transactionIds) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<List<int>> getTransactionIdsByTag(int tagId) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<int> getTransactionCountByTag(int tagId) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<Map<int, int>> getAllTagTransactionCounts() async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<({int count, double expense, double income})> getTagStats(int tagId) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<List<Transaction>> getTransactionsByTag(int tagId) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<List<Transaction>> getTransactionsByTagInRange({
    required int tagId,
    required DateTime start,
    required DateTime end,
  }) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Stream<List<Tag>> watchAllTags() {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Stream<List<({Tag tag, int transactionCount})>> watchTagsWithStats() {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Stream<Tag?> watchTag(int tagId) {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Stream<List<Tag>> watchTagsForTransaction(int transactionId) {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Stream<List<Transaction>> watchTransactionsByTag(int tagId) {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<bool> isTagNameDuplicate({required String name, int? excludeId}) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<void> updateTagSortOrders(List<({int id, int sortOrder})> updates) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  @override
  Future<List<Tag>> getRecentlyUsedTags({int limit = 10}) async {
    throw UnimplementedError('标签功能在云端模式下暂不可用');
  }

  // ============================================
  // BudgetRepository 接口实现（云端暂不支持）
  // ============================================

  @override
  Future<int> createBudget({
    required int ledgerId,
    required String type,
    int? categoryId,
    required double amount,
    String period = 'monthly',
    int startDay = 1,
  }) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<void> updateBudget(
    int id, {
    double? amount,
    int? startDay,
    bool? enabled,
  }) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<void> deleteBudget(int id) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<Budget?> getTotalBudget(int ledgerId) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<List<Budget>> getCategoryBudgets(int ledgerId) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<Budget?> getBudgetByCategory(int ledgerId, int categoryId) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<List<Budget>> getAllBudgets(int ledgerId) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<List<Budget>> getAllBudgetsForExport() async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<BudgetUsage> getBudgetUsage(int budgetId, DateTime month) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<BudgetOverview> getBudgetOverview(int ledgerId, DateTime month) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Future<List<CategoryBudgetUsage>> getCategoryBudgetUsages(
    int ledgerId,
    DateTime month,
  ) async {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  @override
  Stream<List<Budget>> watchBudgets(int ledgerId) {
    throw UnimplementedError('预算功能在云端模式下暂不可用');
  }

  // ============================================
  // AttachmentRepository 接口实现（云端暂不支持附件文件存储）
  // ============================================

  @override
  Future<int> createAttachment({
    required int transactionId,
    required String fileName,
    String? originalName,
    int? fileSize,
    int? width,
    int? height,
    int sortOrder = 0,
  }) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<TransactionAttachment?> getAttachmentById(int id) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<List<TransactionAttachment>> getAttachmentsByTransaction(int transactionId) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<void> deleteAttachment(int id) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<void> deleteAttachmentsByTransaction(int transactionId) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<void> updateAttachmentSortOrder(int id, int sortOrder) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<void> updateAttachmentSortOrders(List<({int id, int sortOrder})> updates) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<bool> attachmentExistsByFileName(String fileName) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<int> getAttachmentCountByTransaction(int transactionId) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<Map<int, int>> getAttachmentCountsForTransactions(List<int> transactionIds) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<Map<int, List<TransactionAttachment>>> getAttachmentsForTransactions(List<int> transactionIds) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<List<int>> getTransactionIdsWithAttachments() async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<List<TransactionAttachment>> getAllAttachments() async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Future<void> deleteAttachmentByFileName(String fileName) async {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Stream<List<TransactionAttachment>> watchAttachmentsByTransaction(int transactionId) {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }

  @override
  Stream<int> watchAttachmentCountByTransaction(int transactionId) {
    throw UnimplementedError('附件功能在云端模式下暂不可用');
  }
}
