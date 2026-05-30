import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as d;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../../../utils/shared_ledger_picker_filter.dart';
import '../transaction_repository.dart';
import '../../../services/system/logger_service.dart';

/// 本地交易Repository实现
/// 基于 Drift 数据库实现
class LocalTransactionRepository implements TransactionRepository {
  final BeeDatabase db;

  LocalTransactionRepository(this.db);

  @override
  Stream<List<Transaction>> watchRecentTransactions({
    required int ledgerId,
    int limit = 20,
  }) {
    return (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ])
          ..limit(limit))
        .watch();
  }

  @override
  Stream<List<Transaction>> watchTransactionsInMonth({
    required int ledgerId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .watch();
  }

  /// Drift `accounts` 表的两个 alias —— from 账户(`transactions.account_id`)
  /// 和 to 账户(`transactions.to_account_id`,转账场景)。Drift 同一张表
  /// JOIN 两次必须用 alias 区分,否则解析阶段就报"column reference ambiguous"。
  late final $AccountsTable _fromAccountTable =
      db.alias(db.accounts, 'from_account');
  late final $AccountsTable _toAccountTable =
      db.alias(db.accounts, 'to_account');

  /// 标准 tx + category + from/to account 三连 LEFT JOIN。所有 list 风格的
  /// watch 都走这个,避免重复写 join 表。
  List<d.Join<d.HasResultSet, dynamic>> _txJoins() => [
        d.leftOuterJoin(db.categories,
            db.categories.id.equalsExp(db.transactions.categoryId)),
        d.leftOuterJoin(_fromAccountTable,
            _fromAccountTable.id.equalsExp(db.transactions.accountId)),
        d.leftOuterJoin(_toAccountTable,
            _toAccountTable.id.equalsExp(db.transactions.toAccountId)),
      ];

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      watchTransactionsWithCategoryAll({
    int? ledgerId,
  }) {
    final select = db.select(db.transactions);
    if (ledgerId != null) {
      select.where((t) => t.ledgerId.equals(ledgerId));
    }
    select.orderBy([
      (t) => d.OrderingTerm(
          expression: t.happenedAt, mode: d.OrderingMode.desc)
    ]);
    final q = select.join(_txJoins());
    return _watchTxJoinWithSharedHydration(q);
  }

  /// §7 共享账本:把 Drift 主表 stream 跟 SharedLedger* 表更新合流,任一
  /// 变化都重跑 hydration 并 emit。
  ///
  /// 单纯用 q.watch() 时,Drift 只 track query 里 join 到的表(transactions /
  /// categories / accounts)。SharedLedger* 行被 WS handler 改了,stream 不会
  /// re-emit → tx tile 显示旧名字/图标,跟 picker 不一致。这里手动加两路
  /// db.tableUpdates(SharedLedger{Categories,Accounts}) 监听,触发时拿上一次
  /// Drift 结果重 hydrate 再 emit。
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      _watchTxJoinWithSharedHydration(d.JoinedSelectStatement q) {
    late StreamController<List<({Transaction t, Category? category, Account? account, Account? toAccount})>> ctrl;
    StreamSubscription? txSub;
    StreamSubscription? sharedCatSub;
    StreamSubscription? sharedAccSub;
    List<d.TypedResult>? lastRows;

    Future<void> rehydrate() async {
      if (lastRows == null) return;
      final out = lastRows!
          .map((r) => (
                t: r.readTable(db.transactions),
                category: r.readTableOrNull(db.categories),
                account: r.readTableOrNull(_fromAccountTable),
                toAccount: r.readTableOrNull(_toAccountTable),
              ))
          .toList();
      final hydrated = await _hydrateSharedOverrides(out);
      if (!ctrl.isClosed) ctrl.add(hydrated);
    }

    ctrl = StreamController<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>(
      onListen: () {
        txSub = q.watch().listen((rows) {
          lastRows = rows;
          rehydrate();
        });
        sharedCatSub = db
            .tableUpdates(d.TableUpdateQuery.onTable(db.sharedLedgerCategories))
            .listen((_) => rehydrate());
        sharedAccSub = db
            .tableUpdates(d.TableUpdateQuery.onTable(db.sharedLedgerAccounts))
            .listen((_) => rehydrate());
      },
      onCancel: () async {
        await txSub?.cancel();
        await sharedCatSub?.cancel();
        await sharedAccSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  /// §7 v25:Editor 在共享账本下记的 tx,主表 JOIN 不到 category / account 行,
  /// 字段是 null。这里二次查 SharedLedger{Categories,Accounts} 按 syncId 找,
  /// 转 synthetic 实体回填,UI 不用区分。
  ///
  /// 合并 category + from-account + to-account 三类 hydration:共用同一遍 rows
  /// 扫描;每类各一个 batch query。
  Future<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      _hydrateSharedOverrides(
    List<({Transaction t, Category? category, Account? account, Account? toAccount})> rows,
  ) async {
    // 1. 收集所有需要反查的 syncId(分类 / from 账户 / to 账户)
    final catSyncIds = <String>{};
    final accSyncIds = <String>{};
    for (final r in rows) {
      final cOv = r.t.categorySyncIdOverride;
      if (r.category == null && cOv != null && cOv.isNotEmpty) {
        catSyncIds.add(cOv);
      }
      final aOv = r.t.accountSyncIdOverride;
      if (r.account == null && aOv != null && aOv.isNotEmpty) {
        accSyncIds.add(aOv);
      }
      final tOv = r.t.toAccountSyncIdOverride;
      if (r.toAccount == null && tOv != null && tOv.isNotEmpty) {
        accSyncIds.add(tOv);
      }
    }
    if (catSyncIds.isEmpty && accSyncIds.isEmpty) return rows;

    // 2. 批量查 SharedLedger* 镜像表
    final catBySyncId = <String, SharedLedgerCategory>{};
    if (catSyncIds.isNotEmpty) {
      final shared = await (db.select(db.sharedLedgerCategories)
            ..where((t) => t.syncId.isIn(catSyncIds.toList())))
          .get();
      for (final s in shared) {
        catBySyncId[s.syncId] = s;
      }
    }
    final accBySyncId = <String, SharedLedgerAccount>{};
    if (accSyncIds.isNotEmpty) {
      final shared = await (db.select(db.sharedLedgerAccounts)
            ..where((t) => t.syncId.isIn(accSyncIds.toList())))
          .get();
      for (final s in shared) {
        accBySyncId[s.syncId] = s;
      }
    }

    // 3. 回填到每行
    return rows.map((r) {
      Category? category = r.category;
      Account? account = r.account;
      Account? toAccount = r.toAccount;

      final cOv = r.t.categorySyncIdOverride;
      if (category == null && cOv != null && cOv.isNotEmpty) {
        final s = catBySyncId[cOv];
        if (s != null) category = _syntheticCategoryFromShared(s);
      }
      final aOv = r.t.accountSyncIdOverride;
      if (account == null && aOv != null && aOv.isNotEmpty) {
        final s = accBySyncId[aOv];
        if (s != null) account = _syntheticAccountFromShared(s);
      }
      final tOv = r.t.toAccountSyncIdOverride;
      if (toAccount == null && tOv != null && tOv.isNotEmpty) {
        final s = accBySyncId[tOv];
        if (s != null) toAccount = _syntheticAccountFromShared(s);
      }

      return (
        t: r.t,
        category: category,
        account: account,
        toAccount: toAccount,
      );
    }).toList();
  }

  /// SharedLedgerCategory → synthetic Category。用 syntheticIdForSyncId 而不
  /// 是 -1 — 否则所有共享分类都拿到同一个 id,首页点击分类详情时反查不到
  /// 目标 syncId,详情页 0 笔交易。改成 hash 派生后跟 picker / watchCategory
  /// 路径对齐。
  Category _syntheticCategoryFromShared(SharedLedgerCategory s) {
    return Category(
      id: syntheticIdForSyncId(s.syncId),
      name: s.name,
      kind: s.kind,
      icon: s.icon,
      sortOrder: s.sortOrder,
      parentId: null,
      level: s.level,
      iconType: s.iconType,
      customIconPath: s.iconType == 'custom' && s.iconCloudSha256 != null
          ? 'custom_icons/shared_${s.iconCloudSha256}.png'
          : null,
      communityIconId: null,
      syncId: s.syncId,
    );
  }

  /// SharedLedgerAccount → synthetic Account。跟 accountForTxProvider 同款映射。
  Account _syntheticAccountFromShared(SharedLedgerAccount s) {
    return Account(
      id: syntheticIdForSyncId(s.syncId),
      ledgerId: 0,
      name: s.name,
      type: s.accountType,
      currency: s.currency,
      initialBalance: s.initialBalance ?? 0.0,
      createdAt: null,
      updatedAt: null,
      sortOrder: 0,
      creditLimit: s.creditLimit,
      billingDay: s.billingDay,
      paymentDueDay: s.paymentDueDay,
      bankName: s.bankName,
      cardLastFour: s.cardLastFour,
      note: s.note,
      syncId: s.syncId,
    );
  }

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .join(_txJoins());
    return _watchTxJoinWithSharedHydration(q);
  }

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  }) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .join(_txJoins());
    return _watchTxJoinWithSharedHydration(q);
  }

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      watchTransactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type,
  }) {
    final base = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .join(_txJoins());
    if (categoryId == null) {
      base.where(db.transactions.categoryId.isNull());
    } else {
      base.where(db.transactions.categoryId.equals(categoryId));
    }
    return _watchTxJoinWithSharedHydration(base);
  }

  static const _uuid = Uuid();

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
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: type,
          amount: amount,
          categoryId: d.Value(categoryId),
          accountId: d.Value(accountId),
          toAccountId: d.Value(toAccountId),
          happenedAt: d.Value(happenedAt),
          note: d.Value(note),
          syncId: d.Value(syncId ?? _uuid.v4()),
          categorySyncIdOverride: d.Value(categorySyncIdOverride),
          accountSyncIdOverride: d.Value(accountSyncIdOverride),
          toAccountSyncIdOverride: d.Value(toAccountSyncIdOverride),
        ));
  }

  @override
  Future<int> insertTransactionsBatch(
    List<TransactionsCompanion> items, {
    bool recordChanges = true,
  }) async {
    // 子仓库不挂 changeTracker,recordChanges 参数对它无作用 — 真正的 record
    // 在 LocalRepository wrapper 那一层。这里保留参数只是为了接口一致。
    if (items.isEmpty) return 0;
    final effectiveItems = items.map((item) {
      if (item.syncId == const d.Value.absent() || item.syncId.value == null) {
        return item.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return item;
    }).toList();
    return db.transaction(() async {
      await db.batch((b) => b.insertAll(db.transactions, effectiveItems));
      return effectiveItems.length;
    });
  }

  @override
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    Map<int, List<int>> tagIdsByIndex = const {},
    Map<int, List<BatchAttachmentData>> attachmentsByIndex = const {},
    bool recordChanges = true,
  }) async {
    if (transactions.isEmpty) return const [];
    // 预填充 syncId — batch insertAll 不返回 row id,必须靠 syncId 反查。
    final effective = transactions.map((tx) {
      if (tx.syncId == const d.Value.absent() || tx.syncId.value == null) {
        return tx.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return tx;
    }).toList();

    return db.transaction(() async {
      // 1. 一次性 batch insert 所有 tx
      await db.batch((b) => b.insertAll(db.transactions, effective));

      // 2. SELECT 回拿 (id, syncId) 映射,按 effective 顺序对齐
      final syncIds = effective.map((c) => c.syncId.value!).toList();
      final inserted = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      final idBySyncId = <String, int>{
        for (final tx in inserted)
          if (tx.syncId != null) tx.syncId!: tx.id,
      };
      final ids = syncIds.map((s) => idBySyncId[s]!).toList();

      // 3. batch insert tag 关联 — 调用方需保证 tagIds 已去重,本方法不查重
      //   (TransactionTags 表没 UNIQUE 约束,select 防重就是 N+1 来源)
      if (tagIdsByIndex.isNotEmpty) {
        await db.batch((b) {
          for (final entry in tagIdsByIndex.entries) {
            final txId = ids[entry.key];
            for (final tagId in entry.value) {
              b.insert(
                db.transactionTags,
                TransactionTagsCompanion.insert(
                  transactionId: txId,
                  tagId: tagId,
                ),
              );
            }
          }
        });
      }

      // 4. batch insert attachment 元数据(文件本身在另一个流程下载)
      if (attachmentsByIndex.isNotEmpty) {
        await db.batch((b) {
          for (final entry in attachmentsByIndex.entries) {
            final txId = ids[entry.key];
            for (final att in entry.value) {
              b.insert(
                db.transactionAttachments,
                TransactionAttachmentsCompanion.insert(
                  transactionId: txId,
                  fileName: att.fileName,
                  originalName: d.Value(att.originalName),
                  fileSize: d.Value(att.fileSize),
                  width: d.Value(att.width),
                  height: d.Value(att.height),
                  sortOrder: d.Value(att.sortOrder),
                  cloudFileId: d.Value(att.cloudFileId),
                  cloudSha256: d.Value(att.cloudSha256),
                ),
              );
            }
          }
        });
      }

      return ids;
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
    // 处理 accountId 参数
    final d.Value<int?> accountIdValue;
    if (accountId == null) {
      accountIdValue = const d.Value.absent();
    } else if (accountId is d.Value<int?>) {
      accountIdValue = accountId;
    } else {
      accountIdValue = d.Value(accountId as int?);
    }

    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        type: d.Value(type),
        amount: d.Value(amount),
        categoryId: d.Value(categoryId),
        note: d.Value(note),
        happenedAt:
            happenedAt != null ? d.Value(happenedAt) : const d.Value.absent(),
        accountId: accountIdValue,
        categorySyncIdOverride: d.Value(categorySyncIdOverride),
        accountSyncIdOverride: d.Value(accountSyncIdOverride),
        toAccountSyncIdOverride: d.Value(toAccountSyncIdOverride),
      ),
    );
  }

  /// 共享账本:在本地标记 tx 的创建人 / 编辑人,让 UI 能立即展示头像。
  /// 服务端 push.py 已经会兜底注入 userId,但本地写入路径(addTransaction /
  /// updateTransaction)不知道 currentUser 是谁,需要 UI 层在写完后调一下这个
  /// 方法。
  ///   - isCreate=true:同时写 createdByUserId + lastEditedByUserId(新建场景)
  ///   - isCreate=false:只写 lastEditedByUserId(编辑场景,createdByUserId
  ///     维持 first-write-wins)
  Future<void> markTxAuthor({
    required int txId,
    required String userId,
    required bool isCreate,
  }) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(txId))).write(
      TransactionsCompanion(
        createdByUserId:
            isCreate ? d.Value(userId) : const d.Value.absent(),
        lastEditedByUserId: d.Value(userId),
      ),
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    // 先删除关联的标签
    await (db.delete(db.transactionTags)
          ..where((tt) => tt.transactionId.equals(id)))
        .go();

    // 再删除关联的附件
    await _deleteAttachmentsForTransaction(id);

    // 最后删除交易记录
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }

  /// 删除交易关联的所有附件（包括文件和数据库记录）
  Future<void> _deleteAttachmentsForTransaction(int transactionId) async {
    try {
      // 获取该交易的所有附件
      final attachments = await (db.select(db.transactionAttachments)
            ..where((a) => a.transactionId.equals(transactionId)))
          .get();

      if (attachments.isEmpty) return;

      // 获取附件存储目录
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentDir = Directory('${appDir.path}/attachments');
      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory('${cacheDir.path}/attachment_thumbs');

      final fileNames = attachments.map((a) => a.fileName).toSet();

      // 先删数据库记录,再按引用计数删物理文件:多笔共享同一文件时,仅当没有
      // 其他行引用该 fileName 才删物理文件,避免误删别笔还在用的图。
      await (db.delete(db.transactionAttachments)
            ..where((a) => a.transactionId.equals(transactionId)))
          .go();

      for (final fileName in fileNames) {
        final stillRef = await (db.select(db.transactionAttachments)
              ..where((a) => a.fileName.equals(fileName)))
            .getSingleOrNull();
        if (stillRef != null) continue; // 仍有其他行引用,保留物理文件

        final file = File('${attachmentDir.path}/$fileName');
        if (await file.exists()) {
          await file.delete();
          logger.debug('LocalTransactionRepository', '删除附件文件: $fileName');
        }
        final thumbName =
            '${path.basenameWithoutExtension(fileName)}_thumb.jpg';
        final thumbFile = File('${thumbDir.path}/$thumbName');
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      logger.info('LocalTransactionRepository', '已删除交易 $transactionId 的 ${attachments.length} 个附件');
    } catch (e, stackTrace) {
      logger.error('LocalTransactionRepository', '删除交易附件失败', e, stackTrace);
      // 不抛出异常，继续删除交易
    }
  }

  @override
  Future<Transaction?> getTransactionById(int id) async {
    return await (db.select(db.transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<int> insertTransactionCompanion(
    TransactionsCompanion item, {
    bool recordChanges = true,
  }) async {
    // 子仓库不挂 changeTracker,recordChanges 仅为接口一致保留。
    final effective = item.syncId == const d.Value.absent() || item.syncId.value == null
        ? item.copyWith(syncId: d.Value(_uuid.v4()))
        : item;
    return await db.into(db.transactions).insert(effective);
  }

  @override
  Stream<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      transactionsWithCategoryAll({
    int? ledgerId,
  }) =>
          watchTransactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Future<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>
      getRecentTransactionsWithCategory({
    required int ledgerId,
    required int limit,
  }) async {
    final q = (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ])
          ..limit(limit))
        .join(_txJoins());
    final rows = await q.get();
    final out = rows
        .map((r) => (
              t: r.readTable(db.transactions),
              category: r.readTableOrNull(db.categories),
              account: r.readTableOrNull(_fromAccountTable),
              toAccount: r.readTableOrNull(_toAccountTable),
            ))
        .toList();
    return _hydrateSharedOverrides(out);
  }

  @override
  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE ledger_id = ?1 AND type = ?2 AND happened_at >= ?3 AND happened_at < ?4',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<String>(type),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();
    final v = row.data['c'];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Future<List<Transaction>> getTransactionsByLedger(int ledgerId) async {
    return await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) =>
                d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .get();
  }

  @override
  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    return await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBiggerOrEqualValue(start) &
              t.happenedAt.isSmallerThanValue(end))
          ..orderBy([
            (t) =>
                d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .get();
  }

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
    // accountId / toAccountId 接受 null(absent / 不更新)、int(直接写)、
    // `d.Value<int?>`(显式 null 清空)三种语义,跟 updateTransaction 对齐。
    final d.Value<int?> accountIdValue;
    if (accountId == null) {
      accountIdValue = const d.Value.absent();
    } else if (accountId is d.Value<int?>) {
      accountIdValue = accountId;
    } else {
      accountIdValue = d.Value(accountId as int?);
    }
    final d.Value<int?> toAccountIdValue;
    if (toAccountId == null) {
      toAccountIdValue = const d.Value.absent();
    } else if (toAccountId is d.Value<int?>) {
      toAccountIdValue = toAccountId;
    } else {
      toAccountIdValue = d.Value(toAccountId as int?);
    }
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        accountId: accountIdValue,
        toAccountId: toAccountIdValue,
        // override 写入只在调用方明确要求时才动(否则保留 Drift 老值),
        // 区别于 dart null 默认行为(=absent)。共享账本 Editor 场景:
        // synthetic 账户 → accountId=null + 这里写 syncIdOverride。
        accountSyncIdOverride: writeAccountSyncIdOverride
            ? d.Value(accountSyncIdOverride)
            : const d.Value.absent(),
        toAccountSyncIdOverride: writeToAccountSyncIdOverride
            ? d.Value(toAccountSyncIdOverride)
            : const d.Value.absent(),
      ),
    );
  }

  @override
  Future<Transaction?> getFirstTransactionByLedger(int ledgerId) async {
    return await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) =>
                d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.asc)
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<Transaction?> getLastTransactionByLedger(int ledgerId) async {
    return await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) =>
                d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<void> updateTransactionLedger({
    required int id,
    required int ledgerId,
  }) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(ledgerId: d.Value(ledgerId)),
    );
  }

  // ==================== 日历功能相关 ====================

  @override
  Future<Map<String, (double, double)>> getDailyTotalsByMonth({
    required int ledgerId,
    required DateTime month,
  }) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    print('🔍 Repository查询: ledgerId=$ledgerId, 日期范围: $startDate ~ $endDate');

    // 先查询该月份有多少条交易
    final countQuery = '''
      SELECT COUNT(*) as count
      FROM transactions
      WHERE ledger_id = ?
        AND happened_at >= ?
        AND happened_at <= ?
    ''';

    final countResult = await db.customSelect(
      countQuery,
      variables: [
        d.Variable.withInt(ledgerId),
        d.Variable.withDateTime(startDate),
        d.Variable.withDateTime(endDate),
      ],
    ).getSingle();

    final totalCount = countResult.read<int>('count');
    print('🔍 该月份总交易数: $totalCount');

    // 查看一条交易的 happened_at 值
    if (totalCount > 0) {
      final sampleQuery = 'SELECT happened_at FROM transactions WHERE ledger_id = ? LIMIT 1';
      final sample = await db.customSelect(
        sampleQuery,
        variables: [d.Variable.withInt(ledgerId)],
      ).getSingle();
      final happenedAtValue = sample.read<int>('happened_at');
      print('🔍 样例 happened_at 值(int): $happenedAtValue');

      // 尝试转换为 DateTime 看看
      final asDateTime = DateTime.fromMillisecondsSinceEpoch(happenedAtValue * 1000);
      print('🔍 转换为 DateTime (假设是秒): $asDateTime');
    }

    // SQL 聚合查询
    // Drift 存储 DateTime 为 Unix timestamp（秒），直接使用 strftime
    final query = '''
      SELECT
        strftime('%Y-%m-%d', happened_at, 'unixepoch', 'localtime') as date,
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE ledger_id = ?
        AND happened_at >= ?
        AND happened_at <= ?
      GROUP BY date
      ORDER BY date DESC
    ''';

    final results = await db.customSelect(
      query,
      variables: [
        d.Variable.withInt(ledgerId),
        d.Variable.withDateTime(startDate),
        d.Variable.withDateTime(endDate),
      ],
    ).get();

    print('🔍 SQL聚合查询结果: ${results.length} 条');

    final map = <String, (double, double)>{};
    for (final row in results) {
      final date = row.read<String?>('date');
      if (date == null) continue; // 跳过null日期
      final income = row.read<double>('income') ?? 0.0;
      final expense = row.read<double>('expense') ?? 0.0;
      map[date] = (income, expense);
      print('  $date: 收入=$income, 支出=$expense');
    }

    print('🔍 最终返回 Map: ${map.length} 条');
    return map;
  }

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
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // 查询当天的所有交易
    final transactions = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .get();

    if (transactions.isEmpty) {
      return [];
    }

    final txIds = transactions.map((t) => t.id).toList();

    // 批量查询分类
    final categoriesMap = <int, Category>{};
    for (final tx in transactions) {
      if (tx.categoryId != null) {
        final category = await (db.select(db.categories)
              ..where((c) => c.id.equals(tx.categoryId!)))
            .getSingleOrNull();
        if (category != null) {
          categoriesMap[tx.categoryId!] = category;
        }
      }
    }

    // 批量查询标签
    final tagsMap = <int, List<Tag>>{};
    final tagRelations = await (db.select(db.transactionTags)
          ..where((tt) => tt.transactionId.isIn(txIds)))
        .get();

    final tagIds = tagRelations.map((r) => r.tagId).toSet();
    if (tagIds.isNotEmpty) {
      final tags = await (db.select(db.tags)
            ..where((t) => t.id.isIn(tagIds.toList())))
          .get();
      final tagsById = {for (var tag in tags) tag.id: tag};

      for (final rel in tagRelations) {
        final tag = tagsById[rel.tagId];
        if (tag != null) {
          tagsMap.putIfAbsent(rel.transactionId, () => []).add(tag);
        }
      }
    }

    // 批量查询附件
    final attachmentsMap = <int, List<TransactionAttachment>>{};
    final attachments = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds)))
        .get();
    for (final attachment in attachments) {
      attachmentsMap
          .putIfAbsent(attachment.transactionId, () => [])
          .add(attachment);
    }

    // 批量查询账户
    final accountIds = transactions
        .where((t) => t.accountId != null)
        .map((t) => t.accountId!)
        .toSet();
    final accountsMap = <int, Account>{};
    if (accountIds.isNotEmpty) {
      final accounts = await (db.select(db.accounts)
            ..where((a) => a.id.isIn(accountIds.toList())))
          .get();
      for (final account in accounts) {
        accountsMap[account.id] = account;
      }
    }

    // 组装结果
    final raw = transactions.map((tx) {
      return (
        t: tx,
        category: tx.categoryId != null ? categoriesMap[tx.categoryId] : null,
        tags: tagsMap[tx.id] ?? [],
        attachments: attachmentsMap[tx.id] ?? [],
        account: tx.accountId != null ? accountsMap[tx.accountId] : null,
      );
    }).toList();
    return _hydrateSharedOverridesFull(raw);
  }

  /// §7 共享账本统一 hydration:
  /// - tx.categoryId 为空 + categorySyncIdOverride 非空 → 查 SharedLedgerCategories
  ///   构造 synthetic Category(同 _hydrateSharedCategoryOverrides)
  /// - tx.accountId 为空 + accountSyncIdOverride 非空 → 查 SharedLedgerAccounts
  ///   构造 synthetic Account
  /// - tx.tagSyncIdsOverride 不为空 → 查 TransactionTagOverrides → SharedLedgerTags
  ///   union 到 tags 列表(synthetic id<0)
  ///
  /// 日历页 / 详情页等任何返回 tx + category + tags + account 完整 tuple 的查询
  /// 都用这个 helper 兜底,跟 transaction_list 走 _hydrateSharedCategoryOverrides
  /// 一致。
  Future<List<({
    Transaction t,
    Category? category,
    List<Tag> tags,
    List<TransactionAttachment> attachments,
    Account? account,
  })>> _hydrateSharedOverridesFull(
    List<({
      Transaction t,
      Category? category,
      List<Tag> tags,
      List<TransactionAttachment> attachments,
      Account? account,
    })> rows,
  ) async {
    if (rows.isEmpty) return rows;

    // 收集需要 hydrate 的 syncId / tx.syncId
    final catSyncIds = <String>{};
    final accSyncIds = <String>{};
    final txSyncIds = <String>{};
    for (final r in rows) {
      final cov = r.t.categorySyncIdOverride;
      if (r.category == null && cov != null && cov.isNotEmpty) {
        catSyncIds.add(cov);
      }
      final aov = r.t.accountSyncIdOverride;
      if (r.account == null && aov != null && aov.isNotEmpty) {
        accSyncIds.add(aov);
      }
      if (r.t.syncId != null && r.t.syncId!.isNotEmpty) {
        txSyncIds.add(r.t.syncId!);
      }
    }

    // 批量查共享分类
    final sharedCatBySyncId = <String, SharedLedgerCategory>{};
    if (catSyncIds.isNotEmpty) {
      final list = await (db.select(db.sharedLedgerCategories)
            ..where((t) => t.syncId.isIn(catSyncIds.toList())))
          .get();
      for (final s in list) sharedCatBySyncId[s.syncId] = s;
    }

    // 批量查共享账户
    final sharedAccBySyncId = <String, SharedLedgerAccount>{};
    if (accSyncIds.isNotEmpty) {
      final list = await (db.select(db.sharedLedgerAccounts)
            ..where((t) => t.syncId.isIn(accSyncIds.toList())))
          .get();
      for (final s in list) sharedAccBySyncId[s.syncId] = s;
    }

    // 批量查 tag overrides + shared tags
    final tagOverridesByTxSyncId = <String, List<String>>{};
    final sharedTagBySyncId = <String, SharedLedgerTag>{};
    if (txSyncIds.isNotEmpty) {
      final overrides = await (db.select(db.transactionTagOverrides)
            ..where((t) => t.transactionSyncId.isIn(txSyncIds.toList())))
          .get();
      for (final ov in overrides) {
        tagOverridesByTxSyncId
            .putIfAbsent(ov.transactionSyncId, () => [])
            .add(ov.tagSyncId);
      }
      if (overrides.isNotEmpty) {
        final tagSids = overrides.map((o) => o.tagSyncId).toSet().toList();
        final sharedTags = await (db.select(db.sharedLedgerTags)
              ..where((t) => t.syncId.isIn(tagSids)))
            .get();
        for (final s in sharedTags) sharedTagBySyncId[s.syncId] = s;
      }
    }

    return rows.map((r) {
      Category? category = r.category;
      Account? account = r.account;
      List<Tag> tags = r.tags;

      if (category == null) {
        final cov = r.t.categorySyncIdOverride;
        if (cov != null && cov.isNotEmpty) {
          final s = sharedCatBySyncId[cov];
          if (s != null) {
            category = Category(
              id: syntheticIdForSyncId(s.syncId),
              name: s.name,
              kind: s.kind,
              icon: s.icon,
              sortOrder: s.sortOrder,
              parentId: null,
              level: s.level,
              iconType: s.iconType,
              customIconPath:
                  s.iconType == 'custom' && s.iconCloudSha256 != null
                      ? 'custom_icons/shared_${s.iconCloudSha256}.png'
                      : null,
              communityIconId: null,
              syncId: s.syncId,
            );
          }
        }
      }

      if (account == null) {
        final aov = r.t.accountSyncIdOverride;
        if (aov != null && aov.isNotEmpty) {
          final s = sharedAccBySyncId[aov];
          if (s != null) {
            account = Account(
              id: syntheticIdForSyncId(s.syncId),
              ledgerId: r.t.ledgerId,
              name: s.name,
              type: s.accountType,
              currency: s.currency,
              note: s.note,
              initialBalance: s.initialBalance ?? 0.0,
              sortOrder: 0,
              creditLimit: s.creditLimit,
              billingDay: s.billingDay,
              paymentDueDay: s.paymentDueDay,
              bankName: s.bankName,
              cardLastFour: s.cardLastFour,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              syncId: s.syncId,
            );
          }
        }
      }

      final txSid = r.t.syncId;
      if (txSid != null && tagOverridesByTxSyncId.containsKey(txSid)) {
        final extra = <Tag>[];
        for (final tagSid in tagOverridesByTxSyncId[txSid]!) {
          final s = sharedTagBySyncId[tagSid];
          if (s != null) {
            extra.add(Tag(
              id: syntheticIdForSyncId(s.syncId),
              name: s.name,
              color: s.color,
              sortOrder: 0,
              createdAt: DateTime.now(),
              syncId: s.syncId,
            ));
          }
        }
        if (extra.isNotEmpty) tags = [...tags, ...extra];
      }

      return (
        t: r.t,
        category: category,
        tags: tags,
        attachments: r.attachments,
        account: account,
      );
    }).toList();
  }

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
  }) async {
    // 查询时间范围内的所有交易
    final transactions = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(startDate, endDate))
          ..orderBy([
            (t) => d.OrderingTerm(
                  expression: t.happenedAt,
                  mode: d.OrderingMode.desc,
                ),
          ]))
        .get();

    // 批量获取所有相关的 category, tags, attachments, account
    final result = <({
      Transaction t,
      Category? category,
      List<Tag> tags,
      List<TransactionAttachment> attachments,
      Account? account,
    })>[];

    for (final transaction in transactions) {
      // 获取分类
      Category? category;
      if (transaction.categoryId != null) {
        category = await (db.select(db.categories)
              ..where((c) => c.id.equals(transaction.categoryId!)))
            .getSingleOrNull();
      }

      // 获取标签
      final tagRelations = await (db.select(db.transactionTags)
            ..where((tt) => tt.transactionId.equals(transaction.id)))
          .get();

      final tags = <Tag>[];
      for (final rel in tagRelations) {
        final tag = await (db.select(db.tags)
              ..where((t) => t.id.equals(rel.tagId)))
            .getSingleOrNull();
        if (tag != null) tags.add(tag);
      }

      // 获取附件
      final attachments = await (db.select(db.transactionAttachments)
            ..where((a) => a.transactionId.equals(transaction.id)))
          .get();

      // 获取账户
      Account? account;
      if (transaction.accountId != null) {
        account = await (db.select(db.accounts)
              ..where((a) => a.id.equals(transaction.accountId!)))
            .getSingleOrNull();
      }

      result.add((
        t: transaction,
        category: category,
        tags: tags,
        attachments: attachments,
        account: account,
      ));
    }

    return _hydrateSharedOverridesFull(result);
  }

  @override
  Future<List<String>> getTransactionDatesByMonth({
    required int ledgerId,
    required DateTime month,
  }) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final query = '''
      SELECT DISTINCT DATE(happened_at) as date
      FROM transactions
      WHERE ledger_id = ?
        AND happened_at >= ?
        AND happened_at <= ?
      ORDER BY date DESC
    ''';

    final results = await db.customSelect(
      query,
      variables: [
        d.Variable.withInt(ledgerId),
        d.Variable.withDateTime(startDate),
        d.Variable.withDateTime(endDate),
      ],
    ).get();

    return results
        .map((row) => row.read<String?>('date'))
        .where((date) => date != null)
        .cast<String>()
        .toList();
  }

  // ==================== syncId 相关 ====================

  @override
  Future<Transaction?> getTransactionBySyncId(String syncId) async {
    return await (db.select(db.transactions)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
  }

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
  }) async {
    await (db.update(db.transactions)..where((t) => t.syncId.equals(syncId)))
        .write(TransactionsCompanion(
      type: d.Value(type),
      amount: d.Value(amount),
      categoryId: d.Value(categoryId),
      accountId: d.Value(accountId),
      toAccountId: d.Value(toAccountId),
      happenedAt: d.Value(happenedAt),
      note: d.Value(note),
    ));
  }

  @override
  Future<void> deleteTransactionBySyncId(String syncId) async {
    // 先查找交易ID，以便删除关联数据
    final tx = await getTransactionBySyncId(syncId);
    if (tx != null) {
      await deleteTransaction(tx.id);
    }
  }

  @override
  Future<Map<String, int>> updateTransactionsBatchBySyncId(
    List<TransactionUpdateBySyncIdData> updates, {
    bool recordChanges = true,
  }) async {
    if (updates.isEmpty) return const {};
    return db.transaction(() async {
      await db.batch((b) {
        for (final u in updates) {
          b.update(
            db.transactions,
            TransactionsCompanion(
              type: d.Value(u.type),
              amount: d.Value(u.amount),
              categoryId: d.Value(u.categoryId),
              accountId: d.Value(u.accountId),
              toAccountId: d.Value(u.toAccountId),
              happenedAt: d.Value(u.happenedAt),
              note: d.Value(u.note),
            ),
            where: (t) => t.syncId.equals(u.syncId),
          );
        }
      });
      // 反查 (syncId, txId) 映射,caller 用它批量更新 tag 关联
      final syncIds = updates.map((u) => u.syncId).toList();
      final rows = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      return {
        for (final tx in rows)
          if (tx.syncId != null) tx.syncId!: tx.id,
      };
    });
  }

  @override
  Future<int> deleteTransactionsBatchBySyncIds(
    List<String> syncIds, {
    bool recordChanges = true,
  }) async {
    // recordChanges 由 LocalRepository wrapper 处理(子仓库无 changeTracker)。
    if (syncIds.isEmpty) return 0;
    return db.transaction(() async {
      // 先 SELECT 拿到 tx id 列表(用来删 transactionTags / attachments 关联)
      final rows = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      final txIds = rows.map((r) => r.id).toList();
      if (txIds.isEmpty) return 0;
      // 删关联数据(级联)
      await (db.delete(db.transactionTags)
            ..where((t) => t.transactionId.isIn(txIds)))
          .go();
      await (db.delete(db.transactionAttachments)
            ..where((t) => t.transactionId.isIn(txIds)))
          .go();
      // 主表 DELETE WHERE IN — 一次 SQL 删 N 条
      final deleted = await (db.delete(db.transactions)
            ..where((t) => t.id.isIn(txIds)))
          .go();
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
  }) async {
    return await addTransaction(
      ledgerId: ledgerId,
      type: 'adjustment',
      amount: amount,
      accountId: accountId,
      happenedAt: happenedAt,
      note: note,
    );
  }
}
