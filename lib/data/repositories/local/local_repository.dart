import '../../db.dart';
import '../../../cloud/sync/change_tracker.dart';
import '../base_repository.dart';
import '../budget_repository.dart';
import 'local_ledger_repository.dart';
import 'local_transaction_repository.dart';
import 'local_category_repository.dart';
import 'local_account_repository.dart';
import 'local_statistics_repository.dart';
import 'local_recurring_transaction_repository.dart';
import 'local_ai_repository.dart';
import 'local_tag_repository.dart';
import 'local_budget_repository.dart';
import 'local_attachment_repository.dart';

/// LocalRepository 本地数据库实现
/// 基于 Drift 本地数据库实现所有 Repository 接口
/// 使用委托模式，将具体实现委托给各个子 Repository
class LocalRepository extends BaseRepository {
  /// 底层数据库实例
  /// 仅供需要直接数据库访问的场景使用（如数据库初始化、导入导出）
  final BeeDatabase db;

  /// 可选的变更追踪器，用于云同步
  ChangeTracker? changeTracker;

  // 子 Repository 实例
  late final LocalLedgerRepository _ledgerRepo;
  late final LocalTransactionRepository _transactionRepo;
  late final LocalCategoryRepository _categoryRepo;
  late final LocalAccountRepository _accountRepo;
  late final LocalStatisticsRepository _statisticsRepo;
  late final LocalRecurringTransactionRepository _recurringTransactionRepo;
  late final LocalAIRepository _aiRepo;
  late final LocalTagRepository _tagRepo;
  late final LocalBudgetRepository _budgetRepo;
  late final LocalAttachmentRepository _attachmentRepo;

  LocalRepository(this.db, {this.changeTracker}) {
    _ledgerRepo = LocalLedgerRepository(db);
    _transactionRepo = LocalTransactionRepository(db);
    _categoryRepo = LocalCategoryRepository(db);
    _accountRepo = LocalAccountRepository(db);
    _statisticsRepo = LocalStatisticsRepository(db);
    _recurringTransactionRepo = LocalRecurringTransactionRepository(db);
    _aiRepo = LocalAIRepository(db);
    _tagRepo = LocalTagRepository(db);
    _budgetRepo = LocalBudgetRepository(db);
    _attachmentRepo = LocalAttachmentRepository(db);
  }

  // ============================================
  // LedgerRepository 接口实现 - 委托给 LocalLedgerRepository
  // ============================================

  @override
  Stream<List<Ledger>> watchLedgers() => _ledgerRepo.watchLedgers();

  @override
  Future<List<Ledger>> getAllLedgers() => _ledgerRepo.getAllLedgers();

  @override
  Future<Ledger?> getLedgerById(int id) => _ledgerRepo.getLedgerById(id);

  @override
  Future<int> getLedgerCount() => _ledgerRepo.getLedgerCount();

  @override
  Future<int> ledgerCount() => _ledgerRepo.ledgerCount();

  @override
  Future<({int dayCount, int txCount})> getCountsForLedger({required int ledgerId}) =>
      _ledgerRepo.getCountsForLedger(ledgerId: ledgerId);

  @override
  Future<({int dayCount, int txCount})> getCountsAll() => _ledgerRepo.getCountsAll();

  @override
  Future<({double balance, int transactionCount})> getLedgerStats({
    required int ledgerId,
    bool accountFeatureEnabled = true,
    List<Transaction>? transactions,
  }) =>
      _ledgerRepo.getLedgerStats(
        ledgerId: ledgerId,
        accountFeatureEnabled: accountFeatureEnabled,
        transactions: transactions,
      );

  @override
  Future<int> createLedger({required String name, String currency = 'CNY'}) =>
      _ledgerRepo.createLedger(name: name, currency: currency);

  @override
  Future<void> updateLedgerName({required int id, required String name}) =>
      _ledgerRepo.updateLedgerName(id: id, name: name);

  @override
  Future<void> updateLedger({required int id, String? name, String? currency}) async {
    await _ledgerRepo.updateLedger(id: id, name: name, currency: currency);
    if (changeTracker != null) {
      final row =
          await (db.select(db.ledgers)..where((l) => l.id.equals(id))).getSingleOrNull();
      if (row != null && row.syncId != null && row.syncId!.isNotEmpty) {
        await changeTracker!.recordChange(
          entityType: 'ledger',
          entityId: id,
          entitySyncId: row.syncId!,
          ledgerId: id,
          action: 'update',
        );
      }
    }
  }

  @override
  Future<void> deleteLedger(int id) async {
    await _ledgerRepo.deleteLedger(id);
    if (changeTracker != null) {
      // Ledger 表没有 syncId 列，mobile 向 server 推送 ledger_snapshot 时
      // 都用本地 id 的字符串形式（见 sync_engine.fullPush line 1025）作为
      // external_id / entity_sync_id，这里保持一致。
      await changeTracker!.recordChange(
        entityType: 'ledger_snapshot',
        entityId: id,
        entitySyncId: id.toString(),
        ledgerId: id,
        action: 'delete',
      );
    }
  }

  @override
  Future<int> getMaxLedgerId() => _ledgerRepo.getMaxLedgerId();

  @override
  Future<int> getNextFreeLedgerId() => _ledgerRepo.getNextFreeLedgerId();

  @override
  Future<void> reassignLedgerId({required int fromId, required int toId}) =>
      _ledgerRepo.reassignLedgerId(fromId: fromId, toId: toId);

  @override
  Future<int> clearLedgerTransactions(int ledgerId) =>
      _ledgerRepo.clearLedgerTransactions(ledgerId);

  @override
  Future<double> getTotalInitialBalance(int ledgerId) =>
      _ledgerRepo.getTotalInitialBalance(ledgerId);

  // ============================================
  // TransactionRepository 接口实现 - 委托给 LocalTransactionRepository
  // ============================================

  @override
  Stream<List<Transaction>> watchRecentTransactions({required int ledgerId, int limit = 20}) =>
      _transactionRepo.watchRecentTransactions(ledgerId: ledgerId, limit: limit);

  @override
  Stream<List<Transaction>> watchTransactionsInMonth({required int ledgerId, required DateTime month}) =>
      _transactionRepo.watchTransactionsInMonth(ledgerId: ledgerId, month: month);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryAll({int? ledgerId}) =>
      _transactionRepo.watchTransactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transactionRepo.watchTransactionsWithCategoryInMonth(ledgerId: ledgerId, month: month);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  }) =>
      _transactionRepo.watchTransactionsWithCategoryInYear(ledgerId: ledgerId, year: year);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type,
  }) =>
      _transactionRepo.watchTransactionsForCategoryInRange(
        ledgerId: ledgerId,
        start: start,
        end: end,
        categoryId: categoryId,
        type: type,
      );

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
    String? syncId,
  }) async {
    final id = await _transactionRepo.addTransaction(
      ledgerId: ledgerId,
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      happenedAt: happenedAt,
      note: note,
      syncId: syncId,
    );
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx != null) {
        await changeTracker!.recordChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx.syncId!,
          ledgerId: ledgerId,
          action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<int> insertTransactionsBatch(List<TransactionsCompanion> items) =>
      _transactionRepo.insertTransactionsBatch(items);

  @override
  Future<void> updateTransaction({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    String? note,
    DateTime? happenedAt,
    dynamic accountId,
  }) async {
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx?.syncId != null) {
        await _transactionRepo.updateTransaction(
          id: id, type: type, amount: amount,
          categoryId: categoryId, note: note,
          happenedAt: happenedAt, accountId: accountId,
        );
        await changeTracker!.recordChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx!.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
        return;
      }
    }
    await _transactionRepo.updateTransaction(
      id: id, type: type, amount: amount,
      categoryId: categoryId, note: note,
      happenedAt: happenedAt, accountId: accountId,
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx!.syncId!,
          ledgerId: tx.ledgerId,
          action: 'delete',
        );
      }
    }
    await _transactionRepo.deleteTransaction(id);
  }

  @override
  Future<Transaction?> getTransactionById(int id) => _transactionRepo.getTransactionById(id);

  @override
  Future<int> insertTransactionCompanion(TransactionsCompanion item) =>
      _transactionRepo.insertTransactionCompanion(item);

  @override
  Stream<List<({Transaction t, Category? category})>> transactionsWithCategoryAll({int? ledgerId}) =>
      _transactionRepo.transactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Future<List<({Transaction t, Category? category})>> getRecentTransactionsWithCategory({
    required int ledgerId,
    required int limit,
  }) =>
      _transactionRepo.getRecentTransactionsWithCategory(ledgerId: ledgerId, limit: limit);

  @override
  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _transactionRepo.countByTypeInRange(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  @override
  Future<List<Transaction>> getTransactionsByLedger(int ledgerId) =>
      _transactionRepo.getTransactionsByLedger(ledgerId);

  @override
  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) =>
      _transactionRepo.getTransactionsByLedgerInRange(
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
      _transactionRepo.updateTransactionFields(
        id: id,
        accountId: accountId,
        toAccountId: toAccountId,
      );

  @override
  Future<Transaction?> getFirstTransactionByLedger(int ledgerId) =>
      _transactionRepo.getFirstTransactionByLedger(ledgerId);

  @override
  Future<Transaction?> getLastTransactionByLedger(int ledgerId) =>
      _transactionRepo.getLastTransactionByLedger(ledgerId);

  @override
  Future<void> updateTransactionLedger({required int id, required int ledgerId}) =>
      _transactionRepo.updateTransactionLedger(id: id, ledgerId: ledgerId);

  // ==================== 日历功能相关 ====================

  @override
  Future<Map<String, (double, double)>> getDailyTotalsByMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transactionRepo.getDailyTotalsByMonth(ledgerId: ledgerId, month: month);

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
      _transactionRepo.getTransactionsByDate(ledgerId: ledgerId, date: date);

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
      _transactionRepo.getTransactionsByDateRange(
          ledgerId: ledgerId, startDate: startDate, endDate: endDate);

  @override
  Future<List<String>> getTransactionDatesByMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transactionRepo.getTransactionDatesByMonth(
          ledgerId: ledgerId, month: month);

  @override
  Future<Transaction?> getTransactionBySyncId(String syncId) =>
      _transactionRepo.getTransactionBySyncId(syncId);

  @override
  Future<void> updateTransactionBySyncId({
    required String syncId,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    required DateTime happenedAt,
    String? note,
  }) =>
      _transactionRepo.updateTransactionBySyncId(
        syncId: syncId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        happenedAt: happenedAt,
        note: note,
      );

  @override
  Future<void> deleteTransactionBySyncId(String syncId) =>
      _transactionRepo.deleteTransactionBySyncId(syncId);

  @override
  Future<int> createAdjustmentTransaction({
    required int ledgerId,
    required int accountId,
    required double amount,
    required DateTime happenedAt,
    String? note,
  }) =>
      _transactionRepo.createAdjustmentTransaction(
        ledgerId: ledgerId,
        accountId: accountId,
        amount: amount,
        happenedAt: happenedAt,
        note: note,
      );

  // ============================================
  // CategoryRepository 接口实现 - 委托给 LocalCategoryRepository
  // ============================================

  @override
  Future<int> createCategory({required String name, required String kind, String? icon, int? sortOrder}) async {
    final id = await _categoryRepo.createCategory(name: name, kind: kind, icon: icon, sortOrder: sortOrder);
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, ledgerId: 0, action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) async {
    final id = await _categoryRepo.createSubCategory(
      parentId: parentId, name: name, kind: kind, icon: icon, sortOrder: sortOrder,
    );
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, ledgerId: 0, action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<void> updateCategory(int id, {String? name, String? icon, int? parentId, int? level}) async {
    final cat = changeTracker != null ? await _categoryRepo.getCategoryById(id) : null;
    await _categoryRepo.updateCategory(id, name: name, icon: icon, parentId: parentId, level: level);
    if (cat?.syncId != null) {
      await changeTracker!.recordChange(
        entityType: 'category', entityId: id,
        entitySyncId: cat!.syncId!, ledgerId: 0, action: 'update',
      );
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, ledgerId: 0, action: 'delete',
        );
      }
    }
    await _categoryRepo.deleteCategory(id);
  }

  @override
  Future<void> deleteCategoriesByIds(List<int> ids) =>
      _categoryRepo.deleteCategoriesByIds(ids);

  @override
  Future<int> upsertCategory({required String name, required String kind}) =>
      _categoryRepo.upsertCategory(name: name, kind: kind);

  @override
  Future<Category?> getCategoryById(int categoryId) =>
      _categoryRepo.getCategoryById(categoryId);

  @override
  Future<List<Category>> getTopLevelCategories(String kind) =>
      _categoryRepo.getTopLevelCategories(kind);

  @override
  Future<List<Category>> getSubCategories(int parentId) =>
      _categoryRepo.getSubCategories(parentId);

  @override
  Future<List<Category>> getUsableCategories(String kind) =>
      _categoryRepo.getUsableCategories(kind);

  @override
  Future<bool> isCategoryNameDuplicate({required String name, int? excludeId}) =>
      _categoryRepo.isCategoryNameDuplicate(name: name, excludeId: excludeId);

  @override
  Future<bool> hasSubCategories(int categoryId) =>
      _categoryRepo.hasSubCategories(categoryId);

  @override
  Future<int> getSubCategoryCount(int categoryId) =>
      _categoryRepo.getSubCategoryCount(categoryId);

  @override
  Future<int> getTransactionCountByCategory(int categoryId) =>
      _categoryRepo.getTransactionCountByCategory(categoryId);

  @override
  Future<Map<int, int>> getAllCategoryTransactionCounts() =>
      _categoryRepo.getAllCategoryTransactionCounts();

  @override
  Future<({int totalCount, double totalAmount, double averageAmount})> getCategorySummary(int categoryId) =>
      _categoryRepo.getCategorySummary(categoryId);

  @override
  Future<List<Transaction>> getTransactionsByCategory(int categoryId) =>
      _categoryRepo.getTransactionsByCategory(categoryId);

  @override
  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time',
    bool ascending = false,
  }) =>
      _categoryRepo.getTransactionsByCategoryWithSort(
        categoryId,
        sortBy: sortBy,
        ascending: ascending,
      );

  @override
  Future<int> migrateCategory({required int fromCategoryId, required int toCategoryId}) =>
      _categoryRepo.migrateCategory(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

  @override
  Future<({int migratedTransactions, int migratedSubCategories})> migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  }) =>
      _categoryRepo.migrateCategoryTransactions(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

  @override
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  }) =>
      _categoryRepo.getCategoryMigrationInfo(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

  @override
  Future<void> updateCategorySortOrders(List<({int id, int sortOrder})> updates) =>
      _categoryRepo.updateCategorySortOrders(updates);

  @override
  Future<String> getCategoryFullName(int categoryId) =>
      _categoryRepo.getCategoryFullName(categoryId);

  @override
  Stream<Category?> watchCategory(int categoryId) =>
      _categoryRepo.watchCategory(categoryId);

  @override
  Stream<List<Transaction>> watchTransactionsByCategory(int categoryId, {int? ledgerId}) =>
      _categoryRepo.watchTransactionsByCategory(categoryId, ledgerId: ledgerId);

  @override
  Stream<List<Category>> watchCategoryWithSubs(int categoryId) =>
      _categoryRepo.watchCategoryWithSubs(categoryId);

  @override
  Stream<List<({Category category, int transactionCount})>> watchCategoriesWithCount() =>
      _categoryRepo.watchCategoriesWithCount();

  @override
  Future<List<Category>> getAllCategories() => _categoryRepo.getAllCategories();

  @override
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories) =>
      _categoryRepo.batchInsertCategories(categories);

  @override
  Future<int> insertCategory(CategoriesCompanion category) =>
      _categoryRepo.insertCategory(category);

  @override
  Future<void> updateCategoryIcon(
    int id, {
    required String iconType,
    String? icon,
    String? customIconPath,
    String? communityIconId,
  }) async {
    await _categoryRepo.updateCategoryIcon(
      id,
      iconType: iconType,
      icon: icon,
      customIconPath: customIconPath,
      communityIconId: communityIconId,
    );
    // 图标改动也需要 push 到服务端 —— 否则 mobile 改了图标 web 永远看不到。
    // ledgerId=0：分类是 user-scoped，和 name 改动走同一条 push 通道。
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, ledgerId: 0, action: 'update',
        );
      }
    }
  }

  @override
  Future<void> clearCategoryCustomIcon(int id, {String? materialIcon}) async {
    await _categoryRepo.clearCategoryCustomIcon(id, materialIcon: materialIcon);
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, ledgerId: 0, action: 'update',
        );
      }
    }
  }

  @override
  Future<List<String>> getCustomIconPaths() => _categoryRepo.getCustomIconPaths();

  @override
  Future<Category> getTransferCategory() => _categoryRepo.getTransferCategory();

  // ============================================
  // AccountRepository 接口实现 - 委托给 LocalAccountRepository
  // ============================================

  @override
  Stream<List<Account>> watchAccountsForLedger(int ledgerId) =>
      _accountRepo.watchAccountsForLedger(ledgerId);

  @override
  Stream<List<Account>> watchAllAccounts() => _accountRepo.watchAllAccounts();

  @override
  Future<List<Account>> getAllAccounts() => _accountRepo.getAllAccounts();

  @override
  Future<Account?> getAccount(int accountId) => _accountRepo.getAccount(accountId);

  @override
  Future<List<Account>> getAvailableAccountsForLedger(int ledgerId) =>
      _accountRepo.getAvailableAccountsForLedger(ledgerId);

  @override
  Future<List<Account>> getAccountsByCurrency(String currency) =>
      _accountRepo.getAccountsByCurrency(currency);

  @override
  Future<Map<String, List<Account>>> getAccountsGroupedByCurrency() =>
      _accountRepo.getAccountsGroupedByCurrency();

  @override
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
  }) async {
    final id = await _accountRepo.createAccount(
      ledgerId: ledgerId,
      name: name,
      type: type,
      currency: currency,
      initialBalance: initialBalance,
      creditLimit: creditLimit,
      billingDay: billingDay,
      paymentDueDay: paymentDueDay,
      bankName: bankName,
      cardLastFour: cardLastFour,
      note: note,
    );
    if (changeTracker != null) {
      final account = await _accountRepo.getAccount(id);
      if (account?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'account',
          entityId: id,
          entitySyncId: account!.syncId!,
          // Account 跟 Category / Tag 一样是 user-global 实体,走 ledgerId=0
          // 通道 —— sync_engine._push 里 globalChanges 会把 ledgerId=0 的
          // 变更搭任一账本的同步链带出去。之前用 account.ledgerId 会让
          // 变更只挂到某个具体账本上,用户在其它账本触发 sync 时 _push 拉
          // 不到这条 orphan change,rename/create/delete 就永远卡在本地。
          ledgerId: 0,
          action: 'create',
        );
      }
    }
    return id;
  }

  @override
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
  }) async {
    final account = changeTracker != null ? await _accountRepo.getAccount(id) : null;
    await _accountRepo.updateAccount(
      id,
      name: name,
      type: type,
      currency: currency,
      initialBalance: initialBalance,
      creditLimit: creditLimit,
      billingDay: billingDay,
      paymentDueDay: paymentDueDay,
      clearCreditCardFields: clearCreditCardFields,
      bankName: bankName,
      cardLastFour: cardLastFour,
      note: note,
      clearMetadataFields: clearMetadataFields,
    );
    if (account?.syncId != null) {
      await changeTracker!.recordChange(
        entityType: 'account',
        entityId: id,
        entitySyncId: account!.syncId!,
        // user-global,走 ledgerId=0 通道。见 createAccount 处的详细注释。
        ledgerId: 0,
        action: 'update',
      );
    }
  }

  @override
  Future<List<Account>> getCreditCardAccounts() =>
      _accountRepo.getCreditCardAccounts();

  @override
  Future<double> getCreditCardUsedAmount(int accountId) =>
      _accountRepo.getCreditCardUsedAmount(accountId);

  @override
  Future<void> deleteAccount(int id) async {
    if (changeTracker != null) {
      final account = await _accountRepo.getAccount(id);
      if (account?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'account',
          entityId: id,
          entitySyncId: account!.syncId!,
          // user-global,走 ledgerId=0 通道。见 createAccount 处的详细注释。
          ledgerId: 0,
          action: 'delete',
        );
      }
    }
    await _accountRepo.deleteAccount(id);
  }

  @override
  Future<double> getAccountBalance(int accountId) =>
      _accountRepo.getAccountBalance(accountId);

  @override
  Future<double> getAccountGlobalBalance(int accountId) =>
      _accountRepo.getAccountGlobalBalance(accountId);

  @override
  Future<double> getAccountBalanceInLedger(int accountId, int ledgerId) =>
      _accountRepo.getAccountBalanceInLedger(accountId, ledgerId);

  @override
  Future<Map<int, double>> getAllAccountBalances(int ledgerId) =>
      _accountRepo.getAllAccountBalances(ledgerId);

  @override
  Future<int> getTransactionCountByAccount(int accountId) =>
      _accountRepo.getTransactionCountByAccount(accountId);

  @override
  Future<double> getAccountExpense(int accountId) =>
      _accountRepo.getAccountExpense(accountId);

  @override
  Future<double> getAccountIncome(int accountId) =>
      _accountRepo.getAccountIncome(accountId);

  @override
  Future<({double balance, double expense, double income})> getAccountStats(int accountId) =>
      _accountRepo.getAccountStats(accountId);

  @override
  Future<Map<int, ({double balance, double expense, double income})>> getAllAccountStats() =>
      _accountRepo.getAllAccountStats();

  @override
  Future<({double totalBalance, double totalExpense, double totalIncome})> getAllAccountsTotalStats() =>
      _accountRepo.getAllAccountsTotalStats();

  @override
  Future<Map<int, int>> getAccountUsageInLedgers(int accountId) =>
      _accountRepo.getAccountUsageInLedgers(accountId);

  @override
  Future<int> migrateAccount({required int fromAccountId, required int toAccountId}) =>
      _accountRepo.migrateAccount(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
      );

  @override
  Future<bool> hasTransactions(int accountId) =>
      _accountRepo.hasTransactions(accountId);

  @override
  Stream<Account?> watchAccount(int accountId) =>
      _accountRepo.watchAccount(accountId);

  @override
  Stream<List<Transaction>> watchAccountTransactions(int accountId) =>
      _accountRepo.watchAccountTransactions(accountId);

  @override
  Future<void> batchInsertAccounts(List<AccountsCompanion> accounts) =>
      _accountRepo.batchInsertAccounts(accounts);

  @override
  Future<List<Account>> getAccountsByIds(List<int> accountIds) =>
      _accountRepo.getAccountsByIds(accountIds);

  @override
  Future<void> updateAccountSortOrders(List<({int id, int sortOrder})> updates) =>
      _accountRepo.updateAccountSortOrders(updates);

  @override
  Future<List<Transaction>> getAccountTransactions(
    int accountId, {int limit = 50, int offset = 0}) =>
      _accountRepo.getAccountTransactions(accountId, limit: limit, offset: offset);

  @override
  Future<List<({DateTime date, double balance})>> getAccountDailyBalances(
    int accountId, {required DateTime startDate, required DateTime endDate}) =>
      _accountRepo.getAccountDailyBalances(accountId, startDate: startDate, endDate: endDate);

  @override
  Future<List<({int? id, String name, String? icon, double total})>>
      getAccountCategoryStats(int accountId, {required String type}) =>
      _accountRepo.getAccountCategoryStats(accountId, type: type);

  @override
  Future<({double totalAssets, double totalLiabilities, double netWorth})> getNetWorthBreakdown() =>
      _accountRepo.getNetWorthBreakdown();

  @override
  Future<Map<String, ({double totalAssets, double totalLiabilities, double netWorth})>> getNetWorthBreakdownByCurrency() =>
      _accountRepo.getNetWorthBreakdownByCurrency();

  @override
  Future<List<({DateTime date, double balance})>> getNetWorthDailyBalances({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _accountRepo.getNetWorthDailyBalances(startDate: startDate, endDate: endDate);

  @override
  Future<List<({String type, double totalBalance})>> getAssetCompositionByType() =>
      _accountRepo.getAssetCompositionByType();

  @override
  Future<void> updateAccountValuation(int accountId, double newValue) =>
      _accountRepo.updateAccountValuation(accountId, newValue);

  // ============================================
  // StatisticsRepository 接口实现 - 委托给 LocalStatisticsRepository
  // ============================================

  @override
  Future<List<({int? id, String name, String? icon, double total})>> totalsByCategory({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _statisticsRepo.totalsByCategory(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  @override
  Future<List<({int? id, String name, String? icon, int? parentId, int level, double total})>>
      totalsByCategoryWithHierarchy({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
          _statisticsRepo.totalsByCategoryWithHierarchy(
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
      _statisticsRepo.totalsByDay(
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
      _statisticsRepo.totalsByMonth(
        ledgerId: ledgerId,
        type: type,
        year: year,
      );

  @override
  Future<List<({int year, double total})>> totalsByYearSeries({
    required int ledgerId,
    required String type,
  }) =>
      _statisticsRepo.totalsByYearSeries(
        ledgerId: ledgerId,
        type: type,
      );

  @override
  Future<(double income, double expense)> totalsInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) =>
      _statisticsRepo.totalsInRange(
        ledgerId: ledgerId,
        start: start,
        end: end,
      );

  @override
  Future<(double income, double expense)> monthlyTotals({
    required int ledgerId,
    required DateTime month,
  }) =>
      _statisticsRepo.monthlyTotals(
        ledgerId: ledgerId,
        month: month,
      );

  @override
  Future<(double income, double expense)> yearlyTotals({
    required int ledgerId,
    required int year,
  }) =>
      _statisticsRepo.yearlyTotals(
        ledgerId: ledgerId,
        year: year,
      );

  // ============================================
  // RecurringTransactionRepository 接口实现 - 委托给 LocalRecurringTransactionRepository
  // ============================================

  @override
  Future<List<RecurringTransaction>> getAllRecurringTransactions() =>
      _recurringTransactionRepo.getAllRecurringTransactions();

  @override
  Future<List<RecurringTransaction>> getRecurringTransactionsByLedger(int ledgerId) =>
      _recurringTransactionRepo.getRecurringTransactionsByLedger(ledgerId);

  @override
  Future<List<RecurringTransaction>> getEnabledRecurringTransactions(int ledgerId) =>
      _recurringTransactionRepo.getEnabledRecurringTransactions(ledgerId);

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
      _recurringTransactionRepo.addRecurringTransaction(
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
    DateTime? lastGeneratedDate,
  }) =>
      _recurringTransactionRepo.updateRecurringTransaction(
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
        lastGeneratedDate: lastGeneratedDate,
      );

  @override
  Future<void> deleteRecurringTransaction(int id) =>
      _recurringTransactionRepo.deleteRecurringTransaction(id);

  @override
  Future<void> toggleRecurringTransaction(int id, bool enabled) =>
      _recurringTransactionRepo.toggleRecurringTransaction(id, enabled);

  @override
  Future<void> updateLastGeneratedDate(int id, DateTime date) =>
      _recurringTransactionRepo.updateLastGeneratedDate(id, date);

  @override
  Stream<List<RecurringTransaction>> watchAllRecurringTransactions() =>
      _recurringTransactionRepo.watchAllRecurringTransactions();

  @override
  Stream<List<RecurringTransaction>> watchRecurringTransactionsByLedger(int ledgerId) =>
      _recurringTransactionRepo.watchRecurringTransactionsByLedger(ledgerId);

  @override
  Future<void> batchInsertRecurringTransactions(List<RecurringTransactionsCompanion> items) =>
      _recurringTransactionRepo.batchInsertRecurringTransactions(items);

  // ============================================
  // AIRepository 接口实现 - 委托给 LocalAIRepository
  // ============================================

  @override
  Future<Conversation?> getActiveConversation() =>
      _aiRepo.getActiveConversation();

  @override
  Future<Conversation?> getConversationById(int id) =>
      _aiRepo.getConversationById(id);

  @override
  Future<int> createConversation(ConversationsCompanion conversation) =>
      _aiRepo.createConversation(conversation);

  @override
  Future<void> updateConversation(Conversation conversation) =>
      _aiRepo.updateConversation(conversation);

  @override
  Future<void> deleteConversation(int id) =>
      _aiRepo.deleteConversation(id);

  @override
  Stream<List<Message>> watchMessages(int conversationId) =>
      _aiRepo.watchMessages(conversationId);

  @override
  Future<Message?> getMessageById(int id) =>
      _aiRepo.getMessageById(id);

  @override
  Future<int> createMessage(MessagesCompanion message) =>
      _aiRepo.createMessage(message);

  @override
  Future<void> updateMessage(Message message) =>
      _aiRepo.updateMessage(message);

  @override
  Future<void> deleteMessagesByConversation(int conversationId) =>
      _aiRepo.deleteMessagesByConversation(conversationId);

  @override
  Future<void> deleteMessage(int id) =>
      _aiRepo.deleteMessage(id);

  @override
  Future<Message?> getMessageByTransactionId(int transactionId) =>
      _aiRepo.getMessageByTransactionId(transactionId);

  // ============================================
  // TagRepository 接口实现 - 委托给 LocalTagRepository
  // ============================================

  @override
  Future<int> createTag({
    required String name,
    String? color,
    int sortOrder = 0,
  }) async {
    final id = await _tagRepo.createTag(name: name, color: color, sortOrder: sortOrder);
    if (changeTracker != null) {
      final tag = await _tagRepo.getTagById(id);
      if (tag?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'tag', entityId: id,
          entitySyncId: tag!.syncId!, ledgerId: 0, action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<void> updateTag(
    int id, {
    String? name,
    String? color,
    int? sortOrder,
  }) async {
    final tag = changeTracker != null ? await _tagRepo.getTagById(id) : null;
    await _tagRepo.updateTag(id, name: name, color: color, sortOrder: sortOrder);
    if (tag?.syncId != null) {
      await changeTracker!.recordChange(
        entityType: 'tag', entityId: id,
        entitySyncId: tag!.syncId!, ledgerId: 0, action: 'update',
      );
    }
  }

  @override
  Future<void> deleteTag(int id) async {
    if (changeTracker != null) {
      final tag = await _tagRepo.getTagById(id);
      if (tag?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'tag', entityId: id,
          entitySyncId: tag!.syncId!, ledgerId: 0, action: 'delete',
        );
      }
    }
    await _tagRepo.deleteTag(id);
  }

  @override
  Future<Tag?> getTagById(int id) => _tagRepo.getTagById(id);

  @override
  Future<Tag?> getTagByName(String name) => _tagRepo.getTagByName(name);

  @override
  Future<List<Tag>> getAllTags() => _tagRepo.getAllTags();

  @override
  Future<void> batchInsertTags(List<TagsCompanion> tags) =>
      _tagRepo.batchInsertTags(tags);

  @override
  Future<void> addTagToTransaction({
    required int transactionId,
    required int tagId,
  }) =>
      _tagRepo.addTagToTransaction(transactionId: transactionId, tagId: tagId);

  @override
  Future<void> addTagsToTransaction({
    required int transactionId,
    required List<int> tagIds,
  }) =>
      _tagRepo.addTagsToTransaction(transactionId: transactionId, tagIds: tagIds);

  @override
  Future<void> removeTagFromTransaction({
    required int transactionId,
    required int tagId,
  }) =>
      _tagRepo.removeTagFromTransaction(transactionId: transactionId, tagId: tagId);

  @override
  Future<void> removeAllTagsFromTransaction(int transactionId) =>
      _tagRepo.removeAllTagsFromTransaction(transactionId);

  @override
  Future<void> updateTransactionTags({
    required int transactionId,
    required List<int> tagIds,
  }) =>
      _tagRepo.updateTransactionTags(transactionId: transactionId, tagIds: tagIds);

  @override
  Future<List<Tag>> getTagsForTransaction(int transactionId) =>
      _tagRepo.getTagsForTransaction(transactionId);

  @override
  Future<Map<int, List<Tag>>> getTagsForTransactions(List<int> transactionIds) =>
      _tagRepo.getTagsForTransactions(transactionIds);

  @override
  Future<List<int>> getTransactionIdsByTag(int tagId) =>
      _tagRepo.getTransactionIdsByTag(tagId);

  @override
  Future<int> getTransactionCountByTag(int tagId) =>
      _tagRepo.getTransactionCountByTag(tagId);

  @override
  Future<Map<int, int>> getAllTagTransactionCounts() =>
      _tagRepo.getAllTagTransactionCounts();

  @override
  Future<({int count, double expense, double income})> getTagStats(int tagId) =>
      _tagRepo.getTagStats(tagId);

  @override
  Future<List<Transaction>> getTransactionsByTag(int tagId) =>
      _tagRepo.getTransactionsByTag(tagId);

  @override
  Future<List<Transaction>> getTransactionsByTagInRange({
    required int tagId,
    required DateTime start,
    required DateTime end,
  }) =>
      _tagRepo.getTransactionsByTagInRange(tagId: tagId, start: start, end: end);

  @override
  Stream<List<Tag>> watchAllTags() => _tagRepo.watchAllTags();

  @override
  Stream<List<({Tag tag, int transactionCount})>> watchTagsWithStats() =>
      _tagRepo.watchTagsWithStats();

  @override
  Stream<Tag?> watchTag(int tagId) => _tagRepo.watchTag(tagId);

  @override
  Stream<List<Tag>> watchTagsForTransaction(int transactionId) =>
      _tagRepo.watchTagsForTransaction(transactionId);

  @override
  Stream<List<Transaction>> watchTransactionsByTag(int tagId) =>
      _tagRepo.watchTransactionsByTag(tagId);

  @override
  Future<bool> isTagNameDuplicate({required String name, int? excludeId}) =>
      _tagRepo.isTagNameDuplicate(name: name, excludeId: excludeId);

  @override
  Future<void> updateTagSortOrders(List<({int id, int sortOrder})> updates) =>
      _tagRepo.updateTagSortOrders(updates);

  @override
  Future<List<Tag>> getRecentlyUsedTags({int limit = 10}) =>
      _tagRepo.getRecentlyUsedTags(limit: limit);

  // ============================================
  // BudgetRepository 接口实现 - 委托给 LocalBudgetRepository
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
    final id = await _budgetRepo.createBudget(
      ledgerId: ledgerId,
      type: type,
      categoryId: categoryId,
      amount: amount,
      period: period,
      startDay: startDay,
    );
    if (changeTracker != null) {
      final row = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
          .getSingleOrNull();
      if (row?.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'budget',
          entityId: id,
          entitySyncId: row!.syncId!,
          ledgerId: ledgerId,
          action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<void> updateBudget(
    int id, {
    double? amount,
    int? startDay,
    bool? enabled,
  }) async {
    await _budgetRepo.updateBudget(
      id,
      amount: amount,
      startDay: startDay,
      enabled: enabled,
    );
    if (changeTracker != null) {
      final row = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
          .getSingleOrNull();
      if (row != null && row.syncId != null) {
        await changeTracker!.recordChange(
          entityType: 'budget',
          entityId: id,
          entitySyncId: row.syncId!,
          ledgerId: row.ledgerId,
          action: 'update',
        );
      }
    }
  }

  @override
  Future<void> deleteBudget(int id) async {
    // 先拿到要删的行(syncId / ledgerId),再走仓库的级联删除。删总预算会连同
    // 带所有分类预算一起清;这里需要为每条挂掉的 budget 登记一条 delete change,
    // 否则对端的总预算删不掉。
    final target = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (target == null) return;

    List<Budget> toRecord = [target];
    if (target.type == 'total') {
      // 总预算的删除会级联清同 ledger 下所有 budget。
      toRecord = await (db.select(db.budgets)
            ..where((b) => b.ledgerId.equals(target.ledgerId)))
          .get();
    }

    await _budgetRepo.deleteBudget(id);

    if (changeTracker != null) {
      for (final b in toRecord) {
        if (b.syncId == null) continue;
        await changeTracker!.recordChange(
          entityType: 'budget',
          entityId: b.id,
          entitySyncId: b.syncId!,
          ledgerId: b.ledgerId,
          action: 'delete',
        );
      }
    }
  }

  @override
  Future<Budget?> getTotalBudget(int ledgerId) => _budgetRepo.getTotalBudget(ledgerId);

  @override
  Future<List<Budget>> getCategoryBudgets(int ledgerId) =>
      _budgetRepo.getCategoryBudgets(ledgerId);

  @override
  Future<Budget?> getBudgetByCategory(int ledgerId, int categoryId) =>
      _budgetRepo.getBudgetByCategory(ledgerId, categoryId);

  @override
  Future<List<Budget>> getAllBudgets(int ledgerId) => _budgetRepo.getAllBudgets(ledgerId);

  @override
  Future<List<Budget>> getAllBudgetsForExport() => _budgetRepo.getAllBudgetsForExport();

  @override
  Future<BudgetUsage> getBudgetUsage(int budgetId, DateTime month) =>
      _budgetRepo.getBudgetUsage(budgetId, month);

  @override
  Future<BudgetOverview> getBudgetOverview(int ledgerId, DateTime month) =>
      _budgetRepo.getBudgetOverview(ledgerId, month);

  @override
  Future<List<CategoryBudgetUsage>> getCategoryBudgetUsages(int ledgerId, DateTime month) =>
      _budgetRepo.getCategoryBudgetUsages(ledgerId, month);

  @override
  Stream<List<Budget>> watchBudgets(int ledgerId) => _budgetRepo.watchBudgets(ledgerId);

  // ============================================
  // AttachmentRepository 接口实现 - 委托给 LocalAttachmentRepository
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
    String? cloudFileId,
    String? cloudSha256,
  }) async {
    final id = await _attachmentRepo.createAttachment(
      transactionId: transactionId,
      fileName: fileName,
      originalName: originalName,
      fileSize: fileSize,
      width: width,
      height: height,
      sortOrder: sortOrder,
      cloudFileId: cloudFileId,
      cloudSha256: cloudSha256,
    );
    // 附件本身不走 sync_change 表（server 通过 tx payload 里的 attachments
    // 数组下发），但必须给父 tx 登记一条 update change，否则另一台设备永远
    // 收不到"这条 tx 多了附件"的通知。
    await _recordTransactionUpdateForAttachmentChange(transactionId);
    return id;
  }

  @override
  Future<TransactionAttachment?> getAttachmentById(int id) =>
      _attachmentRepo.getAttachmentById(id);

  @override
  Future<List<TransactionAttachment>> getAttachmentsByTransaction(int transactionId) =>
      _attachmentRepo.getAttachmentsByTransaction(transactionId);

  @override
  Future<void> deleteAttachment(int id) async {
    // 在真正删除之前读出 transactionId，删除后登记父 tx update，让 B 端 pull
    // 下去也能看到附件已被移除。
    final row = await _attachmentRepo.getAttachmentById(id);
    await _attachmentRepo.deleteAttachment(id);
    if (row != null) {
      await _recordTransactionUpdateForAttachmentChange(row.transactionId);
    }
  }

  @override
  Future<void> deleteAttachmentsByTransaction(int transactionId) async {
    await _attachmentRepo.deleteAttachmentsByTransaction(transactionId);
    await _recordTransactionUpdateForAttachmentChange(transactionId);
  }

  /// 附件增删触发父 tx 的 update change，让 push 侧重序列化 tx payload
  /// （带上新 attachments 数组）推到 server，B 端 pull 后同步到视图。
  Future<void> _recordTransactionUpdateForAttachmentChange(
      int transactionId) async {
    if (changeTracker == null) return;
    final tx = await _transactionRepo.getTransactionById(transactionId);
    if (tx == null || tx.syncId == null) return;
    await changeTracker!.recordChange(
      entityType: 'transaction',
      entityId: transactionId,
      entitySyncId: tx.syncId!,
      ledgerId: tx.ledgerId,
      action: 'update',
    );
  }

  @override
  Future<void> updateAttachmentSortOrder(int id, int sortOrder) =>
      _attachmentRepo.updateAttachmentSortOrder(id, sortOrder);

  @override
  Future<void> updateAttachmentSortOrders(List<({int id, int sortOrder})> updates) =>
      _attachmentRepo.updateAttachmentSortOrders(updates);

  @override
  Future<void> updateAttachmentCloudRef(int id, {String? cloudFileId, String? cloudSha256}) =>
      _attachmentRepo.updateAttachmentCloudRef(id, cloudFileId: cloudFileId, cloudSha256: cloudSha256);

  @override
  Future<bool> attachmentExistsByFileName(String fileName) =>
      _attachmentRepo.attachmentExistsByFileName(fileName);

  @override
  Future<int> getAttachmentCountByTransaction(int transactionId) =>
      _attachmentRepo.getAttachmentCountByTransaction(transactionId);

  @override
  Future<Map<int, int>> getAttachmentCountsForTransactions(List<int> transactionIds) =>
      _attachmentRepo.getAttachmentCountsForTransactions(transactionIds);

  @override
  Future<Map<int, List<TransactionAttachment>>> getAttachmentsForTransactions(List<int> transactionIds) =>
      _attachmentRepo.getAttachmentsForTransactions(transactionIds);

  @override
  Future<List<int>> getTransactionIdsWithAttachments() =>
      _attachmentRepo.getTransactionIdsWithAttachments();

  @override
  Future<List<TransactionAttachment>> getAllAttachments() =>
      _attachmentRepo.getAllAttachments();

  @override
  Future<void> deleteAttachmentByFileName(String fileName) =>
      _attachmentRepo.deleteAttachmentByFileName(fileName);

  @override
  Stream<List<TransactionAttachment>> watchAttachmentsByTransaction(int transactionId) =>
      _attachmentRepo.watchAttachmentsByTransaction(transactionId);

  @override
  Stream<int> watchAttachmentCountByTransaction(int transactionId) =>
      _attachmentRepo.watchAttachmentCountByTransaction(transactionId);
}
