import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../../../cloud/sync/change_tracker.dart';
import '../../../services/system/logger_service.dart';
import '../base_repository.dart';
import '../budget_repository.dart';
import '../transaction_repository.dart'
    show BatchAttachmentData, TransactionUpdateBySyncIdData;
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

  /// UUID 生成器,批量方法需要预填 syncId 才能查回插入的行登记变更。
  static const _uuid = Uuid();

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
        await changeTracker!.recordLedgerChange(
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
    if (changeTracker == null) {
      await _ledgerRepo.deleteLedger(id);
      return;
    }
    // 删除前预查级联会消失的 transactions 和 budgets,删完后逐条登记 delete
    // change。之前只记 ledger_snapshot:delete 一条,server 端如果不做级联
    // (或对端 mobile 各按自己的契约 apply),本地删干净的 tx 在云端可能继续
    // 残留。多记不会错,server 重复 delete 是幂等的。
    //
    // 顺便清掉 budgets:子仓库 deleteLedger 当前只 cascade tx,budgets 留着
    // 会成 ledgerId 悬空的孤儿行(pre-existing 小 bug)。在同一个 db.transaction
    // 里清掉,登记 budget:delete 推到 server。
    //
    // 关键修复:必须先把 ledger.syncId 拿出来,否则 _ledgerRepo.deleteLedger
    // 之后 ledger 行就没了,后续 _push 拿不到 syncId 推不掉云端账本。
    await db.transaction(() async {
      final ledgerRow = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(id)))
          .getSingleOrNull();
      // ledger.syncId 是 server 端的 external_id(v21 migration 把老数据回填
      // 成 id.toString(),新建账本是 UUID)。删本地行之后这个值就丢了,所以
      // 必须现在捕获。fallback id.toString() 只为兼容缺 syncId 的极老数据。
      final ledgerSyncId = ledgerRow?.syncId ?? id.toString();

      final txs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(id)))
          .get();
      final budgets = await (db.select(db.budgets)
            ..where((b) => b.ledgerId.equals(id)))
          .get();

      await _ledgerRepo.deleteLedger(id);
      // 顺便把残留的 budgets 一起清,见上面注释。
      if (budgets.isNotEmpty) {
        await (db.delete(db.budgets)..where((b) => b.ledgerId.equals(id)))
            .go();
      }

      for (final tx in txs) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: id,
          action: 'delete',
        );
      }
      for (final b in budgets) {
        if (b.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'budget',
          entityId: b.id,
          entitySyncId: b.syncId!,
          ledgerId: id,
          action: 'delete',
        );
      }
      // ledger_snapshot:delete 用 ledger.syncId 作为 entity_sync_id,server
      // 才能按 external_id 找到对应的 ledger 删掉(server 用 syncId/UUID 做
      // external_id,不是本地 int id)。这点跟 sync_engine._pushAllEntities
      // line 2116 `final ledgerId = ledger.syncId ?? ledger.id.toString()`
      // 完全一致。
      await changeTracker!.recordLedgerChange(
        entityType: 'ledger_snapshot',
        entityId: id,
        entitySyncId: ledgerSyncId,
        ledgerId: id,
        action: 'delete',
      );
      logger.info('LocalRepository',
          'deleteLedger($id) 已登记 ${txs.length} 条 transaction:delete + '
          '${budgets.length} 条 budget:delete + 1 条 ledger_snapshot:delete '
          '(ledgerSyncId=$ledgerSyncId)');
    });
  }

  @override
  Future<int> getMaxLedgerId() => _ledgerRepo.getMaxLedgerId();

  @override
  Future<int> getNextFreeLedgerId() => _ledgerRepo.getNextFreeLedgerId();

  @override
  Future<void> reassignLedgerId({required int fromId, required int toId}) =>
      _ledgerRepo.reassignLedgerId(fromId: fromId, toId: toId);

  @override
  Future<int> clearLedgerTransactions(int ledgerId) async {
    if (changeTracker == null) {
      return _ledgerRepo.clearLedgerTransactions(ledgerId);
    }
    // 删除前预查 (id, syncId),删完才能登记 N 条 transaction:delete 变更。
    // 之前清空账本走裸 SQL bulk delete 不登记变更,UI 调了 sync 但
    // ChangeTracker 是空,云端永远删不掉。
    return db.transaction(() async {
      final txs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(ledgerId)))
          .get();
      final n = await _ledgerRepo.clearLedgerTransactions(ledgerId);
      for (final tx in txs) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: ledgerId,
          action: 'delete',
        );
      }
      return n;
    });
  }

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
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsWithCategoryAll({int? ledgerId}) =>
      _transactionRepo.watchTransactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transactionRepo.watchTransactionsWithCategoryInMonth(ledgerId: ledgerId, month: month);

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  }) =>
      _transactionRepo.watchTransactionsWithCategoryInYear(ledgerId: ledgerId, year: year);

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> watchTransactionsForCategoryInRange({
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
    String? categorySyncIdOverride,
    String? accountSyncIdOverride,
    String? toAccountSyncIdOverride,
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
      categorySyncIdOverride: categorySyncIdOverride,
      accountSyncIdOverride: accountSyncIdOverride,
      toAccountSyncIdOverride: toAccountSyncIdOverride,
    );
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx != null) {
        await changeTracker!.recordLedgerChange(
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
  Future<int> insertTransactionsBatch(
    List<TransactionsCompanion> items, {
    bool recordChanges = true,
  }) async {
    // recordChanges=false:FullPull 走静默写入路径,云端拉下来的数据**不**再
    // 反向 push 回去(否则 10k 条 fullPull 会产生 10k 行 local_changes,触发
    // SyncCoordinator 反向同步,白白多一轮)。
    if (!recordChanges || changeTracker == null || items.isEmpty) {
      return _transactionRepo.insertTransactionsBatch(items);
    }
    // 预填充 syncId,这样插入完能根据 syncId 查回行,逐条登记 create change。
    // 子仓库虽然也会自动补 syncId,但补完是局部变量,wrapper 这里看不到,所
    // 以不能依赖。
    final effective = items.map((item) {
      if (item.syncId == const d.Value.absent() || item.syncId.value == null) {
        return item.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return item;
    }).toList();
    return db.transaction(() async {
      final n = await _transactionRepo.insertTransactionsBatch(effective);
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return n;
      final inserted = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      for (final tx in inserted) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'create',
        );
      }
      return n;
    });
  }

  @override
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
  }) async {
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx?.syncId != null) {
        await _transactionRepo.updateTransaction(
          id: id, type: type, amount: amount,
          categoryId: categoryId, note: note,
          happenedAt: happenedAt, accountId: accountId,
          categorySyncIdOverride: categorySyncIdOverride,
          accountSyncIdOverride: accountSyncIdOverride,
          toAccountSyncIdOverride: toAccountSyncIdOverride,
        );
        await changeTracker!.recordLedgerChange(
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
      categorySyncIdOverride: categorySyncIdOverride,
      accountSyncIdOverride: accountSyncIdOverride,
      toAccountSyncIdOverride: toAccountSyncIdOverride,
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx?.syncId != null) {
        await changeTracker!.recordLedgerChange(
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
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    Map<int, List<int>> tagIdsByIndex = const {},
    Map<int, List<BatchAttachmentData>> attachmentsByIndex = const {},
    bool recordChanges = true,
  }) async {
    if (transactions.isEmpty) return const [];
    // recordChanges=false / 没挂 changeTracker → 直接走子仓库,不补 change log。
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.insertTransactionsBatchWithRelations(
        transactions: transactions,
        tagIdsByIndex: tagIdsByIndex,
        attachmentsByIndex: attachmentsByIndex,
      );
    }
    // 预填充 syncId 让 wrapper 也能根据 syncId 查回行后登记 change(子仓库会
    // 看到这些已填的 syncId,不会重复生成)。
    final effective = transactions.map((tx) {
      if (tx.syncId == const d.Value.absent() || tx.syncId.value == null) {
        return tx.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return tx;
    }).toList();
    return db.transaction(() async {
      final ids = await _transactionRepo.insertTransactionsBatchWithRelations(
        transactions: effective,
        tagIdsByIndex: tagIdsByIndex,
        attachmentsByIndex: attachmentsByIndex,
      );
      // 一次性 batch insert N 条 transaction:create change,代替逐条
      // recordLedgerChange,把 N 次跨 isolate boundary 摊成 1 次。
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return ids;
      final inserted = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      await db.batch((b) {
        for (final tx in inserted) {
          if (tx.syncId == null) continue;
          b.insert(
            db.localChanges,
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: tx.id,
              entitySyncId: tx.syncId!,
              ledgerId: tx.ledgerId,
              action: 'create',
            ),
          );
        }
      });
      return ids;
    });
  }

  @override
  Future<int> insertTransactionCompanion(
    TransactionsCompanion item, {
    bool recordChanges = true,
  }) async {
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.insertTransactionCompanion(item);
    }
    // 带标签/附件的交易走这条单条插入路径(见 data_import_service.dart:510)。
    // 之前此处只 delegate,导入完没登记 transaction:create 变更,云端拿不到
    // 这部分交易。现在跟 insertTransactionsBatch 一样补登记。
    return db.transaction(() async {
      final id = await _transactionRepo.insertTransactionCompanion(item);
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx != null && tx.syncId != null) {
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'create',
        );
      }
      return id;
    });
  }

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> transactionsWithCategoryAll({int? ledgerId}) =>
      _transactionRepo.transactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Future<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> getRecentTransactionsWithCategory({
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
    dynamic accountId,
    dynamic toAccountId,
    String? accountSyncIdOverride,
    String? toAccountSyncIdOverride,
    bool writeAccountSyncIdOverride = false,
    bool writeToAccountSyncIdOverride = false,
  }) async {
    await _transactionRepo.updateTransactionFields(
      id: id,
      accountId: accountId,
      toAccountId: toAccountId,
      accountSyncIdOverride: accountSyncIdOverride,
      toAccountSyncIdOverride: toAccountSyncIdOverride,
      writeAccountSyncIdOverride: writeAccountSyncIdOverride,
      writeToAccountSyncIdOverride: writeToAccountSyncIdOverride,
    );
    // 历史 bug:这里之前没记 ChangeTracker,transfer 编辑模式改 toAccountId
    // 永远不 sync。补一刀 update change,跟 updateTransaction 对齐。
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx?.syncId != null) {
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx!.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
      }
    }
  }

  @override
  Future<Transaction?> getFirstTransactionByLedger(int ledgerId) =>
      _transactionRepo.getFirstTransactionByLedger(ledgerId);

  @override
  Future<Transaction?> getLastTransactionByLedger(int ledgerId) =>
      _transactionRepo.getLastTransactionByLedger(ledgerId);

  @override
  Future<void> updateTransactionLedger({required int id, required int ledgerId}) =>
      _transactionRepo.updateTransactionLedger(id: id, ledgerId: ledgerId);

  /// 共享账本:本地 tx 写完后回填 createdByUserId / lastEditedByUserId。
  /// 详见 [LocalTransactionRepository.markTxAuthor]。
  Future<void> markTxAuthor({
    required int txId,
    required String userId,
    required bool isCreate,
  }) =>
      _transactionRepo.markTxAuthor(
        txId: txId,
        userId: userId,
        isCreate: isCreate,
      );

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
  Future<Map<String, int>> updateTransactionsBatchBySyncId(
    List<TransactionUpdateBySyncIdData> updates, {
    bool recordChanges = true,
  }) async {
    if (updates.isEmpty) return const {};
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.updateTransactionsBatchBySyncId(updates);
    }
    return db.transaction(() async {
      final syncIdToTxId =
          await _transactionRepo.updateTransactionsBatchBySyncId(updates);
      if (syncIdToTxId.isEmpty) return syncIdToTxId;
      // 反查 ledgerId 用于 change log
      final txs = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIdToTxId.keys.toList())))
          .get();
      await db.batch((b) {
        for (final tx in txs) {
          if (tx.syncId == null) continue;
          b.insert(
            db.localChanges,
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: tx.id,
              entitySyncId: tx.syncId!,
              ledgerId: tx.ledgerId,
              action: 'update',
            ),
          );
        }
      });
      return syncIdToTxId;
    });
  }

  @override
  Future<int> deleteTransactionsBatchBySyncIds(
    List<String> syncIds, {
    bool recordChanges = true,
  }) async {
    if (syncIds.isEmpty) return 0;
    // recordChanges=false / 无 changeTracker → 直接走子仓库,不写 change log
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.deleteTransactionsBatchBySyncIds(syncIds);
    }
    return db.transaction(() async {
      // 先 SELECT 出待删的 tx(留下 ledgerId / syncId 用于 change log)
      final rows = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      if (rows.isEmpty) return 0;
      final deleted =
          await _transactionRepo.deleteTransactionsBatchBySyncIds(syncIds);
      // 一次性 batch insert N 条 transaction:delete change,代替逐条
      // recordLedgerChange,跨 isolate boundary 从 N 次降到 1 次。
      await db.batch((b) {
        for (final tx in rows) {
          if (tx.syncId == null) continue;
          b.insert(
            db.localChanges,
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: tx.id,
              entitySyncId: tx.syncId!,
              ledgerId: tx.ledgerId,
              action: 'delete',
            ),
          );
        }
      });
      return deleted;
    });
  }

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
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    int level = 1,
    int? parentId,
    String? syncId,
  }) async {
    final id = await _categoryRepo.createCategory(
      name: name,
      kind: kind,
      icon: icon,
      sortOrder: sortOrder,
      level: level,
      parentId: parentId,
      syncId: syncId,
    );
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'create',
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
    String? syncId,
  }) async {
    final id = await _categoryRepo.createSubCategory(
      parentId: parentId, name: name, kind: kind, icon: icon,
      sortOrder: sortOrder, syncId: syncId,
    );
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'create',
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
      await changeTracker!.recordUserGlobalChange(
        entityType: 'category', entityId: id,
        entitySyncId: cat!.syncId!, action: 'update',
      );
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'delete',
        );
      }
    }
    await _categoryRepo.deleteCategory(id);
  }

  @override
  Future<void> deleteCategoriesByIds(List<int> ids) async {
    if (changeTracker == null || ids.isEmpty) {
      logger.info('LocalRepository',
          'deleteCategoriesByIds(${ids.length}): changeTracker=null=${changeTracker == null} → 不登记 change');
      return _categoryRepo.deleteCategoriesByIds(ids);
    }
    // 子仓库会同时删 ids 自身和 parent_id 在 ids 里的子分类,所以这里也要把
    // 子分类的 syncId 一并预查出来登记 delete change。
    await db.transaction(() async {
      final cats = await (db.select(db.categories)
            ..where((c) => c.id.isIn(ids) | c.parentId.isIn(ids)))
          .get();
      await _categoryRepo.deleteCategoriesByIds(ids);
      var recorded = 0;
      var skippedNoSyncId = 0;
      for (final c in cats) {
        if (c.syncId == null) {
          skippedNoSyncId++;
          continue;
        }
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category',
          entityId: c.id,
          entitySyncId: c.syncId!,
          action: 'delete',
        );
        recorded++;
      }
      logger.info('LocalRepository',
          'deleteCategoriesByIds(${ids.length}): 预查到 ${cats.length} 行,'
          '登记 $recorded 条 category:delete change'
          '${skippedNoSyncId > 0 ? ", $skippedNoSyncId 条因 syncId=null 跳过(本地未同步过的种子分类)" : ""}');
    });
  }

  @override
  Future<int> upsertCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) =>
      _categoryRepo.upsertCategory(
          name: name, kind: kind, icon: icon, sortOrder: sortOrder);

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
  Future<int> migrateCategory({required int fromCategoryId, required int toCategoryId}) async {
    if (changeTracker == null) {
      return _categoryRepo.migrateCategory(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );
    }
    return db.transaction(() async {
      // 预查受影响的交易,迁移完后逐条登记 update change。
      final affected = await (db.select(db.transactions)
            ..where((t) => t.categoryId.equals(fromCategoryId)))
          .get();
      final n = await _categoryRepo.migrateCategory(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );
      for (final tx in affected) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
      }
      return n;
    });
  }

  @override
  Future<({int migratedTransactions, int migratedSubCategories})> migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    if (changeTracker == null) {
      return _categoryRepo.migrateCategoryTransactions(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );
    }
    return db.transaction(() async {
      // 预查 fromCategory + 子分类(level=1 时),以及所有可能受影响的交易。
      // 子分类有两种命运:
      //   - 目标父类下已有同名 → 子分类被合并(删除)
      //   - 没有同名 → 子分类被移动(parentId 改变)
      // 用"迁移前 vs 迁移后"对比来区分这两种情况,避免提前 hardcode 决策。
      final fromCategory = await _categoryRepo.getCategoryById(fromCategoryId);
      final subCategories = fromCategory?.level == 1
          ? await _categoryRepo.getSubCategories(fromCategoryId)
          : <Category>[];
      final affectedCategoryIds = [
        fromCategoryId,
        ...subCategories.map((s) => s.id),
      ];
      final affectedTxs = await (db.select(db.transactions)
            ..where((t) => t.categoryId.isIn(affectedCategoryIds)))
          .get();

      final result = await _categoryRepo.migrateCategoryTransactions(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

      // 受影响交易: categoryId 变了,登记 update。
      for (final tx in affectedTxs) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
      }
      // 子分类:迁移后查不到 → 被合并删除;parentId 变了 → 被移动。
      for (final sub in subCategories) {
        if (sub.syncId == null) continue;
        final after = await _categoryRepo.getCategoryById(sub.id);
        if (after == null) {
          await changeTracker!.recordUserGlobalChange(
            entityType: 'category',
            entityId: sub.id,
            entitySyncId: sub.syncId!,
            action: 'delete',
          );
        } else if (after.parentId != sub.parentId) {
          await changeTracker!.recordUserGlobalChange(
            entityType: 'category',
            entityId: sub.id,
            entitySyncId: sub.syncId!,
            action: 'update',
          );
        }
      }
      return result;
    });
  }

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
  Future<List<Category>> getAllCategoriesIncludingShared() =>
      _categoryRepo.getAllCategoriesIncludingShared();

  @override
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories) async {
    if (changeTracker == null || categories.isEmpty) {
      return _categoryRepo.batchInsertCategories(categories);
    }
    // 预填充 syncId 以便插入后查回登记 create change。子仓库 batchInsert
    // 不会自动补 syncId,companion 里没有的会被插成 NULL,跨设备同步对不上。
    final effective = categories.map((c) {
      if (c.syncId == const d.Value.absent() || c.syncId.value == null) {
        return c.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return c;
    }).toList();
    await db.transaction(() async {
      await _categoryRepo.batchInsertCategories(effective);
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return;
      final inserted = await (db.select(db.categories)
            ..where((c) => c.syncId.isIn(syncIds)))
          .get();
      for (final c in inserted) {
        if (c.syncId == null) continue;
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category',
          entityId: c.id,
          entitySyncId: c.syncId!,
          action: 'create',
        );
      }
    });
  }

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
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'update',
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
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'update',
        );
      }
    }
  }

  @override
  Future<List<String>> getCustomIconPaths() => _categoryRepo.getCustomIconPaths();

  @override
  Future<Category> getTransferCategory() async {
    // 干净数据下 transfer 分类应该恰好 1 条。少数历史脏数据用户(早期
    // seed 多次 / 云同步重复 pull / 手动改 kind)出现过多条,会让原来
    // .getSingleOrNull() 直接 throw、UI 卡死(编辑转账时表现明显)。
    //
    // 这里发现 >1 条时被动合并:保留 id 最小的 keeper,把所有指向 dupes
    // 的 transactions 改写到 keeper 上,再删除 dupes,所有变更一次性
    // 通过 ChangeTracker 推到云端 — 同账号的其它设备下次 pull 时也能
    // 自动擦掉脏数据。
    final all = await _categoryRepo.getAllTransferCategories();
    if (all.length <= 1) {
      // 0 条走子仓库的兜底创建,1 条直接返
      return _categoryRepo.getTransferCategory();
    }

    final keeper = all.first;
    final dupes = all.sublist(1);
    final dupeIds = dupes.map((c) => c.id).toList();
    logger.warning(
      'LocalRepository',
      'transfer 分类发现 ${all.length} 条,合并 → keeper=${keeper.id} dupes=$dupeIds',
    );

    // 预查受影响的 transactions(为 ChangeTracker 记录)
    final affectedTxs = await (db.select(db.transactions)
          ..where((t) => t.categoryId.isIn(dupeIds)))
        .get();

    await db.transaction(() async {
      // 1) 把 transactions.categoryId 从 dupes 改写到 keeper
      await (db.update(db.transactions)
            ..where((t) => t.categoryId.isIn(dupeIds)))
          .write(TransactionsCompanion(categoryId: d.Value(keeper.id)));

      // 2) 同步把 budgets / recurring_transactions 上引用的 dupe 也搬到 keeper
      await (db.update(db.budgets)
            ..where((b) => b.categoryId.isIn(dupeIds)))
          .write(BudgetsCompanion(categoryId: d.Value(keeper.id)));
      await (db.update(db.recurringTransactions)
            ..where((r) => r.categoryId.isIn(dupeIds)))
          .write(RecurringTransactionsCompanion(categoryId: d.Value(keeper.id)));

      // 3) 删 dupe categories
      await (db.delete(db.categories)
            ..where((c) => c.id.isIn(dupeIds)))
          .go();
    });

    // ChangeTracker 记录:受影响 transactions 的 update + dupe categories 的 delete
    if (changeTracker != null) {
      for (final tx in affectedTxs) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
      }
      for (final dupe in dupes) {
        if (dupe.syncId == null) continue;
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category',
          entityId: dupe.id,
          entitySyncId: dupe.syncId!,
          action: 'delete',
        );
      }
    }

    return keeper;
  }

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
    String? syncId,
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
      syncId: syncId,
    );
    if (changeTracker != null) {
      final account = await _accountRepo.getAccount(id);
      if (account?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'account',
          entityId: id,
          entitySyncId: account!.syncId!,
          action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<int> upsertAccount({
    required String name,
    int ledgerId = 0,
    String type = 'cash',
    String currency = 'CNY',
    double initialBalance = 0.0,
  }) async {
    // 委托底层 upsert(同名复用)。新建分支会自动记 sync change(走 createAccount
    // 已有逻辑);复用分支已有 syncId、不需要再记 create。
    final existing = await _accountRepo.getAllAccounts();
    final hit = existing.where((a) => a.name == name).toList();
    if (hit.isNotEmpty) return hit.first.id;
    return createAccount(
      ledgerId: ledgerId,
      name: name,
      type: type,
      currency: currency,
      initialBalance: initialBalance,
    );
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
      await changeTracker!.recordUserGlobalChange(
        entityType: 'account',
        entityId: id,
        entitySyncId: account!.syncId!,
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
        await changeTracker!.recordUserGlobalChange(
          entityType: 'account',
          entityId: id,
          entitySyncId: account!.syncId!,
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
  Future<int> migrateAccount({required int fromAccountId, required int toAccountId}) async {
    if (changeTracker == null) {
      return _accountRepo.migrateAccount(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
      );
    }
    return db.transaction(() async {
      // 既要迁移作为主账户的交易,也要迁移作为转入账户的交易,两处都要预查。
      final affected = await (db.select(db.transactions)
            ..where((t) =>
                t.accountId.equals(fromAccountId) |
                t.toAccountId.equals(fromAccountId)))
          .get();
      final n = await _accountRepo.migrateAccount(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
      );
      for (final tx in affected) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
      }
      return n;
    });
  }

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
  Future<void> batchInsertAccounts(List<AccountsCompanion> accounts) async {
    if (changeTracker == null || accounts.isEmpty) {
      return _accountRepo.batchInsertAccounts(accounts);
    }
    final effective = accounts.map((a) {
      if (a.syncId == const d.Value.absent() || a.syncId.value == null) {
        return a.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return a;
    }).toList();
    await db.transaction(() async {
      await _accountRepo.batchInsertAccounts(effective);
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return;
      final inserted = await (db.select(db.accounts)
            ..where((a) => a.syncId.isIn(syncIds)))
          .get();
      for (final a in inserted) {
        if (a.syncId == null) continue;
        await changeTracker!.recordUserGlobalChange(
          entityType: 'account',
          entityId: a.id,
          entitySyncId: a.syncId!,
          action: 'create',
        );
      }
    });
  }

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

  @override
  Future<SharedLedgerAccount?> getSharedAccountBySyncId(String syncId) =>
      _accountRepo.getSharedAccountBySyncId(syncId);

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

  @override
  Future<Map<int, Category>> getSharedSyntheticCategoriesForLedger(
          int ledgerId) =>
      _statisticsRepo.getSharedSyntheticCategoriesForLedger(ledgerId);

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
    String? syncId,
  }) async {
    final id = await _tagRepo.createTag(
        name: name, color: color, sortOrder: sortOrder, syncId: syncId);
    if (changeTracker != null) {
      final tag = await _tagRepo.getTagById(id);
      if (tag?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'tag', entityId: id,
          entitySyncId: tag!.syncId!, action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<int> upsertTag({
    required String name,
    String? color,
  }) async {
    // 委托底层 upsert;新建分支走 createTag 自动记 sync change。
    final existing = await _tagRepo.getTagByName(name);
    if (existing != null) return existing.id;
    return createTag(name: name, color: color);
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
      await changeTracker!.recordUserGlobalChange(
        entityType: 'tag', entityId: id,
        entitySyncId: tag!.syncId!, action: 'update',
      );
    }
  }

  @override
  Future<void> deleteTag(int id) async {
    var recorded = false;
    if (changeTracker != null) {
      final tag = await _tagRepo.getTagById(id);
      if (tag?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'tag', entityId: id,
          entitySyncId: tag!.syncId!, action: 'delete',
        );
        recorded = true;
      } else if (tag != null) {
        logger.info('LocalRepository',
            'deleteTag($id) tag.syncId=null,跳过 change 登记(本地未同步过的种子标签)');
      }
    }
    await _tagRepo.deleteTag(id);
    if (changeTracker != null && !recorded) {
      logger.debug('LocalRepository',
          'deleteTag($id): changeTracker 在但没登记 change(syncId 缺失)');
    }
  }

  @override
  Future<Tag?> getTagById(int id) => _tagRepo.getTagById(id);

  @override
  Future<Tag?> getTagByName(String name) => _tagRepo.getTagByName(name);

  @override
  Future<List<Tag>> getAllTags() => _tagRepo.getAllTags();

  @override
  Future<void> batchInsertTags(List<TagsCompanion> tags) async {
    if (changeTracker == null || tags.isEmpty) {
      return _tagRepo.batchInsertTags(tags);
    }
    final effective = tags.map((t) {
      if (t.syncId == const d.Value.absent() || t.syncId.value == null) {
        return t.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return t;
    }).toList();
    await db.transaction(() async {
      await _tagRepo.batchInsertTags(effective);
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return;
      final inserted = await (db.select(db.tags)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      for (final t in inserted) {
        if (t.syncId == null) continue;
        await changeTracker!.recordUserGlobalChange(
          entityType: 'tag',
          entityId: t.id,
          entitySyncId: t.syncId!,
          action: 'create',
        );
      }
    });
  }

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
  Future<({int count, double expense, double income})> getTagStats(int tagId, {int? ledgerId}) =>
      _tagRepo.getTagStats(tagId, ledgerId: ledgerId);

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
  Stream<List<Transaction>> watchTransactionsByTag(int tagId, {int? ledgerId}) =>
      _tagRepo.watchTransactionsByTag(tagId, ledgerId: ledgerId);

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
        await changeTracker!.recordLedgerChange(
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
        await changeTracker!.recordLedgerChange(
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
        await changeTracker!.recordLedgerChange(
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
    await changeTracker!.recordLedgerChange(
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
